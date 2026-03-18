import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';

class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Payments')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(child: Text(context.tr('No payments yet.')));
              }
              final totalAmount = docs.fold<double>(
                0,
                (sum, doc) =>
                    sum + ((doc.data()['amount'] ?? 0) as num).toDouble(),
              );
              final pendingDocs = docs
                  .where(
                    (doc) =>
                        (doc.data()['status'] ?? 'pending')
                            .toString()
                            .toLowerCase() ==
                        'pending',
                  )
                  .toList();
              final pendingAmount = pendingDocs.fold<double>(
                0,
                (sum, doc) =>
                    sum + ((doc.data()['amount'] ?? 0) as num).toDouble(),
              );
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width >= 480 ? 3 : 2;
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: width >= 480 ? 0.95 : 1.55,
                          children: [
                            _MetricCard(
                              label: context.tr('Total Payment'),
                              value: '\$${totalAmount.toStringAsFixed(2)}',
                              icon: Icons.account_balance_wallet_rounded,
                              color: AppColors.hotPink,
                            ),
                            _MetricCard(
                              label: context.tr('Pending Payments'),
                              value: pendingDocs.length.toString(),
                              icon: Icons.pending_actions_rounded,
                              color: AppColors.sunset,
                            ),
                            _MetricCard(
                              label: context.tr('Pending Amount'),
                              value: '\$${pendingAmount.toStringAsFixed(2)}',
                              icon: Icons.hourglass_top_rounded,
                              color: Colors.redAccent,
                            ),
                          ],
                        );
                      },
                    );
                  }
                  final data = docs[index - 1].data();
                  final amount = ((data['amount'] ?? 0) as num).toDouble();
                  final status = (data['status'] ?? 'pending').toString();
                  final provider = (data['provider'] ?? 'stripe').toString();
                  final invoice = (data['invoiceNumber'] ?? '-').toString();
                  final applicationId = (data['applicationId'] ?? '')
                      .toString();
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
                        Text(
                          '\$${amount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.tr('Status')}: $status | ${context.tr('Provider')}: $provider',
                        ),
                        const SizedBox(height: 4),
                        Text('${context.tr('Invoice')}: $invoice'),
                        const SizedBox(height: 4),
                        if (applicationId.isNotEmpty)
                          Text(
                            '${context.tr('Application ID')}: $applicationId',
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
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
