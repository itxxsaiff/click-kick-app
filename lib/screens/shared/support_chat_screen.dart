import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({
    super.key,
    required this.threadId,
    required this.title,
    this.subtitle,
    this.isAdmin = false,
  });

  final String threadId;
  final String title;
  final String? subtitle;
  final bool isAdmin;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  DocumentReference<Map<String, dynamic>> get _threadRef =>
      FirebaseFirestore.instance.collection('support_threads').doc(widget.threadId);

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    final auth = FirebaseAuth.instance.currentUser;
    if (auth == null) return;

    setState(() => _sending = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uid)
          .get();
      final userData = userDoc.data() ?? const <String, dynamic>{};
      final existingThread =
          widget.isAdmin ? await _threadRef.get() : null;
      final existingThreadData =
          existingThread?.data() ?? const <String, dynamic>{};
      final senderRole = widget.isAdmin
          ? 'admin'
          : (userData['role'] ?? 'user').toString();
      final senderName =
          (userData['displayName'] ?? auth.displayName ?? auth.email ?? 'User')
              .toString();
      final now = Timestamp.now();

      await _threadRef.set({
        'userId': widget.isAdmin ? widget.threadId : auth.uid,
        'userName': widget.isAdmin
            ? (existingThreadData['userName'] ?? widget.title)
            : senderName,
        'userEmail': widget.isAdmin
            ? (existingThreadData['userEmail'] ?? widget.subtitle ?? '')
            : (auth.email ?? ''),
        'userRole': widget.isAdmin
            ? (existingThreadData['userRole'] ?? 'user')
            : senderRole,
        'lastMessage': text,
        'lastMessageAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      await _threadRef.collection('messages').add({
        'text': text,
        'senderId': auth.uid,
        'senderRole': senderRole,
        'senderName': senderName,
        'createdAt': now,
      });

      _messageController.clear();
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = _threadRef
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            if ((widget.subtitle ?? '').isNotEmpty)
              Text(
                widget.subtitle!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? const [];
                if (snapshot.connectionState != ConnectionState.active &&
                    docs.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                _scrollToBottom();
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      context.tr('Start the conversation.'),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final isMine = (data['senderId'] ?? '').toString() == currentUserId;
                    final senderName = (data['senderName'] ?? '').toString();
                    final text = (data['text'] ?? '').toString();
                    final dt = (data['createdAt'] as Timestamp?)?.toDate();
                    final timeText = dt == null
                        ? ''
                        : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    return Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMine
                                ? AppColors.hotPink.withValues(alpha: 0.18)
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isMine ? AppColors.hotPink : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                senderName,
                                style: TextStyle(
                                  color: isMine ? AppColors.hotPink : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              if (timeText.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    timeText,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: context.tr('Type your message'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.hotPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      _sending ? context.tr('Sending...') : context.tr('Send'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
