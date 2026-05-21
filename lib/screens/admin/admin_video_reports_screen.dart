import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';

class AdminVideoReportsScreen extends StatefulWidget {
  const AdminVideoReportsScreen({super.key});

  @override
  State<AdminVideoReportsScreen> createState() =>
      _AdminVideoReportsScreenState();
}

class _AdminVideoReportsScreenState extends State<AdminVideoReportsScreen> {
  final _search = TextEditingController();

  String _query = '';
  String _statusFilter = 'all';
  String _sort = 'newest';
  String? _selectedReportId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Video Reports')),
            Text(
              context.tr('Review, manage and take action on reported videos'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1222), Color(0xFF09111E)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('video_reports')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allDocs = snapshot.data!.docs.toList();
            final summary = _ReportSummary.fromDocs(allDocs);
            final filtered = _filteredDocs(allDocs);
            final selectedDoc = _selectedDoc(filtered, allDocs);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(
                    searchController: _search,
                    query: _query,
                    onQueryChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    sort: _sort,
                    onSortChanged: (value) => setState(() => _sort = value),
                  ),
                  const SizedBox(height: 14),
                  _SummaryGrid(summary: summary),
                  const SizedBox(height: 14),
                  _StatusFilterRow(
                    selected: _statusFilter,
                    counts: summary,
                    onChanged: (value) => setState(() => _statusFilter = value),
                  ),
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    _EmptyReportsCard(
                      message: context.tr('No matching reports.'),
                    )
                  else ...[
                    for (final doc in filtered) ...[
                      _ReportCard(
                        data: doc.data(),
                        isSelected: doc.id == _selectedReportId,
                        onTap: () => setState(() => _selectedReportId = doc.id),
                        onMenuSelected: (action) =>
                            _handleAction(doc.reference, action),
                        onQuickAction: (action) =>
                            _handleAction(doc.reference, action),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 6),
                    _ReportDetailPanel(
                      data: selectedDoc?.data(),
                      onAction: selectedDoc == null
                          ? null
                          : (action) =>
                                _handleAction(selectedDoc.reference, action),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        context.tr('No more reports'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.58),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final filtered = docs.where((doc) {
      final data = doc.data();
      final status = _reportStatus(data);
      if (_statusFilter != 'all' && _statusFilter != status) {
        return false;
      }

      if (_query.isEmpty) return true;
      final haystack = [
        _reportTitle(data),
        _videoOwner(data),
        _reporterName(data),
        _reportReason(data),
        _videoTypeLabel(data),
      ].join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case 'oldest':
          return _timestampOf(
            a.data(),
            'createdAt',
          ).compareTo(_timestampOf(b.data(), 'createdAt'));
        case 'reporter':
          return _reporterName(
            a.data(),
          ).toLowerCase().compareTo(_reporterName(b.data()).toLowerCase());
        case 'video':
          return _reportTitle(
            a.data(),
          ).toLowerCase().compareTo(_reportTitle(b.data()).toLowerCase());
        case 'newest':
        default:
          return _timestampOf(
            b.data(),
            'createdAt',
          ).compareTo(_timestampOf(a.data(), 'createdAt'));
      }
    });

    return filtered;
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _selectedDoc(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) {
    if (allDocs.isEmpty) return null;
    final pool = filtered.isNotEmpty ? filtered : allDocs;
    if (_selectedReportId == null) {
      _selectedReportId = pool.first.id;
    }
    for (final doc in pool) {
      if (doc.id == _selectedReportId) return doc;
    }
    _selectedReportId = pool.first.id;
    return pool.first;
  }

  Future<void> _handleAction(
    DocumentReference<Map<String, dynamic>> ref,
    _ReportAction action,
  ) async {
    switch (action) {
      case _ReportAction.markReviewed:
        await _setStatus(ref, 'resolved');
        break;
      case _ReportAction.dismiss:
        await _setStatus(ref, 'dismissed');
        break;
      case _ReportAction.reopen:
        await _setStatus(ref, 'open');
        break;
    }
  }

  Future<void> _setStatus(
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) async {
    await ref.update({
      'status': status,
      'reviewedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.sort,
    required this.onSortChanged,
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final String sort;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: context.tr('Search videos, users, reporters'),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: const Color(0xFF101A2B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.hotPink),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          tooltip: context.tr('Sort'),
          initialValue: sort,
          onSelected: onSortChanged,
          color: const Color(0xFF151E31),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'newest',
              child: Text(context.tr('Newest first')),
            ),
            PopupMenuItem(
              value: 'oldest',
              child: Text(context.tr('Oldest first')),
            ),
            const PopupMenuItem(value: 'video', child: Text('Video A-Z')),
            const PopupMenuItem(value: 'reporter', child: Text('Reporter A-Z')),
          ],
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF7C45F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final _ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCardData(
        label: context.tr('Pending'),
        value: summary.open.toString(),
        helper: context.tr('Needs review'),
        color: const Color(0xFFEF8A2F),
        icon: Icons.pending_outlined,
      ),
      _SummaryCardData(
        label: context.tr('Reviewed'),
        value: summary.reviewed.toString(),
        helper: context.tr('Handled reports'),
        color: const Color(0xFF38C172),
        icon: Icons.verified_outlined,
      ),
      _SummaryCardData(
        label: context.tr('Dismissed'),
        value: summary.dismissed.toString(),
        helper: context.tr('Closed reports'),
        color: const Color(0xFF8B95A7),
        icon: Icons.remove_circle_outline_rounded,
      ),
      _SummaryCardData(
        label: context.tr('Contest Reports'),
        value: summary.contestReports.toString(),
        helper: context.tr('Participant videos'),
        color: const Color(0xFF53A7FF),
        icon: Icons.emoji_events_outlined,
      ),
      _SummaryCardData(
        label: context.tr('Feed Reports'),
        value: summary.feedReports.toString(),
        helper: context.tr('Admin feed videos'),
        color: const Color(0xFFE35D9A),
        icon: Icons.video_collection_outlined,
      ),
      _SummaryCardData(
        label: context.tr('Total Reports'),
        value: summary.total.toString(),
        helper: context.tr('All time'),
        color: const Color(0xFF9F7BFF),
        icon: Icons.flag_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 6
            : width >= 760
            ? 3
            : 2;
        final itemWidth =
            (width - ((crossAxisCount - 1) * 10)) / crossAxisCount;
        final itemHeight = width >= 760 ? 114.0 : 142.0;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards)
              SizedBox(
                width: itemWidth,
                child: _SummaryCard(data: card, height: itemHeight),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String helper;
  final Color color;
  final IconData icon;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.height});

  final _SummaryCardData data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isCompact = height < 130;

    return Container(
      height: height,
      padding: EdgeInsets.all(isCompact ? 14 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10192A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isCompact ? 42 : 38,
            height: isCompact ? 42 : 38,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              data.icon,
              color: data.color,
              size: isCompact ? 22 : 20,
            ),
          ),
          const Spacer(),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (isCompact
                        ? Theme.of(context).textTheme.headlineSmall
                        : Theme.of(context).textTheme.titleLarge)
                    ?.copyWith(color: data.color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.helper,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.64),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final String selected;
  final _ReportSummary counts;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('all', context.tr('All')),
      ('open', '${context.tr('Pending')} (${counts.open})'),
      ('resolved', '${context.tr('Reviewed')} (${counts.reviewed})'),
      ('dismissed', '${context.tr('Dismissed')} (${counts.dismissed})'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected == value
                        ? const Color(0xFF6D42F5)
                        : const Color(0xFF10192A),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.data,
    required this.isSelected,
    required this.onTap,
    required this.onMenuSelected,
    required this.onQuickAction,
  });

  final Map<String, dynamic> data;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<_ReportAction> onMenuSelected;
  final ValueChanged<_ReportAction> onQuickAction;

  @override
  Widget build(BuildContext context) {
    final status = _reportStatus(data);
    final createdAt = _timestampOf(data, 'createdAt');
    final title = _reportTitle(data);
    final videoOwner = _videoOwner(data);
    final reporter = _reporterName(data);
    final reason = _reportReason(data);
    final duration = _durationLabel(data);
    final thumb = _thumbnailUrl(data);
    final typeLabel = _videoTypeLabel(data);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF131F33)
                : const Color(0xFF10192A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6D42F5)
                  : Colors.white.withOpacity(0.07),
              width: isSelected ? 1.3 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 104,
                      height: 78,
                      color: const Color(0xFF1A2740),
                      child: thumb == null || thumb.isEmpty
                          ? const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF324F84),
                                    Color(0xFF121D31),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.ondemand_video_rounded,
                                color: Colors.white70,
                                size: 32,
                              ),
                            )
                          : Image.network(
                              thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF324F84),
                                      Color(0xFF121D31),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.ondemand_video_rounded,
                                  color: Colors.white70,
                                  size: 32,
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (duration != null)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          duration,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                ],
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${context.tr('by')} $videoOwner',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withOpacity(0.76),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(status: status),
                        PopupMenuButton<_ReportAction>(
                          onSelected: onMenuSelected,
                          color: const Color(0xFF151E31),
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white.withOpacity(0.75),
                          ),
                          itemBuilder: (context) => [
                            if (status != 'resolved')
                              PopupMenuItem(
                                value: _ReportAction.markReviewed,
                                child: Text(context.tr('Mark reviewed')),
                              ),
                            if (status != 'dismissed')
                              PopupMenuItem(
                                value: _ReportAction.dismiss,
                                child: Text(context.tr('Dismiss')),
                              ),
                            if (status != 'open')
                              PopupMenuItem(
                                value: _ReportAction.reopen,
                                child: Text(context.tr('Reopen')),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _MetaText(
                          icon: Icons.video_collection_outlined,
                          text: typeLabel,
                        ),
                        _MetaText(
                          icon: Icons.person_outline_rounded,
                          text: '${context.tr('Reported by')}: $reporter',
                        ),
                        _MetaText(
                          icon: Icons.event_outlined,
                          text: _formatDateTime(createdAt),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr('Reason')}: $reason',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.7),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (status != 'resolved')
                          _QuickActionChip(
                            label: context.tr('Review'),
                            color: const Color(0xFF239A54),
                            icon: Icons.check_circle_outline,
                            onTap: () =>
                                onQuickAction(_ReportAction.markReviewed),
                          ),
                        if (status != 'dismissed')
                          _QuickActionChip(
                            label: context.tr('Dismiss'),
                            color: const Color(0xFF8B95A7),
                            icon: Icons.remove_circle_outline,
                            onTap: () => onQuickAction(_ReportAction.dismiss),
                          ),
                        if (status != 'open')
                          _QuickActionChip(
                            label: context.tr('Reopen'),
                            color: const Color(0xFFB86BFF),
                            icon: Icons.refresh_rounded,
                            onTap: () => onQuickAction(_ReportAction.reopen),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.6)),
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withOpacity(0.72),
          ),
        ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportDetailPanel extends StatelessWidget {
  const _ReportDetailPanel({required this.data, required this.onAction});

  final Map<String, dynamic>? data;
  final ValueChanged<_ReportAction>? onAction;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const SizedBox.shrink();
    }

    final status = _reportStatus(data!);
    final createdAt = _timestampOf(data!, 'createdAt');
    final updatedAt = _timestampOf(data!, 'updatedAt');
    final reviewedAt = _timestampOf(data!, 'reviewedAt');
    final title = _reportTitle(data!);
    final owner = _videoOwner(data!);
    final reporter = _reporterName(data!);
    final reason = _reportReason(data!);
    final thumb = _thumbnailUrl(data!);
    final duration = _durationLabel(data!);
    final typeLabel = _videoTypeLabel(data!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1829),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Report Details'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 118,
                      height: 88,
                      color: const Color(0xFF1A2740),
                      child: thumb == null || thumb.isEmpty
                          ? const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF324F84),
                                    Color(0xFF121D31),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.ondemand_video_rounded,
                                color: Colors.white70,
                                size: 36,
                              ),
                            )
                          : Image.network(
                              thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF324F84),
                                      Color(0xFF121D31),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.ondemand_video_rounded,
                                  color: Colors.white70,
                                  size: 36,
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (duration != null)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          duration,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        _StatusPill(status: status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${context.tr('by')} $owner',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _MetaText(
                          icon: Icons.video_collection_outlined,
                          text: typeLabel,
                        ),
                        _MetaText(
                          icon: Icons.person_outline_rounded,
                          text: reporter,
                        ),
                        _MetaText(
                          icon: Icons.event_outlined,
                          text: _formatDateTime(createdAt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailRow(label: context.tr('Reason'), value: reason),
          _DetailRow(
            label: context.tr('Reporter'),
            value: _reporterDetail(data!),
          ),
          _DetailRow(
            label: context.tr('Video owner'),
            value: _ownerDetail(data!),
          ),
          _DetailRow(
            label: context.tr('Created'),
            value: _formatDateTime(createdAt),
          ),
          if (updatedAt.millisecondsSinceEpoch > 0)
            _DetailRow(
              label: context.tr('Updated'),
              value: _formatDateTime(updatedAt),
            ),
          if (reviewedAt.millisecondsSinceEpoch > 0)
            _DetailRow(
              label: context.tr('Reviewed at'),
              value: _formatDateTime(reviewedAt),
            ),
          const SizedBox(height: 14),
          Text(
            context.tr('Take Action'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (status != 'resolved')
                _ActionButton(
                  label: context.tr('Mark reviewed'),
                  color: const Color(0xFF239A54),
                  onTap: onAction == null
                      ? null
                      : () => onAction!(_ReportAction.markReviewed),
                ),
              if (status != 'dismissed')
                _ActionButton(
                  label: context.tr('Dismiss report'),
                  color: const Color(0xFF8B95A7),
                  onTap: onAction == null
                      ? null
                      : () => onAction!(_ReportAction.dismiss),
                ),
              if (status != 'open')
                _ActionButton(
                  label: context.tr('Reopen'),
                  color: const Color(0xFFB86BFF),
                  onTap: onAction == null
                      ? null
                      : () => onAction!(_ReportAction.reopen),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.58),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.88),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'resolved' => const Color(0xFF25A95C),
      'dismissed' => const Color(0xFF6B7280),
      _ => const Color(0xFFB84A4A),
    };
    final label = switch (status) {
      'resolved' => context.tr('Reviewed'),
      'dismissed' => context.tr('Dismissed'),
      _ => context.tr('Pending'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyReportsCard extends StatelessWidget {
  const _EmptyReportsCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10192A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.8)),
      ),
    );
  }
}

