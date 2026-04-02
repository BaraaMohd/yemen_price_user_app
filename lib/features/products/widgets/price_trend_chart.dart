// #1 - Price Trend Chart Widget
// Displays a line chart of historical store prices for a given product using fl_chart.
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class PriceTrendChart extends StatelessWidget {
  /// List of [price, dayOffset] data points — newest last.
  final List<Map<String, dynamic>> offers;
  final String currency;

  const PriceTrendChart({
    super.key,
    required this.offers,
    this.currency = 'YER',
  });

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return Center(
        child: Text(
          'لا توجد بيانات تاريخية',
          style: GoogleFonts.cairo(color: Theme.of(context).hintColor),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    // Build spots from store offer prices
    final spots = <FlSpot>[];
    for (var i = 0; i < offers.length; i++) {
      final price = (offers[i]['price'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), price));
    }

    final prices = spots.map((s) => s.y).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final pad = (maxPrice - minPrice) * 0.2 + 100;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: (minPrice - pad).clamp(0, double.infinity),
          maxY: maxPrice + pad,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: cs.outline.withValues(alpha: 0.18),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (v, meta) => Text(
                  v.toStringAsFixed(0),
                  style: GoogleFonts.cairo(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: cs.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: cs.primary,
                  strokeColor: cs.surface,
                  strokeWidth: 1.5,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: 0.22),
                    cs.primary.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => cs.primaryContainer,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                '${s.y.toStringAsFixed(0)} $currency',
                GoogleFonts.cairo(
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer,
                  fontSize: 12,
                ),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
