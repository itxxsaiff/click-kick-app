import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/moderation_stat_card.dart';

/// One country's display info: a friendly name plus its ISO-3166 alpha-2
/// code (used to render the flag emoji).
class _CountryInfo {
  const _CountryInfo(this.name, this.iso2);
  final String name;
  final String iso2;
}

/// Known calling codes -> country info. Only the markets the client cares
/// about are named explicitly; anything else just shows its raw dialing
/// code so nothing silently gets lost.
const Map<String, _CountryInfo> _kDialCodeInfo = {
  '+962': _CountryInfo('Jordan', 'JO'),
  '+966': _CountryInfo('Saudi Arabia', 'SA'),
  '+973': _CountryInfo('Bahrain', 'BH'),
  '+971': _CountryInfo('United Arab Emirates', 'AE'),
  '+965': _CountryInfo('Kuwait', 'KW'),
  '+974': _CountryInfo('Qatar', 'QA'),
  '+968': _CountryInfo('Oman', 'OM'),
  '+20': _CountryInfo('Egypt', 'EG'),
  '+961': _CountryInfo('Lebanon', 'LB'),
  '+964': _CountryInfo('Iraq', 'IQ'),
  '+970': _CountryInfo('Palestine', 'PS'),
  '+963': _CountryInfo('Syria', 'SY'),
  '+967': _CountryInfo('Yemen', 'YE'),
  '+1': _CountryInfo('United States / Canada', 'US'),
};

/// ISO-3166 alpha-2 -> country name, for the locale-derived fallback used
/// for accounts that signed up via Google/Apple (no phone number captured).
const Map<String, String> _kIsoCountryNames = {
  'JO': 'Jordan',
  'SA': 'Saudi Arabia',
  'BH': 'Bahrain',
  'AE': 'United Arab Emirates',
  'KW': 'Kuwait',
  'QA': 'Qatar',
  'OM': 'Oman',
  'EG': 'Egypt',
  'LB': 'Lebanon',
  'IQ': 'Iraq',
  'PS': 'Palestine',
  'SY': 'Syria',
  'YE': 'Yemen',
  'US': 'United States',
  'CA': 'Canada',
};

/// Converts a 2-letter ISO country code into its flag emoji (regional
/// indicator symbols), e.g. "JO" -> 🇯🇴. Returns a generic globe for
/// anything that isn't a clean 2-letter code.
String _flagEmoji(String iso2) {
  final code = iso2.trim().toUpperCase();
  if (code.length != 2) return '🌐';
  const base = 0x1F1E6; // Regional Indicator Symbol Letter A
  final first = code.codeUnitAt(0) - 'A'.codeUnitAt(0);
  final second = code.codeUnitAt(1) - 'A'.codeUnitAt(0);
  if (first < 0 || first > 25 || second < 0 || second > 25) return '🌐';
  return String.fromCharCode(base + first) + String.fromCharCode(base + second);
}

class AdminRegistrationStatsScreen extends StatefulWidget {
  const AdminRegistrationStatsScreen({super.key});

  @override
  State<AdminRegistrationStatsScreen> createState() =>
      _AdminRegistrationStatsScreenState();
}

enum _Period { daily, weekly, monthly }

