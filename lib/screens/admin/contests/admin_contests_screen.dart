import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../services/contest_report_service.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/pdf_preview_screen.dart';
import 'admin_contest_form.dart';
import 'admin_video_contest_form.dart';

class AdminContestsScreen extends StatefulWidget {
  const AdminContestsScreen({super.key});

  @override
  State<AdminContestsScreen> createState() => _AdminContestsScreenState();
}

class _AdminContestsScreenState extends State<AdminContestsScreen> {
  final _searchController = TextEditingController();
  final _reportService = ContestReportService();
  String _search = '';
  bool _sortDesc = true;
  String _typeFilter = 'video_contest';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contests = FirebaseFirestore.instance
        .collection('contests')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Contests')),
        backgroundColor: AppColors.deepSpace,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminVideoContestForm()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr('Create Video Contest')),
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (v) =>
                            setState(() => _search = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: context.tr(
                            'Search contest, details, region',
                          ),
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
                      const SizedBox(height: 10),
                      Text(
                        context.tr('Contest Type'),
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text(context.tr('Video Contests')),
                            selected: _typeFilter == 'video_contest',
                            onSelected: (_) =>
                                setState(() => _typeFilter = 'video_contest'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('Sort By Created Date'),
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text(context.tr('Newest First')),
                            selected: _sortDesc,
                            onSelected: (_) => setState(() => _sortDesc = true),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(context.tr('Oldest First')),
                            selected: !_sortDesc,
                            onSelected: (_) =>
                                setState(() => _sortDesc = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: contests,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final at =
                            (a.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        final bt =
                            (b.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        return _sortDesc ? bt.compareTo(at) : at.compareTo(bt);
                      });

                    final filtered = docs.where((doc) {
                      final data = doc.data();
                      final rawType = (data['contestType'] ?? 'video_contest')
                          .toString();
                      if (_typeFilter == 'video_contest' &&
                          rawType == 'sponsor_contest') {
                        return false;
                      }
                      if (_search.isEmpty) return true;
                      final title = (data['title'] ?? '')
                          .toString()
                          .toLowerCase();
                      final desc = (data['description'] ?? '')
                          .toString()
                          .toLowerCase();
                      final region = (data['region'] ?? '')
                          .toString()
                          .toLowerCase();
                      final sponsor = (data['sponsorName'] ?? '')
                          .toString()
                          .toLowerCase();
                      final type = rawType.toLowerCase();
                      return title.contains(_search) ||
                          desc.contains(_search) ||
                          region.contains(_search) ||
                          sponsor.contains(_search) ||
                          type.contains(_search);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(context.tr('No matching contests.')),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data();
                        final title = (data['title'] ?? '') as String;
                        final desc = (data['description'] ?? '') as String;
                        final region = (data['region'] ?? '') as String;
                        final maxVideos = (data['maxVideos'] ?? 0).toString();
                        final logoUrl = (data['logoUrl'] ?? '') as String;
                        final sponsorName =
                            (data['sponsorName'] ?? 'Unassigned').toString();
                        final winnerPrize =
                            ((data['winnerPrize'] ?? 100) as num).toDouble();
                        final challengeQuestion =
                            (data['challengeQuestion'] ?? '').toString();
                        final contestType =
                            (data['contestType'] ?? 'video_contest').toString();
                        final contestVideoUrl = (data['contestVideoUrl'] ?? '')
                            .toString();
                        final status = (data['status'] ?? 'contest_created')
                            .toString()
                            .replaceAll('_', ' ');
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: AppColors.cardSoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: logoUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          logoUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.emoji_events,
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
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: contestType == 'sponsor_contest'
                                            ? AppColors.sunset.withOpacity(0.18)
                                            : AppColors.hotPink.withOpacity(
                                                0.18,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        contestType == 'sponsor_contest'
                                            ? context.tr('Sponsored Contest')
                                            : context.tr('Video Contest'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              contestType == 'sponsor_contest'
                                              ? AppColors.sunset
                                              : AppColors.hotPink,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          '${context.tr('Region')}: $region',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${context.tr('Max')}: $maxVideos',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    if (contestType == 'sponsor_contest') ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${context.tr('Sponsor')}: $sponsorName',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                    const SizedBox(height: 2),
                                    Text(
                                      '${context.tr('Winner Prize')}: \$${winnerPrize.toStringAsFixed(0)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${context.tr('Status')}: $status',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    if (challengeQuestion.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${context.tr('Challenge')}: $challengeQuestion',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                    if (contestType == 'video_contest' &&
                                        contestVideoUrl.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.video_library,
                                            size: 15,
                                            color: AppColors.sunset,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            context.tr('Script video attached'),
                                            style: const TextStyle(
                                              color: AppColors.sunset,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            contestType == 'sponsor_contest'
                                            ? AdminContestForm(
                                                contestId: doc.id,
                                                existing: data,
                                              )
                                            : AdminVideoContestForm(
                                                contestId: doc.id,
                                                existing: data,
                                              ),
                                      ),
                                    );
                                  } else if (value == 'report') {
                                    await _openContestReport(
                                      contestId: doc.id,
                                      data: data,
                                    );
                                  } else if (value == 'delete') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                          context.tr('Delete contest?'),
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
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'report',
                                    child: Text(context.tr('Contest Report')),
                                  ),
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

  Future<void> _openContestReport({
    required String contestId,
    required Map<String, dynamic> data,
  }) async {
    final title = (data['title'] ?? contestId).toString();
    final bytes = await _reportService.buildContestReportFromFirestore(
      contestId: contestId,
      contestData: data,
    );
    if (!mounted) return;
    final safe = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: context.tr('Contest Report'),
          bytes: bytes,
          filename: '$safe-contest-report.pdf',
        ),
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
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -40,
            child: _GlowOrb(size: 220, color: AppColors.hotPink),
          ),
          Positioned(
            top: 160,
            right: -60,
            child: _GlowOrb(size: 220, color: AppColors.neonGreen),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.55), color.withOpacity(0.0)],
        ),
      ),
    );
  }
}
