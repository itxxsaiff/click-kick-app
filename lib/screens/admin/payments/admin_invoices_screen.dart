import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';

class AdminInvoicesScreen extends StatelessWidget {
  const AdminInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Invoices')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .orderBy('invoiceGeneratedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs
                  .where(
                    (d) =>
                        (d.data()['invoiceNumber'] ?? '').toString().isNotEmpty,
                  )
                  .toList();
              if (docs.isEmpty) {
                return Center(
                  child: Text(context.tr('No invoices generated yet.')),
                );
              }
              final total = docs.length;
              final paid = docs
                  .where((d) => (d.data()['status'] ?? '').toString() == 'paid')
                  .length;
              final unpaid = total - paid;
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width >= 390 ? 3 : 2;
                        final ratio = width >= 900
                            ? 2.0
                            : width >= 700
                            ? 1.65
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
                            _InvoiceStatCard(
                              label: context.tr('Total'),
                              value: total.toString(),
                              color: AppColors.hotPink,
                              icon: Icons.receipt_long,
                            ),
                            _InvoiceStatCard(
                              label: context.tr('Paid'),
                              value: paid.toString(),
                              color: AppColors.neonGreen,
                              icon: Icons.check_circle,
                            ),
                            _InvoiceStatCard(
                              label: context.tr('Unpaid'),
                              value: unpaid.toString(),
                              color: AppColors.sunset,
                              icon: Icons.hourglass_top,
                            ),
                          ],
                        );
                      },
                    );
                  }
                  final data = docs[index - 1].data();
                  final amount = ((data['amount'] ?? 0) as num).toDouble();
                  final invoiceNumber = (data['invoiceNumber'] ?? '-')
                      .toString();
                  final sponsorId = (data['sponsorId'] ?? '').toString();
                  final applicationId = (data['applicationId'] ?? '')
                      .toString();
                  final invoiceUrl = (data['invoiceUrl'] ?? '').toString();
                  final createdAt = (data['invoiceGeneratedAt'] as Timestamp?)
                      ?.toDate();
                  final date = createdAt == null
                      ? '--'
                      : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
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
                          invoiceNumber,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('${context.tr('Date')}: $date'),
                        const SizedBox(height: 4),
                        Text(
                          '${context.tr('Amount')}: \$${amount.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 4),
                        Text('${context.tr('Sponsor ID')}: $sponsorId'),
                        if (applicationId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${context.tr('Application ID')}: $applicationId',
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: invoiceUrl.isEmpty
                                    ? null
                                    : () => launchUrl(
                                        Uri.parse(invoiceUrl),
                                        mode: LaunchMode.externalApplication,
                                      ),
                                icon: const Icon(Icons.visibility),
                                label: Text(context.tr('View PDF')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: invoiceUrl.isEmpty
                                    ? null
                                    : () => launchUrl(
                                        Uri.parse(
                                          _downloadUrl(
                                            invoiceUrl,
                                            invoiceNumber,
                                          ),
                                        ),
                                        mode: LaunchMode.externalApplication,
                                      ),
                                icon: const Icon(Icons.download),
                                label: Text(context.tr('Download')),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.hotPink,
                                  foregroundColor: Colors.white,
                                ),
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

class _InvoiceStatCard extends StatelessWidget {
  const _InvoiceStatCard({
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
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

String _downloadUrl(String original, String invoiceNumber) {
  final uri = Uri.parse(original);
  final qp = Map<String, String>.from(uri.queryParameters);
  qp['response-content-disposition'] =
      'attachment; filename="$invoiceNumber.pdf"';
  return uri.replace(queryParameters: qp).toString();
}
