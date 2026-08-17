import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// Renders a support-chat attachment (image or video) as a tappable preview.
/// Tapping an image opens a full-screen zoomable viewer; tapping a video opens
/// a full-screen player. Works for both the user and admin support screens.
class SupportAttachmentView extends StatelessWidget {
  const SupportAttachmentView({super.key, required this.attachment});

  final Map<String, dynamic> attachment;

  @override
  Widget build(BuildContext context) {
    final type = (attachment['type'] ?? '').toString();
    final name = (attachment['name'] ?? '').toString();
    final url = (attachment['url'] ?? '').toString();
    if (url.isEmpty) return const SizedBox.shrink();

    final isVideo = type == 'video';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isVideo
                ? _VideoViewerScreen(url: url)
                : _ImageViewerScreen(url: url, name: name),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isVideo
              ? _VideoThumb(name: name)
              : Image.network(
                  url,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 220,
                      height: 220,
                      color: const Color(0xFF0E1A25),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stack) => _AttachmentFallback(
                    icon: Icons.broken_image_outlined,
                    label: name.isNotEmpty ? name : context.tr('Image'),
                  ),
                ),
        ),
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 140,
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.play_circle_fill,
            color: AppColors.hotPink,
            size: 46,
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('Tap to play video'),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AttachmentFallback extends StatelessWidget {
  const _AttachmentFallback({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334354)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.hotPink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageViewerScreen extends StatelessWidget {
  const _ImageViewerScreen({required this.url, required this.name});

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          name.isNotEmpty ? name : context.tr('Image'),
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator();
            },
            errorBuilder: (context, error, stack) => Text(
              context.tr('Unable to load image.'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoViewerScreen extends StatefulWidget {
  const _VideoViewerScreen({required this.url});

  final String url;

  @override
  State<_VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<_VideoViewerScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initFuture = _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.setLooping(true);
      _controller.play();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          context.tr('Video'),
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      body: Center(
        child: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                !_controller.value.isInitialized) {
              return const CircularProgressIndicator();
            }
            return GestureDetector(
              onTap: () => setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              }),
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio > 0
                    ? _controller.value.aspectRatio
                    : 9 / 16,
                child: VideoPlayer(_controller),
              ),
            );
          },
        ),
      ),
    );
  }
}
