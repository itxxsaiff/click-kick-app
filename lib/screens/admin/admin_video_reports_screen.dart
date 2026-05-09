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
  String _status = 'open';
  bool _showOldestFirst = false;

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
              context.tr('Review user reported videos'),
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
            final pendingCount = allDocs
                .where((doc) => _reportStatus(doc.data()) == 'open')
                .length;
            final reviewedCount = allDocs
                .where((doc) => _reportStatus(doc.data()) == 'resolved')
                .length;
            final dismissedCount = allDocs
                .where((doc) => _reportStatus(doc.data()) == 'dismissed')
                .length;

            final filtered =
                allDocs.where((doc) {
                  final data = doc.data();
                  final status = _reportStatus(data);
                  if (_status != status) return false;

                  if (_query.isEmpty) return true;
                  final haystack = [
                    _reportTitle(context, data),
                    _videoOwner(data),
                    _reporterName(data),
                    _reportReason(data),
                  ].join(' ').toLowerCase();
                  return haystack.contains(_query);
                }).toList()..sort((a, b) {
                  final aDate = _timestampOf(a.data(), 'createdAt');
                  final bDate = _timestampOf(b.data(), 'createdAt');
                  final compare = aDate.compareTo(bDate);
                  return _showOldestFirst ? compare : -compare;
                });

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              children: [
                _ReportTabs(
                  selected: _status,
                  pendingCount: pendingCount,
                  reviewedCount: reviewedCount,
                  dismissedCount: dismissedCount,
                  onChanged: (value) => setState(() => _status = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: context.tr('Search reports'),
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: const Color(0xFF101A2B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.hotPink,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PopupMenuButton<bool>(
                      tooltip: context.tr('Sort'),
                      initialValue: _showOldestFirst,
                      onSelected: (value) =>
                          setState(() => _showOldestFirst = value),
                      color: const Color(0xFF151E31),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: false,
                          child: Text(context.tr('Newest first')),
                        ),
                        PopupMenuItem(
                          value: true,
                          child: Text(context.tr('Oldest first')),
                        ),
                      ],
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C45F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  _EmptyReportsCard(message: context.tr('No matching reports.'))
                else ...[
                  for (final doc in filtered) ...[
                    _ReportCard(
                      data: doc.data(),
                      onMenuSelected: (action) =>
                          _handleAction(doc.reference, action),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Text(
                        context.tr('No more reports'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.58),
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
    );
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

class _ReportTabs extends StatelessWidget {
  const _ReportTabs({
    required this.selected,
    required this.pendingCount,
    required this.reviewedCount,
    required this.dismissedCount,
    required this.onChanged,
  });

  final String selected;
  final int pendingCount;
  final int reviewedCount;
  final int dismissedCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('open', '${context.tr('Pending')} ($pendingCount)'),
      ('resolved', '${context.tr('Reviewed')} ($reviewedCount)'),
      ('dismissed', '${context.tr('Dismissed')} ($dismissedCount)'),
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF10192A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          for (final (value, label) in tabs)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected == value
                        ? const Color(0xFF6D42F5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
  const _ReportCard({required this.data, required this.onMenuSelected});

  final Map<String, dynamic> data;
  final ValueChanged<_ReportAction> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final status = _reportStatus(data);
    final submittedAt = _timestampOf(data, 'createdAt');
    final title = _reportTitle(context, data);
    final subtitle = _videoOwner(data);
    final reporter = _reporterName(data);
    final reason = _reportReason(data);
    final duration = _durationLabel(data);
    final thumb = _thumbnailUrl(data);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF10192A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 96,
                  height: 72,
                  color: const Color(0xFF1A2740),
                  child: thumb == null || thumb.isEmpty
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF324F84), Color(0xFF121D31)],
                            ),
                          ),
                          child: Icon(
                            Icons.ondemand_video_rounded,
                            color: Colors.white70,
                            size: 30,
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
                                colors: [Color(0xFF324F84), Color(0xFF121D31)],
                              ),
                            ),
                            child: Icon(
                              Icons.ondemand_video_rounded,
                              color: Colors.white70,
                              size: 30,
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
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                          const SizedBox(height: 2),
                          Text(
                            '${context.tr('by')} $subtitle',
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
                    const SizedBox(width: 4),
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
                Text(
                  '${context.tr('Reported by')}: $reporter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.78),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${context.tr('Reason')}: $reason',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.62),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatShortDate(submittedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.58),
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

String _reportTitle(BuildContext context, Map<String, dynamic> data) {
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
  return context.tr('Untitled video');
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

String _formatShortDate(DateTime value) {
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
  return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year}';
}
