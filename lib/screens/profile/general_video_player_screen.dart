import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../services/follow_service.dart';
import '../../services/general_video_service.dart';
import '../../services/short_link_service.dart';
import '../../services/video_download_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/follow_widgets.dart';
import 'user_profile_screen.dart';

String formatCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  }
  return value.toString();
}

/// Opens [url] in a new [VideoPlayerController], retrying a failed load.
///
/// Browsers fetch fragmented MP4s (common for videos saved from other apps)
/// with many range requests, and Firebase Storage occasionally answers one of
/// them with a redirect. Chrome then reports MEDIA_ERR_SRC_NOT_SUPPORTED for a
/// perfectly good file, and the very next attempt works. So a failure gets a
/// fresh controller and a couple more tries before it is treated as real.
Future<VideoPlayerController> openVideoWithRetry(
  String url, {
  int attempts = 3,
}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      return controller;
    } catch (e) {
      lastError = e;
      debugPrint('Video load attempt $attempt/$attempts failed: $e');
      await controller.dispose();
      if (attempt < attempts) {
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }
  throw lastError!;
}

/// Full-screen player for one general video (opened from a profile grid).
class GeneralVideoPlayerScreen extends StatefulWidget {
  const GeneralVideoPlayerScreen({super.key, required this.video});

  final GeneralVideo video;

  @override
  State<GeneralVideoPlayerScreen> createState() =>
      _GeneralVideoPlayerScreenState();
}

class _GeneralVideoPlayerScreenState extends State<GeneralVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _failed = false;
  String _error = '';
  late int _shareCount = widget.video.shareCount;
  late int _likeCount = widget.video.likeCount;
  UserBrief _author = UserBrief.empty('');

  GeneralVideo get _video => widget.video;

  @override
  void initState() {
    super.initState();
    _init();
    UserDirectory.get(_video.userId).then((u) {
      if (mounted) setState(() => _author = u);
    });
    _trackView();
  }

  Future<void> _init() async {
    VideoPlayerController controller;
    try {
      controller = await openVideoWithRetry(_video.videoUrl);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.setLooping(true);
    } catch (e) {
      // The file could not be loaded / decoded (network, or an unsupported
      // codec such as HEVC in a browser).
      debugPrint('Video load failed for ${_video.videoUrl}: $e');
      _failed = true;
      _error = e.toString();
    }
    if (mounted) setState(() {});
    final loaded = _controller;
    if (_failed || loaded == null || !mounted) return;
    try {
      await loaded.play();
    } catch (e) {
      // Browsers can refuse autoplay once the load took a while. That is not
      // a broken video: leave it paused so a tap on the screen starts it.
      debugPrint('Autoplay blocked: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _trackView() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == _video.userId || !_video.isApproved) return;
    try {
      await AuthService().incrementGeneralVideoView(_video.id);
    } catch (_) {}
  }

  /// No watermark yet — that is a separate, not-yet-built feature.
  Future<void> _download() async {
    final result = await VideoDownloadService.saveVideo(
      videoUrl: _video.videoUrl,
      fileName: 'clickkick_${_video.id}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr(result.messageKey)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _like() async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please login to like.'))),
      );
      return;
    }
    final failMsg = context.tr('Could not update like. Please try again.');
    try {
      final liked = await AuthService().toggleGeneralVideoLike(_video.id);
      if (mounted) setState(() => _likeCount += liked ? 1 : -1);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failMsg), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _share() async {
    if (FirebaseAuth.instance.currentUser != null && _video.isApproved) {
      try {
        await AuthService().incrementGeneralVideoShare(_video.id);
        if (mounted) setState(() => _shareCount++);
      } catch (_) {}
    }
    final name = _author.name.isNotEmpty ? _author.name : _video.userName;
    String link;
    try {
      link = await ShortLinkService().generalVideoLink(_video.id);
    } catch (_) {
      link = GeneralVideoService.shareLink(_video.id);
    }
    await Share.share(
      '$name\nClick Kick\n$link',
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

  Future<void> _togglePlayback() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    c.value.isPlaying ? await c.pause() : await c.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final name = _author.name.isNotEmpty ? _author.name : _video.userName;
    final isOwner = FirebaseAuth.instance.currentUser?.uid == _video.userId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _togglePlayback,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              )
            else
              Center(
                child: _failed
                    ? _PlayError(message: _error)
                    : const CircularProgressIndicator(color: AppColors.hotPink),
              ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xD0100A1E)],
                  stops: [0.55, 1],
                ),
              ),
            ),
            if (ready)
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: c.value.isPlaying ? 0 : 1,
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.hotPink,
                      size: 72,
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                    ),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 120,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<bool>(
                    stream: GeneralVideoService().isLikedStream(_video.id),
                    builder: (context, likeSnap) {
                      final liked = likeSnap.data ?? false;
                      return _Metric(
                        icon: liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        iconColor: liked ? AppColors.hotPink : Colors.white,
                        value: formatCount(_likeCount),
                        label: context.tr('Like'),
                        onTap: _like,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _Metric(
                    icon: Icons.visibility_outlined,
                    value: formatCount(_video.viewCount),
                    label: context.tr('Views'),
                  ),
                  const SizedBox(height: 16),
                  _Metric(
                    icon: Icons.share_outlined,
                    value: formatCount(_shareCount),
                    label: context.tr('Share'),
                    onTap: _video.isApproved ? _share : null,
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 16),
                    _Metric(
                      icon: Icons.download_outlined,
                      value: '',
                      label: context.tr('Download'),
                      onTap: _download,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 96,
              bottom: 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOwner && !_video.isApproved)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sunset.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _video.status == 'rejected'
                            ? context.tr('Rejected')
                            : context.tr('Pending review'),
                        style: const TextStyle(
                          color: AppColors.sunset,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: isOwner
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UserProfileScreen(userId: _video.userId),
                                ),
                              ),
                        child: UserAvatar(photoUrl: _author.photoUrl, size: 42),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!isOwner) ...[
                        const SizedBox(width: 10),
                        FollowButton(
                          targetUserId: _video.userId,
                          width: 88,
                          height: 30,
                        ),
                      ],
                    ],
                  ),
                  if (_video.caption.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _video.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = Colors.white,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 34),
          if (value.isNotEmpty) const SizedBox(height: 4),
          if (value.isNotEmpty)
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Opened from a shared link (`/general-video?videoId=...`): loads the video
/// and shows it in the player.
class GeneralVideoLinkScreen extends StatelessWidget {
  const GeneralVideoLinkScreen({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GeneralVideo?>(
      future: GeneralVideoService().loadById(videoId).catchError((_) => null),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final video = snapshot.data;
        if (video == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(context.tr('This video is not available.')),
            ),
          );
        }
        return GeneralVideoPlayerScreen(video: video);
      },
    );
  }
}

