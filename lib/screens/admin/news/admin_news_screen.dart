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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _statusValue(Map<String, dynamic> data) {
    final raw = (data['status'] ?? '').toString().trim().toLowerCase();
    if (raw.isNotEmpty) return raw;
    final scheduledAt = data['scheduledAt'];
    if (scheduledAt is Timestamp &&
        scheduledAt.toDate().isAfter(DateTime.now())) {
      return 'scheduled';
    }
    return 'published';
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'published':
        return context.tr('Published');
      case 'draft':
        return context.tr('Draft');
      case 'scheduled':
        return context.tr('Scheduled');
      case 'expired':
        return context.tr('Expired');
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return const Color(0xFF38E27B);
      case 'draft':
        return const Color(0xFFFFB23F);
      case 'scheduled':
        return const Color(0xFF4EA3FF);
      case 'expired':
        return const Color(0xFFFF5D73);
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

                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data();
                      final title = (data['title'] ?? '')
                          .toString()
                          .toLowerCase();
                      final body = (data['body'] ?? '')
                          .toString()
                          .toLowerCase();
                      final matchesSearch =
                          _search.isEmpty ||
                          title.contains(_search) ||
                          body.contains(_search);
                      return matchesSearch;
                    }).toList();

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          _search.isEmpty
                              ? context.tr('No news added yet.')
                              : context.tr('No matching news.'),
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
                                context.tr('No more news'),
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
                        final title = (data['title'] ?? '').toString();
                        final body = (data['body'] ?? '').toString();
                        final imageUrl = (data['imageUrl'] ?? '').toString();
                        final createdAt = (data['createdAt'] as Timestamp?)
                            ?.toDate();
                        final scheduledAt = (data['scheduledAt'] as Timestamp?)
                            ?.toDate();
                        final views =
                            ((data['views'] ?? data['viewCount'] ?? 0) as num)
                                .toDouble();
                        final status = _statusValue(data);
                        final statusColor = _statusColor(status);

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151324),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border.withOpacity(0.88),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 96,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.cardSoft,
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: imageUrl.isEmpty
                                      ? const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF4B1A7E),
                                            Color(0xFF12101C),
                                          ],
                                        )
                                      : null,
                                ),
                                child: imageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.image_not_supported,
                                                color: AppColors.textMuted,
                                              ),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.campaign,
                                          color: Colors.white70,
                                          size: 30,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
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
                                            color: statusColor.withOpacity(
                                              0.16,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            _statusLabel(context, status),
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
                                          label: _formatShortDate(createdAt),
                                        ),
                                        if (scheduledAt != null)
                                          _MetaPill(
                                            icon: Icons.schedule_outlined,
                                            label: _formatShortDate(
                                              scheduledAt,
                                            ),
                                          ),
                                        _MetaPill(
                                          icon: Icons.visibility_outlined,
                                          label:
                                              '${_formatViews(views)} ${context.tr('views')}',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: AppColors.textMuted,
                                ),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AdminNewsForm(
                                          newsId: doc.id,
                                          existing: data,
                                        ),
                                      ),
                                    );
                                  } else if (value == 'delete') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text(context.tr('Delete news?')),
                                        content: Text(
                                          context.tr('This cannot be undone.'),
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
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(context.tr('Edit')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(context.tr('Delete')),
                                  ),
                                ],
                              ),
                            ],
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
