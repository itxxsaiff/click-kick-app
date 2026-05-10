import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/news_slider.dart';
import '../shared/legal_center_screen.dart';
import '../user/contest_detail_screen.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key, required this.displayName});

  final String displayName;

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _index = 0;

  IconData _headerIcon() {
    switch (_index) {
      case 0:
        return Icons.emoji_events;
      case 1:
        return Icons.dashboard_customize;
      case 2:
        return Icons.workspace_premium;
      default:
        return Icons.person;
    }
  }

  String _headerTitle() {
    switch (_index) {
      case 0:
        return 'Contests';
      case 1:
        return 'Dashboard';
      case 2:
        return 'Winners';
      default:
        return 'Profile';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.cardSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_headerIcon(), color: AppColors.hotPink),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(_headerTitle()),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              widget.displayName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const LanguageMenuButton(compact: true),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      _UserContestsTab(),
                      _UserDashboardTab(userId: user?.uid ?? ''),
                      const _UserWinnersTab(),
                      _UserProfileTab(displayName: widget.displayName),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x221B1033), Color(0xCC130B25)],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A1847), Color(0xFF1C1232)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border.withOpacity(0.9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: (v) => setState(() => _index = v),
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.hotPink,
              unselectedItemColor: AppColors.textMuted.withOpacity(0.95),
              selectedFontSize: 13,
              unselectedFontSize: 12,
              showUnselectedLabels: true,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.emoji_events_outlined),
                  activeIcon: Icon(Icons.emoji_events),
                  label: context.tr('Contests'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard_customize),
                  label: context.tr('Dashboard'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.workspace_premium_outlined),
                  activeIcon: Icon(Icons.workspace_premium),
                  label: context.tr('Winners'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: context.tr('Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserContestsTab extends StatefulWidget {
  @override
  State<_UserContestsTab> createState() => _UserContestsTabState();
}

class _UserContestsTabState extends State<_UserContestsTab> {
  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('contests')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final contestType = (data['contestType'] ?? 'video_contest')
              .toString();
          final status = (data['status'] ?? '').toString();
          if (contestType == 'sponsor_contest') {
            return status == 'live';
          }
          return true;
        }).toList();
        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              NewsSlider(),
              SizedBox(height: 12),
              _UserHintCard(message: 'No contests available right now.'),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 2,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const NewsSlider();
            }
            if (index == 1) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5F2A9A), Color(0xFF2A1550)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.stars, color: AppColors.hotPink),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr(
                          'Join ongoing contests, upload your best short video, and track results in Dashboard.',
                        ),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            }
            final doc = docs[index - 2];
            final data = doc.data();
            final title = (data['title'] ?? '') as String;
            final desc = (data['description'] ?? '') as String;
            final logoUrl = (data['logoUrl'] ?? '') as String;
            final contestType = (data['contestType'] ?? 'video_contest')
                .toString();
            final winnerPrize = ((data['winnerPrize'] ?? 100) as num)
                .toDouble();

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ContestDetailScreen(contestId: doc.id, data: data),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.cardSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: logoUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(logoUrl, fit: BoxFit.cover),
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
                            style: Theme.of(context).textTheme.titleMedium,
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
                                  : AppColors.hotPink.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              contestType == 'sponsor_contest'
                                  ? context.tr('Sponsored Contest')
                                  : context.tr('Video Contest'),
                              style: TextStyle(
                                color: contestType == 'sponsor_contest'
                                    ? AppColors.sunset
                                    : AppColors.hotPink,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${context.tr('Winner Prize')}: \$${winnerPrize.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.sunset,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: AppColors.hotPink,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.tr('Open Contest'),
                                style: const TextStyle(
                                  color: AppColors.hotPink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _UserHintCard extends StatelessWidget {
  const _UserHintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _UserDashboardTab extends StatefulWidget {
  const _UserDashboardTab({required this.userId});

  final String userId;

  @override
  State<_UserDashboardTab> createState() => _UserDashboardTabState();
}

class _UserDashboardTabState extends State<_UserDashboardTab> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _errorMessage;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final firestore = FirebaseFirestore.instance;
    try {
      final snap = await firestore
          .collectionGroup('submissions')
          .where('userId', isEqualTo: widget.userId)
          .get()
          .timeout(const Duration(seconds: 15));

      final docs = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        final fromPathContestId = doc.reference.parent.parent?.id;
        data['contestId'] = (data['contestId'] ?? fromPathContestId ?? '')
            .toString();
        data['_docId'] = doc.id;
        data['isWinner'] = false;
        return data;
      }).toList();
      return _markOwnWinners(docs, firestore);
    } catch (_) {
      final contests = await firestore
          .collection('contests')
          .get()
          .timeout(const Duration(seconds: 15));
      final out = <Map<String, dynamic>>[];
      for (final contest in contests.docs) {
        final subSnap = await contest.reference
            .collection('submissions')
            .where('userId', isEqualTo: widget.userId)
            .get()
            .timeout(const Duration(seconds: 15));
        for (final sub in subSnap.docs) {
          final data = Map<String, dynamic>.from(sub.data());
          data['contestId'] = contest.id;
          data['contestName'] = (contest.data()['title'] ?? '').toString();
          data['_docId'] = sub.id;
          data['isWinner'] = false;
          out.add(data);
        }
      }
      return _markOwnWinners(out, firestore);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _errorMessage = null;
      _future = _load();
    });
    try {
      await _future;
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Dashboard request timed out. Check internet and retry.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load dashboard data. Tap retry.';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _markOwnWinners(
    List<Map<String, dynamic>> docs,
    FirebaseFirestore firestore,
  ) async {
    if (docs.isEmpty) return docs;
    final now = DateTime.now();
    final contestIds = docs
        .map((d) => (d['contestId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final contestId in contestIds) {
      final contestDoc = await firestore
          .collection('contests')
          .doc(contestId)
          .get();
      if (!contestDoc.exists) continue;
      final votingEndTs = contestDoc.data()?['votingEnd'] as Timestamp?;
      final votingEnd = votingEndTs?.toDate();
      if (votingEnd == null || now.isBefore(votingEnd)) continue;

      final submissionsSnap = await contestDoc.reference
          .collection('submissions')
          .where('status', isEqualTo: 'approved')
          .get()
          .timeout(const Duration(seconds: 15));
      if (submissionsSnap.docs.isEmpty) continue;

      var maxVotes = 0;
      for (final sub in submissionsSnap.docs) {
        final votes = ((sub.data()['voteCount'] ?? 0) as num).toInt();
        if (votes > maxVotes) maxVotes = votes;
      }
      final winnerIds = submissionsSnap.docs
          .where(
            (sub) =>
                ((sub.data()['voteCount'] ?? 0) as num).toInt() == maxVotes,
          )
          .map((sub) => sub.id)
          .toSet();

      for (final doc in docs) {
        if ((doc['contestId'] ?? '').toString() != contestId) continue;
        final status = (doc['status'] ?? '').toString();
        final docId = (doc['_docId'] ?? '').toString();
        if (status == 'approved' && winnerIds.contains(docId)) {
          doc['isWinner'] = true;
        }
      }
    }
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty)
      return Center(child: Text(context.tr('Please login.')));

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            _errorMessage == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_errorMessage != null || snapshot.hasError) {
          final errorText =
              _errorMessage ?? _dashboardErrorText(snapshot.error);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 36,
                    color: AppColors.hotPink,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    errorText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
          );
        }

        final docs =
            List<Map<String, dynamic>>.from(
              snapshot.data ?? <Map<String, dynamic>>[],
            )..sort((a, b) {
              final at =
                  (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bt =
                  (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bt.compareTo(at);
            });
        final filteredDocs = _statusFilter == 'all'
            ? docs
            : _statusFilter == 'winner'
            ? docs.where((e) => e['isWinner'] == true).toList()
            : docs
                  .where((e) => (e['status'] ?? '').toString() == _statusFilter)
                  .toList();

        final pending = docs
            .where((e) => (e['status'] ?? '') == 'pending')
            .length;
        final approved = docs
            .where((e) => (e['status'] ?? '') == 'approved')
            .length;
        final rejected = docs
            .where((e) => (e['status'] ?? '') == 'rejected')
            .length;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.isEmpty ? 3 : filteredDocs.length + 2,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _StatsRow(
                  total: docs.length,
                  pending: pending,
                  approved: approved,
                  rejected: rejected,
                );
              }
              if (index == 1) {
                return _DashboardStatusFilter(
                  selected: _statusFilter,
                  onChanged: (value) => setState(() => _statusFilter = value),
                );
              }
              if (filteredDocs.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      context.tr('No videos found for selected filter.'),
                    ),
                  ),
                );
              }
              final data = filteredDocs[index - 2];
              final contestId = (data['contestId'] ?? '').toString();
              final contestNameFromData = (data['contestName'] ?? '')
                  .toString();
              final status = (data['isWinner'] == true)
                  ? 'winner'
                  : (data['status'] ?? 'pending').toString();
              final reason = (data['rejectionReason'] ?? '').toString();
              final videoUrl = (data['videoUrl'] ?? '').toString();

              if (contestNameFromData.isNotEmpty) {
                return _DashboardSubmissionCard(
                  contestName: contestNameFromData,
                  status: status,
                  reason: reason,
                  videoUrl: videoUrl,
                  statusColor: _statusColor(status),
                );
              }

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('contests')
                    .doc(contestId)
                    .get(),
                builder: (context, snap) {
                  final contestName = (snap.data?.data()?['title'] ?? contestId)
                      .toString();
                  return _DashboardSubmissionCard(
                    contestName: contestName,
                    status: status,
                    reason: reason,
                    videoUrl: videoUrl,
                    statusColor: _statusColor(status),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'winner':
        return AppColors.sunset;
      case 'approved':
        return const Color(0xFF2DAF6F);
      case 'rejected':
        return const Color(0xFFC53D5D);
      default:
        return AppColors.sunset;
    }
  }

  String _dashboardErrorText(Object? error) {
    final message = error?.toString() ?? '';
    if (message.contains('permission-denied')) {
      return 'تم رفض الوصول لبيانات لوحة التحكم. تحقق من قواعد Firestore.';
    }
    if (message.contains('unavailable') || message.contains('socket')) {
      return 'مشكلة شبكة أثناء تحميل لوحة التحكم. يرجى إعادة المحاولة.';
    }
    if (message.contains('deadline-exceeded') ||
        message.contains('timed out')) {
      return 'انتهت مهلة طلب لوحة التحكم. يرجى إعادة المحاولة.';
    }
    return 'تعذر تحميل بيانات لوحة التحكم. اضغط إعادة المحاولة.';
  }
}

