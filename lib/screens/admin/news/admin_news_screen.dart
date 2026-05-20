import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import 'admin_news_form.dart';

class AdminNewsScreen extends StatefulWidget {
  const AdminNewsScreen({super.key});

  @override
  State<AdminNewsScreen> createState() => _AdminNewsScreenState();
}

class _AdminNewsScreenState extends State<AdminNewsScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String _statusFilter = 'all';
  String _sortBy = 'newest';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _statusValue(Map<String, dynamic> data) {
    final now = DateTime.now();
    final start =
        (data['publishStart'] as Timestamp?)?.toDate() ??
        (data['scheduledAt'] as Timestamp?)?.toDate();
    final end = (data['publishEnd'] as Timestamp?)?.toDate();
    if (start == null || end == null) return 'draft';
    if (now.isBefore(start)) return 'coming';
    if (now.isAfter(end)) return 'expired';
    return 'live';
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'published':
      case 'live':
        return context.tr('Live');
      case 'coming':
        return context.tr('Coming');
      case 'expired':
        return context.tr('Expired');
      case 'draft':
        return context.tr('Draft');
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'live':
        return const Color(0xFF38E27B);
      case 'coming':
        return const Color(0xFF4EA3FF);
      case 'expired':
        return const Color(0xFFFF5D73);
      case 'draft':
        return const Color(0xFFFFB23F);
      default:
        return AppColors.textMuted;
    }
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
        .collection('news')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('News')),
            Text(
              context.tr('Announcements & updates'),
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
                  MaterialPageRoute(builder: (_) => const AdminNewsForm()),
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
              label: Text(context.tr('Add News')),
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
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: context.tr('Search news'),
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
                      (total, doc) =>
                          total +
                          ((doc.data()['views'] ?? doc.data()['viewCount'] ?? 0)
                              as num),
                    );
                    final liveCount = allDocs
                        .where((doc) => _statusValue(doc.data()) == 'live')
                        .length;
                    final comingCount = allDocs
                        .where((doc) => _statusValue(doc.data()) == 'coming')
                        .length;
                    final expiredCount = allDocs
                        .where((doc) => _statusValue(doc.data()) == 'expired')
                        .length;
                    final draftCount = allDocs
                        .where((doc) => _statusValue(doc.data()) == 'draft')
                        .length;

                    final docs = [
                      ...allDocs.where((doc) {
                        final data = doc.data();
                        final title = (data['title'] ?? '')
                            .toString()
                            .toLowerCase();
                        final body = (data['body'] ?? '')
                            .toString()
                            .toLowerCase();
                        final status = _statusValue(data);
                        final matchesSearch =
                            _search.isEmpty ||
                            title.contains(_search) ||
                            body.contains(_search);
                        final matchesStatus =
                            _statusFilter == 'all' || status == _statusFilter;
                        return matchesSearch && matchesStatus;
                      }),
                    ];

                    docs.sort((a, b) {
                      final aDate =
                          ((a.data()['publishStart'] ??
                                      a.data()['scheduledAt'] ??
                                      a.data()['createdAt'])
                                  as Timestamp?)
                              ?.toDate() ??
                          DateTime(2000);
                      final bDate =
                          ((b.data()['publishStart'] ??
                                      b.data()['scheduledAt'] ??
                                      b.data()['createdAt'])
                                  as Timestamp?)
                              ?.toDate() ??
                          DateTime(2000);
                      return _sortBy == 'oldest'
                          ? aDate.compareTo(bDate)
                          : bDate.compareTo(aDate);
                    });

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        _NewsSummaryCards(
                          total: allDocs.length,
                          live: liveCount,
                          coming: comingCount,
                          expired: expiredCount,
                          draft: draftCount,
                          totalViews: totalViews,
                          formatViews: _formatViews,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _FilterChip(
                                      label: context.tr('All'),
                                      selected: _statusFilter == 'all',
                                      onTap: () =>
                                          setState(() => _statusFilter = 'all'),
                                    ),
                                    _FilterChip(
                                      label: context.tr('Live'),
                                      selected: _statusFilter == 'live',
                                      dotColor: const Color(0xFF38E27B),
                                      onTap: () => setState(
                                        () => _statusFilter = 'live',
                                      ),
                                    ),
                                    _FilterChip(
                                      label: context.tr('Coming'),
                                      selected: _statusFilter == 'coming',
                                      dotColor: const Color(0xFF4EA3FF),
                                      onTap: () => setState(
                                        () => _statusFilter = 'coming',
                                      ),
                                    ),
                                    _FilterChip(
                                      label: context.tr('Expired'),
                                      selected: _statusFilter == 'expired',
                                      dotColor: const Color(0xFFFF5D73),
                                      onTap: () => setState(
                                        () => _statusFilter = 'expired',
                                      ),
                                    ),
                                    _FilterChip(
                                      label: context.tr('Draft'),
                                      selected: _statusFilter == 'draft',
                                      dotColor: const Color(0xFFFFB23F),
                                      onTap: () => setState(
                                        () => _statusFilter = 'draft',
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
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF151324),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.border.withOpacity(0.85),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _sortBy,
                                  dropdownColor: const Color(0xFF151324),
                                  style: const TextStyle(
                                    color: AppColors.textLight,
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
                              color: const Color(0xFF151324),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border.withOpacity(0.88),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _search.isEmpty
                                    ? context.tr('No news added yet.')
                                    : context.tr('No matching news.'),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        if (docs.isNotEmpty) ...[
                          for (int i = 0; i < docs.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _NewsCard(
                              doc: docs[i],
                              status: _statusValue(docs[i].data()),
                              statusLabel: _statusLabel(
                                context,
                                _statusValue(docs[i].data()),
                              ),
                              statusColor: _statusColor(
                                _statusValue(docs[i].data()),
                              ),
                              formatShortDate: _formatShortDate,
                              formatTime: _formatTime,
                              formatViews: _formatViews,
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: Text(
                                context.tr('No more news'),
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _NewsSummaryCards extends StatelessWidget {
  const _NewsSummaryCards({
    required this.total,
    required this.live,
    required this.coming,
    required this.expired,
    required this.draft,
    required this.totalViews,
    required this.formatViews,
  });

  final int total;
  final int live;
  final int coming;
  final int expired;
  final int draft;
  final num totalViews;
  final String Function(num) formatViews;

  @override
  Widget build(BuildContext context) {
    final items = [
      (_CardMetric(
        context.tr('Total News'),
        total.toString(),
        const Color(0xFFA565FF),
      )),
      (_CardMetric(
        context.tr('Live'),
        live.toString(),
        const Color(0xFF38E27B),
      )),
      (_CardMetric(
        context.tr('Coming'),
        coming.toString(),
        const Color(0xFF4EA3FF),
      )),
      (_CardMetric(
        context.tr('Expired'),
        expired.toString(),
        const Color(0xFFFF5D73),
      )),
      (_CardMetric(
        context.tr('Draft'),
        draft.toString(),
        const Color(0xFFFFB23F),
      )),
      (_CardMetric(
        context.tr('Total Views'),
        formatViews(totalViews),
        const Color(0xFFB56DFF),
      )),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 6
            : width >= 900
            ? 3
            : 2;
        final itemWidth = (width - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151324),
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
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
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

class _CardMetric {
  const _CardMetric(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
            color: selected ? const Color(0xFF6F3CFF) : const Color(0xFF151324),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF8C63FF)
                  : AppColors.border.withOpacity(0.85),
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

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.doc,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.formatShortDate,
    required this.formatTime,
    required this.formatViews,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String status;
  final String statusLabel;
  final Color statusColor;
  final String Function(DateTime?) formatShortDate;
  final String Function(DateTime?) formatTime;
  final String Function(num) formatViews;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = (data['title'] ?? '').toString();
    final body = (data['body'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final publishStart =
        (data['publishStart'] as Timestamp?)?.toDate() ??
        (data['scheduledAt'] as Timestamp?)?.toDate();
    final publishEnd = (data['publishEnd'] as Timestamp?)?.toDate();
    final views = ((data['views'] ?? data['viewCount'] ?? 0) as num).toDouble();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF151324),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.88)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 96,
            height: 78,
            decoration: BoxDecoration(
              color: AppColors.cardSoft,
              borderRadius: BorderRadius.circular(12),
              gradient: imageUrl.isEmpty
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4B1A7E), Color(0xFF12101C)],
                    )
                  : null,
            ),
            child: imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported,
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : const Center(
                    child: Icon(
                      Icons.campaign_rounded,
                      color: Colors.white70,
                      size: 30,
                    ),
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _MetaPill(
                      icon: Icons.calendar_today_outlined,
                      label: formatShortDate(createdAt),
                    ),
                    if (publishStart != null)
                      _MetaPill(
                        icon: status == 'coming'
                            ? Icons.schedule_outlined
                            : Icons.play_circle_outline,
                        label:
                            '${formatShortDate(publishStart)} • ${formatTime(publishStart)}',
                      ),
                    if (publishEnd != null)
                      _MetaPill(
                        icon: Icons.event_busy_outlined,
                        label:
                            '${formatShortDate(publishEnd)} • ${formatTime(publishEnd)}',
                      ),
                    _MetaPill(
                      icon: Icons.visibility_outlined,
                      label: '${formatViews(views)} ${context.tr('views')}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
            onSelected: (value) async {
              if (value == 'edit') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminNewsForm(newsId: doc.id, existing: data),
                  ),
                );
              } else if (value == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(context.tr('Delete news?')),
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
              PopupMenuItem(value: 'edit', child: Text(context.tr('Edit'))),
              PopupMenuItem(value: 'delete', child: Text(context.tr('Delete'))),
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
