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
    this.deletedFor = const [],
    this.deletedForEveryone = false,
    this.replyToId = '',
    this.replyToSenderId = '',
    this.replyToType = '',
    this.replyToText = '',
  });

  final String id;
  final String senderId;

  /// 'text' | 'image' | 'video' | 'audio'.
  final String type;
  final String text;
  final String mediaUrl;
  final int durationMs;
  final DateTime? createdAt;

  /// Uids who chose "delete for me" — hidden only in their own view.
  final List<String> deletedFor;

  /// The sender chose "delete for everyone" — shown as a placeholder to
  /// both sides instead of the real content.
  final bool deletedForEveryone;

  /// A quoted-reply preview, denormalized onto the reply itself so showing
  /// it never needs a second read. Empty `replyToId` means not a reply.
  final String replyToId;
  final String replyToSenderId;
  final String replyToType;
  final String replyToText;

  bool get isReply => replyToId.isNotEmpty;

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
      replyToId: (data['replyToId'] ?? '').toString(),
      replyToSenderId: (data['replyToSenderId'] ?? '').toString(),
      replyToType: (data['replyToType'] ?? '').toString(),
      replyToText: (data['replyToText'] ?? '').toString(),
      deletedFor: (data['deletedFor'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      deletedForEveryone: data['deletedForEveryone'] == true,
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

  /// Whether [otherUserId] has blocked the current user (so they shouldn't
  /// be able to message them). Same `users/{uid}.blockedUserIds` list the
  /// rest of the app already uses for blocking video content.
  Future<bool> _blockedByRecipient(String otherUserId) async {
    final me = currentUserId;
    if (me == null) return false;
    final snap = await _firestore.collection('users').doc(otherUserId).get();
    final blocked = (snap.data()?['blockedUserIds'] as List?) ?? const [];
    return blocked.map((e) => e.toString()).contains(me);
  }

  /// Throws `login-required` when signed out, `cannot-chat-self`, or
  /// `blocked-by-recipient` when the other user has blocked this account.
  Future<String> getOrCreateChat(String otherUserId) async {
    final me = currentUserId;
    if (me == null) throw Exception('login-required');
    if (otherUserId.isEmpty || otherUserId == me) {
      throw Exception('cannot-chat-self');
    }
    if (await _blockedByRecipient(otherUserId)) {
      throw Exception('blocked-by-recipient');
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
          (snap) => snap.docs.map((d) => ChatSummary.fromDoc(d, me)).toList(),
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

  /// The other participant in [chatId], or null if the chat doc is missing.
  Future<String?> _otherParticipant(String chatId) async {
    final me = currentUserId;
    if (me == null) return null;
    final snap = await _chats.doc(chatId).get();
    final participants = (snap.data()?['participants'] as List? ?? const [])
        .map((e) => e.toString());
    return participants.firstWhere((id) => id != me, orElse: () => '');
  }

  /// Denormalized quoted-reply fields for a new message, or `{}` when not
  /// replying to anything.
  Map<String, dynamic> _replyFields(ChatMessage? replyTo) {
    if (replyTo == null) return const {};
    final preview = switch (replyTo.type) {
      'image' => '📷 Photo',
      'video' => '🎬 Video',
      'audio' => '🎤 Voice message',
      _ => replyTo.text,
    };
    return {
      'replyToId': replyTo.id,
      'replyToSenderId': replyTo.senderId,
      'replyToType': replyTo.type,
      'replyToText': preview,
    };
  }

  Future<void> sendText(
    String chatId,
    String text, {
    ChatMessage? replyTo,
  }) async {
    final me = currentUserId;
    if (me == null) throw Exception('login-required');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final other = await _otherParticipant(chatId);
    if (other != null && other.isNotEmpty && await _blockedByRecipient(other)) {
      throw Exception('blocked-by-recipient');
    }
    await _chats.doc(chatId).collection('messages').add({
      'senderId': me,
      'type': 'text',
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      ..._replyFields(replyTo),
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
    ChatMessage? replyTo,
  }) async {
    final me = currentUserId;
    if (me == null) throw Exception('login-required');
    final other = await _otherParticipant(chatId);
    if (other != null && other.isNotEmpty && await _blockedByRecipient(other)) {
      throw Exception('blocked-by-recipient');
    }
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
      ..._replyFields(replyTo),
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

  /// Hides a message in the current user's own view only — the other
  /// participant still sees it.
  Future<void> deleteForMe(String chatId, String messageId) async {
    final me = currentUserId;
    if (me == null) throw Exception('login-required');
    await _chats.doc(chatId).collection('messages').doc(messageId).update({
      'deletedFor': FieldValue.arrayUnion([me]),
    });
  }

  /// Replaces a message with a "deleted" placeholder for both sides.
  /// Only the original sender can do this (enforced by Firestore rules too).
  Future<void> deleteForEveryone(String chatId, String messageId) async {
    final me = currentUserId;
    if (me == null) throw Exception('login-required');
    await _chats.doc(chatId).collection('messages').doc(messageId).update({
      'deletedForEveryone': true,
    });
  }

  /// Re-sends [message]'s content (text, or the same media URL — no
  /// re-upload) as a new message in [targetChatId].
  Future<void> forwardMessage(String targetChatId, ChatMessage message) async {
    final me = currentUserId;
    if (me == null) throw Exception('login-required');
    final other = await _otherParticipant(targetChatId);
    if (other != null && other.isNotEmpty && await _blockedByRecipient(other)) {
      throw Exception('blocked-by-recipient');
    }
    await _chats.doc(targetChatId).collection('messages').add({
      'senderId': me,
      'type': message.type,
      'text': message.text,
      'mediaUrl': message.mediaUrl,
      if (message.durationMs > 0) 'durationMs': message.durationMs,
      'createdAt': FieldValue.serverTimestamp(),
      'forwarded': true,
    });
  }
}