class _DashboardSubmissionCard extends StatelessWidget {
  const _DashboardSubmissionCard({
    required this.contestName,
    required this.status,
    required this.reason,
    required this.videoUrl,
    required this.statusColor,
  });

  final String contestName;
  final String status;
  final String reason;
  final String videoUrl;
  final Color statusColor;

  String _statusLabel(BuildContext context, String value) {
    switch (value.toLowerCase()) {
      case 'approved':
        return context.tr('Approved');
      case 'pending':
        return context.tr('Pending');
      case 'rejected':
        return context.tr('Rejected');
      case 'winner':
        return context.tr('Winner');
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${context.tr('Contest')}: $contestName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusLabel(context, status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: videoUrl.isEmpty
                ? null
                : () async {
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      barrierDismissible: true,
                      builder: (_) =>
                          _UserVideoPlayerDialog(videoUrl: videoUrl),
                    );
                  },
            icon: const Icon(Icons.play_circle_fill),
            label: Text(context.tr('Watch Video')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cardSoft,
              foregroundColor: Colors.white,
            ),
          ),
          if (status == 'rejected' && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${context.tr('Reason')}: $reason',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardStatusFilter extends StatelessWidget {
  const _DashboardStatusFilter({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = <String>[
      'all',
      'pending',
      'approved',
      'rejected',
      'winner',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Filter by status'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((option) {
              final isSelected = selected == option;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    context.tr(option[0].toUpperCase() + option.substring(1)),
                    style: const TextStyle(color: Colors.white),
                  ),
                  selected: isSelected,
                  onSelected: (_) => onChanged(option),
                  selectedColor: AppColors.hotPink.withOpacity(0.22),
                  backgroundColor: AppColors.card,
                  side: BorderSide(
                    color: isSelected ? AppColors.hotPink : AppColors.border,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _UserVideoPlayerDialog extends StatefulWidget {
  const _UserVideoPlayerDialog({required this.videoUrl});

  final String videoUrl;

  @override
  State<_UserVideoPlayerDialog> createState() => _UserVideoPlayerDialogState();
}

class _UserVideoPlayerDialogState extends State<_UserVideoPlayerDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initFuture = _controller.initialize();
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('Your Video'),
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textLight),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  );
                }
                if (!_controller.value.isInitialized) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(context.tr('Unable to load video.')),
                  );
                }
                return Column(
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: VideoPlayer(_controller),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () async {
                            final position = _controller.value.position;
                            await _controller.seekTo(
                              position - const Duration(seconds: 5),
                            );
                          },
                          icon: const Icon(
                            Icons.replay_5,
                            color: AppColors.textLight,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                            setState(() {});
                          },
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                            color: AppColors.hotPink,
                            size: 34,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final position = _controller.value.position;
                            await _controller.seekTo(
                              position + const Duration(seconds: 5),
                            );
                          },
                          icon: const Icon(
                            Icons.forward_5,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WinnerVideoItem {
  const _WinnerVideoItem({
    required this.contestTitle,
    required this.winnerName,
    required this.voteCount,
    required this.videoUrl,
  });

  final String contestTitle;
  final String winnerName;
  final int voteCount;
  final String videoUrl;
}

class _UserWinnersTab extends StatefulWidget {
  const _UserWinnersTab();

  @override
  State<_UserWinnersTab> createState() => _UserWinnersTabState();
}

class _UserWinnersTabState extends State<_UserWinnersTab> {
  late Future<List<_WinnerVideoItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<List<_WinnerVideoItem>> _load() async {
    final firestore = FirebaseFirestore.instance;
    final now = Timestamp.fromDate(DateTime.now());
    final contests = await firestore
        .collection('contests')
        .where('votingEnd', isLessThanOrEqualTo: now)
        .orderBy('votingEnd', descending: true)
        .limit(20)
        .get()
        .timeout(const Duration(seconds: 20));

    final userNameCache = <String, String>{};
    final result = <_WinnerVideoItem>[];

    for (final contest in contests.docs) {
      final contestTitle = (contest.data()['title'] ?? contest.id).toString();
      final submissions = await contest.reference
          .collection('submissions')
          .where('status', isEqualTo: 'approved')
          .get()
          .timeout(const Duration(seconds: 20));
      if (submissions.docs.isEmpty) continue;

      var maxVotes = 0;
      for (final sub in submissions.docs) {
        final votes = ((sub.data()['voteCount'] ?? 0) as num).toInt();
        if (votes > maxVotes) maxVotes = votes;
      }

      for (final sub in submissions.docs) {
        final data = sub.data();
        final votes = ((data['voteCount'] ?? 0) as num).toInt();
        if (votes != maxVotes) continue;
        final userId = (data['userId'] ?? '').toString();
        if (userId.isEmpty) continue;

        var winnerName = userNameCache[userId] ?? '';
        if (winnerName.isEmpty) {
          final userDoc = await firestore.collection('users').doc(userId).get();
          winnerName =
              (userDoc.data()?['displayName'] ??
                      userDoc.data()?['email'] ??
                      userId)
                  .toString();
          userNameCache[userId] = winnerName;
        }

        result.add(
          _WinnerVideoItem(
            contestTitle: contestTitle,
            winnerName: winnerName,
            voteCount: votes,
            videoUrl: (data['videoUrl'] ?? '').toString(),
          ),
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<_WinnerVideoItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(height: 40),
                Center(
                  child: Text(
                    context.tr('Unable to load winners. Pull to refresh.'),
                  ),
                ),
              ],
            );
          }

          final winners = snapshot.data ?? const <_WinnerVideoItem>[];
          if (winners.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(height: 40),
                Center(
                  child: Text(context.tr('No winner videos available yet.')),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: winners.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final w = winners[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sunset.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            context.tr('WINNER'),
                            style: TextStyle(
                              color: AppColors.sunset,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${w.voteCount} ${context.tr('votes')}',
                          style: const TextStyle(
                            color: AppColors.hotPink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr('Contest')}: ${w.contestTitle}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.tr('Winner')}: ${w.winnerName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: w.videoUrl.isEmpty
                          ? null
                          : () async {
                              if (!context.mounted) return;
                              await showDialog<void>(
                                context: context,
                                barrierDismissible: true,
                                builder: (_) => _UserVideoPlayerDialog(
                                  videoUrl: w.videoUrl,
                                ),
                              );
                            },
                      icon: const Icon(Icons.play_circle_fill),
                      label: Text(context.tr('Watch')),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.cardSoft,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _UserProfileTab extends StatefulWidget {
  const _UserProfileTab({required this.displayName});

  final String displayName;

  @override
  State<_UserProfileTab> createState() => _UserProfileTabState();
}

class _UserProfileTabState extends State<_UserProfileTab> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _phoneCodeController = TextEditingController(text: '+1');
  final _phoneNumberController = TextEditingController();
  String _phoneIso = 'US';
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _saving = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(
      text: user?.displayName ?? widget.displayName,
    );
    _emailController = TextEditingController(text: user?.email ?? '');
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    final data = snap.data() ?? <String, dynamic>{};
    setState(() {
      _phoneCodeController.text = (data['phoneCountryCode'] ?? '+1').toString();
      _phoneNumberController.text = (data['phoneNumber'] ?? '').toString();
      _phoneIso = (data['phoneCountryIso'] ?? 'US').toString();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneCodeController.dispose();
    _phoneNumberController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();
      final currentPassword = _currentPasswordController.text.trim();
      final newPassword = _newPasswordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      final normalizedEmail = newEmail.trim().toLowerCase();
      final willUpdateEmail =
          normalizedEmail.isNotEmpty && normalizedEmail != (user.email ?? '');
      final willUpdatePassword =
          newPassword.isNotEmpty || confirmPassword.isNotEmpty;

      if (willUpdatePassword && newPassword != confirmPassword) {
        _show(context, 'New password and confirm password do not match.');
        return;
      }

      if ((willUpdateEmail || willUpdatePassword) && currentPassword.isEmpty) {
        _show(
          context,
          'Current password is required to update email or password.',
        );
        return;
      }

      if (willUpdateEmail || willUpdatePassword) {
        final credential = EmailAuthProvider.credential(
          email: user.email ?? '',
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
      }

      await user.updateDisplayName(newName);
      if (willUpdateEmail) {
        await user.verifyBeforeUpdateEmail(
          normalizedEmail,
          AuthService.emailActionCodeSettings(),
        );
      }
      if (willUpdatePassword && newPassword.isNotEmpty) {
        await user.updatePassword(newPassword);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': newName,
        'email': (user.email ?? '').trim().toLowerCase(),
        'emailLower': (user.email ?? '').trim().toLowerCase(),
        'phoneCountryCode': _phoneCodeController.text.trim(),
        'phoneCountryIso': _phoneIso,
        'phoneNumber': _phoneNumberController.text.trim(),
        'phoneE164':
            '${_phoneCodeController.text.trim()}${_phoneNumberController.text.trim()}',
        if (willUpdateEmail) 'pendingEmail': normalizedEmail,
        'updatedAt': DateTime.now().toUtc(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (willUpdateEmail) {
        _show(
          context,
          'Verification email sent. Confirm it to complete email change.',
        );
      } else {
        _show(context, 'Profile updated successfully.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _show(context, 'Current password is incorrect.');
      } else if (e.code == 'email-already-in-use') {
        _show(context, 'This email is already in use.');
      } else if (e.code == 'weak-password') {
        _show(context, 'New password is too weak.');
      } else {
        _show(context, 'Profile update failed (${e.code}).');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: context.tr('Full Name')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: context.tr('Email')),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: InkWell(
                      onTap: () {
                        showCountryPicker(
                          context: context,
                          showPhoneCode: true,
                          onSelect: (country) {
                            setState(() {
                              _phoneCodeController.text =
                                  '+${country.phoneCode}';
                              _phoneIso = country.countryCode;
                            });
                          },
                        );
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: context.tr('Country code'),
                        ),
                        child: Text(
                          '$_phoneIso ${_phoneCodeController.text}',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 7,
                    child: TextField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: context.tr('Phone number'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.tr('Security'),
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: context.tr('Current Password'),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscureCurrentPassword = !_obscureCurrentPassword,
                    ),
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: context.tr('New Password (optional)'),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscureNewPassword = !_obscureNewPassword,
                    ),
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: context.tr('Confirm New Password'),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hotPink,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _saving
                        ? context.tr('Saving...')
                        : context.tr('Update Profile'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegalCenterScreen()),
              );
            },
            icon: const Icon(Icons.privacy_tip_outlined),
            label: Text(context.tr('Legal & Privacy')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              backgroundColor: AppColors.card,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: Text(context.tr('Logout')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB93A63),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2B1B44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  final int total;
  final int pending;
  final int approved;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: context.tr('Total'),
            value: total,
            color: AppColors.hotPink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: context.tr('Pending'),
            value: pending,
            color: AppColors.sunset,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: context.tr('Approved'),
            value: approved,
            color: const Color(0xFF2DAF6F),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: context.tr('Rejected'),
            value: rejected,
            color: const Color(0xFFC53D5D),
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
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
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
