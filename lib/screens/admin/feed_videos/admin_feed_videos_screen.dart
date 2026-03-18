import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('admin_videos')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Feed Videos')),
        backgroundColor: AppColors.deepSpace,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminFeedVideoForm()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr('Add Video')),
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    labelText: context.tr('Search by caption'),
                    prefixIcon: const Icon(Icons.search),
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
                      if (_search.isEmpty) return true;
                      final data = doc.data();
                      final caption = (data['caption'] ?? '')
                          .toString()
                          .toLowerCase();
                      return caption.contains(_search);
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final caption = (data['caption'] ?? '').toString();
                        final adminName = (data['adminName'] ?? '').toString();
                        final videoUrl = (data['videoUrl'] ?? '').toString();

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 58,
                                height: 82,
                                decoration: BoxDecoration(
                                  color: AppColors.cardSoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: AppColors.hotPink,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          radius: 12,
                                          backgroundColor: AppColors.cardSoft,
                                          child: Icon(
                                            Icons.admin_panel_settings,
                                            color: AppColors.hotPink,
                                            size: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            adminName.isEmpty
                                                ? context.tr('Admin')
                                                : adminName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.textLight,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      caption,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        height: 1.35,
                                      ),
                                    ),
                                    if (videoUrl.isEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        context.tr('Video missing'),
                                        style: const TextStyle(
                                          color: AppColors.sunset,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'delete') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text(
                                          context.tr('Delete video?'),
                                        ),
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
