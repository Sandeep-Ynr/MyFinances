import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FlowDonutChart extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final double totalTransfer;
  final double totalFlow;

  const FlowDonutChart({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalTransfer,
    required this.totalFlow,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,##,###');
    final incPct = totalFlow > 0 ? (totalIncome / totalFlow) * 100 : 0.0;
    final expPct = totalFlow > 0 ? (totalExpense / totalFlow) * 100 : 0.0;
    final trfPct = totalFlow > 0 ? (totalTransfer / totalFlow) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense vs Income',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Donut Chart Graphic
              SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    incomePct: incPct,
                    expensePct: expPct,
                    transferPct: trfPct,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Total Flow',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${currencyFmt.format(totalFlow.toInt())}',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendRow(
                      color: const Color(0xFF22C55E),
                      label: 'Income (${incPct.toStringAsFixed(1)}%)',
                      amount: '₹${currencyFmt.format(totalIncome.toInt())}',
                    ),
                    const SizedBox(height: 10),
                    _buildLegendRow(
                      color: const Color(0xFFEF4444),
                      label: 'Expense (${expPct.toStringAsFixed(1)}%)',
                      amount: '₹${currencyFmt.format(totalExpense.toInt())}',
                    ),
                    const SizedBox(height: 10),
                    _buildLegendRow(
                      color: const Color(0xFF3B82F6),
                      label: 'Transfer (${trfPct.toStringAsFixed(1)}%)',
                      amount: '₹${currencyFmt.format(totalTransfer.toInt())}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow({
    required Color color,
    required String label,
    required String amount,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double incomePct;
  final double expensePct;
  final double transferPct;

  _DonutChartPainter({
    required this.incomePct,
    required this.expensePct,
    required this.transferPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    const strokeWidth = 14.0;

    final paintBg = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, paintBg);

    double startAngle = -pi / 2;

    void drawSegment(double pct, Color color) {
      if (pct <= 0) return;
      final sweepAngle = (pct / 100) * 2 * pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Small inset to separate segments cleanly
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + 0.04,
        sweepAngle - 0.08 > 0 ? sweepAngle - 0.08 : sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    drawSegment(incomePct, const Color(0xFF22C55E));
    drawSegment(expensePct, const Color(0xFFEF4444));
    drawSegment(transferPct, const Color(0xFF3B82F6));
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.incomePct != incomePct ||
        oldDelegate.expensePct != expensePct ||
        oldDelegate.transferPct != transferPct;
  }
}
