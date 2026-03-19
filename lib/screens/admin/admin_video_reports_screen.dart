import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';

class AdminVideoReportsScreen extends StatefulWidget {
  const AdminVideoReportsScreen({super.key});

  @override
  State<AdminVideoReportsScreen> createState() => _AdminVideoReportsScreenState();
}

class _AdminVideoReportsScreenState extends State<AdminVideoReportsScreen> {
  String _status = 'all';
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Video Reports')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: context.tr('Search reports'),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['all', 'open', 'resolved', 'dismissed'].map((status) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                selected: _status == status,
                                label: Text(_statusLabel(context, status)),
                                onSelected: (_) => setState(() => _status = status),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('video_reports')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data();
                      final status = (data['status'] ?? 'open').toString();
                      final contestTitle = (data['contestTitle'] ?? '').toString().toLowerCase();
                      final participantName = (data['participantName'] ?? '').toString().toLowerCase();
                      final reason = (data['reason'] ?? '').toString().toLowerCase();
                      if (_status != 'all' && status != _status) return false;
                      if (_query.isEmpty) return true;
                      return contestTitle.contains(_query) ||
                          participantName.contains(_query) ||
                          reason.contains(_query);
                    }).toList();

                    if (docs.isEmpty) {
                      return Center(child: Text(context.tr('No video reports found.')));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final status = (data['status'] ?? 'open').toString();
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (data['contestTitle'] ?? context.tr('Unknown Contest')).toString(),
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusLabel(context, status),
                                      style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${context.tr('Participant')}: ${(data['participantName'] ?? context.tr('Unknown User')).toString()}'),
                              Text('${context.tr('Reporter')}: ${(data['reporterEmail'] ?? '').toString()}'),
                              const SizedBox(height: 8),
                              Text('${context.tr('Reason')}: ${(data['reason'] ?? '').toString()}'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: status == 'resolved'
                                          ? null
                                          : () => _setStatus(doc.reference, 'resolved'),
                                      child: Text(context.tr('Resolve')),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: status == 'dismissed'
                                          ? null
                                          : () => _setStatus(doc.reference, 'dismissed'),
                                      child: Text(context.tr('Dismiss')),
                                    ),
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

  Future<void> _setStatus(DocumentReference<Map<String, dynamic>> ref, String status) async {
    await ref.update({
      'status': status,
      'reviewedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
    });
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'open':
        return context.tr('Open');
      case 'resolved':
        return context.tr('Resolved');
      case 'dismissed':
        return context.tr('Dismissed');
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return const Color(0xFF2DAF6F);
      case 'dismissed':
        return const Color(0xFFC53D5D);
      default:
        return AppColors.sunset;
    }
  }
}

class _SpaceBackground extends StatelessWidget {
  const _SpaceBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.nebula, AppColors.deepSpace],
        ),
      ),
    );
  }
}
