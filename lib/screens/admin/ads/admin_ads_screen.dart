import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../services/contest_report_service.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/pdf_preview_screen.dart';
import '../contests/admin_contest_form.dart';
import '../../shared/contest_video_review_screen.dart';

class AdminAdsScreen extends StatefulWidget {
  const AdminAdsScreen({super.key});

  @override
  State<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends State<AdminAdsScreen> {
  final _feeController = TextEditingController();
  final _winnerPrizeController = TextEditingController();
  final _contestReportService = ContestReportService();
  bool _savingSettings = false;
  bool _showLinkedContests = false;

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'pending':
        return context.tr('Pending');
      case 'approved':
        return context.tr('Approved');
      case 'contest_created':
        return context.tr('Contest Created');
      case 'live':
        return context.tr('Live');
      case 'needs_improvement':
        return context.tr('Needs Improvement');
      case 'rejected':
        return context.tr('Rejected');
      default:
        return status.replaceAll('_', ' ');
    }
  }

  String _paymentLabel(BuildContext context, String status) {
    switch (status) {
      case 'paid':
        return context.tr('Paid');
      case 'unpaid':
        return context.tr('Unpaid');
      default:
        return status;
    }
  }

  String _videoReviewLabel(BuildContext context, String status) {
    switch (status) {
      case 'approved':
        return context.tr('Approved');
      case 'rejected':
        return context.tr('Rejected');
      case 'pending':
        return context.tr('Pending Sponsor Review');
      case 'pending_upload':
        return context.tr('Awaiting Admin Video Upload');
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Widget _buildLinkedContestsPanel(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('contests')
        .where('contestType', isEqualTo: 'sponsor_contest')
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(context.tr('No sponsor contests created yet.')),
            ),
          );
        }
        docs.sort((a, b) {
          final at =
              (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
              0;
          final bt =
              (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
              0;
          return bt.compareTo(at);
        });
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final doc = docs[i];
            final d = doc.data();
            final title = (d['title'] ?? doc.id).toString();
            final region = (d['region'] ?? '').toString();
            final status = (d['status'] ?? 'contest_created').toString();
            final videoApprovalStatus =
                (d['sponsorVideoApprovalStatus'] ?? 'pending_upload')
                    .toString();
            final applicationId = (d['sponsorshipApplicationId'] ?? '')
                .toString();
            final challenge = (d['challengeQuestion'] ?? '').toString();
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(context, status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (challenge.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('${context.tr('Challenge')}: $challenge'),
                  ],
                  if (region.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('${context.tr('Region')}: $region'),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${context.tr('Contest Video Review')}: ${_videoReviewLabel(context, videoApprovalStatus)}',
                  ),
                  if (applicationId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('${context.tr('Application ID')}: $applicationId'),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContestVideoReviewScreen(
                                contestId: doc.id,
                                onEditContest: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminContestForm(
                                        contestId: doc.id,
                                        existing: d,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.forum_outlined),
                        label: Text(context.tr('Open Review')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminContestForm(
                                contestId: doc.id,
                                existing: d,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(context.tr('Edit Contest')),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _feeController.dispose();
    _winnerPrizeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final snap = await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('sponsorship')
        .get();
    final data = snap.data() ?? const <String, dynamic>{};
    _feeController.text = ((data['applicationFee'] ?? 1000) as num)
        .toDouble()
        .toStringAsFixed(0);
    _winnerPrizeController.text = ((data['winnerPrize'] ?? 100) as num)
        .toDouble()
        .toStringAsFixed(0);
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    final fee = double.tryParse(_feeController.text.trim());
    final winnerPrize = double.tryParse(_winnerPrizeController.text.trim());
    if (fee == null || fee <= 0) {
      _show('Enter a valid sponsorship application fee.');
      return;
    }
    if (winnerPrize == null || winnerPrize <= 0) {
      _show('Enter a valid winner prize amount.');
      return;
    }

    setState(() => _savingSettings = true);
    await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('sponsorship')
        .set({
          'applicationFee': fee,
          'winnerPrize': winnerPrize,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
    if (!mounted) return;
    setState(() => _savingSettings = false);
    _show('Sponsorship settings updated.');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'live':
        return const Color(0xFF2EDB85);
      case 'contest_created':
        return const Color(0xFF5AB4FF);
      case 'approved':
        return AppColors.neonGreen;
      case 'needs_improvement':
        return AppColors.sunset;
      case 'rejected':
        return const Color(0xFFD64B6A);
      default:
        return AppColors.hotPink;
    }
  }

  Future<void> _updateStatus(
    DocumentReference<Map<String, dynamic>> ref, {
    required String status,
    String note = '',
    String selectedQuestion = '',
    int? selectedQuestionIndex,
  }) async {
    await ref.set({
      'applicationStatus': status,
      'adminReviewNote': note,
      'selectedQuestion': selectedQuestion,
      'selectedQuestionIndex': selectedQuestionIndex,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  Future<String> _createContestFromApplication({
    required String applicationId,
    required Map<String, dynamic> appData,
    required String selectedQuestion,
  }) async {
    final contests = FirebaseFirestore.instance.collection('contests');
    final linkedContestId = (appData['linkedContestId'] ?? '').toString();
    final now = Timestamp.fromDate(DateTime.now());
    final winnerPrize = ((appData['winnerPrize'] ?? 100) as num).toDouble();
    final companyName =
        (appData['companySponsorName'] ??
                appData['applicationName'] ??
                appData['companyName'] ??
                'Sponsor Contest')
            .toString();
    final sponsorName = (appData['sponsorName'] ?? appData['companyName'] ?? '')
        .toString();
    final region = (appData['targetCountry'] ?? '').toString();
    final logoUrl = (appData['logoUrl'] ?? '').toString();
    final productName = (appData['productName'] ?? '').toString();
    final sponsorId = (appData['sponsorId'] ?? '').toString();
    final proposedSubmissionStart = appData['proposedSubmissionStart'];
    final proposedSubmissionEnd = appData['proposedSubmissionEnd'];
    final proposedVotingStart = appData['proposedVotingStart'];
    final proposedVotingEnd = appData['proposedVotingEnd'];

    Map<String, dynamic> contestData = {
      'title': companyName,
      'description': selectedQuestion,
      'region': region,
      'maxVideos': 50,
      'contestType': 'sponsor_contest',
      'winnerPrize': winnerPrize,
      'sponsorId': sponsorId,
      'sponsorName': sponsorName,
      'sponsorshipApplicationId': applicationId,
      'challengeQuestion': selectedQuestion,
      'sponsorProductName': productName,
      'status': 'contest_created',
      'sponsorVideoApprovalStatus': 'pending_upload',
      'sponsorVideoReviewReason': '',
      'updatedAt': now,
      if (logoUrl.isNotEmpty) 'logoUrl': logoUrl,
      if (proposedSubmissionStart is Timestamp)
        'submissionStart': proposedSubmissionStart,
      if (proposedSubmissionEnd is Timestamp)
        'submissionEnd': proposedSubmissionEnd,
      if (proposedVotingStart is Timestamp) 'votingStart': proposedVotingStart,
      if (proposedVotingEnd is Timestamp) 'votingEnd': proposedVotingEnd,
    };

    if (linkedContestId.isNotEmpty) {
      final linkedDoc = contests.doc(linkedContestId);
      final exists = await linkedDoc.get();
      if (exists.exists) {
        await linkedDoc.set(contestData, SetOptions(merge: true));
        return linkedContestId;
      }
    }

    final newDoc = contests.doc();
    await newDoc.set({...contestData, 'createdAt': now});
    return newDoc.id;
  }

  Future<void> _approveApplication(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final paymentStatus = (data['paymentStatus'] ?? 'unpaid').toString();
    if (paymentStatus != 'paid') {
      _show('Cannot approve before payment. Please mark payment first.');
      return;
    }

    final options = ((data['questionOptions'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (options.isEmpty) {
      _show('This application has no suggested questions.');
      return;
    }

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) {
        var index = 0;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(context.tr('Approve Application')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Select 1 question to become the official topic:'),
                ),
                const SizedBox(height: 10),
                ...List.generate(options.length, (i) {
                  return RadioListTile<int>(
                    value: i,
                    groupValue: index,
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() => index = v);
                    },
                    title: Text(options[i]),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, index),
                child: Text(context.tr('Approve')),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    final chosenQuestion = options[selected];
    await _updateStatus(
      doc.reference,
      status: 'approved',
      note: '',
      selectedQuestion: chosenQuestion,
      selectedQuestionIndex: selected,
    );
    final contestId = await _createContestFromApplication(
      applicationId: doc.id,
      appData: data,
      selectedQuestion: chosenQuestion,
    );
    await _updateStatus(
      doc.reference,
      status: 'contest_created',
      note: '',
      selectedQuestion: chosenQuestion,
      selectedQuestionIndex: selected,
    );
    await doc.reference.set({
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'linkedContestId': contestId,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
    _show('Application approved and contest created.');
  }

  Future<void> _requestImprovement(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final c = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Request Improvement')),
        content: TextField(
          controller: c,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: context.tr('Required note'),
            hintText: context.tr('Tell sponsor what to improve'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = c.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(ctx, value);
            },
            child: Text(context.tr('Send')),
          ),
        ],
      ),
    );

    if (note == null || note.isEmpty) return;
    await _updateStatus(doc.reference, status: 'needs_improvement', note: note);
    _show('Improvement request sent.');
  }

  Future<void> _rejectApplication(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final c = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Reject Application')),
        content: TextField(
          controller: c,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: context.tr('Reason (optional)'),
            hintText: context.tr('Why is this rejected?'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: Text(context.tr('Reject')),
          ),
        ],
      ),
    );

    if (note == null) return;
    await _updateStatus(doc.reference, status: 'rejected', note: note);
    _show('Application rejected.');
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2B1B44),
      ),
    );
  }

  Future<void> _openContestReport({required String contestId}) async {
    final contestDoc = await FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .get();
    final data = contestDoc.data();
    if (data == null) {
      _show('Linked contest not found.');
      return;
    }
    final title = (data['title'] ?? contestId).toString();
    final bytes = await _contestReportService.buildContestReportFromFirestore(
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

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Sponsorship Applications')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('sponsorship_applications')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              final total = docs.length;
              final pending = docs
                  .where(
                    (d) =>
                        (d.data()['applicationStatus'] ?? '').toString() ==
                        'pending',
                  )
                  .length;
              final approved = docs
                  .where(
                    (d) =>
                        (d.data()['applicationStatus'] ?? '').toString() ==
                        'approved',
                  )
                  .length;
              final contestCreated = docs
                  .where(
                    (d) =>
                        (d.data()['applicationStatus'] ?? '').toString() ==
                        'contest_created',
                  )
                  .length;
              final live = docs
                  .where(
                    (d) =>
                        (d.data()['applicationStatus'] ?? '').toString() ==
                        'live',
                  )
                  .length;
              final needsImprovement = docs
                  .where(
                    (d) =>
                        (d.data()['applicationStatus'] ?? '').toString() ==
                        'needs_improvement',
                  )
                  .length;
              final rejected = docs
                  .where(
                    (d) =>
                        (d.data()['applicationStatus'] ?? '').toString() ==
                        'rejected',
                  )
                  .length;
              final paid = docs
                  .where(
                    (d) =>
                        (d.data()['paymentStatus'] ?? '').toString() == 'paid',
                  )
                  .length;
              final unpaid = total - paid;

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _showLinkedContests ? 3 : docs.length + 2,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _feeController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: context.tr('Platform Fee (USD)'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _winnerPrizeController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: context.tr('Winner Prize (USD)'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _savingSettings ? null : _saveSettings,
                              icon: const Icon(Icons.save),
                              label: Text(
                                _savingSettings
                                    ? context.tr('Saving...')
                                    : context.tr('Save Sponsorship Settings'),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.hotPink,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (index == 1) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final crossAxisCount = width >= 1040
                                ? 4
                                : width >= 780
                                ? 3
                                : width >= 390
                                ? 3
                                : 2;
                            final ratio = width >= 1040
                                ? 2.1
                                : width >= 780
                                ? 1.7
                                : crossAxisCount == 3
                                ? 1.12
                                : 1.35;
                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: ratio,
                              children: [
                                _StatCard(
                                  label: context.tr('Total'),
                                  value: total.toString(),
                                  color: AppColors.hotPink,
                                  icon: Icons.inventory_2,
                                ),
                                _StatCard(
                                  label: context.tr('Pending'),
                                  value: pending.toString(),
                                  color: AppColors.sunset,
                                  icon: Icons.hourglass_top,
                                ),
                                _StatCard(
                                  label: context.tr('Approved'),
                                  value: approved.toString(),
                                  color: AppColors.neonGreen,
                                  icon: Icons.check_circle,
                                ),
                                _StatCard(
                                  label: context.tr('Contest Created'),
                                  value: contestCreated.toString(),
                                  color: const Color(0xFF5AB4FF),
                                  icon: Icons.pending_actions,
                                ),
                                _StatCard(
                                  label: context.tr('Live'),
                                  value: live.toString(),
                                  color: const Color(0xFF2EDB85),
                                  icon: Icons.bolt,
                                ),
                                _StatCard(
                                  label: context.tr('Needs Improvement'),
                                  value: needsImprovement.toString(),
                                  color: AppColors.sunset,
                                  icon: Icons.edit_note,
                                ),
                                _StatCard(
                                  label: context.tr('Rejected'),
                                  value: rejected.toString(),
                                  color: const Color(0xFFD64B6A),
                                  icon: Icons.cancel,
                                ),
                                _StatCard(
                                  label: context.tr('Paid'),
                                  value: paid.toString(),
                                  color: const Color(0xFF32C37A),
                                  icon: Icons.payments,
                                ),
                                _StatCard(
                                  label: context.tr('Unpaid'),
                                  value: unpaid.toString(),
                                  color: const Color(0xFFC53D5D),
                                  icon: Icons.money_off,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ChoiceChip(
                              label: Text(context.tr('Applications')),
                              selected: !_showLinkedContests,
                              onSelected: (_) => setState(() {
                                _showLinkedContests = false;
                              }),
                            ),
                            const SizedBox(width: 10),
                            ChoiceChip(
                              label: Text(context.tr('Created Contests')),
                              selected: _showLinkedContests,
                              onSelected: (_) => setState(() {
                                _showLinkedContests = true;
                              }),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  if (_showLinkedContests) {
                    if (index == 2) {
                      return SizedBox(
                        height: 440,
                        child: _buildLinkedContestsPanel(context),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  final doc = docs[index - 2];
                  final data = doc.data();
                  final appName =
                      (data['companySponsorName'] ??
                              data['applicationName'] ??
                              'Application')
                          .toString();
                  final sponsorName =
                      (data['sponsorName'] ?? data['sponsorId'] ?? '')
                          .toString();
                  final sponsorEmail = (data['sponsorEmail'] ?? '').toString();
                  final country = (data['targetCountry'] ?? '').toString();
                  final status = (data['applicationStatus'] ?? 'pending')
                      .toString();
                  final paymentStatus = (data['paymentStatus'] ?? 'unpaid')
                      .toString();
                  final paymentStatusLabel = _paymentLabel(
                    context,
                    paymentStatus,
                  );
                  final fee = ((data['applicationFee'] ?? 1000) as num)
                      .toDouble();
                  final winnerPrize = ((data['winnerPrize'] ?? 100) as num)
                      .toDouble();
                  final logoUrl = (data['logoUrl'] ?? '').toString();
                  final reviewNote = (data['adminReviewNote'] ?? '').toString();
                  final selectedQuestion = (data['selectedQuestion'] ?? '')
                      .toString();
                  final brandName = (data['brandName'] ?? '').toString();
                  final questions =
                      ((data['questionOptions'] as List?) ?? const [])
                          .map((e) => e.toString())
                          .toList();
                  final productName = (data['productName'] ?? '').toString();
                  final extraPrize = (data['additionalPrizes'] ?? '')
                      .toString();
                  final linkedContestId = (data['linkedContestId'] ?? '')
                      .toString();
                  final isLockedAfterApproval =
                      status == 'approved' ||
                      status == 'contest_created' ||
                      status == 'live';
                  final canReview = !isLockedAfterApproval;
                  final proposedSubmissionStart =
                      (data['proposedSubmissionStart'] as Timestamp?)?.toDate();
                  final proposedSubmissionEnd =
                      (data['proposedSubmissionEnd'] as Timestamp?)?.toDate();
                  final proposedVotingStart =
                      (data['proposedVotingStart'] as Timestamp?)?.toDate();
                  final proposedVotingEnd =
                      (data['proposedVotingEnd'] as Timestamp?)?.toDate();

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: AppColors.cardSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: logoUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        logoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.image_not_supported,
                                              color: AppColors.textMuted,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.storefront,
                                      color: AppColors.hotPink,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    sponsorName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  if (sponsorEmail.isNotEmpty)
                                    Text(
                                      sponsorEmail,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _statusLabel(context, status),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      Text(
                          '${context.tr('Platform Fee')}: \$${fee.toStringAsFixed(0)} | ${context.tr('Payment')}: $paymentStatusLabel',
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${context.tr('Winner Prize')}: \$${winnerPrize.toStringAsFixed(0)}',
                        ),
                        if (country.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('${context.tr('Region')}: $country'),
                        ],
                        if (brandName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('${context.tr('Brand')}: $brandName'),
                        ],
                        if (productName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('${context.tr('Product')}: $productName'),
                        ],
                        if (extraPrize.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${context.tr('Additional prizes')}: $extraPrize',
                          ),
                        ],
                        if (selectedQuestion.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${context.tr('Selected Question')}: $selectedQuestion',
                            style: const TextStyle(color: AppColors.neonGreen),
                          ),
                        ],
                        if (proposedSubmissionStart != null &&
                            proposedSubmissionEnd != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${context.tr('Proposed Submission')}: ${_formatDate(proposedSubmissionStart)} ${context.tr('to')} ${_formatDate(proposedSubmissionEnd)}',
                          ),
                        ],
                        if (proposedVotingStart != null &&
                            proposedVotingEnd != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${context.tr('Proposed Voting')}: ${_formatDate(proposedVotingStart)} ${context.tr('to')} ${_formatDate(proposedVotingEnd)}',
                          ),
                        ],
                        if (questions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                          '${context.tr('Questions')}: ${questions.join(' | ')}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (reviewNote.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${context.tr('Admin note')}: $reviewNote',
                            style: const TextStyle(color: AppColors.sunset),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (isLockedAfterApproval)
                          Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              context.tr(
                                'Application is locked after approval. Use Edit Contest / Set Live only.',
                              ),
                              style: TextStyle(
                                color: AppColors.neonGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (linkedContestId.isNotEmpty) ...[
                              OutlinedButton.icon(
                                onPressed: () async {
                                  if (!mounted) return;
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ContestVideoReviewScreen(
                                        contestId: linkedContestId,
                                        onEditContest: () async {
                                          final contestDoc = await FirebaseFirestore
                                              .instance
                                              .collection('contests')
                                              .doc(linkedContestId)
                                              .get();
                                          final existing = contestDoc.data();
                                          if (existing == null) {
                                            _show('Linked contest not found.');
                                            return;
                                          }
                                          if (!mounted) return;
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AdminContestForm(
                                                contestId: linkedContestId,
                                                existing: existing,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.forum_outlined),
                                label: Text(context.tr('Open Review')),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _openContestReport(
                                  contestId: linkedContestId,
                                ),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: Text(context.tr('Contest Report')),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final contestDoc = await FirebaseFirestore
                                      .instance
                                      .collection('contests')
                                      .doc(linkedContestId)
                                      .get();
                                  final existing = contestDoc.data();
                                  if (existing == null) {
                                    _show('Linked contest not found.');
                                    return;
                                  }
                                  if (!mounted) return;
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminContestForm(
                                        contestId: linkedContestId,
                                        existing: existing,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit_outlined),
                                label: Text(context.tr('Edit Contest')),
                              ),
                            ],
                            FilledButton(
                              onPressed: canReview && paymentStatus == 'paid'
                                  ? () => _approveApplication(context, doc)
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.neonGreen,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                context.tr('Approve + Pick Question'),
                              ),
                            ),
                            FilledButton(
                              onPressed: canReview
                                  ? () => _requestImprovement(context, doc)
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.sunset,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(context.tr('Need Improvement')),
                            ),
                            FilledButton(
                              onPressed: canReview
                                  ? () => _rejectApplication(context, doc)
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFC53D5D),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(context.tr('Reject')),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
