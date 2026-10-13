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
              // Calculate days difference from 7 days ago
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
        for (var total in dailyTotals.values) {
           if (total > maxTotal) maxTotal = total;
        }
        if (maxTotal == 0) maxTotal = 1000; // default scale
        
        // Build bar groups
        List<BarChartGroupData> barGroups = [];
        for (int i = 0; i < 7; i++) {
           barGroups.add(
             BarChartGroupData(
               x: i,
               barRods: [
                 BarChartRodData(
                   toY: dailyTotals[i]!,
                   color: AppColors.primaryDark,
                   width: 16,
                   borderRadius: BorderRadius.circular(4),
                   backDrawRodData: BackgroundBarChartRodData(
                     show: true,
                     toY: maxTotal,
                     color: AppColors.primaryLight.withValues(alpha: 0.2),
                   )
                 )
               ],
             )
           );
        }

        Widget chartContent = AspectRatio(
          aspectRatio: isDesktop ? 2.0 : 1.5,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxTotal * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => AppColors.textDark,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '₹${rod.toY.toStringAsFixed(0)}',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      DateTime date = startOf7DaysAgo.add(Duration(days: value.toInt()));
                      String dayStr = DateFormat('E').format(date); // Mon, Tue...
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(dayStr, style: const TextStyle(color: AppColors.textMid, fontSize: 10)),
                      );
                    },
                    reservedSize: 28,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                         value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                         style: const TextStyle(color: AppColors.textMid, fontSize: 10)
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxTotal / 4 == 0 ? 1 : maxTotal / 4,
                getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.bgTint, strokeWidth: 1, dashArray: [5, 5]),
              ),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            )
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
              Text('Weekly Sales', style: AppTextStyles.heading2(color: AppColors.textDark)),
              const SizedBox(height: 24),
              chartContent,
            ],
          ),
        );
      }
    );
  }
}
