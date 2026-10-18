import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../shop_provider.dart';
import '../language_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import '../modern_loader.dart';

/// Horizontal scrollable analytics carousel displaying:
/// 1. Revenue Trends (Weekly sales line graph)
/// 2. Order Volume Graph (Daily orders count)
/// 3. Fulfillment Split (Delivery vs Store Pickup)
/// 4. Peak Rush Hours (Order distribution across morning, afternoon, evening, night)
class HomeAnalyticsChartsCarousel extends StatefulWidget {
  final bool isDesktop;
  const HomeAnalyticsChartsCarousel({super.key, this.isDesktop = false});

  @override
  State<HomeAnalyticsChartsCarousel> createState() =>
      _HomeAnalyticsChartsCarouselState();
}

class _HomeAnalyticsChartsCarouselState
    extends State<HomeAnalyticsChartsCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOf7DaysAgo = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
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
          return Container(
            height: 290,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: ModernLoader(color: Color(0xFF0C831F)),
            ),
          );
        }

        // 1. Data Aggregation
        final Map<int, double> dailyRevenue = {for (int i = 0; i < 7; i++) i: 0.0};
        final Map<int, int> dailyOrderCounts = {for (int i = 0; i < 7; i++) i: 0};
        int deliveryCount = 0;
        int pickupCount = 0;

        // Peak Rush: Morning (6-11), Afternoon (11-16), Evening (16-21), Night (21-24 & 0-6)
        int morningOrders = 0;
        int afternoonOrders = 0;
        int eveningOrders = 0;
        int nightOrders = 0;

        double weekTotalRevenue = 0.0;
        int totalOrdersCount = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();

          if (status == 'Cancelled' || status == 'Rejected') continue;

          totalOrdersCount++;
          final deliveryType =
              (data['delivery_type'] ?? data['type'] ?? '').toString().toLowerCase();
          if (deliveryType.contains('pickup')) {
            pickupCount++;
          } else {
            deliveryCount++;
          }

          final createdAt = data['created_at'] as Timestamp?;
          if (createdAt != null) {
            final date = createdAt.toDate();
            final diff = date.difference(startOf7DaysAgo).inDays;
            if (diff >= 0 && diff < 7) {
              final amount =
                  double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0.0;
              if (['Packed', 'Ready', 'Out for Delivery', 'Delivered']
                  .contains(status)) {
                dailyRevenue[diff] = (dailyRevenue[diff] ?? 0.0) + amount;
                weekTotalRevenue += amount;
              }
              dailyOrderCounts[diff] = (dailyOrderCounts[diff] ?? 0) + 1;
            }

            final hour = date.hour;
            if (hour >= 6 && hour < 11) {
              morningOrders++;
            } else if (hour >= 11 && hour < 16) {
              afternoonOrders++;
            } else if (hour >= 16 && hour < 21) {
              eveningOrders++;
            } else {
              nightOrders++;
            }
          }
        }

        final tabTitles = [
          t('Revenue', 'कमाई', 'Revenue'),
          t('Orders', 'ऑर्डर्स', 'Orders'),
          t('Delivery / Pickup', 'डिलीवरी / पिकअप', 'Delivery / Pickup'),
          t('Rush Hours', 'पीक समय', 'Rush Hours'),
        ];

        return Container(
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
              // Top Tab Navigation Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(4, (index) {
                      final isSelected = _currentPage == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0C831F)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tabTitles[index],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Horizontal Scroll PageView for Charts
              SizedBox(
                height: 250,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  children: [
                    // Chart 1: Revenue Line Chart
                    _buildRevenueChart(
                      context: context,
                      t: t,
                      dailyRevenue: dailyRevenue,
                      weekTotalRevenue: weekTotalRevenue,
                      startOf7DaysAgo: startOf7DaysAgo,
                      getDayName: getDayName,
                    ),

                    // Chart 2: Order Counts Bar Chart
                    _buildOrderCountsChart(
                      context: context,
                      t: t,
                      dailyOrderCounts: dailyOrderCounts,
                      totalOrdersCount: totalOrdersCount,
                      startOf7DaysAgo: startOf7DaysAgo,
                      getDayName: getDayName,
                    ),

                    // Chart 3: Delivery vs Store Pickup Distribution
                    _buildFulfillmentChart(
                      context: context,
                      t: t,
                      deliveryCount: deliveryCount,
                      pickupCount: pickupCount,
                      totalOrdersCount: totalOrdersCount,
                    ),

                    // Chart 4: Peak Rush Hours
                    _buildPeakRushHoursChart(
                      context: context,
                      t: t,
                      morning: morningOrders,
                      afternoon: afternoonOrders,
                      evening: eveningOrders,
                      night: nightOrders,
                    ),
                  ],
                ),
              ),

              // Bottom Carousel Dots Indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isSelected = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 5,
                      width: isSelected ? 18 : 6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0C831F)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 1. Weekly Revenue Trend Line Chart
  Widget _buildRevenueChart({
    required BuildContext context,
    required String Function(String, String, String) t,
    required Map<int, double> dailyRevenue,
    required double weekTotalRevenue,
    required DateTime startOf7DaysAgo,
    required String Function(DateTime) getDayName,
  }) {
    double maxRevenue = 0;
    for (var val in dailyRevenue.values) {
      if (val > maxRevenue) maxRevenue = val;
    }
    if (maxRevenue == 0) maxRevenue = 1000;

    final List<FlSpot> spots = [];
    for (int i = 0; i < 7; i++) {
      spots.add(FlSpot(i.toDouble(), dailyRevenue[i] ?? 0.0));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.show_chart_rounded,
                        color: Color(0xFF0C831F), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Weekly Revenue Trend', 'साप्ताहिक कमाई ट्रेंड', 'Weekly Revenue Trend'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        t('Last 7 days total sales', 'पिछले 7 दिनों की कुल बिक्री', 'Last 7 days total sales'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up_rounded,
                        color: Color(0xFF0C831F), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '₹${weekTotalRevenue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0C831F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      maxRevenue <= 0 ? 250 : (maxRevenue / 3).clamp(50, 100000),
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFFF1F5F9),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        String label = value >= 1000
                            ? '₹${(value / 1000).toStringAsFixed(1)}k'
                            : '₹${value.toInt()}';
                        return Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= 7) return const SizedBox.shrink();
                        DateTime date =
                            startOf7DaysAgo.add(Duration(days: index));
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            getDayName(date),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
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
                maxY: maxRevenue * 1.25,
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF0F172A),
                    tooltipBorderRadius: BorderRadius.circular(8),
                    tooltipPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '₹${spot.y.toStringAsFixed(0)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
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
                    color: const Color(0xFF0C831F),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3.5,
                          color: Colors.white,
                          strokeWidth: 2,
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
          ),
        ],
      ),
    );
  }

  // 2. Order Volume Graph (Daily orders count Bar Chart)
  Widget _buildOrderCountsChart({
    required BuildContext context,
    required String Function(String, String, String) t,
    required Map<int, int> dailyOrderCounts,
    required int totalOrdersCount,
    required DateTime startOf7DaysAgo,
    required String Function(DateTime) getDayName,
  }) {
    int maxOrders = 0;
    for (var count in dailyOrderCounts.values) {
      if (count > maxOrders) maxOrders = count;
    }
    if (maxOrders == 0) maxOrders = 10;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Daily Order Volume', 'दैनिक ऑर्डर्स संख्या', 'Daily Order Volume'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        t('Number of orders processed', 'रोजाना प्रोसेस किए गए ऑर्डर्स', 'Orders processed per day'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag_outlined,
                        color: Color(0xFF2563EB), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$totalOrdersCount ${t('Orders', 'ऑर्डर्स', 'Orders')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxOrders * 1.3,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF0F172A),
                    tooltipBorderRadius: BorderRadius.circular(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()} ${t('orders', 'ऑर्डर्स', 'orders')}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        if (value % 2 != 0 && value != 0) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= 7) return const SizedBox.shrink();
                        DateTime date =
                            startOf7DaysAgo.add(Duration(days: index));
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            getDayName(date),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => const FlLine(
                    color: Color(0xFFF1F5F9),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final count = (dailyOrderCounts[i] ?? 0).toDouble();
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: count,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Fulfillment Split (Delivery vs Store Pickup)
  Widget _buildFulfillmentChart({
    required BuildContext context,
    required String Function(String, String, String) t,
    required int deliveryCount,
    required int pickupCount,
    required int totalOrdersCount,
  }) {
    final double deliveryPercent = totalOrdersCount > 0
        ? ((deliveryCount / totalOrdersCount) * 100)
        : 50.0;
    final double pickupPercent = totalOrdersCount > 0
        ? ((pickupCount / totalOrdersCount) * 100)
        : 50.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    color: Color(0xFF7C3AED), size: 18),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Fulfillment Split', 'फुलफिलमेंट प्रकार', 'Fulfillment Split'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    t('Doorstep Delivery vs Store Pickup', 'होम डिलीवरी बनाम दुकान पिकअप', 'Delivery vs Store Pickup'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Two metric tiles side-by-side
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.two_wheeler_rounded,
                              size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Text(
                            t('Home Delivery', 'होम डिलीवरी', 'Home Delivery'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$deliveryCount ${t('orders', 'ऑर्डर्स', 'orders')}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      Text(
                        '${deliveryPercent.toStringAsFixed(1)}% ${t('of total', 'कुल का', 'of total')}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded,
                              size: 16, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 6),
                          Text(
                            t('Store Pickup', 'दुकान पिकअप', 'Store Pickup'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B21A8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$pickupCount ${t('orders', 'ऑर्डर्स', 'orders')}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF581C87),
                        ),
                      ),
                      Text(
                        '${pickupPercent.toStringAsFixed(1)}% ${t('of total', 'कुल का', 'of total')}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9333EA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Visual Progress Proportion Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Flexible(
                    flex: (deliveryPercent * 10).toInt().clamp(1, 1000),
                    child: Container(color: const Color(0xFF2563EB)),
                  ),
                  Flexible(
                    flex: (pickupPercent * 10).toInt().clamp(1, 1000),
                    child: Container(color: const Color(0xFF7C3AED)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Peak Rush Hours Distribution
  Widget _buildPeakRushHoursChart({
    required BuildContext context,
    required String Function(String, String, String) t,
    required int morning,
    required int afternoon,
    required int evening,
    required int night,
  }) {
    final int maxVal = [morning, afternoon, evening, night]
        .reduce((a, b) => a > b ? a : b);
    final double safeMax = maxVal == 0 ? 1.0 : maxVal.toDouble();

    final timeSlots = [
      {
        'label': t('Morning', 'सुबह', 'Morning'),
        'sub': '6 AM - 11 AM',
        'count': morning,
        'color': const Color(0xFFD97706),
        'icon': Icons.wb_sunny_rounded,
      },
      {
        'label': t('Afternoon', 'दोपहर', 'Afternoon'),
        'sub': '11 AM - 4 PM',
        'count': afternoon,
        'color': const Color(0xFF0C831F),
        'icon': Icons.light_mode_rounded,
      },
      {
        'label': t('Evening', 'शाम', 'Evening'),
        'sub': '4 PM - 9 PM',
        'count': evening,
        'color': const Color(0xFF2563EB),
        'icon': Icons.nights_stay_rounded,
      },
      {
        'label': t('Night', 'रात', 'Night'),
        'sub': '9 PM - 12 AM',
        'count': night,
        'color': const Color(0xFF475569),
        'icon': Icons.bedtime_rounded,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.access_time_rounded,
                        color: Color(0xFFD97706), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Peak Rush Hours', 'ऑर्डर का पीक समय', 'Peak Rush Hours'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        t('Rush distribution across time of day', 'दिन के समय अनुसार ग्राहकों की भीड़', 'Time of day order rush'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: Color(0xFFD97706), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      t('Live Heat', 'लाइव भीड़', 'Live Rush'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: timeSlots.map((slot) {
                final count = slot['count'] as int;
                final color = slot['color'] as Color;
                final icon = slot['icon'] as IconData;
                final label = slot['label'] as String;
                final sub = slot['sub'] as String;
                final double progress = (count / safeMax).clamp(0.05, 1.0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Icon(icon, size: 15, color: color),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 90,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              sub,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 10,
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