class _ReportSummary {
  const _ReportSummary({
    required this.total,
    required this.open,
    required this.reviewed,
    required this.dismissed,
    required this.contestReports,
    required this.feedReports,
  });

  final int total;
  final int open;
  final int reviewed;
  final int dismissed;
  final int contestReports;
  final int feedReports;

  factory _ReportSummary.fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var open = 0;
    var reviewed = 0;
    var dismissed = 0;
    var contestReports = 0;
    var feedReports = 0;

    for (final doc in docs) {
      final data = doc.data();
      switch (_reportStatus(data)) {
        case 'resolved':
          reviewed++;
          break;
        case 'dismissed':
          dismissed++;
          break;
        default:
          open++;
      }

      final type = _videoTypeKey(data);
      if (type == 'contest') {
        contestReports++;
      } else if (type == 'feed') {
        feedReports++;
      }
    }

    return _ReportSummary(
      total: docs.length,
      open: open,
      reviewed: reviewed,
      dismissed: dismissed,
      contestReports: contestReports,
      feedReports: feedReports,
    );
  }
}

enum _ReportAction { markReviewed, dismiss, reopen }

String _reportStatus(Map<String, dynamic> data) {
  final raw = (data['status'] ?? 'open').toString().toLowerCase();
  switch (raw) {
    case 'resolved':
    case 'reviewed':
      return 'resolved';
    case 'dismissed':
      return 'dismissed';
    default:
      return 'open';
  }
}

