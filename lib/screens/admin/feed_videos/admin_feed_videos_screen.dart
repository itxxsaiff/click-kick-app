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
  String _statusFilter = 'all';
  String _sortBy = 'newest';

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

  String _normalizedStatus(Map<String, dynamic> data) {
    final raw = data['isVisibleOnFeed'];
    if (raw is bool) {
      return raw ? 'shown' : 'hidden';
    }
    return 'shown';
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs];
    int compareNum(num a, num b) => b.compareTo(a);

    switch (_sortBy) {
      case 'oldest':
        sorted.sort((a, b) {
          final aDate = (a.data()['createdAt'] as Timestamp?)?.toDate();
          final bDate = (b.data()['createdAt'] as Timestamp?)?.toDate();
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return -1;
          if (bDate == null) return 1;
          return aDate.compareTo(bDate);
        });
        break;
      case 'most_viewed':
        sorted.sort(
          (a, b) => compareNum(
            ((a.data()['views'] ?? a.data()['viewCount'] ?? 0) as num),
            ((b.data()['views'] ?? b.data()['viewCount'] ?? 0) as num),
          ),
        );
        break;
      case 'most_shared':
        sorted.sort(
          (a, b) => compareNum(
            ((a.data()['shareCount'] ?? 0) as num),
            ((b.data()['shareCount'] ?? 0) as num),
          ),
        );
        break;
      case 'newest':
      default:
        sorted.sort((a, b) {
          final aDate = (a.data()['createdAt'] as Timestamp?)?.toDate();
          final bDate = (b.data()['createdAt'] as Timestamp?)?.toDate();
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        break;
    }
    return sorted;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'shown':
        return const Color(0xFF4CD964);
      case 'hidden':
        return const Color(0xFFFF5D73);
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'shown':
        return context.tr('Shown');
      case 'hidden':
        return context.tr('Hidden');
      default:
        return context.tr('All');
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '--:--';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
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

                    final allDocs = snapshot.data!.docs;
                    final totalViews = allDocs.fold<num>(
                      0,
                      (sum, doc) =>
                          sum +
                          ((doc.data()['views'] ?? doc.data()['viewCount'] ?? 0)
                              as num),
                    );
                    final totalShares = allDocs.fold<num>(
                      0,
                      (total, doc) =>
                          total + ((doc.data()['shareCount'] ?? 0) as num),
                    );
                    final shownCount = allDocs
                        .where(
                          (doc) => _normalizedStatus(doc.data()) == 'shown',
                        )
                        .length;
                    final hiddenCount = allDocs
                        .where(
                          (doc) => _normalizedStatus(doc.data()) == 'hidden',
                        )
                        .length;

                    final docs = _sortDocs(
                      allDocs.where((doc) {
                        final data = doc.data();
                        final caption = (data['caption'] ?? '')
                            .toString()
                            .toLowerCase();
                        final adminName = (data['adminName'] ?? '')
                            .toString()
                            .toLowerCase();
                        final status = _normalizedStatus(data);
                        final matchesSearch =
                            _search.isEmpty ||
                            caption.contains(_search) ||
                            adminName.contains(_search);
                        final matchesStatus =
                            _statusFilter == 'all' || status == _statusFilter;
                        return matchesSearch && matchesStatus;
                      }).toList(),
                    );

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      children: [
                        const SizedBox(height: 2),
                        _SummaryStatsRow(
                          items: [
                            _SummaryStatItem(
                              value: allDocs.length.toString(),
                              label: context.tr('Total Clips'),
                              color: const Color(0xFFA565FF),
                            ),
                            _SummaryStatItem(
                              value: shownCount.toString(),
                              label: context.tr('Shown on Feed'),
                              color: const Color(0xFF4CD964),
                            ),
                            _SummaryStatItem(
                              value: hiddenCount.toString(),
                              label: context.tr('Hidden from Feed'),
                              color: const Color(0xFFFF5D73),
                            ),
                            _SummaryStatItem(
                              value: _formatViews(totalViews),
                              label: context.tr('Total Views'),
                              color: const Color(0xFFB56DFF),
                            ),
                            _SummaryStatItem(
                              value: _formatViews(totalShares),
                              label: context.tr('Total Shares'),
                              color: const Color(0xFFFF66D9),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _StatusFilterChip(
                                      label: context.tr('All'),
                                      selected: _statusFilter == 'all',
                                      onTap: () =>
                                          setState(() => _statusFilter = 'all'),
                                    ),
                                    _StatusFilterChip(
                                      label: context.tr('Shown'),
                                      selected: _statusFilter == 'shown',
                                      dotColor: const Color(0xFF4CD964),
                                      onTap: () => setState(
                                        () => _statusFilter = 'shown',
                                      ),
                                    ),
                                    _StatusFilterChip(
                                      label: context.tr('Hidden'),
                                      selected: _statusFilter == 'hidden',
                                      dotColor: const Color(0xFFFF5D73),
                                      onTap: () => setState(
                                        () => _statusFilter = 'hidden',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF18152A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.border.withOpacity(0.8),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _sortBy,
                                  dropdownColor: const Color(0xFF18152A),
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  iconEnabledColor: AppColors.textMuted,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _sortBy = value);
                                  },
                                  items: [
                                    DropdownMenuItem(
                                      value: 'newest',
                                      child: Text(context.tr('Newest First')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'oldest',
                                      child: Text(context.tr('Oldest First')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'most_viewed',
                                      child: Text(context.tr('Most Viewed')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'most_shared',
                                      child: Text(context.tr('Most Shared')),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (docs.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18152A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border.withOpacity(0.88),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _search.isEmpty
                                    ? context.tr('No feed videos added yet.')
                                    : context.tr('No matching videos.'),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        if (docs.isNotEmpty) ...[
                          for (int index = 0; index < docs.length; index++) ...[
                            if (index > 0) const SizedBox(height: 10),
                            _ImprovedFeedClipCard(
                              doc: docs[index],
                              formatShortDate: _formatShortDate,
                              formatTime: _formatTime,
                              formatViews: _formatViews,
                              statusLabel: _statusLabel(
                                context,
                                _normalizedStatus(docs[index].data()),
                              ),
                              statusColor: _statusColor(
                                _normalizedStatus(docs[index].data()),
                              ),
                              onPreview: _openVideoPreview,
                              onDetails: _openVideoDetails,
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 4),
                            child: Center(
                              child: Text(
                                context.tr('No more clips'),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
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

class _SummaryStatItem {
  const _SummaryStatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;
}

class _SummaryStatsRow extends StatelessWidget {
  const _SummaryStatsRow({required this.items});

  final List<_SummaryStatItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 5
            : width >= 820
            ? 3
            : 2;
        final cardWidth = (width - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18152A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.88),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.value,
                          style: TextStyle(
                            color: item.color,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6F3CFF) : const Color(0xFF18152A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF8C63FF)
                  : AppColors.border.withOpacity(0.8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImprovedFeedClipCard extends StatelessWidget {
  const _ImprovedFeedClipCard({
    required this.doc,
    required this.formatShortDate,
    required this.formatTime,
    required this.formatViews,
    required this.statusLabel,
    required this.statusColor,
    required this.onPreview,
    required this.onDetails,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String Function(DateTime?) formatShortDate;
  final String Function(DateTime?) formatTime;
  final String Function(num) formatViews;
  final String statusLabel;
  final Color statusColor;
  final Future<void> Function(String) onPreview;
  final Future<void> Function(Map<String, dynamic>) onDetails;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final caption = (data['caption'] ?? '').toString();
    final adminName = (data['adminName'] ?? context.tr('Admin')).toString();
    final videoUrl = (data['videoUrl'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    final views = ((data['views'] ?? data['viewCount'] ?? 0) as num).toDouble();
    final shares = ((data['shareCount'] ?? 0) as num).toDouble();
    final durationText = (data['durationLabel'] ?? data['duration'] ?? '')
        .toString()
        .trim();
    final visibility = (data['visibility'] ?? '').toString().trim();
    final category = (data['category'] ?? '').toString().trim();
    final isVisibleOnFeed = (data['isVisibleOnFeed'] as bool?) ?? true;

    return InkWell(
      onTap: videoUrl.isEmpty
          ? () => onDetails(data)
          : () => onPreview(videoUrl),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF18152A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withOpacity(0.88)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: videoUrl.isEmpty
                  ? () => onDetails(data)
                  : () => onPreview(videoUrl),
              child: Stack(
                children: [
                  Container(
                    width: 116,
                    height: 82,
                    decoration: BoxDecoration(
                      color: AppColors.cardSoft,
                      borderRadius: BorderRadius.circular(12),
                      gradient: videoUrl.isEmpty
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2A1952), Color(0xFF171124)],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF4B1A7E), Color(0xFF12101C)],
                            ),
                    ),
                    child: Center(
                      child: Icon(
                        videoUrl.isEmpty
                            ? Icons.info_outline_rounded
                            : Icons.play_circle_fill_rounded,
                        color: Colors.white70,
                        size: 34,
                      ),
                    ),
                  ),
                  if (durationText.isNotEmpty)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.68),
                          borderRadius: BorderRadius.circular(8),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (statusLabel != context.tr('All'))
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
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
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        formatShortDate(createdAt),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        formatTime(updatedAt ?? createdAt),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (visibility.isNotEmpty)
                        _InlineMetaDot(
                          color: const Color(0xFF4CD964),
                          label: visibility,
                        ),
                      if (category.isNotEmpty)
                        _InlineMetaDot(
                          color: const Color(0xFFFFB020),
                          label: category,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _MetricWithIcon(
                        icon: Icons.visibility_outlined,
                        value: formatViews(views),
                      ),
                      _MetricWithIcon(
                        icon: Icons.share_outlined,
                        value: formatViews(shares),
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
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  onPressed: videoUrl.isEmpty
                      ? null
                      : () => onPreview(videoUrl),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  color: Colors.white,
                  tooltip: context.tr('Watch video'),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'watch' && videoUrl.isNotEmpty) {
                      await onPreview(videoUrl);
                    } else if (value == 'details') {
                      await onDetails(data);
                    } else if (value == 'toggle_visibility') {
                      await doc.reference.update({
                        'isVisibleOnFeed': !isVisibleOnFeed,
                        'updatedAt': Timestamp.now(),
                      });
                    } else if (value == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(context.tr('Delete video?')),
                          content: Text(context.tr('This cannot be undone.')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(context.tr('Cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
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
                      value: 'toggle_visibility',
                      child: Text(
                        isVisibleOnFeed
                            ? context.tr('Hide from feed')
                            : context.tr('Show on feed'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.tr('Delete')),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMetaDot extends StatelessWidget {
  const _InlineMetaDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _MetricWithIcon extends StatelessWidget {
  const _MetricWithIcon({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
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