/// Minimal full-screen player (used for competition entries on a profile).
class SimpleVideoPlayerScreen extends StatefulWidget {
  const SimpleVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.title = '',
  });

  final String videoUrl;
  final String title;

  @override
  State<SimpleVideoPlayerScreen> createState() =>
      _SimpleVideoPlayerScreenState();
}

class _SimpleVideoPlayerScreenState extends State<SimpleVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _failed = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    VideoPlayerController controller;
    try {
      controller = await openVideoWithRetry(widget.videoUrl);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.setLooping(true);
    } catch (e) {
      // The file could not be loaded / decoded (network, or an unsupported
      // codec such as HEVC in a browser).
      debugPrint('Video load failed for ${widget.videoUrl}: $e');
      _failed = true;
      _error = e.toString();
    }
    if (mounted) setState(() {});
    final loaded = _controller;
    if (_failed || loaded == null || !mounted) return;
    try {
      await loaded.play();
    } catch (e) {
      // Browsers can refuse autoplay once the load took a while. That is not
      // a broken video: leave it paused so a tap on the screen starts it.
      debugPrint('Autoplay blocked: $e');
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.title),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () async {
          if (!ready) return;
          c.value.isPlaying ? await c.pause() : await c.play();
          if (mounted) setState(() {});
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: ready
              ? AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                )
              : _failed
              ? _PlayError(message: _error)
              : const CircularProgressIndicator(color: AppColors.hotPink),
        ),
      ),
    );
  }
}

class _PlayError extends StatelessWidget {
  const _PlayError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('Unable to play this video.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