String _reportTitle(Map<String, dynamic> data) {
  final values = [
    data['videoTitle'],
    data['submissionTitle'],
    data['contestTitle'],
    data['title'],
  ];
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return 'Untitled video';
}

String _videoOwner(Map<String, dynamic> data) {
  final values = [
    data['participantName'],
    data['userName'],
    data['participantEmail'],
    data['userEmail'],
  ];
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return 'Unknown';
}

String _ownerDetail(Map<String, dynamic> data) {
  final values = [
    data['participantName'],
    data['userName'],
    data['participantEmail'],
    data['userEmail'],
    data['targetUserId'],
  ].map((value) => (value ?? '').toString().trim()).where((e) => e.isNotEmpty);
  if (values.isEmpty) return 'Unknown';
  return values.join(' • ');
}

String _reporterName(Map<String, dynamic> data) {
  final values = [
    data['reporterName'],
    data['reporterEmail'],
    data['reportedBy'],
  ];
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return 'Unknown';
}

String _reporterDetail(Map<String, dynamic> data) {
  final values = [
    data['reporterName'],
    data['reporterEmail'],
    data['reporterId'],
  ].map((value) => (value ?? '').toString().trim()).where((e) => e.isNotEmpty);
  if (values.isEmpty) return 'Unknown';
  return values.join(' • ');
}

