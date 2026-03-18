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
  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('news')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('News')),
        backgroundColor: AppColors.deepSpace,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminNewsForm()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr('Add News')),
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(child: Text(context.tr('No news added yet.')));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final title = (data['title'] ?? '').toString();
                  final body = (data['body'] ?? '').toString();
                  final imageUrl = (data['imageUrl'] ?? '').toString();

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.cardSoft,
                            borderRadius: BorderRadius.circular(12),
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
                              : const Icon(
                                  Icons.campaign,
                                  color: AppColors.hotPink,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminNewsForm(
                                    newsId: doc.id,
                                    existing: data,
                                  ),
                                ),
                              );
                            } else if (v == 'delete') {
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
