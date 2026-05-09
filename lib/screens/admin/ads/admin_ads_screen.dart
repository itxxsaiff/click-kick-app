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
  final _searchController = TextEditingController();
  final _contestReportService = ContestReportService();
  bool _savingSettings = false;
  bool _showLinkedContests = false;
  String _statusFilter = 'all';

  String _applicationCardSubtitle(Map<String, dynamic> data) {
    final brand = (data['brandName'] ?? '').toString().trim();
    final product = (data['productName'] ?? '').toString().trim();
    final category = (data['category'] ?? '').toString().trim();
    if (brand.isNotEmpty) return brand;
    if (product.isNotEmpty) return product;
    if (category.isNotEmpty) return category;
    return 'Partner';
  }

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
    _searchController.dispose();
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

  void _openSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepSpace,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Sponsorship Settings'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _feeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.tr('Platform Fee (USD)'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _winnerPrizeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.tr('Winner Prize (USD)'),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _savingSettings
                      ? null
                      : () async {
                          await _saveSettings();
                          if (mounted) Navigator.pop(context);
                        },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _savingSettings
                        ? context.tr('Saving...')
                        : context.tr('Save Settings'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7B3FF2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
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

  void _showApplicationDetailsSheet(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final questions = ((data['questionOptions'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepSpace,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text(
              context.tr('Application Details'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...[
                  [
                    'Company',
                    (data['companySponsorName'] ??
                            data['applicationName'] ??
                            '')
                        .toString(),
                  ],
                  ['Contact Person', (data['sponsorName'] ?? '').toString()],
                  ['Email', (data['sponsorEmail'] ?? '').toString()],
                  ['Region', (data['targetCountry'] ?? '').toString()],
                  ['Brand', (data['brandName'] ?? '').toString()],
                  ['Product', (data['productName'] ?? '').toString()],
                  [
                    'Status',
                    _statusLabel(
                      context,
                      (data['applicationStatus'] ?? 'pending').toString(),
                    ),
                  ],
                  [
                    'Payment',
                    _paymentLabel(
                      context,
                      (data['paymentStatus'] ?? 'unpaid').toString(),
                    ),
                  ],
                  ['Admin note', (data['adminReviewNote'] ?? '').toString()],
                ]
                .where((row) => row[1]!.trim().isNotEmpty)
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(row[0]!),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          row[1]!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (questions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('Questions'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...questions.map(
                (question) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    question,
                    style: const TextStyle(color: Colors.white, height: 1.4),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Sponsorships')),
            Text(
              context.tr('Applications & settings'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.deepSpace,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => _openSettingsSheet(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7B3FF2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('Add Sponsorship')),
            ),
          ),
        ],
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
              final filteredDocs = docs.where((doc) {
                final data = doc.data();
                final status = (data['applicationStatus'] ?? 'pending')
                    .toString();
                if (_statusFilter != 'all' && status != _statusFilter) {
                  return false;
                }
                final query = _searchController.text.trim().toLowerCase();
                if (query.isEmpty) return true;
                final haystack = [
                  data['companySponsorName'],
                  data['applicationName'],
                  data['sponsorName'],
                  data['sponsorEmail'],
                  data['targetCountry'],
                ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
                return haystack.contains(query);
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text(context.tr('Applications')),
                        selected: !_showLinkedContests,
                        onSelected: (_) =>
                            setState(() => _showLinkedContests = false),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: Text(context.tr('Created Contests')),
                        selected: _showLinkedContests,
                        onSelected: (_) =>
                            setState(() => _showLinkedContests = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_showLinkedContests)
                    _AdminTableShell(
                      title: context.tr('Created Contests'),
                      child: SizedBox(
                        height: 460,
                        child: _buildLinkedContestsPanel(context),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: context.tr('Search sponsorships'),
                              prefixIcon: const Icon(Icons.search),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF18152A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: PopupMenuButton<String>(
                            tooltip: context.tr('Filter'),
                            initialValue: _statusFilter,
                            color: AppColors.card,
                            icon: const Icon(
                              Icons.filter_list_rounded,
                              color: Colors.white,
                            ),
                            onSelected: (value) =>
                                setState(() => _statusFilter = value),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'all',
                                child: Text('All'),
                              ),
                              const PopupMenuItem(
                                value: 'pending',
                                child: Text('Pending'),
                              ),
                              const PopupMenuItem(
                                value: 'approved',
                                child: Text('Approved'),
                              ),
                              const PopupMenuItem(
                                value: 'contest_created',
                                child: Text('Contest Created'),
                              ),
                              const PopupMenuItem(
                                value: 'needs_improvement',
                                child: Text('Needs Improvement'),
                              ),
                              const PopupMenuItem(
                                value: 'rejected',
                                child: Text('Rejected'),
                              ),
                              const PopupMenuItem(
                                value: 'live',
                                child: Text('Live'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (filteredDocs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151324),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            context.tr('No sponsorship applications found.'),
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      ...filteredDocs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final doc = entry.value;
                        final data = doc.data();
                        final title =
                            (data['companySponsorName'] ??
                                    data['applicationName'] ??
                                    'Sponsorship')
                                .toString();
                        final subtitle = _applicationCardSubtitle(data);
                        final logoUrl = (data['logoUrl'] ?? '').toString();
                        final status = (data['applicationStatus'] ?? 'pending')
                            .toString();
                        final paymentStatus =
                            (data['paymentStatus'] ?? 'unpaid').toString();
                        final fee = ((data['applicationFee'] ?? 1000) as num)
                            .toDouble();
                        final createdAt = (data['createdAt'] as Timestamp?)
                            ?.toDate();
                        final sponsorName = (data['sponsorName'] ?? '')
                            .toString();
                        final linkedContestId = (data['linkedContestId'] ?? '')
                            .toString();
                        final statusColor = _statusColor(status);
                        final isLockedAfterApproval =
                            status == 'approved' ||
                            status == 'contest_created' ||
                            status == 'live';
                        final canReview = !isLockedAfterApproval;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == filteredDocs.length - 1 ? 0 : 10,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF151324),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: logoUrl.isEmpty
                                        ? const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF4B1A7E),
                                              Color(0xFF12101C),
                                            ],
                                          )
                                        : null,
                                    color: AppColors.cardSoft,
                                  ),
                                  child: logoUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: Image.network(
                                            logoUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.storefront_outlined,
                                                  color: Colors.white70,
                                                ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            title.isEmpty
                                                ? 'SP'
                                                : title
                                                      .trim()
                                                      .split(RegExp(r'\s+'))
                                                      .take(2)
                                                      .map(
                                                        (e) =>
                                                            e[0].toUpperCase(),
                                                      )
                                                      .join(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  subtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: AppColors.textMuted,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.16,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              _statusLabel(context, status),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 6,
                                        children: [
                                          _SponsorshipMeta(
                                            icon: Icons
                                                .workspace_premium_outlined,
                                            label: sponsorName.isNotEmpty
                                                ? sponsorName
                                                : subtitle,
                                          ),
                                          _SponsorshipMeta(
                                            icon: Icons.attach_money_outlined,
                                            label:
                                                '\$${fee.toStringAsFixed(0)}',
                                          ),
                                          _SponsorshipMeta(
                                            icon: Icons.calendar_today_outlined,
                                            label: createdAt == null
                                                ? '--'
                                                : _formatDate(createdAt),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: AppColors.textMuted,
                                  ),
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'details':
                                        _showApplicationDetailsSheet(
                                          context,
                                          data,
                                        );
                                        break;
                                      case 'approve':
                                        if (canReview &&
                                            paymentStatus == 'paid') {
                                          await _approveApplication(
                                            context,
                                            doc,
                                          );
                                        }
                                        break;
                                      case 'improve':
                                        if (canReview) {
                                          await _requestImprovement(
                                            context,
                                            doc,
                                          );
                                        }
                                        break;
                                      case 'reject':
                                        if (canReview) {
                                          await _rejectApplication(
                                            context,
                                            doc,
                                          );
                                        }
                                        break;
                                      case 'report':
                                        if (linkedContestId.isNotEmpty) {
                                          await _openContestReport(
                                            contestId: linkedContestId,
                                          );
                                        }
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'details',
                                      child: Text(context.tr('View Details')),
                                    ),
                                    PopupMenuItem(
                                      value: 'approve',
                                      enabled:
                                          canReview && paymentStatus == 'paid',
                                      child: Text(context.tr('Approve')),
                                    ),
                                    PopupMenuItem(
                                      value: 'improve',
                                      enabled: canReview,
                                      child: Text(
                                        context.tr('Need Improvement'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'reject',
                                      enabled: canReview,
                                      child: Text(context.tr('Reject')),
                                    ),
                                    if (linkedContestId.isNotEmpty)
                                      PopupMenuItem(
                                        value: 'report',
                                        child: Text(
                                          context.tr('Contest Report'),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        context.tr('No more sponsorships'),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminTableShell extends StatelessWidget {
  const _AdminTableShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.hotPink.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.table_chart_outlined,
                    color: AppColors.hotPink,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),
          child,
        ],
      ),
    );
  }
}

class _AdminTableHeader extends StatelessWidget {
  const _AdminTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          _AdminTableCell(label: 'Application', width: 180),
          _AdminTableCell(label: 'Company', width: 240),
          _AdminTableCell(label: 'Contact Person', width: 190),
          _AdminTableCell(label: 'Plan', width: 110),
          _AdminTableCell(label: 'Status', width: 220),
          _AdminTableCell(label: 'Received At', width: 130),
          _AdminTableCell(label: 'Actions', width: 170, alignEnd: true),
        ],
      ),
    );
  }
}

class _AdminTableCell extends StatelessWidget {
  const _AdminTableCell({
    required this.label,
    required this.width,
    this.alignEnd = false,
  });

  final String label;
  final double width;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _AdminTableRow extends StatelessWidget {
  const _AdminTableRow({
    required this.application,
    required this.company,
    required this.contactPerson,
    required this.plan,
    required this.statusLabel,
    required this.statusColor,
    required this.receivedAt,
    required this.actions,
  });

  final String application;
  final String company;
  final String contactPerson;
  final String plan;
  final String statusLabel;
  final Color statusColor;
  final String receivedAt;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              application,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 240,
            child: Text(
              company,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 190,
            child: Text(
              contactPerson,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              plan,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusBadge(label: statusLabel, color: statusColor),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              receivedAt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: Align(alignment: Alignment.centerRight, child: actions),
          ),
        ],
      ),
    );
  }
}

class _TableActionIcon extends StatelessWidget {
  const _TableActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: enabled
                ? color.withOpacity(0.14)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled ? color.withOpacity(0.28) : AppColors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? color : AppColors.textMuted.withOpacity(0.45),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SponsorshipMeta extends StatelessWidget {
  const _SponsorshipMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
