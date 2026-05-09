import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  static const List<String> _topics = <String>[
    'General Inquiry',
    'Technical Issue',
    'Payment Help',
    'Contest Support',
  ];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _sending = false;
  bool _showSuccess = false;
  String _selectedTopic = _topics.first;
  XFile? _imageAttachment;
  XFile? _videoAttachment;

  DocumentReference<Map<String, dynamic>> get _threadRef => FirebaseFirestore
      .instance
      .collection('support_threads')
      .doc(widget.threadId);

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (!mounted || file == null) return;
    setState(() => _imageAttachment = file);
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (!mounted || file == null) return;
    setState(() => _videoAttachment = file);
  }

  Future<Map<String, dynamic>?> _uploadAttachment({
    required String uid,
    required XFile file,
    required String kind,
  }) async {
    final bytes = await file.readAsBytes();
    final path =
        'support_attachments/$uid/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: kind == 'image' ? 'image/jpeg' : 'video/mp4',
      ),
    );
    final url = await ref.getDownloadURL();
    return <String, dynamic>{
      'type': kind,
      'url': url,
      'name': file.name,
      'size': bytes.length,
    };
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    final hasAttachment = _imageAttachment != null || _videoAttachment != null;
    if ((text.isEmpty && !hasAttachment) || _sending) return;
    final auth = FirebaseAuth.instance.currentUser;
    if (auth == null) return;

    setState(() {
      _sending = true;
      _showSuccess = false;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uid)
          .get();
      final userData = userDoc.data() ?? const <String, dynamic>{};
      final existingThread = widget.isAdmin ? await _threadRef.get() : null;
      final existingThreadData =
          existingThread?.data() ?? const <String, dynamic>{};
      final senderRole = widget.isAdmin
          ? 'admin'
          : (userData['role'] ?? 'user').toString();
      final senderName =
          (userData['displayName'] ?? auth.displayName ?? auth.email ?? 'User')
              .toString();
      final now = Timestamp.now();

      final attachments = <Map<String, dynamic>>[];
      if (_imageAttachment != null) {
        final uploaded = await _uploadAttachment(
          uid: auth.uid,
          file: _imageAttachment!,
          kind: 'image',
        );
        if (uploaded != null) attachments.add(uploaded);
      }
      if (_videoAttachment != null) {
        final uploaded = await _uploadAttachment(
          uid: auth.uid,
          file: _videoAttachment!,
          kind: 'video',
        );
        if (uploaded != null) attachments.add(uploaded);
      }

      final lastMessage = text.isNotEmpty
          ? text
          : attachments.isNotEmpty
          ? context.tr('Attachment sent')
          : '';

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
        'inquiryType': widget.isAdmin
            ? (existingThreadData['inquiryType'] ?? _selectedTopic)
            : _selectedTopic,
        'lastMessage': lastMessage,
        'lastMessageAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      await _threadRef.collection('messages').add({
        'text': text,
        'senderId': auth.uid,
        'senderRole': senderRole,
        'senderName': senderName,
        'createdAt': now,
        'inquiryType': _selectedTopic,
        'attachments': attachments,
      });

      _messageController.clear();
      setState(() {
        _imageAttachment = null;
        _videoAttachment = null;
        _showSuccess = true;
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
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
    return widget.isAdmin
        ? _buildAdminChat(context)
        : _buildSupportComposer(context);
  }

  Widget _buildSupportComposer(BuildContext context) {
    final canSend =
        !_sending &&
        (_messageController.text.trim().isNotEmpty ||
            _imageAttachment != null ||
            _videoAttachment != null);

    return Scaffold(
      backgroundColor: const Color(0xFF07121B),
      appBar: AppBar(title: Text(context.tr('Support'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Text(
            context.tr('How can we help you?'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            child: DropdownButtonFormField<String>(
              value: _selectedTopic,
              dropdownColor: const Color(0xFF0E1A25),
              decoration: InputDecoration(
                hintText: context.tr('General Inquiry'),
                filled: true,
                fillColor: const Color(0xFF0E1A25),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF263646)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF263646)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.hotPink,
                    width: 1.5,
                  ),
                ),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              iconEnabledColor: Colors.white,
              items: _topics
                  .map(
                    (topic) => DropdownMenuItem<String>(
                      value: topic,
                      child: Text(context.tr(topic)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedTopic = value);
              },
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            child: TextField(
              controller: _messageController,
              maxLines: 6,
              minLines: 6,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: context.tr('Write your message...'),
                hintStyle: const TextStyle(
                  color: Color(0xFF97A5B3),
                  fontSize: 17,
                ),
                filled: true,
                fillColor: const Color(0xFF0E1A25),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF263646)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF263646)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.hotPink,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF07121B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFFF4D6D).withValues(alpha: 0.75),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Attachments'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _attachmentButton(
                      icon: Icons.image_outlined,
                      selected: _imageAttachment != null,
                      label: _imageAttachment?.name ?? context.tr('Image'),
                      onTap: _pickImage,
                    ),
                    const SizedBox(width: 12),
                    _attachmentButton(
                      icon: Icons.videocam_outlined,
                      selected: _videoAttachment != null,
                      label: _videoAttachment?.name ?? context.tr('Video'),
                      onTap: _pickVideo,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: canSend ? _send : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hotPink,
                disabledBackgroundColor: AppColors.hotPink.withValues(
                  alpha: 0.35,
                ),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _sending ? context.tr('Sending...') : context.tr('Send'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (_showSuccess) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF091D11),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF65D96D), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF65D96D),
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('Message sent successfully'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          _buildConversationPanel(context),
        ],
      ),
    );
  }

  Widget _buildAdminChat(BuildContext context) {
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
                final currentUserId =
                    FirebaseAuth.instance.currentUser?.uid ?? '';
                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final isMine =
                        (data['senderId'] ?? '').toString() == currentUserId;
                    final senderName = (data['senderName'] ?? '').toString();
                    final text = (data['text'] ?? '').toString();
                    final inquiryType = (data['inquiryType'] ?? '').toString();
                    final rawAttachments =
                        (data['attachments'] as List<dynamic>? ??
                                const <dynamic>[])
                            .cast<Map<String, dynamic>>();
                    final dt = (data['createdAt'] as Timestamp?)?.toDate();
                    final timeText = dt == null
                        ? ''
                        : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMine
                                ? AppColors.hotPink.withValues(alpha: 0.18)
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isMine
                                  ? AppColors.hotPink
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                senderName,
                                style: TextStyle(
                                  color: isMine
                                      ? AppColors.hotPink
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (inquiryType.isNotEmpty && !isMine) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0E1A25),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    context.tr(inquiryType),
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (text.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              if (rawAttachments.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ...rawAttachments.map(_buildAttachmentPreview),
                              ],
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

  Widget _panel({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07121B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _buildConversationPanel(BuildContext context) {
    final stream = _threadRef
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (snapshot.connectionState != ConnectionState.active &&
            docs.isEmpty) {
          return const SizedBox.shrink();
        }
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1620),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF223240)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Support Replies'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              ...docs.map((doc) {
                final data = doc.data();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildMessageBubble(
                    context: context,
                    data: data,
                    isMine:
                        (data['senderId'] ?? '').toString() == currentUserId,
                    showInquiryType: false,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _attachmentButton({
    required IconData icon,
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1A25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.hotPink : const Color(0xFF334354),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(Map<String, dynamic> attachment) {
    final type = (attachment['type'] ?? '').toString();
    final name = (attachment['name'] ?? '').toString();
    final url = (attachment['url'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1A25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334354)),
        ),
        child: Row(
          children: [
            Icon(
              type == 'video' ? Icons.videocam_outlined : Icons.image_outlined,
              color: AppColors.hotPink,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name.isNotEmpty ? name : url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required BuildContext context,
    required Map<String, dynamic> data,
    required bool isMine,
    required bool showInquiryType,
  }) {
    final senderName = (data['senderName'] ?? '').toString();
    final text = (data['text'] ?? '').toString();
    final inquiryType = (data['inquiryType'] ?? '').toString();
    final rawAttachments =
        (data['attachments'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
    final dt = (data['createdAt'] as Timestamp?)?.toDate();
    final timeText = dt == null
        ? ''
        : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
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
              if (showInquiryType && inquiryType.isNotEmpty && !isMine) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1A25),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    context.tr(inquiryType),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (text.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
              if (rawAttachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...rawAttachments.map(_buildAttachmentPreview),
              ],
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
  }
}
