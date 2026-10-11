import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _init();
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
        SnackBar(content: Text(context.tr('Could not open chat.'))),
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
    _textController.clear();
    try {
      await _service.sendText(chatId, text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Message failed to send.'))),
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
    setState(() => _sendingMedia = true);
    try {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await _service.sendMedia(
          chatId,
          type: 'image',
          bytes: bytes,
          extension: 'jpg',
        );
      } else {
        await _service.sendMedia(
          chatId,
          type: 'image',
          file: File(picked.path),
          extension: 'jpg',
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Could not send photo.'))),
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
    setState(() => _sendingMedia = true);
    try {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await _service.sendMedia(
          chatId,
          type: 'video',
          bytes: bytes,
          extension: 'mp4',
        );
      } else {
        await _service.sendMedia(
          chatId,
          type: 'video',
          file: File(picked.path),
          extension: 'mp4',
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Could not send video.'))),
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
    setState(() => _sendingMedia = true);
    try {
      await _service.sendMedia(
        chatId,
        type: 'audio',
        file: File(path),
        extension: 'm4a',
        durationMs: duration.inMilliseconds,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Could not send voice message.'))),
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
                            final messages =
                                snapshot.data ?? const <ChatMessage>[];
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
                            return ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                12,
                              ),
                              itemCount: messages.length,
                              itemBuilder: (context, i) => _MessageBubble(
                                message: messages[i],
                                isMine: messages[i].senderId == myUid,
                                isPlayingAudio:
                                    _playingMessageId == messages[i].id,
                                onToggleAudio: () =>
                                    _togglePlayAudio(messages[i]),
                                onOpenImage: (url) => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _ImageViewerScreen(url: url),
                                  ),
                                ),
                                onOpenVideo: (url) => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SimpleVideoPlayerScreen(videoUrl: url),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_sendingMedia)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
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
                  border: InputBorder.none,
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
  });

  final ChatMessage message;
  final bool isMine;
  final bool isPlayingAudio;
  final VoidCallback onToggleAudio;
  final ValueChanged<String> onOpenImage;
  final ValueChanged<String> onOpenVideo;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.hotPink : AppColors.card;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: message.type == 'text'
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
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
  }

  Widget _buildContent(BuildContext context) {
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
