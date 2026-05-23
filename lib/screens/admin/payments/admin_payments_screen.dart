import 'dart:math' as math;

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
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Payments')),
            Text(
              context.tr('Revenue, status and transaction overview'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.68),
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
                return Center(
                  child: Text(
                    context.tr('No payments yet.'),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              final rows = docs.map(_paymentFromDoc).toList();
              final totalAmount = rows.fold<double>(
                0,
                (total, row) => total + row.amount,
              );
              final paidAmount = rows.fold<double>(
                0,
                (total, row) => total + (row.isPaid ? row.amount : 0),
              );
              final pendingAmount = rows.fold<double>(
                0,
                (total, row) => total + (row.isPending ? row.amount : 0),
              );
              final failedAmount = rows.fold<double>(
                0,
                (total, row) => total + (row.isFailed ? row.amount : 0),
              );
              final paidCount = rows.where((row) => row.isPaid).length;
              final pendingCount = rows.where((row) => row.isPending).length;
              final failedCount = rows.where((row) => row.isFailed).length;
              final monthlySeries = _lastSixMonthsPayments(rows);
              final providerSeries = _providerBreakdown(rows);

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount = width >= 980
                              ? 4
                              : width >= 640
                              ? 2
                              : 1;
                          final itemWidth =
                              (width - ((crossAxisCount - 1) * 10)) /
                              crossAxisCount;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              SizedBox(
                                width: itemWidth,
                                child: _TopStatCard(
                                  label: context.tr('Total Payment'),
                                  value: '\$${totalAmount.toStringAsFixed(0)}',
                                  color: AppColors.hotPink,
                                  icon: Icons.account_balance_wallet_rounded,
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _TopStatCard(
                                  label: context.tr('Paid Amount'),
                                  value: '\$${paidAmount.toStringAsFixed(0)}',
                                  color: AppColors.neonGreen,
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _TopStatCard(
                                  label: context.tr('Pending Amount'),
                                  value:
                                      '\$${pendingAmount.toStringAsFixed(0)}',
                                  color: AppColors.sunset,
                                  icon: Icons.pending_actions_rounded,
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _TopStatCard(
                                  label: context.tr('Failed Amount'),
                                  value: '\$${failedAmount.toStringAsFixed(0)}',
                                  color: const Color(0xFFE84B5B),
                                  icon: Icons.error_outline_rounded,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _DashboardPanel(
                        title: context.tr('Revenue Insights'),
                        child: _RevenueInsightsPanel(
                          totalAmount: totalAmount,
                          paidAmount: paidAmount,
                          pendingAmount: pendingAmount,
                          monthlySeries: monthlySeries,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 820;
                          return GridView.count(
                            crossAxisCount: wide ? 2 : 1,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: wide ? 1.6 : 1.02,
                            children: [
                              _DashboardPanel(
                                title: context.tr('Payment Status Overview'),
                                expandChild: true,
                                child: _PaymentOverviewPanel(
                                  total: rows.length,
                                  paidCount: paidCount,
                                  pendingCount: pendingCount,
                                  failedCount: failedCount,
                                ),
                              ),
                              _DashboardPanel(
                                title: context.tr('Payment Providers'),
                                expandChild: true,
                                child: _ProviderBreakdownPanel(
                                  providers: providerSeries,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _DashboardPanel(
                        title: context.tr('Recent Payments'),
                        child: _PaymentsTable(rows: rows),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopStatCard extends StatelessWidget {
  const _TopStatCard({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 230;
        final iconSize = compact ? 34.0 : 38.0;
        final valueSize = compact ? 16.0 : 18.0;
        final labelSize = compact ? 10.0 : 11.0;
        final cardHeight = compact ? 124.0 : 112.0;

        return Container(
          height: cardHeight,
          padding: EdgeInsets.all(compact ? 11 : 12),
          decoration: BoxDecoration(
            color: const Color(0xFF111A2B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: compact ? 17 : 18),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: valueSize,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: labelSize,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.child,
    this.expandChild = false,
  });

  final String title;
  final Widget child;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10192A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _RevenueInsightsPanel extends StatelessWidget {
  const _RevenueInsightsPanel({
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.monthlySeries,
  });

  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final List<_MonthlyPoint> monthlySeries;

  @override
  Widget build(BuildContext context) {
    final values = monthlySeries.map((e) => e.amount).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 760;
        final metrics = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MiniRevenueStat(
              label: context.tr('Total Payment'),
              value: '\$${totalAmount.toStringAsFixed(0)}',
              color: AppColors.hotPink,
            ),
            _MiniRevenueStat(
              label: context.tr('Paid Amount'),
              value: '\$${paidAmount.toStringAsFixed(0)}',
              color: AppColors.neonGreen,
            ),
            _MiniRevenueStat(
              label: context.tr('Pending Amount'),
              value: '\$${pendingAmount.toStringAsFixed(0)}',
              color: AppColors.sunset,
            ),
          ],
        );
        final chart = Container(
          height: 220,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          decoration: BoxDecoration(
            color: AppColors.cardSoft.withOpacity(0.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _LineChartPainter(
                    values: values,
                    lineColor: const Color(0xFF8F79FF),
                    fillColor: const Color(0x338F79FF),
                  ),
                  child: Container(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final point in monthlySeries)
                    Expanded(
                      child: Text(
                        point.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 250, child: metrics),
              const SizedBox(width: 14),
              Expanded(child: chart),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [metrics, const SizedBox(height: 14), chart],
        );
      },
    );
  }
}

class _MiniRevenueStat extends StatelessWidget {
  const _MiniRevenueStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSoft.withOpacity(0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
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

class _PaymentOverviewPanel extends StatelessWidget {
  const _PaymentOverviewPanel({
    required this.total,
    required this.paidCount,
    required this.pendingCount,
    required this.failedCount,
  });

  final int total;
  final int paidCount;
  final int pendingCount;
  final int failedCount;

  @override
  Widget build(BuildContext context) {
    final segments = [
      _PieSegment(
        value: paidCount.toDouble(),
        color: AppColors.neonGreen,
        label: context.tr('Paid'),
      ),
      _PieSegment(
        value: pendingCount.toDouble(),
        color: AppColors.sunset,
        label: context.tr('Pending'),
      ),
      _PieSegment(
        value: failedCount.toDouble(),
        color: const Color(0xFFE84B5B),
        label: context.tr('Failed'),
      ),
    ];
    final totalValue = math.max<double>(
      1,
      segments.fold<double>(0, (total, segment) => total + segment.value),
    );

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _DonutChartPainter(
                segments: segments,
                total: totalValue,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$total',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      context.tr('Total'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: segments
                .map(
                  (segment) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: segment.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            segment.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${segment.value.toInt()}',
                          style: TextStyle(
                            color: segment.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ProviderBreakdownPanel extends StatelessWidget {
  const _ProviderBreakdownPanel({required this.providers});

  final List<_StatusBarData> providers;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max<double>(
      1,
      providers.fold<double>(
        0,
        (max, item) => item.value > max ? item.value : max,
      ),
    );
    return CustomPaint(
      painter: _BarsPainter(bars: providers, maxValue: maxValue),
      child: Container(),
    );
  }
}

class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({required this.rows});

  final List<_PaymentRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaymentsHeader(
          labels: [
            context.tr('Customer'),
            context.tr('Amount'),
            context.tr('Provider'),
            context.tr('Date'),
            context.tr('Status'),
          ],
        ),
        const SizedBox(height: 10),
        for (final row in rows.take(8)) ...[
          _PaymentTransactionRow(row: row),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PaymentsHeader extends StatelessWidget {
  const _PaymentsHeader({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 2, child: _headerText(labels[0])),
        Expanded(child: _headerText(labels[1])),
        Expanded(child: _headerText(labels[2])),
        Expanded(child: _headerText(labels[3])),
        Expanded(child: _headerText(labels[4])),
      ],
    );
  }

  Widget _headerText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PaymentTransactionRow extends StatelessWidget {
  const _PaymentTransactionRow({required this.row});

  final _PaymentRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSoft.withOpacity(0.42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              row.customer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '\$${row.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.provider,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _formatDate(row.createdAt),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: _StatusPill(status: row.status)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'paid' || 'completed' || 'success' => AppColors.neonGreen,
      'failed' || 'error' || 'cancelled' => const Color(0xFFE84B5B),
      _ => AppColors.sunset,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _capitalize(normalized),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter({required this.bars, required this.maxValue});

  final List<_StatusBarData> bars;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    final chartHeight = size.height - 38.0;

    for (var i = 0; i <= 3; i++) {
      final y = chartHeight * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axisPaint);
    }

    final slotWidth = size.width / math.max(1, bars.length);
    final columnWidth = slotWidth * 0.44;
    final baseY = chartHeight;

    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final left = slotWidth * i + ((slotWidth - columnWidth) / 2);
      final barHeight = maxValue == 0
          ? 0.0
          : ((bar.value / maxValue) * (chartHeight - 12)).toDouble();
      final paint = Paint()..color = bar.color;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseY - barHeight, columnWidth, barHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, paint);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: bar.label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slotWidth);
      labelPainter.paint(
        canvas,
        Offset(
          slotWidth * i + ((slotWidth - labelPainter.width) / 2),
          size.height - 18,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) {
    return oldDelegate.bars != bars || oldDelegate.maxValue != maxValue;
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    final chart = Rect.fromLTWH(0, 8, size.width, size.height - 18);

    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * (i / 3);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), axisPaint);
    }

    final maxValue = math.max<double>(
      1,
      values.fold<double>(0, (max, item) => item > max ? item : max),
    );
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = chart.left + chart.width * (i / math.max(1, values.length - 1));
      final y = chart.bottom - ((values[i] / maxValue) * (chart.height - 12));
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, chart.bottom);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(points.last.dx, chart.bottom)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    for (final point in points) {
      canvas.drawCircle(point, 3.5, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({required this.segments, required this.total});

  final List<_PieSegment> segments;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.15;
    final rect = Rect.fromLTWH(
      stroke,
      stroke,
      size.width - stroke * 2,
      size.height - stroke * 2,
    );
    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      final sweep = total == 0 ? 0.0 : (segment.value / total) * math.pi * 2;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments || oldDelegate.total != total;
  }
}

class _PieSegment {
  const _PieSegment({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;
}

class _StatusBarData {
  const _StatusBarData(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class _PaymentRow {
  const _PaymentRow({
    required this.customer,
    required this.amount,
    required this.status,
    required this.provider,
    required this.createdAt,
  });

  final String customer;
  final double amount;
  final String status;
  final String provider;
  final DateTime createdAt;

  bool get isPaid {
    final normalized = status.toLowerCase();
    return normalized == 'paid' ||
        normalized == 'completed' ||
        normalized == 'success';
  }

  bool get isPending {
    final normalized = status.toLowerCase();
    return normalized == 'pending' || normalized == 'unpaid';
  }

  bool get isFailed {
    final normalized = status.toLowerCase();
    return normalized == 'failed' ||
        normalized == 'cancelled' ||
        normalized == 'error';
  }
}

class _MonthlyPoint {
  const _MonthlyPoint({required this.label, required this.amount});

  final String label;
  final double amount;
}

_PaymentRow _paymentFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final amount = ((data['amount'] ?? 0) as num).toDouble();
  final createdAt =
      ((data['createdAt'] ?? data['updatedAt']) as Timestamp?)?.toDate() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  return _PaymentRow(
    customer: _paymentCustomerLabel(data),
    amount: amount,
    status: (data['status'] ?? 'pending').toString(),
    provider: (data['provider'] ?? 'stripe').toString(),
    createdAt: createdAt,
  );
}

String _paymentCustomerLabel(Map<String, dynamic> data) {
  final values = [
    data['customerName'],
    data['sponsorName'],
    data['companyName'],
    data['displayName'],
    data['email'],
    data['customerEmail'],
  ];
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return 'Customer';
}

List<_MonthlyPoint> _lastSixMonthsPayments(List<_PaymentRow> rows) {
  final now = DateTime.now();
  final months = List.generate(6, (index) {
    final date = DateTime(now.year, now.month - (5 - index), 1);
    return DateTime(date.year, date.month, 1);
  });

  final totals = <DateTime, double>{for (final month in months) month: 0};

  for (final row in rows) {
    final monthKey = DateTime(row.createdAt.year, row.createdAt.month, 1);
    if (totals.containsKey(monthKey)) {
      totals[monthKey] = (totals[monthKey] ?? 0) + row.amount;
    }
  }

  const labels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months
      .map(
        (month) => _MonthlyPoint(
          label: labels[month.month - 1],
          amount: totals[month] ?? 0,
        ),
      )
      .toList();
}

List<_StatusBarData> _providerBreakdown(List<_PaymentRow> rows) {
  final totals = <String, double>{};
  for (final row in rows) {
    final key = row.provider.trim().isEmpty
        ? 'stripe'
        : row.provider.toLowerCase();
    totals[key] = (totals[key] ?? 0) + row.amount;
  }

  final colors = [
    AppColors.hotPink,
    AppColors.neonGreen,
    AppColors.sunset,
    const Color(0xFF69E8FF),
    const Color(0xFF8F79FF),
  ];

  final entries = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return [
    for (var i = 0; i < entries.length; i++)
      _StatusBarData(
        _capitalize(entries[i].key),
        entries[i].value,
        colors[i % colors.length],
      ),
  ];
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _formatDate(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return '-';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]}';
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
