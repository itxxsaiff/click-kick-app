import 'dart:math' as math;

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
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Invoice Dashboard')),
            Text(
              context.tr('Overview of all invoices and payments'),
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
                  child: Text(
                    context.tr('No invoices generated yet.'),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              final rows = docs.map(_invoiceFromDoc).toList();
              final totalRevenue = rows.fold<double>(
                0,
                (sum, row) => sum + (row.status == 'paid' ? row.amount : 0),
              );
              final paidAmount = rows.fold<double>(
                0,
                (sum, row) => sum + (row.status == 'paid' ? row.amount : 0),
              );
              final pendingAmount = rows.fold<double>(
                0,
                (sum, row) =>
                    sum +
                    ((row.status == 'pending' || row.status == 'unpaid')
                        ? row.amount
                        : 0),
              );
              final totalInvoices = rows.length;
              final paidCount = rows
                  .where((row) => row.status == 'paid')
                  .length;
              final pendingCount = rows
                  .where(
                    (row) => row.status == 'pending' || row.status == 'unpaid',
                  )
                  .length;
              final overdueCount = rows
                  .where((row) => row.status == 'overdue')
                  .length;
              final revenueSeries = _lastSixMonthsRevenue(rows);
              final latestInvoices = rows.take(5).toList();

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return SizedBox(
                            height: 112,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _TopStatCard(
                                    label: context.tr('Total Revenue'),
                                    value:
                                        '\$${totalRevenue.toStringAsFixed(0)}',
                                    color: AppColors.hotPink,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _TopStatCard(
                                    label: context.tr('Paid Amount'),
                                    value: '\$${paidAmount.toStringAsFixed(0)}',
                                    color: AppColors.neonGreen,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _TopStatCard(
                                    label: context.tr('Pending Amount'),
                                    value:
                                        '\$${pendingAmount.toStringAsFixed(0)}',
                                    color: AppColors.sunset,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _TopStatCard(
                                    label: context.tr('Total Invoices'),
                                    value: '$totalInvoices',
                                    color: const Color(0xFF69E8FF),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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
                                title: context.tr('Invoices Overview'),
                                expandChild: true,
                                child: _InvoiceOverviewPanel(
                                  total: totalInvoices,
                                  paidCount: paidCount,
                                  pendingCount: pendingCount,
                                  overdueCount: overdueCount,
                                ),
                              ),
                              _DashboardPanel(
                                title: context.tr('Recent Invoices'),
                                trailing: context.tr('View All'),
                                expandChild: true,
                                child: _RecentInvoicesPanel(
                                  rows: latestInvoices,
                                ),
                              ),
                              _DashboardPanel(
                                title: context.tr('Invoices By Status'),
                                expandChild: true,
                                child: _StatusBarsPanel(
                                  paidCount: paidCount,
                                  pendingCount: pendingCount,
                                  overdueCount: overdueCount,
                                ),
                              ),
                              _DashboardPanel(
                                title: context.tr('Monthly Revenue'),
                                expandChild: true,
                                child: _MonthlyRevenuePanel(
                                  series: revenueSeries,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _DashboardPanel(
                        title: context.tr('Recent Transactions'),
                        trailing: context.tr('View All'),
                        expandChild: false,
                        onTrailingTap: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: const Color(0xFF10192A),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(22),
                              ),
                            ),
                            builder: (sheetContext) {
                              return SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    20,
                                  ),
                                  child: SizedBox(
                                    height:
                                        MediaQuery.of(
                                          sheetContext,
                                        ).size.height *
                                        0.78,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                context.tr('All Transactions'),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  Navigator.pop(sheetContext),
                                              icon: const Icon(
                                                Icons.close_rounded,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: _RecentTransactionsTable(
                                              rows: rows,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: _RecentTransactionsTable(
                          rows: rows.take(6).toList(),
                        ),
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
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.child,
    this.trailing,
    this.expandChild = false,
    this.onTrailingTap,
  });

  final String title;
  final String? trailing;
  final Widget child;
  final bool expandChild;
  final VoidCallback? onTrailingTap;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if ((trailing ?? '').isNotEmpty)
                InkWell(
                  onTap: onTrailingTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      trailing!,
                      style: const TextStyle(
                        color: Color(0xFF8F79FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _InvoiceOverviewPanel extends StatelessWidget {
  const _InvoiceOverviewPanel({
    required this.total,
    required this.paidCount,
    required this.pendingCount,
    required this.overdueCount,
  });

  final int total;
  final int paidCount;
  final int pendingCount;
  final int overdueCount;

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
        value: overdueCount.toDouble(),
        color: const Color(0xFFE84B5B),
        label: context.tr('Overdue'),
      ),
    ];
    final totalValue = math.max<double>(
      1,
      segments.fold<double>(0, (sum, segment) => sum + segment.value),
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

class _RecentInvoicesPanel extends StatelessWidget {
  const _RecentInvoicesPanel({required this.rows});

  final List<_InvoiceRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.invoiceNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      row.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 72,
                    child: Text(
                      '\$${row.amount.toStringAsFixed(0)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusPill(status: row.status),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatusBarsPanel extends StatelessWidget {
  const _StatusBarsPanel({
    required this.paidCount,
    required this.pendingCount,
    required this.overdueCount,
  });

  final int paidCount;
  final int pendingCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final bars = [
      _StatusBarData(
        context.tr('Paid'),
        paidCount.toDouble(),
        AppColors.neonGreen,
      ),
      _StatusBarData(
        context.tr('Pending'),
        pendingCount.toDouble(),
        AppColors.sunset,
      ),
      _StatusBarData(
        context.tr('Overdue'),
        overdueCount.toDouble(),
        const Color(0xFFE84B5B),
      ),
    ];
    final maxValue = math.max<double>(
      1,
      bars.fold<double>(0, (max, item) => item.value > max ? item.value : max),
    );

    return CustomPaint(
      painter: _BarsPainter(bars: bars, maxValue: maxValue),
      child: Container(),
    );
  }
}

class _MonthlyRevenuePanel extends StatelessWidget {
  const _MonthlyRevenuePanel({required this.series});

  final List<_MonthlyPoint> series;

  @override
  Widget build(BuildContext context) {
    final values = series.map((e) => e.amount).toList();
    return Column(
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
            for (final point in series)
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
      ],
    );
  }
}

class _RecentTransactionsTable extends StatelessWidget {
  const _RecentTransactionsTable({required this.rows});

  final List<_InvoiceRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TransactionsHeader(
          labels: [
            context.tr('Invoice ID'),
            context.tr('Customer'),
            context.tr('Amount'),
            context.tr('Date'),
            context.tr('Status'),
          ],
        ),
        const SizedBox(height: 10),
        for (final row in rows) ...[
          _TransactionRow(row: row),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TransactionsHeader extends StatelessWidget {
  const _TransactionsHeader({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 2, child: _headerText(labels[0])),
        Expanded(flex: 2, child: _headerText(labels[1])),
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

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.row});

  final _InvoiceRow row;

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
              row.invoiceNumber,
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
            flex: 2,
            child: Text(
              row.customer,
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
              _dateLabel(row.date),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusPill(status: row.status),
                  if (row.invoiceUrl.isNotEmpty)
                    PopupMenuButton<String>(
                      color: const Color(0xFF151E31),
                      padding: EdgeInsets.zero,
                      onSelected: (value) async {
                        final uri = value == 'download'
                            ? Uri.parse(
                                _downloadUrl(row.invoiceUrl, row.invoiceNumber),
                              )
                            : Uri.parse(row.invoiceUrl);
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'view',
                          child: Text(context.tr('View PDF')),
                        ),
                        PopupMenuItem(
                          value: 'download',
                          child: Text(context.tr('Download')),
                        ),
                      ],
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
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
      'paid' => AppColors.neonGreen,
      'overdue' => const Color(0xFFE84B5B),
      _ => AppColors.sunset,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(context, normalized),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.bars, required this.maxValue});

  final List<_StatusBarData> bars;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    final double baseY = size.height - 22.0;
    final double chartHeight = size.height - 38.0;
    final double columnWidth = size.width / (bars.length * 2);
    for (var i = 0; i < 4; i++) {
      final y = chartHeight * (i / 3);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = Colors.white.withOpacity(0.06)
          ..strokeWidth = 1,
      );
    }
    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final double left = ((i * 2) + 0.6) * columnWidth;
      final double barHeight = maxValue == 0
          ? 0.0
          : ((bar.value / maxValue) * (chartHeight - 12)).toDouble();
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseY - barHeight, columnWidth, barHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = bar.color);
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
      )..layout(maxWidth: columnWidth * 1.7);
      labelPainter.paint(
        canvas,
        Offset(left - columnWidth * 0.2, size.height - 16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) {
    return oldDelegate.bars != bars || oldDelegate.maxValue != maxValue;
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = math.max<double>(
      1,
      values.fold<double>(0, (max, value) => value > max ? value : max),
    );
    final chart = Rect.fromLTWH(0, 8, size.width, size.height - 18);

    for (var i = 0; i < 4; i++) {
      final y = chart.top + chart.height * (i / 3);
      canvas.drawLine(
        Offset(chart.left, y),
        Offset(chart.right, y),
        Paint()
          ..color = Colors.white.withOpacity(0.06)
          ..strokeWidth = 1,
      );
    }

    if (values.isEmpty) return;
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = chart.left + chart.width * (i / math.max(1, values.length - 1));
      final y = chart.bottom - ((values[i] / maxValue) * (chart.height - 12));
      points.add(Offset(x, y));
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final midX = (prev.dx + current.dx) / 2;
      line.cubicTo(midX, prev.dy, midX, current.dy, current.dx, current.dy);
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, chart.bottom)
      ..lineTo(points.first.dx, chart.bottom)
      ..close();

    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    for (final point in points) {
      canvas.drawCircle(point, 3.2, Paint()..color = lineColor);
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
  _DonutChartPainter({required this.segments, required this.total});

  final List<_PieSegment> segments;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 10;
    final strokeWidth = radius * 0.3;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white.withOpacity(0.06),
    );

    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweep = (segment.value / total) * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = segment.color,
      );
      start += sweep + 0.05;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments || oldDelegate.total != total;
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

class _InvoiceRow {
  const _InvoiceRow({
    required this.invoiceNumber,
    required this.customer,
    required this.amount,
    required this.status,
    required this.date,
    required this.invoiceUrl,
  });

  final String invoiceNumber;
  final String customer;
  final double amount;
  final String status;
  final DateTime? date;
  final String invoiceUrl;
}

class _MonthlyPoint {
  const _MonthlyPoint({required this.label, required this.amount});

  final String label;
  final double amount;
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

_InvoiceRow _invoiceFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final rawAmount =
      (data['totalAmount'] ?? data['amount'] ?? data['applicationFee'] ?? 0)
          as num;
  final date = (data['invoiceGeneratedAt'] ?? data['createdAt']) as Timestamp?;
  final customer = _resolveCustomerName(data);
  final rawStatus = (data['paymentStatus'] ?? data['status'] ?? 'pending')
      .toString()
      .toLowerCase();
  String status;
  switch (rawStatus) {
    case 'paid':
    case 'succeeded':
    case 'success':
      status = 'paid';
      break;
    case 'failed':
    case 'overdue':
      status = 'overdue';
      break;
    case 'unpaid':
      status = 'pending';
      break;
    default:
      status = rawStatus;
  }

  return _InvoiceRow(
    invoiceNumber: (data['invoiceNumber'] ?? '-').toString(),
    customer: customer,
    amount: rawAmount.toDouble(),
    status: status,
    date: date?.toDate(),
    invoiceUrl: (data['invoiceUrl'] ?? '').toString(),
  );
}

String _resolveCustomerName(Map<String, dynamic> data) {
  final preferred = [
    data['customerName'],
    data['sponsorName'],
    data['companyName'],
    data['displayName'],
    data['customerEmail'],
    data['sponsorEmail'],
  ];
  for (final value in preferred) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return 'Sponsor';
}

List<_MonthlyPoint> _lastSixMonthsRevenue(List<_InvoiceRow> rows) {
  final now = DateTime.now();
  final months = <DateTime>[];
  for (var i = 5; i >= 0; i--) {
    months.add(DateTime(now.year, now.month - i, 1));
  }
  final sums = <String, double>{};
  for (final month in months) {
    sums['${month.year}-${month.month}'] = 0;
  }
  for (final row in rows) {
    if (row.date == null || row.status != 'paid') continue;
    final key = '${row.date!.year}-${row.date!.month}';
    if (sums.containsKey(key)) {
      sums[key] = sums[key]! + row.amount;
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
          amount: sums['${month.year}-${month.month}'] ?? 0,
        ),
      )
      .toList();
}

String _statusLabel(BuildContext context, String status) {
  switch (status) {
    case 'paid':
      return context.tr('Paid');
    case 'overdue':
      return context.tr('Overdue');
    default:
      return context.tr('Pending');
  }
}

String _dateLabel(DateTime? date) {
  if (date == null) return '--';
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _downloadUrl(String original, String invoiceNumber) {
  final uri = Uri.parse(original);
  final qp = Map<String, String>.from(uri.queryParameters);
  qp['response-content-disposition'] =
      'attachment; filename="$invoiceNumber.pdf"';
  return uri.replace(queryParameters: qp).toString();
}
