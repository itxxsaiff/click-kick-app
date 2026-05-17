import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import 'admin_feed_video_form.dart';

class AdminFeedVideosScreen extends StatefulWidget {
  const AdminFeedVideosScreen({super.key});

  @override
  State<AdminFeedVideosScreen> createState() => _AdminFeedVideosScreenState();
}

class _AdminFeedVideosScreenState extends State<AdminFeedVideosScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatShortDate(DateTime? date) {
    if (date == null) return '--';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _formatViews(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  Future<void> _openVideoPreview(String videoUrl) async {
    if (videoUrl.trim().isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _FeedVideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  Future<void> _openVideoDetails(Map<String, dynamic> data) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _FeedVideoDetailsDialog(
        title: (data['caption'] ?? context.tr('Untitled clip')).toString(),
        adminName: (data['adminName'] ?? context.tr('Admin')).toString(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        viewCount: ((data['views'] ?? data['viewCount'] ?? 0) as num).toInt(),
        shareCount: ((data['shareCount'] ?? 0) as num).toInt(),
        videoUrl: (data['videoUrl'] ?? '').toString(),
        durationLabel: (data['durationLabel'] ?? data['duration'] ?? '')
            .toString()
            .trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('admin_videos')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Feed Videos')),
            Text(
              context.tr('Public feed clips'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.deepSpace,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminFeedVideoForm()),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7B3FF2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('Add Clip')),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18152A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.border.withOpacity(0.85),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: context.tr('Search clips'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data();
                      final caption = (data['caption'] ?? '')
                          .toString()
                          .toLowerCase();
                      final adminName = (data['adminName'] ?? '')
                          .toString()
                          .toLowerCase();
                      final matchesSearch =
                          _search.isEmpty ||
                          caption.contains(_search) ||
                          adminName.contains(_search);
                      return matchesSearch;
                    }).toList();

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          _search.isEmpty
                              ? context.tr('No feed videos added yet.')
                              : context.tr('No matching videos.'),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      itemCount: docs.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == docs.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 12),
                            child: Center(
                              child: Text(
                                context.tr('No more clips'),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }

                        final doc = docs[index];
                        final data = doc.data();
                        final caption = (data['caption'] ?? '').toString();
                        final adminName =
                            (data['adminName'] ?? context.tr('Admin'))
                                .toString();
                        final videoUrl = (data['videoUrl'] ?? '').toString();
                        final createdAt = (data['createdAt'] as Timestamp?)
                            ?.toDate();
                        final views =
                            ((data['views'] ?? data['viewCount'] ?? 0) as num)
                                .toDouble();
                        final durationText =
                            (data['durationLabel'] ?? data['duration'] ?? '')
                                .toString()
                                .trim();

                        final shares = ((data['shareCount'] ?? 0) as num)
                            .toDouble();

                        return InkWell(
                          onTap: videoUrl.isEmpty
                              ? () => _openVideoDetails(data)
                              : () => _openVideoPreview(videoUrl),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18152A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border.withOpacity(0.88),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: videoUrl.isEmpty
                                      ? () => _openVideoDetails(data)
                                      : () => _openVideoPreview(videoUrl),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 108,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: AppColors.cardSoft,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          gradient: videoUrl.isEmpty
                                              ? const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xFF2A1952),
                                                    Color(0xFF171124),
                                                  ],
                                                )
                                              : const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xFF4B1A7E),
                                                    Color(0xFF12101C),
                                                  ],
                                                ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            videoUrl.isEmpty
                                                ? Icons.info_outline_rounded
                                                : Icons
                                                      .play_circle_fill_rounded,
                                            color: Colors.white70,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 6,
                                        bottom: 6,
                                        child: durationText.isEmpty
                                            ? const SizedBox.shrink()
                                            : Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.68),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  durationText,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              caption,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${context.tr('by')} $adminName',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatShortDate(createdAt),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.visibility_outlined,
                                                size: 14,
                                                color: AppColors.textMuted,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_formatViews(views)} ${context.tr('views')}',
                                                style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.share_outlined,
                                                size: 14,
                                                color: AppColors.textMuted,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_formatViews(shares)} ${context.tr('shares')}',
                                                style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (videoUrl.isEmpty)
                                            Text(
                                              context.tr('No video attached'),
                                              style: const TextStyle(
                                                color: AppColors.sunset,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'watch') {
                                      await _openVideoPreview(videoUrl);
                                    } else if (value == 'details') {
                                      await _openVideoDetails(data);
                                    } else if (value == 'delete') {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: Text(
                                            context.tr('Delete video?'),
                                          ),
                                          content: Text(
                                            context.tr(
                                              'This cannot be undone.',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text(context.tr('Cancel')),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: Text(context.tr('Delete')),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await doc.reference.delete();
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (videoUrl.isNotEmpty)
                                      PopupMenuItem(
                                        value: 'watch',
                                        child: Text(context.tr('Watch video')),
                                      ),
                                    PopupMenuItem(
                                      value: 'details',
                                      child: Text(context.tr('Video details')),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(context.tr('Delete')),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpaceBackground extends StatelessWidget {
  const _SpaceBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [AppColors.cosmicPurple, AppColors.deepSpace],
        ),
      ),
    );
  }
}

class _FeedVideoDetailsDialog extends StatelessWidget {
  const _FeedVideoDetailsDialog({
    required this.title,
    required this.adminName,
    required this.createdAt,
    required this.updatedAt,
    required this.viewCount,
    required this.shareCount,
    required this.videoUrl,
    required this.durationLabel,
  });

  final String title;
  final String adminName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int viewCount;
  final int shareCount;
  final String videoUrl;
  final String durationLabel;

  String _fmt(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry(context.tr('Title'), title),
      MapEntry(context.tr('Admin'), adminName),
      MapEntry(context.tr('Views'), viewCount.toString()),
      MapEntry(context.tr('Shares'), shareCount.toString()),
      MapEntry(
        context.tr('Duration'),
        durationLabel.isEmpty ? '-' : durationLabel,
      ),
      MapEntry(context.tr('Created At'), _fmt(createdAt)),
      MapEntry(context.tr('Updated At'), _fmt(updatedAt)),
      MapEntry(
        context.tr('Video URL'),
        videoUrl.isEmpty ? context.tr('No video attached') : videoUrl,
      ),
    ];

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Video Details'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, __) => Divider(
                  color: AppColors.border.withOpacity(0.7),
                  height: 14,
                ),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.key,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        row.value,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedVideoPlayerDialog extends StatefulWidget {
  const _FeedVideoPlayerDialog({required this.videoUrl});

  final String videoUrl;

  @override
  State<_FeedVideoPlayerDialog> createState() => _FeedVideoPlayerDialogState();
}

class _FeedVideoPlayerDialogState extends State<_FeedVideoPlayerDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initFuture = _controller.initialize();
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 32;
    final playerWidth = maxWidth > 720 ? 720.0 : maxWidth;
    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('Video Preview'),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textLight),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<void>(
                future: _initFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (!_controller.value.isInitialized) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(context.tr('Unable to load video.')),
                    );
                  }
                  return Column(
                    children: [
                      SizedBox(
                        width: playerWidth,
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () async {
                              final position = _controller.value.position;
                              await _controller.seekTo(
                                position - const Duration(seconds: 5),
                              );
                            },
                            icon: const Icon(
                              Icons.replay_5,
                              color: AppColors.textLight,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                _controller.play();
                              }
                              setState(() {});
                            },
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                              color: AppColors.hotPink,
                              size: 34,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final position = _controller.value.position;
                              await _controller.seekTo(
                                position + const Duration(seconds: 5),
                              );
                            },
                            icon: const Icon(
                              Icons.forward_5,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
