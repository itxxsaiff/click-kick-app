import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// One message in a 1-on-1 chat (`chats/{chatId}/messages/{id}`).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.text,
    required this.mediaUrl,
    required this.durationMs,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  /// 'text' | 'image' | 'video' | 'audio'.
  final String type;
  final String text;
  final String mediaUrl;
  final int durationMs;
  final DateTime? createdAt;

  factory ChatMessage.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] ?? '').toString(),
      type: (data['type'] ?? 'text').toString(),
      text: (data['text'] ?? '').toString(),
      mediaUrl: (data['mediaUrl'] ?? '').toString(),
      durationMs: ((data['durationMs'] ?? 0) as num).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// One row in the chat inbox (`chats/{chatId}`).
class ChatSummary {
  const ChatSummary({
    required this.chatId,
    required this.otherUserId,
    required this.lastMessageText,
    required this.lastMessageType,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String chatId;
  final String otherUserId;
  final String lastMessageText;
  final String lastMessageType;
  final DateTime? lastMessageAt;
  final int unreadCount;

  factory ChatSummary.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String myUid,
  ) {
    final data = doc.data();
    final participants = (data['participants'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final otherUserId = participants.firstWhere(
      (id) => id != myUid,
      orElse: () => '',
    );
    final unreadCounts = (data['unreadCounts'] as Map?) ?? const {};
    return ChatSummary(
      chatId: doc.id,
      otherUserId: otherUserId,
      lastMessageText: (data['lastMessageText'] ?? '').toString(),
      lastMessageType: (data['lastMessageType'] ?? 'text').toString(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCount: ((unreadCounts[myUid] ?? 0) as num).toInt(),
    );
  }
}

/// 1-on-1 direct messages: text, photos, videos (picked from the gallery)
/// and voice notes. Anyone can message anyone (no follow requirement), same
/// as most social apps' DMs.
class ChatService {
  ChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Deterministic doc id for the chat between two users, independent of
  /// call order, so both sides always resolve the same document.
  String chatIdFor(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  /// Throws `login-required` when signed out, `cannot-chat-self`.
  Future<String> getOrCreateChat(String otherUserId) async {
    final me = currentUserId;
    if (me == null) throw Exception('login-required');
    if (otherUserId.isEmpty || otherUserId == me) {
      throw Exception('cannot-chat-self');
    }
    final chatId = chatIdFor(me, otherUserId);
    final ref = _chats.doc(chatId);
    final snap = await ref.get();
    if (!snap.exists) {
      final participants = [me, otherUserId]..sort();
      await ref.set({
        'participants': participants,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': '',
        'lastMessageType': 'text',
        'lastSenderId': '',
        'unreadCounts': {me: 0, otherUserId: 0},
      });
    }
    return chatId;
  }

  /// Live inbox: every chat the current user is in, newest first.
  Stream<List<ChatSummary>> chatsStream() {
    final me = currentUserId;
    if (me == null) return Stream<List<ChatSummary>>.value(const []);
    return _chats
        .where('participants', arrayContains: me)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => ChatSummary.fromDoc(d, me)).toList(),
        );
  }

  /// Live total unread count across every chat, for a badge on the inbox
  /// entry point.
  Stream<int> totalUnreadStream() {
    return chatsStream().map(
      (chats) => chats.fold<int>(0, (total, c) => total + c.unreadCount),
    );
  }

  Stream<List<ChatMessage>> messagesStream(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(300)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> sendText(String chatId, String text) async {
    final me = currentUserId;
    if (me == null) throw Exception('login-required');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _chats.doc(chatId).collection('messages').add({
      'senderId': me,
      'type': 'text',
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Uploads an image/video/audio file and sends it as a message.
  /// [bytes] is used on web, [file] on mobile/desktop — pass whichever one
  /// the picker returned.
  Future<void> sendMedia(
    String chatId, {
    required String type,
    File? file,
    Uint8List? bytes,
    required String extension,
    int durationMs = 0,
  }) async {
    final me = currentUserId;
    if (me == null) throw Exception('login-required');
    final path =
        'chat_media/$chatId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref().child(path);
    final contentType = type == 'image'
        ? 'image/jpeg'
        : type == 'video'
        ? 'video/mp4'
        : 'audio/m4a';
    final metadata = SettableMetadata(contentType: contentType);

    if (kIsWeb) {
      if (bytes == null) throw Exception('missing-bytes');
      await ref.putData(bytes, metadata);
    } else {
      if (file == null) throw Exception('missing-file');
      await ref.putFile(file, metadata);
    }
    final url = await ref.getDownloadURL();

    await _chats.doc(chatId).collection('messages').add({
      'senderId': me,
      'type': type,
      'mediaUrl': url,
      if (durationMs > 0) 'durationMs': durationMs,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Resets the current user's unread count for [chatId] (call when a chat
  /// is opened).
  Future<void> markRead(String chatId) async {
    final me = currentUserId;
    if (me == null) return;
    await _chats.doc(chatId).set({
      'unreadCounts': {me: 0},
    }, SetOptions(merge: true));
  }
}