class _AdminRegistrationStatsScreenState
    extends State<AdminRegistrationStatsScreen> {
  _Period _period = _Period.daily;

  /// Resolves a display string ("🇯🇴 Jordan") from, in order of
  /// confidence: a known dial code, the free-text `country` field (sponsor
  /// sign-up), the locale-derived ISO code captured for Google/Apple
  /// accounts, or finally "Unknown" if none of that data exists at all.
  String _countryDisplay({
    required String dialCode,
    required String fallbackCountry,
    required String localeIso,
  }) {
    final dialInfo = _kDialCodeInfo[dialCode];
    if (dialInfo != null) {
      return '${_flagEmoji(dialInfo.iso2)} ${dialInfo.name}';
    }
    if (fallbackCountry.trim().isNotEmpty) {
      return fallbackCountry.trim();
    }
    if (dialCode.isNotEmpty) {
      return dialCode;
    }
    final isoName = _kIsoCountryNames[localeIso.toUpperCase()];
    if (isoName != null) {
      return '${_flagEmoji(localeIso)} $isoName (${context.tr('estimated')})';
    }
    return context.tr('Unknown');
  }

  String _bucketKey(DateTime dt, _Period period) {
    switch (period) {
      case _Period.daily:
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      case _Period.weekly:
        // ISO-ish week bucket: the Monday that starts this date's week.
        final monday = dt.subtract(Duration(days: dt.weekday - 1));
        return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      case _Period.monthly:
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .snapshots();
    final deletionsStream = FirebaseFirestore.instance
        .collection('account_deletions')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Registration Report')),
            Text(
              context.tr('Sign-ups over time, by country'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: usersStream,
            builder: (context, usersSnap) {
              if (!usersSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: deletionsStream,
                builder: (context, deletionsSnap) {
                  final docs = usersSnap.data!.docs;
                  final cancelledDocs = deletionsSnap.data?.docs ?? const [];

                  var activeCount = 0;
                  final byBucket = <String, int>{};
                  final byCountry = <String, int>{};

                  for (final doc in docs) {
                    final data = doc.data();
                    final isBlocked =
                        (data['accountStatus'] ?? 'active').toString() ==
                        'disabled';
                    if (!isBlocked) activeCount++;

                    final createdAt = (data['createdAt'] as Timestamp?)
                        ?.toDate();
                    if (createdAt != null) {
                      final key = _bucketKey(createdAt, _period);
                      byBucket[key] = (byBucket[key] ?? 0) + 1;
                    }

                    final code = (data['phoneCountryCode'] ?? '')
                        .toString()
                        .trim();
                    final countryField = (data['country'] ?? '').toString();
                    final localeIso = (data['localeCountryCode'] ?? '')
                        .toString();
                    final label = _countryDisplay(
                      dialCode: code,
                      fallbackCountry: countryField,
                      localeIso: localeIso,
                    );
                    byCountry[label] = (byCountry[label] ?? 0) + 1;
                  }

                  final sortedBuckets = byBucket.keys.toList()
                    ..sort((a, b) => b.compareTo(a));
                  final sortedCountries = byCountry.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final maxCountryCount = sortedCountries.isEmpty
                      ? 1
                      : sortedCountries.first.value;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount = width > 880
                              ? 4
                              : width > 620
                              ? 3
                              : 2;
                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: width > 620 ? 1.55 : 1.8,
                            children: [
                              ModerationStatCard(
                                label: context.tr('Total Registrants'),
                                value: '${docs.length}',
                                icon: Icons.how_to_reg_rounded,
                                color: const Color(0xFF5AB4FF),
                              ),
                              ModerationStatCard(
                                label: context.tr('Active'),
                                value: '$activeCount',
                                icon: Icons.verified_rounded,
                                color: const Color(0xFF2DAF6F),
                              ),
                              ModerationStatCard(
                                label: context.tr('Blocked'),
                                value: '${docs.length - activeCount}',
                                icon: Icons.block_rounded,
                                color: const Color(0xFFC53D5D),
                              ),
                              ModerationStatCard(
                                label: context.tr('Cancelled Accounts'),
                                value: '${cancelledDocs.length}',
                                icon: Icons.person_remove_rounded,
                                color: AppColors.sunset,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.tr('Registrations over time'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _PeriodChip(
                            label: context.tr('Daily'),
                            selected: _period == _Period.daily,
                            onTap: () =>
                                setState(() => _period = _Period.daily),
                          ),
                          const SizedBox(width: 8),
                          _PeriodChip(
                            label: context.tr('Weekly'),
                            selected: _period == _Period.weekly,
                            onTap: () =>
                                setState(() => _period = _Period.weekly),
                          ),
                          const SizedBox(width: 8),
                          _PeriodChip(
                            label: context.tr('Monthly'),
                            selected: _period == _Period.monthly,
                            onTap: () =>
                                setState(() => _period = _Period.monthly),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (sortedBuckets.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              context.tr('No registration data yet.'),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        )
                      else
                        ...sortedBuckets
                            .take(30)
                            .map(
                              (key) => _CountRow(
                                label: key,
                                count: byBucket[key]!,
                                maxCount: byBucket.values.reduce(
                                  (a, b) => a > b ? a : b,
                                ),
                                accent: const Color(0xFF3A7EFF),
                              ),
                            ),
                      const SizedBox(height: 24),
                      Text(
                        context.tr('By country'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (sortedCountries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              context.tr('No registration data yet.'),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        )
                      else
                        ...sortedCountries.map(
                          (entry) => _CountRow(
                            label: entry.key,
                            count: entry.value,
                            maxCount: maxCountryCount,
                            accent: AppColors.hotPink,
                          ),
                        ),
                    ],
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

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.hotPink : const Color(0xFF18152A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.hotPink : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.accent,
  });

  final String label;
  final int count;
  final int maxCount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount <= 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: const Color(0xFF18152A),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
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
