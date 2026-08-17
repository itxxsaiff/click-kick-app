import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/block_service.dart';
import '../../theme/app_colors.dart';

/// Lets a user review and unblock participants they have blocked.
/// Reachable from the account/settings area (App Store Guideline 1.2).
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _blockService = BlockService();

  Future<void> _unblock(String userId) async {
    final confirmMsg = context.tr('Unblock this participant?');
    final doneMsg = context.tr('Participant unblocked.');
    final errorMsg = context.tr('Something went wrong. Please try again.');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Unblock')),
        content: Text(confirmMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Unblock')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _blockService.unblockParticipant(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(doneMsg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Blocked Users')),
        backgroundColor: AppColors.deepSpace,
      ),
      backgroundColor: AppColors.deepSpace,
      body: StreamBuilder<Set<String>>(
        stream: _blockService.blockedUserIdsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final blocked = snapshot.data!.toList();
          if (blocked.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr('No blocked users.'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: blocked.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final userId = blocked[index];
              return _BlockedUserTile(
                userId: userId,
                onUnblock: () => _unblock(userId),
              );
            },
          );
        },
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({required this.userId, required this.onUnblock});

  final String userId;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name =
            (data['displayName'] ??
                    data['userName'] ??
                    context.tr('Participant'))
                .toString();
        final email = (data['email'] ?? '').toString();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.cardSoft,
                child: Icon(Icons.person_outline, color: AppColors.hotPink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onUnblock,
                child: Text(context.tr('Unblock')),
              ),
            ],
          ),
        );
      },
    );
  }
}