String _reportReason(Map<String, dynamic> data) {
  final text = (data['reason'] ?? data['message'] ?? '').toString().trim();
  return text.isEmpty ? 'Not specified' : text;
}

String? _thumbnailUrl(Map<String, dynamic> data) {
  final values = [
    data['thumbnailUrl'],
    data['thumbUrl'],
    data['previewImageUrl'],
    data['imageUrl'],
  ];
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

String? _durationLabel(Map<String, dynamic> data) {
  final values = [data['durationLabel'], data['videoDurationLabel']];
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

DateTime _timestampOf(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Timestamp) return value.toDate();
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _videoTypeKey(Map<String, dynamic> data) {
  final raw = (data['videoType'] ?? '').toString().toLowerCase().trim();
  if (raw.contains('admin')) return 'feed';
  if (raw.contains('feed')) return 'feed';
  if (raw.contains('contest')) return 'contest';
  return 'unknown';
}

String _videoTypeLabel(Map<String, dynamic> data) {
  switch (_videoTypeKey(data)) {
    case 'feed':
      return 'Feed Video';
    case 'contest':
      return 'Contest Submission';
    default:
      return 'Reported Video';
  }
}

String _formatDateTime(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return 'Unknown date';
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
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year} • $hour:$minute $suffix';
}
