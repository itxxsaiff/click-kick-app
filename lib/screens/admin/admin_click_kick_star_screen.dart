import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/click_kick_star_service.dart';
import '../../theme/app_colors.dart';

class AdminClickKickStarScreen extends StatefulWidget {
  const AdminClickKickStarScreen({super.key});

  @override
  State<AdminClickKickStarScreen> createState() =>
      _AdminClickKickStarScreenState();
}

class _AdminClickKickStarScreenState extends State<AdminClickKickStarScreen> {
  final _service = ClickKickStarService();
  final _searchController = TextEditingController();
  late Future<List<ClickKickStarEntry>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _service.loadEntries(publicOnly: false);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _future = _service.loadEntries(publicOnly: false));
    await _future;
  }

  List<ClickKickStarEntry> _filterEntries(List<ClickKickStarEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    return entries.where((entry) {
      final matchesQuery =
          query.isEmpty ||
          entry.displayName.toLowerCase().contains(query) ||
          entry.country.toLowerCase().contains(query);
      final matchesFilter =
          _filter == 'all' ||
          (_filter == 'visible' && !entry.hidden && !entry.removed) ||
          (_filter == 'hidden' && entry.hidden) ||
          (_filter == 'unapproved' && !entry.approved) ||
          (_filter == 'removed' && entry.removed);
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Future<void> _applyAction(ClickKickStarEntry entry, String action) async {
    switch (action) {
      case 'approve':
        await _service.updateModeration(
          entry.userId,
          approved: true,
          removed: false,
        );
        break;
      case 'unapprove':
        await _service.updateModeration(entry.userId, approved: false);
        break;
      case 'hide':
        await _service.updateModeration(entry.userId, hidden: true);
        break;
      case 'show':
        await _service.updateModeration(
          entry.userId,
          hidden: false,
          removed: false,
        );
        break;
      case 'remove':
        await _service.updateModeration(
          entry.userId,
          removed: true,
          hidden: true,
        );
        break;
      case 'restore':
        await _service.updateModeration(
          entry.userId,
          removed: false,
          hidden: false,
        );
        break;
    }
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              context.tr('Click Kick Star Management'),
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              context.tr(
                                'Manage creator rankings and visibility',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<ClickKickStarEntry>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final allEntries =
                          snapshot.data ?? const <ClickKickStarEntry>[];
                      final stats = _service.buildStats(allEntries);
                      final entries = _filterEntries(allEntries);
                      return RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _AdminSummaryGrid(stats: stats),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: context.tr('Search by Creator Name'),
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: AppColors.card,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final filter in const [
                                  ['all', 'All'],
                                  ['visible', 'Visible'],
                                  ['hidden', 'Hidden'],
                                  ['unapproved', 'Unapproved'],
                                  ['removed', 'Removed'],
                                ])
                                  ChoiceChip(
                                    label: Text(context.tr(filter[1])),
                                    selected: _filter == filter[0],
                                    onSelected: (_) =>
                                        setState(() => _filter = filter[0]),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (entries.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Center(
                                  child: Text(
                                    context.tr('No ranked creators found yet.'),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...entries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _AdminCreatorCard(
                                    entry: entry,
                                    onAction: (action) =>
                                        _applyAction(entry, action),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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

class _AdminSummaryGrid extends StatelessWidget {
  const _AdminSummaryGrid({required this.stats});

  final ClickKickStarStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      [
        context.tr('Total Creators'),
        '${stats.totalCreators}',
        AppColors.hotPink,
      ],
      [context.tr('Visible'), '${stats.visibleCreators}', AppColors.neonGreen],
      [context.tr('Hidden'), '${stats.hiddenCreators}', AppColors.sunset],
      [
        context.tr('Unapproved'),
        '${stats.unapprovedCreators}',
        const Color(0xFF65E8FF),
      ],
      [context.tr('Total Votes'), '${stats.totalVotes}', AppColors.gold],
      [context.tr('Total Wins'), '${stats.totalWins}', AppColors.magenta],
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: cardWidth,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item[1] as String,
                        style: TextStyle(
                          color: item[2] as Color,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item[0] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminCreatorCard extends StatelessWidget {
  const _AdminCreatorCard({required this.entry, required this.onAction});

  final ClickKickStarEntry entry;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.cardSoft,
            backgroundImage: entry.photoUrl.isNotEmpty
                ? NetworkImage(entry.photoUrl)
                : null,
            child: entry.photoUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
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
                        entry.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _StatusPill(
                      label: entry.removed
                          ? context.tr('Removed')
                          : entry.hidden
                          ? context.tr('Hidden')
                          : entry.approved
                          ? context.tr('Approved')
                          : context.tr('Unapproved'),
                      color: entry.removed
                          ? Colors.redAccent
                          : entry.hidden
                          ? AppColors.sunset
                          : entry.approved
                          ? AppColors.neonGreen
                          : const Color(0xFF65E8FF),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.country.isEmpty ? context.tr('Country not set') : entry.country} • ${context.tr(entry.levelLabel)}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniMetric(
                      label: context.tr('Votes'),
                      value: '${entry.totalVotes}',
                    ),
                    _MiniMetric(
                      label: context.tr('Videos'),
                      value: '${entry.totalUploadedVideos}',
                    ),
                    _MiniMetric(
                      label: context.tr('Wins'),
                      value: '${entry.totalContestWins}',
                    ),
                    _MiniMetric(
                      label: context.tr('Rank'),
                      value: '#${entry.rank}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          onAction(entry.approved ? 'unapprove' : 'approve'),
                      child: Text(
                        context.tr(entry.approved ? 'Unapprove' : 'Approve'),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => onAction(entry.hidden ? 'show' : 'hide'),
                      child: Text(context.tr(entry.hidden ? 'Show' : 'Hide')),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          onAction(entry.removed ? 'restore' : 'remove'),
                      child: Text(
                        context.tr(entry.removed ? 'Restore' : 'Remove'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.nebula, AppColors.deepSpace],
        ),
      ),
    );
  }
}
