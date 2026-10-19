import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../shop_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import '../modern_loader.dart';

class WeeklySalesChart extends StatelessWidget {
  final bool isDesktop;
  const WeeklySalesChart({super.key, this.isDesktop = false});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // 6 days ago + today = 7 days
    final startOf7DaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final startTimestamp = Timestamp.fromDate(startOf7DaysAgo);

    final shopId = Provider.of<ShopProvider>(context).currentShopId;

    final query = shopId == null || shopId.isEmpty
        ? FirebaseUtils.firestore.collection('orders').limit(0)
        : FirebaseUtils.firestore
            .collection('orders')
            .where('shop_id', isEqualTo: shopId)
            .where('created_at', isGreaterThanOrEqualTo: startTimestamp);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: ModernLoader(color: AppColors.primaryDark));
        }

        // Initialize daily totals map
        Map<int, double> dailyTotals = {};
        for (int i = 0; i < 7; i++) {
          dailyTotals[i] = 0.0;
        }

        // Aggregate data
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? '';

          if (['Packed', 'Ready', 'Out for Delivery', 'Delivered'].contains(status)) {
            if (data['created_at'] != null) {
              DateTime date = (data['created_at'] as Timestamp).toDate();
              int diff = date.difference(startOf7DaysAgo).inDays;
              if (diff >= 0 && diff < 7) {
                double amount = double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0;
                dailyTotals[diff] = (dailyTotals[diff] ?? 0) + amount;
              }
            }
          }
        }

        // Find max for Y axis scaling
        double maxTotal = 0;
        double weeklyTotal = 0;
        for (var total in dailyTotals.values) {
          weeklyTotal += total;
          if (total > maxTotal) maxTotal = total;
        }
        if (maxTotal == 0) maxTotal = 1000; // default scale
        final double maxY = maxTotal * 1.25;
        final double yInterval = (maxTotal / 4 <= 0) ? 250 : (maxTotal / 4).ceilToDouble();

        // Build Line spots
        final spots = <FlSpot>[];
        for (int i = 0; i < 7; i++) {
          spots.add(FlSpot(i.toDouble(), dailyTotals[i]!));
        }

        Widget chartContent = AspectRatio(
          aspectRatio: isDesktop ? 2.0 : 1.5,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: maxY,
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => AppColors.textDark,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final int dayIndex = spot.x.toInt();
                      final DateTime date = startOf7DaysAgo.add(Duration(days: dayIndex));
                      final String dayStr = DateFormat('EEE, d MMM').format(date);
                      return LineTooltipItem(
                        '$dayStr\n₹${NumberFormat('#,##,###').format(spot.y.round())}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (value) => const FlLine(
                  color: AppColors.bgTint,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final int dayIndex = value.toInt();
                      if (dayIndex < 0 || dayIndex >= 7 || value != dayIndex.toDouble()) {
                        return const SizedBox.shrink();
                      }
                      DateTime date = startOf7DaysAgo.add(Duration(days: dayIndex));
                      String dayStr = DateFormat('E').format(date); // Mon, Tue...
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          dayStr,
                          style: const TextStyle(
                            color: AppColors.textMid,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      String label = value >= 1000
                          ? '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}k'
                          : value.toStringAsFixed(0);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Text(
                          label,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textMid,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: AppColors.primaryDark,
                  barWidth: 3.2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: AppColors.primaryDark,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primaryDark.withValues(alpha: 0.25),
                        AppColors.primaryDark.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (isDesktop) return chartContent;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.bgTint, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Sales',
                        style: AppTextStyles.heading2(color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${NumberFormat('#,##,###').format(weeklyTotal.round())} this week',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          size: 15,
                          color: AppColors.primaryDark,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Last 7 Days',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              chartContent,
            ],
          ),
        );
      },
    );
  }
}
