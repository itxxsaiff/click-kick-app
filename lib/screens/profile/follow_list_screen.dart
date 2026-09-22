import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/follow_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/follow_widgets.dart';
import 'user_profile_screen.dart';

enum FollowListMode { followers, following }

/// "Followers" (people who follow [userId]) or "Following" (people [userId]
/// follows), with search and a Follow / Following button per row.
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({super.key, required this.userId, required this.mode});

  final String userId;
  final FollowListMode mode;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final _service = FollowService();
  final _searchController = TextEditingController();
  late Future<List<UserBrief>> _future;
  String _query = '';

  bool get _isFollowers => widget.mode == FollowListMode.followers;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<UserBrief>> _load() async {
    final ids = _isFollowers
        ? await _service.followerIds(widget.userId)
        : await _service.followingIds(widget.userId);
    final users = await UserDirectory.getMany(ids);
    // Keep the newest-first order; users whose profile no longer exists are
    // skipped.
    return [
      for (final id in ids)
        if (users[id] != null && users[id]!.name.isNotEmpty) users[id]!,
    ];
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: FutureBuilder<List<UserBrief>>(
              future: _future,
              builder: (context, snapshot) {
                final all = snapshot.data ?? const <UserBrief>[];
                final loading =
                    snapshot.connectionState != ConnectionState.done;
                final filtered = _query.isEmpty
                    ? all
                    : all
                          .where((u) => u.name.toLowerCase().contains(_query))
                          .toList();
                final title = _isFollowers
                    ? context.tr('Followers')
                    : context.tr('Following');
                final countLabel = _isFollowers
                    ? '${all.length} ${context.tr('Followers')}'
                    : '${all.length} ${context.tr('Following')}';

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: () => Navigator.maybePop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.card,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 28,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (!loading)
                                  Text(
                                    countLabel,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) =>
                            setState(() => _query = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: _isFollowers
                              ? context.tr('Search followers...')
                              : context.tr('Search following...'),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : snapshot.hasError
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(context.tr('Unable to load the list.')),
                                  const SizedBox(height: 10),
                                  OutlinedButton(
                                    onPressed: _reload,
                                    child: Text(context.tr('Retry')),
                                  ),
                                ],
                              ),
                            )
                          : filtered.isEmpty
                          ? Center(
                              child: Text(
                                _isFollowers
                                    ? context.tr('No followers yet.')
                                    : context.tr('Not following anyone yet.'),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _reload,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  24,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) =>
                                    _UserRow(user: filtered[i]),
                              ),
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

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final UserBrief user;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: user.uid)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            UserAvatar(photoUrl: user.photoUrl, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (user.country.isNotEmpty)
                    Text(
                      user.country,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FollowButton(targetUserId: user.uid),
          ],
        ),
      ),
    );
  }
}
