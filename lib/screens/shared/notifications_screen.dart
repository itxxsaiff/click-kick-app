import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';

/// A user's own `users/{uid}/notifications` inbox (video approved/rejected,
/// a new contest, voting starting, results, etc.) — the in-app counterpart
/// to the push notification that already arrived on their device.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  CollectionReference<Map<String, dynamic>>? _collection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');
  }

  Future<void> _markAllRead(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final unread = docs.where((d) => d.data()['read'] != true).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final collection = _collection();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Notifications')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: collection == null
                ? Center(child: Text(context.tr('Please login.')))
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: collection
                        .orderBy('createdAt', descending: true)
                        .limit(100)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(context.tr('Unable to load videos.')),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            context.tr('No notifications yet.'),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _markAllRead(context, docs),
                              child: Text(context.tr('Mark all read')),
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              itemCount: docs.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) =>
                                  _NotificationTile(doc: docs[index]),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  String _relativeTime(BuildContext context, DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return context.tr('Just now');
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = (data['title'] ?? '').toString();
    final message = (data['message'] ?? '').toString();
    final isRead = data['read'] == true;
    final route = (data['route'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (!isRead) doc.reference.update({'read': true});
        if (route.isNotEmpty) Navigator.pushNamed(context, route);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead
              ? AppColors.card.withValues(alpha: 0.6)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? AppColors.border : AppColors.hotPink,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(top: 6, right: 10),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.hotPink,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _relativeTime(context, createdAt),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
