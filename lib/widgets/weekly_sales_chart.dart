import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../shop_provider.dart';
import '../language_provider.dart';
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
    final lang = Provider.of<LanguageProvider>(context);

    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    String getDayName(DateTime date) {
      if (lang.isHindi) {
        const hindiDays = ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
        return hindiDays[date.weekday - 1];
      }
      return DateFormat('E').format(date); // Mon, Tue...
    }
    
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

        double weekTotal = 0.0;

        // Aggregate data
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? '';
          
          if (['Packed', 'Ready', 'Out for Delivery', 'Delivered'].contains(status)) {
            if (data['created_at'] != null) {
              DateTime date = (data['created_at'] as Timestamp).toDate();
              // Calculate days difference from 7 days ago
              int diff = date.difference(startOf7DaysAgo).inDays;
              if (diff >= 0 && diff < 7) {
                 double amount = double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0;
                 dailyTotals[diff] = (dailyTotals[diff] ?? 0) + amount;
                 weekTotal += amount;
              }
            }
          }
        }
        
        // Find max for Y axis scaling
        double maxTotal = 0;
        for (var total in dailyTotals.values) {
           if (total > maxTotal) maxTotal = total;
        }
        if (maxTotal == 0) maxTotal = 1000; // default scale
        
        // Build LineChart FlSpots
        List<FlSpot> spots = [];
        for (int i = 0; i < 7; i++) {
          spots.add(FlSpot(i.toDouble(), dailyTotals[i]!));
        }

        Widget chartContent = AspectRatio(
          aspectRatio: isDesktop ? 2.2 : 1.6,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxTotal <= 0 ? 250 : (maxTotal / 3).clamp(50, 100000),
                getDrawingHorizontalLine: (value) => const FlLine(
                  color: Color(0xFFF1F5F9),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      String label = value >= 1000
                          ? '₹${(value / 1000).toStringAsFixed(1)}k'
                          : '₹${value.toInt()}';
                      return Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index < 0 || index >= 7) return const SizedBox.shrink();
                      DateTime date = startOf7DaysAgo.add(Duration(days: index));
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          getDayName(date),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: maxTotal * 1.25,
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF0F172A),
                  tooltipBorderRadius: BorderRadius.circular(8),
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      return LineTooltipItem(
                        '₹${spot.y.toStringAsFixed(0)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: const Color(0xFF0C831F), // Zepto / Blinkit iconic green
                  barWidth: 3.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: const Color(0xFF0C831F),
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0C831F).withValues(alpha: 0.22),
                        const Color(0xFF0C831F).withValues(alpha: 0.01),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (isDesktop) return chartContent;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.show_chart_rounded,
                          color: Color(0xFF0C831F),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('Weekly Sales Trend', 'साप्ताहिक बिक्री ट्रेंड', 'Weekly Bikri Trend'),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            t('Last 7 days performance', 'पिछले 7 दिनों का रिकॉर्ड', 'Last 7 days performance'),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          color: Color(0xFF0C831F),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '₹${weekTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFF0C831F),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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

