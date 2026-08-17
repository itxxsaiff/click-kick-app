import 'package:flutter/material.dart';

import '../services/block_service.dart';

/// Rebuilds [builder] with the current user's blocked participant ids and
/// keeps it live as the block list changes. Emits an empty set while loading
/// or when signed out. Used to instantly hide blocked participants' videos
/// wherever contest submissions are shown (App Store Guideline 1.2).
class BlockedUsersBuilder extends StatelessWidget {
  const BlockedUsersBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, Set<String> blockedUserIds)
  builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: BlockService().blockedUserIdsStream(),
      builder: (context, snapshot) =>
          builder(context, snapshot.data ?? const <String>{}),
    );
  }
}
