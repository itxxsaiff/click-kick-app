import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/click_kick_star_service.dart';
import '../../theme/app_colors.dart';

class ClickKickStarPage extends StatefulWidget {
  const ClickKickStarPage({super.key});

  @override
  State<ClickKickStarPage> createState() => _ClickKickStarPageState();
}

class _ClickKickStarPageState extends State<ClickKickStarPage> {
  final _service = ClickKickStarService();
  final _searchController = TextEditingController();
  late Future<List<ClickKickStarEntry>> _future;
  String _selectedCountry = 'all';
  String _selectedLevel = 'all';
  int _selectedVotes = 0;

  @override
  void initState() {
    super.initState();
    _future = _service.loadEntries();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = _service.loadEntries());
    await _future;
  }

  List<ClickKickStarEntry> _filter(List<ClickKickStarEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    return entries.where((entry) {
      final matchesQuery =
          query.isEmpty ||
          entry.displayName.toLowerCase().contains(query) ||
          entry.country.toLowerCase().contains(query);
      final matchesCountry =
          _selectedCountry == 'all' || entry.country == _selectedCountry;
      final matchesLevel =
          _selectedLevel == 'all' || entry.levelKey == _selectedLevel;
      final matchesVotes = entry.totalVotes >= _selectedVotes;
      return matchesQuery && matchesCountry && matchesLevel && matchesVotes;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ClickKickStarEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEntries = snapshot.data ?? const <ClickKickStarEntry>[];
          final entries = _filter(allEntries);
          final countries = <String>{
            for (final entry in allEntries)
              if (entry.country.trim().isNotEmpty) entry.country.trim(),
          }.toList()..sort();

          final grouped = <String, List<ClickKickStarEntry>>{};
          for (final level in ClickKickStarService.levelDefinitions) {
            final key = (level['key'] ?? '').toString();
            grouped[key] = entries
                .where((entry) => entry.levelKey == key)
                .toList();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeroCard(),
              const SizedBox(height: 14),
              _SearchAndFilters(
                controller: _searchController,
                countries: countries,
                selectedCountry: _selectedCountry,
                selectedLevel: _selectedLevel,
                selectedVotes: _selectedVotes,
                onCountryChanged: (value) =>
                    setState(() => _selectedCountry = value),
                onLevelChanged: (value) =>
                    setState(() => _selectedLevel = value),
                onVotesChanged: (value) =>
                    setState(() => _selectedVotes = value),
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
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                ...ClickKickStarService.levelDefinitions.map((level) {
                  final key = (level['key'] ?? '').toString();
                  final label = (level['label'] ?? '').toString();
                  final levelEntries =
                      grouped[key] ?? const <ClickKickStarEntry>[];
                  if (levelEntries.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            context.tr(label),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        ...levelEntries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CreatorRankCard(entry: entry),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF32145A), Color(0xFF11101F)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.cardSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Click Kick Star'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Official creator ranking based on real contest performance and total votes.',
                  ),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.countries,
    required this.selectedCountry,
    required this.selectedLevel,
    required this.selectedVotes,
    required this.onCountryChanged,
    required this.onLevelChanged,
    required this.onVotesChanged,
  });

  final TextEditingController controller;
  final List<String> countries;
  final String selectedCountry;
  final String selectedLevel;
  final int selectedVotes;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<int> onVotesChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: context.tr('Search by Creator Name'),
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final countryDropdown = _FilterChipDropdown<String>(
              value: selectedCountry,
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(context.tr('All Countries')),
                ),
                ...countries.map(
                  (country) =>
                      DropdownMenuItem(value: country, child: Text(country)),
                ),
              ],
              onChanged: (value) => onCountryChanged(value ?? 'all'),
            );
            final levelDropdown = _FilterChipDropdown<String>(
              value: selectedLevel,
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(context.tr('All Levels')),
                ),
                ...ClickKickStarService.levelDefinitions.map(
                  (level) => DropdownMenuItem(
                    value: (level['key'] ?? '').toString(),
                    child: Text(context.tr((level['label'] ?? '').toString())),
                  ),
                ),
              ],
              onChanged: (value) => onLevelChanged(value ?? 'all'),
            );
            final votesDropdown = _FilterChipDropdown<int>(
              value: selectedVotes,
              items: [
                DropdownMenuItem(
                  value: 0,
                  child: Text(context.tr('All Votes')),
                ),
                const DropdownMenuItem(value: 1000000, child: Text('1M+')),
                const DropdownMenuItem(value: 2000000, child: Text('2M+')),
                const DropdownMenuItem(value: 3000000, child: Text('3M+')),
                const DropdownMenuItem(value: 5000000, child: Text('5M+')),
                const DropdownMenuItem(value: 7000000, child: Text('7M+')),
                const DropdownMenuItem(value: 10000000, child: Text('10M+')),
              ],
              onChanged: (value) => onVotesChanged(value ?? 0),
            );

            if (constraints.maxWidth >= 720) {
              return Row(
                children: [
                  Expanded(child: countryDropdown),
                  const SizedBox(width: 10),
                  Expanded(child: levelDropdown),
                  const SizedBox(width: 10),
                  Expanded(child: votesDropdown),
                ],
              );
            }

            final itemWidth = constraints.maxWidth < 420
                ? 180.0
                : ((constraints.maxWidth - 20) / 3).clamp(170.0, 240.0);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(width: itemWidth, child: countryDropdown),
                  const SizedBox(width: 10),
                  SizedBox(width: itemWidth, child: levelDropdown),
                  const SizedBox(width: 10),
                  SizedBox(width: itemWidth, child: votesDropdown),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FilterChipDropdown<T> extends StatelessWidget {
  const _FilterChipDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          alignment: AlignmentDirectional.centerStart,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          borderRadius: BorderRadius.circular(16),
          dropdownColor: AppColors.card,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CreatorRankCard extends StatelessWidget {
  const _CreatorRankCard({required this.entry});

  final ClickKickStarEntry entry;

  String _formatMetric(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    }
    return value.toString();
  }

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
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '#${entry.rank}',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 30,
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
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (entry.verified)
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF4DA3FF),
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.country.isEmpty
                      ? context.tr('Country not set')
                      : entry.country,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.workspace_premium_outlined,
                      label: context.tr(entry.levelLabel),
                    ),
                    _InfoPill(
                      icon: Icons.how_to_vote_outlined,
                      label:
                          '${_formatMetric(entry.totalVotes)} ${context.tr('Votes')}',
                    ),
                    _InfoPill(
                      icon: Icons.video_library_outlined,
                      label:
                          '${entry.totalUploadedVideos} ${context.tr('Videos')}',
                    ),
                    _InfoPill(
                      icon: Icons.emoji_events_outlined,
                      label: '${entry.totalContestWins} ${context.tr('Wins')}',
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.hotPink),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
