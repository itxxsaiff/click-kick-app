import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../l10n/l10n.dart';
import '../../services/chat_service.dart';
import '../../services/follow_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/follow_widgets.dart';
import '../profile/general_video_player_screen.dart'
    show SimpleVideoPlayerScreen;
import '../profile/user_profile_screen.dart';

/// 1-on-1 chat: text, photos, videos (from the gallery) and voice notes.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhotoUrl,
  });

  final String otherUserId;
  final String otherUserName;
  final String otherUserPhotoUrl;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = ChatService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _audioPlayer = AudioPlayer();
  // Created lazily, mobile-only: on web, just constructing this plugin
  // object can throw/crash the page before it even renders, since the
  // underlying JS interop expects a real recording environment. Voice
  // messages are mobile-only anyway (see _startRecording), so there is
  // never a reason to touch this on web.
  AudioRecorder? _recorder;
  AudioRecorder _ensureRecorder() => _recorder ??= AudioRecorder();

  String? _chatId;
  bool _showEmoji = false;
  bool _sendingMedia = false;
  bool _recording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String? _playingMessageId;
  ChatMessage? _replyingTo;
  final Set<String> _selectedIds = <String>{};
  bool get _inSelectionMode => _selectedIds.isNotEmpty;

  void _toggleSelect(ChatMessage message) {
    setState(() {
      if (!_selectedIds.remove(message.id)) _selectedIds.add(message.id);
    });
  }

  void _exitSelection() => setState(_selectedIds.clear);

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// `blocked-by-recipient` gets its own clear message everywhere a send
  /// can fail for that reason; anything else falls back to [fallback].
  String _errorMessage(Object e, String fallback) {
    if (e.toString().contains('blocked-by-recipient')) {
      return context.tr('You can\'t message this user.');
    }
    return context.tr(fallback);
  }

  Future<void> _init() async {
    try {
      final chatId = await _service.getOrCreateChat(widget.otherUserId);
      if (!mounted) return;
      setState(() => _chatId = chatId);
      await _service.markRead(chatId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e, 'Could not open chat.'))),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _recorder?.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendText() async {
    final chatId = _chatId;
    final text = _textController.text.trim();
    if (chatId == null || text.isEmpty) return;
    final replyTo = _replyingTo;
    _textController.clear();
    setState(() => _replyingTo = null);
    try {
      await _service.sendText(chatId, text, replyTo: replyTo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e, 'Message failed to send.'))),
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    final chatId = _chatId;
    if (chatId == null) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final replyTo = _replyingTo;
    setState(() {
      _sendingMedia = true;
      _replyingTo = null;
    });
    try {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await _service.sendMedia(
          chatId,
          type: 'image',
          bytes: bytes,
          extension: 'jpg',
          replyTo: replyTo,
        );
      } else {
        await _service.sendMedia(
          chatId,
          type: 'image',
          file: File(picked.path),
          extension: 'jpg',
          replyTo: replyTo,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e, 'Could not send photo.'))),
        );
      }
    }
    if (mounted) setState(() => _sendingMedia = false);
  }

  Future<void> _pickAndSendVideo() async {
    final chatId = _chatId;
    if (chatId == null) return;
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final replyTo = _replyingTo;
    setState(() {
      _sendingMedia = true;
      _replyingTo = null;
    });
    try {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await _service.sendMedia(
          chatId,
          type: 'video',
          bytes: bytes,
          extension: 'mp4',
          replyTo: replyTo,
        );
      } else {
        await _service.sendMedia(
          chatId,
          type: 'video',
          file: File(picked.path),
          extension: 'mp4',
          replyTo: replyTo,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e, 'Could not send video.'))),
        );
      }
    }
    if (mounted) setState(() => _sendingMedia = false);
  }

  Future<void> _startRecording() async {
    if (kIsWeb) {
      // Web recording to a re-uploadable file needs a different (byte
      // stream) path than mobile's file-based API; keeping voice notes to
      // mobile for now rather than shipping a half-working web recorder.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Voice messages need the mobile app.')),
        ),
      );
      return;
    }
    final recorder = _ensureRecorder();
    final allowed = await recorder.hasPermission();
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Microphone permission needed.'))),
      );
      return;
    }
    final dir = Directory.systemTemp;
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    setState(() {
      _recording = true;
      _recordDuration = Duration.zero;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _recordTimer?.cancel();
    final path = await _recorder?.stop();
    final duration = _recordDuration;
    if (!mounted) return;
    setState(() => _recording = false);
    if (!send || path == null) return;
    final chatId = _chatId;
    if (chatId == null) return;
    final replyTo = _replyingTo;
    setState(() {
      _sendingMedia = true;
      _replyingTo = null;
    });
    try {
      await _service.sendMedia(
        chatId,
        type: 'audio',
        file: File(path),
        extension: 'm4a',
        durationMs: duration.inMilliseconds,
        replyTo: replyTo,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage(e, 'Could not send voice message.')),
          ),
        );
      }
    }
    if (mounted) setState(() => _sendingMedia = false);
  }

  Future<void> _togglePlayAudio(ChatMessage message) async {
    if (_playingMessageId == message.id) {
      await _audioPlayer.stop();
      setState(() => _playingMessageId = null);
      return;
    }
    try {
      await _audioPlayer.setUrl(message.mediaUrl);
      setState(() => _playingMessageId = message.id);
      await _audioPlayer.play();
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _playingMessageId = null);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _playingMessageId = null);
    }
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final chatId = _chatId;
    if (chatId == null) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMine = message.senderId == myUid;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.white),
              title: Text(
                sheetContext.tr('Reply'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(sheetContext, 'reply'),
            ),
            if (message.type == 'text')
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white),
                title: Text(
                  sheetContext.tr('Copy'),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(sheetContext, 'copy'),
              ),
            ListTile(
              leading: const Icon(Icons.forward_rounded, color: Colors.white),
              title: Text(
                sheetContext.tr('Forward'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(sheetContext, 'forward'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.white),
              title: Text(
                sheetContext.tr('Delete for me'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete_me'),
            ),
            if (isMine)
              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                ),
                title: Text(
                  sheetContext.tr('Delete for everyone'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete_everyone'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'reply':
        setState(() => _replyingTo = message);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Copied to clipboard.'))),
          );
        }
        break;
      case 'forward':
        await _forwardMessage(message);
        break;
      case 'delete_me':
        try {
          await _service.deleteForMe(chatId, message.id);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('Could not delete message.'))),
            );
          }
        }
        break;
      case 'delete_everyone':
        try {
          await _service.deleteForEveryone(chatId, message.id);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('Could not delete message.'))),
            );
          }
        }
        break;
    }
  }

  Future<void> _forwardMessage(ChatMessage message) async {
    final targetChatId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _ForwardPickerScreen()),
    );
    if (targetChatId == null || !mounted) return;
    try {
      await _service.forwardMessage(targetChatId, message);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Message forwarded.'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e, 'Could not forward message.'))),
      );
    }
  }

  Future<void> _forwardSelected(List<ChatMessage> selected) async {
    final targetChatId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _ForwardPickerScreen()),
    );
    if (targetChatId == null || !mounted) return;
    final ordered = [...selected]
      ..sort((a, b) {
        final at = a.createdAt ?? DateTime(2000);
        final bt = b.createdAt ?? DateTime(2000);
        return at.compareTo(bt);
      });
    var failed = 0;
    for (final message in ordered) {
      try {
        await _service.forwardMessage(targetChatId, message);
      } catch (_) {
        failed++;
      }
    }
    _exitSelection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? context.tr('Message forwarded.')
              : context.tr('Could not forward message.'),
        ),
      ),
    );
  }

  Future<void> _deleteSelected(List<ChatMessage> selected) async {
    final chatId = _chatId;
    if (chatId == null) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final allMine = selected.every((m) => m.senderId == myUid);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.white),
              title: Text(
                sheetContext.tr('Delete for me'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete_me'),
            ),
            if (allMine)
              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                ),
                title: Text(
                  sheetContext.tr('Delete for everyone'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete_everyone'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    _exitSelection();
    for (final message in selected) {
      try {
        if (action == 'delete_everyone') {
          await _service.deleteForEveryone(chatId, message.id);
        } else {
          await _service.deleteForMe(chatId, message.id);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: _chatId == null
                      ? const Center(child: CircularProgressIndicator())
                      : StreamBuilder<List<ChatMessage>>(
                          stream: _service.messagesStream(_chatId!),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  context.tr('Unable to load messages.'),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              );
                            }
                            final messages = (snapshot.data ?? const [])
                                .where((m) => !m.deletedFor.contains(myUid))
                                .toList();
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (messages.isEmpty) {
                              return Center(
                                child: Text(
                                  context.tr('Say hi 👋'),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              );
                            }
                            final selected = messages
                                .where((m) => _selectedIds.contains(m.id))
                                .toList();
                            final messagesById = {
                              for (final m in messages) m.id: m,
                            };
                            return Column(
                              children: [
                                if (_inSelectionMode)
                                  _buildSelectionBar(context, selected),
                                Expanded(
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    reverse: true,
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      12,
                                      12,
                                      12,
                                    ),
                                    itemCount: messages.length,
                                    itemBuilder: (context, i) {
                                      final message = messages[i];
                                      return _MessageBubble(
                                        message: message,
                                        isMine: message.senderId == myUid,
                                        myUid: myUid,
                                        otherUserName: widget.otherUserName,
                                        isPlayingAudio:
                                            _playingMessageId == message.id,
                                        selected: _selectedIds.contains(
                                          message.id,
                                        ),
                                        selectionMode: _inSelectionMode,
                                        onToggleSelect: () =>
                                            _toggleSelect(message),
                                        onToggleAudio: () {
                                          if (_inSelectionMode) {
                                            _toggleSelect(message);
                                          } else {
                                            _togglePlayAudio(message);
                                          }
                                        },
                                        onOpenImage: (url) {
                                          if (_inSelectionMode) {
                                            _toggleSelect(message);
                                            return;
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  _ImageViewerScreen(url: url),
                                            ),
                                          );
                                        },
                                        onOpenVideo: (url) {
                                          if (_inSelectionMode) {
                                            _toggleSelect(message);
                                            return;
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  SimpleVideoPlayerScreen(
                                                    videoUrl: url,
                                                  ),
                                            ),
                                          );
                                        },
                                        onShowActions: () =>
                                            _showMessageActions(message),
                                        messagesById: messagesById,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                if (_sendingMedia)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (_replyingTo != null) _buildReplyPreview(context),
                _buildInputBar(context),
                if (_showEmoji)
                  SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        _textController.text += emoji.emoji;
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context, List<ChatMessage> selected) {
    final single = selected.length == 1 ? selected.first : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: AppColors.card,
      child: Row(
        children: [
          IconButton(
            onPressed: _exitSelection,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          Expanded(
            child: Text(
              '${selected.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          if (single != null) ...[
            if (single.type == 'text')
              IconButton(
                tooltip: context.tr('Copy'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: single.text));
                  _exitSelection();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Copied to clipboard.')),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, color: Colors.white),
              ),
            IconButton(
              tooltip: context.tr('Reply'),
              onPressed: () {
                setState(() => _replyingTo = single);
                _exitSelection();
              },
              icon: const Icon(Icons.reply_rounded, color: Colors.white),
            ),
          ],
          IconButton(
            tooltip: context.tr('Forward'),
            onPressed: () => _forwardSelected(selected),
            icon: const Icon(Icons.forward_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: context.tr('Delete'),
            onPressed: () => _deleteSelected(selected),
            icon: const Icon(Icons.delete_outline, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: widget.otherUserId),
                ),
              ),
              child: Row(
                children: [
                  UserAvatar(photoUrl: widget.otherUserPhotoUrl, size: 38),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.otherUserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
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

  Widget _buildReplyPreview(BuildContext context) {
    final replying = _replyingTo!;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final senderLabel = replying.senderId == myUid
        ? context.tr('You')
        : widget.otherUserName;
    final preview = switch (replying.type) {
      'image' => '📷 ${context.tr('Photo')}',
      'video' => '🎬 ${context.tr('Video')}',
      'audio' => '🎤 ${context.tr('Voice message')}',
      _ => replying.text,
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: const Border(
          left: BorderSide(color: AppColors.hotPink, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senderLabel,
                  style: const TextStyle(
                    color: AppColors.hotPink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => setState(() => _replyingTo = null),
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    if (_recording) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.hotPink),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic, color: AppColors.hotPink),
            const SizedBox(width: 10),
            Text(
              '${_recordDuration.inMinutes.toString().padLeft(2, '0')}:'
              '${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _stopRecording(send: false),
              icon: const Icon(Icons.close, color: AppColors.textMuted),
            ),
            IconButton(
              onPressed: () => _stopRecording(send: true),
              icon: const Icon(Icons.send, color: AppColors.hotPink),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () => setState(() => _showEmoji = !_showEmoji),
            icon: Icon(
              Icons.emoji_emotions_outlined,
              color: _showEmoji ? AppColors.hotPink : AppColors.textMuted,
            ),
          ),
          IconButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: AppColors.card,
              builder: (sheetContext) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.image_outlined,
                        color: Colors.white,
                      ),
                      title: Text(
                        context.tr('Photo'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _pickAndSendImage();
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.videocam_outlined,
                        color: Colors.white,
                      ),
                      title: Text(
                        context.tr('Video'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _pickAndSendVideo();
                      },
                    ),
                  ],
                ),
              ),
            ),
            icon: const Icon(
              Icons.add_circle_outline,
              color: AppColors.textMuted,
            ),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: context.tr('Message...'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  // The app's global input theme fills every TextField and
                  // outlines it by default; without overriding all three of
                  // these (not just `border`) that theme shows through
                  // *inside* this pill container, looking like a box nested
                  // inside another box.
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onTap: () {
                  if (_showEmoji) setState(() => _showEmoji = false);
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedBuilder(
            animation: _textController,
            builder: (context, _) {
              final hasText = _textController.text.trim().isNotEmpty;
              return IconButton(
                onPressed: hasText ? _sendText : _startRecording,
                icon: Icon(
                  hasText ? Icons.send_rounded : Icons.mic_none_rounded,
                  color: AppColors.hotPink,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isPlayingAudio,
    required this.onToggleAudio,
    required this.onOpenImage,
    required this.onOpenVideo,
    required this.onShowActions,
    required this.otherUserName,
    required this.myUid,
    required this.selected,
    required this.selectionMode,
    required this.onToggleSelect,
    required this.messagesById,
  });

  final ChatMessage message;
  final bool isMine;
  final bool isPlayingAudio;
  final VoidCallback onToggleAudio;
  final ValueChanged<String> onOpenImage;
  final ValueChanged<String> onOpenVideo;
  final VoidCallback onShowActions;
  final String otherUserName;
  final String myUid;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onToggleSelect;
  final Map<String, ChatMessage> messagesById;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.hotPink : AppColors.card;
    // A visible "..." button next to the bubble, not just long-press: on
    // web, long-press means click-and-hold the mouse for ~500ms without
    // moving, which almost nobody discovers on their own.
    final moreButton = message.deletedForEveryone
        ? null
        : IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onShowActions,
            icon: Icon(
              Icons.more_vert,
              size: 18,
              color: AppColors.textMuted.withValues(alpha: 0.9),
            ),
          );
    final bubble = GestureDetector(
      // Long-press selects (WhatsApp-style); the "..." button above still
      // opens the single-message action sheet for a quicker Reply/Copy/
      // Forward/Delete without entering multi-select. Tap-to-toggle while
      // already in selection mode is handled by the row-wide wrapper below
      // so the whole row (not just the tightly-sized bubble) is tappable.
      onLongPress: message.deletedForEveryone ? null : onToggleSelect,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        padding: message.type == 'text' || message.deletedForEveryone
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
            : const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: selected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isReply && !message.deletedForEveryone)
              _buildReplyQuote(context),
            _buildContent(context),
            const SizedBox(height: 2),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );

    final checkmark = selectionMode && !message.deletedForEveryone
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.hotPink : AppColors.textMuted,
            ),
          )
        : null;

    final row = Row(
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: isMine
          ? [?checkmark, ?(selectionMode ? null : moreButton), bubble]
          : [bubble, ?(selectionMode ? null : moreButton), ?checkmark],
    );

    // While selecting, make the ENTIRE row tappable — not just the tightly
    // sized bubble — so taps that land on the checkmark's padding or the
    // empty space on the other side of the row still toggle selection.
    // Deleted-for-everyone messages can never be selected.
    if (selectionMode && !message.deletedForEveryone) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggleSelect,
        child: row,
      );
    }
    return row;
  }

  Widget _buildReplyQuote(BuildContext context) {
    final senderLabel = message.replyToSenderId == myUid
        ? context.tr('You')
        : otherUserName;
    final original = messagesById[message.replyToId];
    final preview = original != null && original.deletedForEveryone
        ? context.tr('This message was deleted')
        : message.replyToText;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: Colors.white, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.deletedForEveryone) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: 15,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            context.tr('This message was deleted'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
        ],
      );
    }
    switch (message.type) {
      case 'image':
        return GestureDetector(
          onTap: () => onOpenImage(message.mediaUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              message.mediaUrl,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 200,
                height: 200,
                color: AppColors.cardSoft,
                child: const Icon(Icons.broken_image, color: Colors.white54),
              ),
            ),
          ),
        );
      case 'video':
        return GestureDetector(
          onTap: () => onOpenVideo(message.mediaUrl),
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        );
      case 'audio':
        final seconds = (message.durationMs / 1000).round();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onToggleAudio,
                icon: Icon(
                  isPlayingAudio
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              Text(
                '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
                '${(seconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      default:
        return Text(
          message.text,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        );
    }
  }
}

class _ImageViewerScreen extends StatelessWidget {
  const _ImageViewerScreen({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Opens a chat by user id alone (e.g. a `/chat?userId=...` deep link from a
/// push notification), looking up the display name/photo first.
class ChatRouteLoader extends StatelessWidget {
  const ChatRouteLoader({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserBrief>(
      future: UserDirectory.get(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data!;
        return ChatScreen(
          otherUserId: userId,
          otherUserName: user.name.isNotEmpty ? user.name : context.tr('User'),
          otherUserPhotoUrl: user.photoUrl,
        );
      },
    );
  }
}

/// Pick one of the current user's existing conversations to forward a
/// message into. Pops with the chosen chat id, or null if cancelled.
class _ForwardPickerScreen extends StatelessWidget {
  const _ForwardPickerScreen();

  @override
  Widget build(BuildContext context) {
    final service = ChatService();
    return Scaffold(
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Text(
                        context.tr('Forward to...'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ChatSummary>>(
                    stream: service.chatsStream(),
                    builder: (context, snapshot) {
                      final chats = snapshot.data ?? const <ChatSummary>[];
                      if (chats.isEmpty) {
                        return Center(
                          child: Text(
                            context.tr('No messages yet.'),
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: chats.length,
                        itemBuilder: (context, i) {
                          final chat = chats[i];
                          if (chat.otherUserId.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return FutureBuilder<UserBrief>(
                            future: UserDirectory.get(chat.otherUserId),
                            builder: (context, userSnap) {
                              final user =
                                  userSnap.data ??
                                  UserBrief.empty(chat.otherUserId);
                              final name = user.name.isNotEmpty
                                  ? user.name
                                  : context.tr('Unknown User');
                              return ListTile(
                                leading: UserAvatar(
                                  photoUrl: user.photoUrl,
                                  size: 44,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                onTap: () =>
                                    Navigator.pop(context, chat.chatId),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
