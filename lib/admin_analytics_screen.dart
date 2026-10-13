import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  bool _isLoading = true;

  double _totalRevenue = 0.0;
  int _totalOrders = 0;
  int _totalCustomers = 0;
  double _totalUdhaar = 0.0;
  double _discountGiven = 0.0;
  double _avgOrderValue = 0.0;

  Map<int, double> _salesByDay = {};
  Map<int, int> _ordersByDay = {};
  
  int _deliveredCount = 0;
  int _processingCount = 0;
  int _outForDeliveryCount = 0;
  int _cancelledCount = 0;
  int _returnedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    if (shopId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Fetch customers
      final custSnap = await FirebaseUtils.firestore
          .collection('customers')
          .where('shop_ids', arrayContains: shopId)
          .get();
      
      double udhaar = 0;
      for (var doc in custSnap.docs) {
        final data = doc.data();
        udhaar += ((data['shop_balances'] as Map?)?[shopId] ?? 0).toDouble();
      }

      // Fetch orders (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final ordersSnap = await FirebaseUtils.firestore
          .collection('orders')
          .where('shop_id', isEqualTo: shopId)
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      double rev = 0;
      int orders = ordersSnap.docs.length;
      double discount = 0;
      
      Map<int, double> sByDay = {};
      Map<int, int> oByDay = {};
      
      int delivered = 0;
      int processing = 0;
      int outForDelivery = 0;
      int cancelled = 0;
      int returned = 0;

      for (var doc in ordersSnap.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        
        if (status == 'Delivered') delivered++;
        else if (status == 'Cancelled') cancelled++;
        else if (status == 'Out for Delivery') outForDelivery++;
        else if (status == 'Returned') returned++;
        else processing++; // Pending, Packed, etc

        if (['Delivered', 'Completed', 'Packed', 'Ready', 'Out for Delivery'].contains(status)) {
          final amt = (data['total_amount'] as num?)?.toDouble() ?? 0;
          rev += amt;
          discount += (data['discount_amount'] as num?)?.toDouble() ?? 0;
          
          if (data['created_at'] != null) {
            final date = (data['created_at'] as Timestamp).toDate();
            final day = date.day;
            sByDay[day] = (sByDay[day] ?? 0) + amt;
            oByDay[day] = (oByDay[day] ?? 0) + 1;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalCustomers = custSnap.docs.length;
          _totalUdhaar = udhaar;
          _totalOrders = orders;
          _totalRevenue = rev;
          _discountGiven = discount;
          _avgOrderValue = orders > 0 ? rev / orders : 0;
          _salesByDay = sByDay;
          _ordersByDay = oByDay;
          
          _deliveredCount = delivered;
          _processingCount = processing;
          _outForDeliveryCount = outForDelivery;
          _cancelledCount = cancelled;
          _returnedCount = returned;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          const AdminTopHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPageHeader(),
                        const SizedBox(height: 24),
                        _buildKpiRow(),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: _buildSalesOverview()),
                            const SizedBox(width: 24),
                            Expanded(flex: 3, child: _buildOrdersOverview()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildCategoryPerformance()),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: _buildTopProducts()),
                            const SizedBox(width: 24),
                            Expanded(flex: 3, child: _buildCustomerInsights()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 4, child: _buildRevenueTrend()),
                            const SizedBox(width: 24),
                            Expanded(flex: 3, child: _buildOrderTimeAnalysis()),
                            const SizedBox(width: 24),
                            Expanded(flex: 3, child: _buildQuickInsights()),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Track sales, orders, customers and business performance', style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 14)),
          ],
        ),
        Row(
          children: [
            _buildDropdown('This Month', Icons.calendar_today_outlined),
            const SizedBox(width: 16),
            _buildDropdown('All Shops', Icons.store_outlined),
          ],
        )
      ],
    );
  }

  Widget _buildDropdown(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMid),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 13)),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMid),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    return Row(
      children: [
        Expanded(child: _buildKpiCard('Total Revenue', '₹${NumberFormat('#,##,###').format(_totalRevenue)}', '+12.5%', Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildKpiCard('Total Orders', '$_totalOrders', '+8.2%', Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildKpiCard('Total Customers', '$_totalCustomers', '+15.3%', Colors.purple)),
        const SizedBox(width: 16),
        Expanded(child: _buildKpiCard('Total Udhaar', '₹${NumberFormat('#,##,###').format(_totalUdhaar)}', '+6.1%', Colors.orange)),
        const SizedBox(width: 16),
        Expanded(child: _buildKpiCard('Discount Given', '₹${NumberFormat('#,##,###').format(_discountGiven)}', '-3.4%', Colors.red)),
        const SizedBox(width: 16),
        Expanded(child: _buildKpiCard('Avg. Order Value', '₹${NumberFormat('#,##,###.##').format(_avgOrderValue)}', '+4.8%', Colors.teal)),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String trend, MaterialColor color) {
    bool isPositive = !trend.startsWith('-');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.shade50.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.analytics, color: color.shade700, size: 20),
              Text(title, style: TextStyle(color: color.shade900, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: color.shade900, fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: isPositive ? Colors.green : Colors.red, size: 12),
              const SizedBox(width: 4),
              Text(trend, style: TextStyle(color: isPositive ? Colors.green : Colors.red, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(width: 4),
              Expanded(
                child: Text('vs previous period', style: const TextStyle(color: AppColors.textLight, fontSize: 10), overflow: TextOverflow.ellipsis),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSalesOverview() {
    return _buildCardBase(
      title: 'Sales Overview',
      subtitle: 'Daily sales and order trend',
      icon: Icons.bar_chart,
      child: SizedBox(
        height: 250,
        child: Stack(
          children: [
            BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 10,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 5, getTitlesWidget: (v, m) => Text('${v.toInt()} Aug', style: const TextStyle(fontSize: 10, color: AppColors.textMid)))),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 2, getTitlesWidget: (v, m) => Text('${v.toInt()}K', style: const TextStyle(fontSize: 10, color: AppColors.textMid)))),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.bgTint, strokeWidth: 1)),
                barGroups: List.generate(31, (i) => BarChartGroupData(x: i + 1, barRods: [BarChartRodData(toY: (i % 5) + 2.0, color: Colors.green.shade200, width: 8, borderRadius: BorderRadius.circular(2))])),
              ),
            ),
            LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(31, (i) => FlSpot((i + 1).toDouble(), (i % 7) + 3.0)),
                    isCurved: true,
                    color: Colors.green.shade700,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true, getDotPainter: (s, p, d, i) => FlDotCirclePainter(radius: 3, color: Colors.green.shade700, strokeWidth: 1, strokeColor: Colors.white)),
                  ),
                ],
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersOverview() {
    int total = _deliveredCount + _processingCount + _outForDeliveryCount + _cancelledCount + _returnedCount;
    if (total == 0) total = 1; // prevent div by zero
    
    return _buildCardBase(
      title: 'Orders Overview',
      subtitle: 'Order status distribution',
      icon: Icons.shopping_cart_outlined,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 45,
                      sections: [
                        PieChartSectionData(color: Colors.green, value: _deliveredCount.toDouble(), title: '', radius: 15),
                        PieChartSectionData(color: Colors.blue, value: _processingCount.toDouble(), title: '', radius: 15),
                        PieChartSectionData(color: Colors.orange, value: _outForDeliveryCount.toDouble(), title: '', radius: 15),
                        PieChartSectionData(color: Colors.red, value: _cancelledCount.toDouble(), title: '', radius: 15),
                        PieChartSectionData(color: Colors.purple, value: _returnedCount.toDouble(), title: '', radius: 15),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_totalOrders', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 20)),
                      Text('Total Orders', style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 10)),
                    ],
                  )
                ],
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendRow(Colors.green, 'Delivered', _deliveredCount, '${(_deliveredCount / total * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 8),
                _buildLegendRow(Colors.blue, 'Processing', _processingCount, '${(_processingCount / total * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 8),
                _buildLegendRow(Colors.orange, 'Out for Delivery', _outForDeliveryCount, '${(_outForDeliveryCount / total * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 8),
                _buildLegendRow(Colors.red, 'Cancelled', _cancelledCount, '${(_cancelledCount / total * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 8),
                _buildLegendRow(Colors.purple, 'Returned', _returnedCount, '${(_returnedCount / total * 100).toStringAsFixed(1)}%'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label, int count, String percent) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textDark))),
        Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(width: 12),
        SizedBox(width: 35, child: Text(percent, style: const TextStyle(fontSize: 11, color: AppColors.textMid), textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildCategoryPerformance() {
    return _buildCardBase(
      title: 'Category Performance',
      subtitle: 'Top categories by revenue',
      icon: Icons.category_outlined,
      child: Column(
        children: [
          _buildCatBar('Atta, Rice & Flour', 62500, 25.2, Colors.green),
          _buildCatBar('Oil & Ghee', 48200, 19.4, Colors.orange),
          _buildCatBar('Snacks & Biscuits', 36800, 14.8, Colors.red),
          _buildCatBar('Pulses & Dals', 28400, 11.4, Colors.purple),
          _buildCatBar('Beverages', 24600, 9.9, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildCatBar(String name, double rev, double pct, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    Row(
                      children: [
                        Text('₹${NumberFormat('#,##,###').format(rev)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        const SizedBox(width: 8),
                        Text('$pct%', style: const TextStyle(fontSize: 11, color: AppColors.textMid)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: pct / 100, backgroundColor: color.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.6)), minHeight: 8),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return _buildCardBase(
      title: 'Top Products',
      subtitle: 'Best performing products',
      icon: Icons.star_border,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(30),
          1: FlexColumnWidth(1),
          2: FixedColumnWidth(50),
          3: FixedColumnWidth(80),
        },
        children: [
          const TableRow(
            children: [
              Text('#', style: TextStyle(fontSize: 11, color: AppColors.textMid, fontWeight: FontWeight.w600)),
              Text('Product', style: TextStyle(fontSize: 11, color: AppColors.textMid, fontWeight: FontWeight.w600)),
              Text('Sold', style: TextStyle(fontSize: 11, color: AppColors.textMid, fontWeight: FontWeight.w600)),
              Text('Revenue (₹)', style: TextStyle(fontSize: 11, color: AppColors.textMid, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
            ]
          ),
          TableRow(children: [const SizedBox(height: 8), const SizedBox(), const SizedBox(), const SizedBox()]),
          _buildProdRow(1, 'Aashirvaad Atta 5kg', 245, 63700),
          _buildProdRow(2, 'Fortune Sunflower Oil 1L', 189, 37800),
          _buildProdRow(3, 'Tata Tea Premium 250g', 156, 23400),
          _buildProdRow(4, 'Maggi Noodles 70g', 142, 9940),
          _buildProdRow(5, 'Surf Excel 1kg', 128, 18560),
        ],
      ),
    );
  }

  TableRow _buildProdRow(int index, String name, int sold, double rev) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('$index', style: const TextStyle(fontSize: 12, color: AppColors.textMid))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
          Container(width: 16, height: 16, color: Colors.grey.shade200, child: const Icon(Icons.image, size: 10, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark), overflow: TextOverflow.ellipsis)),
        ])),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('$sold', style: const TextStyle(fontSize: 12, color: AppColors.textDark))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('₹${NumberFormat('#,##,###').format(rev)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark), textAlign: TextAlign.right)),
      ]
    );
  }

  Widget _buildCustomerInsights() {
    return _buildCardBase(
      title: 'Customer Insights',
      subtitle: 'Customer growth and behavior',
      icon: Icons.people_outline,
      child: Column(
        children: [
          _buildInsightRow(Icons.person_outline, 'Total Customers', '856', '+15.3%'),
          const Divider(height: 24, color: AppColors.bgTint),
          _buildInsightRow(Icons.person_add_outlined, 'New Customers', '132', '+22.1%'),
          const Divider(height: 24, color: AppColors.bgTint),
          _buildInsightRow(Icons.keyboard_return, 'Returning Customers', '724', '+11.4%'),
          const Divider(height: 24, color: AppColors.bgTint),
          _buildInsightRow(Icons.loop, 'Repeat Purchase Rate', '84.6%', '+5.2%'),
        ],
      ),
    );
  }

  Widget _buildInsightRow(IconData icon, String label, String val, String trend) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMid),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textDark))),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(width: 16),
        Text(trend, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
      ],
    );
  }

  Widget _buildRevenueTrend() {
    return _buildCardBase(
      title: 'Revenue vs Discount Trend',
      subtitle: 'Compare revenue and discount given',
      icon: Icons.percent,
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(10, (i) => FlSpot(i.toDouble(), (i % 3) + 6.0)),
                isCurved: true, color: Colors.green, barWidth: 2, dotData: FlDotData(show: true, getDotPainter: (s, p, d, i) => FlDotCirclePainter(radius: 3, color: Colors.green, strokeWidth: 1, strokeColor: Colors.white)),
              ),
              LineChartBarData(
                spots: List.generate(10, (i) => FlSpot(i.toDouble(), (i % 2) + 1.0)),
                isCurved: true, color: Colors.red, barWidth: 2, dotData: FlDotData(show: true, getDotPainter: (s, p, d, i) => FlDotCirclePainter(radius: 3, color: Colors.red, strokeWidth: 1, strokeColor: Colors.white)),
              ),
            ],
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 2, getTitlesWidget: (v, m) => Text('${(v.toInt()*3)+1} Aug', style: const TextStyle(fontSize: 9, color: AppColors.textMid)))),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 2, getTitlesWidget: (v, m) => Text('${v.toInt()*5}K', style: const TextStyle(fontSize: 9, color: AppColors.textMid)), reservedSize: 30)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.bgTint, strokeWidth: 1)),
          )
        )
      )
    );
  }

  Widget _buildOrderTimeAnalysis() {
    return _buildCardBase(
      title: 'Order Time Analysis',
      subtitle: 'Orders by time of day',
      icon: Icons.access_time,
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 400,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(['6-9A', '9-12P', '12-3P', '3-6P', '6-9P', '9-12A'][v.toInt()], style: const TextStyle(fontSize: 8, color: AppColors.textMid)))),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: AppColors.textMid)), reservedSize: 25)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.bgTint, strokeWidth: 1)),
            barGroups: [
              BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 45, color: Colors.green.shade600, width: 20, borderRadius: BorderRadius.circular(2))]),
              BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 182, color: Colors.green.shade600, width: 20, borderRadius: BorderRadius.circular(2))]),
              BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 324, color: Colors.green.shade600, width: 20, borderRadius: BorderRadius.circular(2))]),
              BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 298, color: Colors.green.shade600, width: 20, borderRadius: BorderRadius.circular(2))]),
              BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 261, color: Colors.green.shade600, width: 20, borderRadius: BorderRadius.circular(2))]),
              BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 135, color: Colors.green.shade600, width: 20, borderRadius: BorderRadius.circular(2))]),
            ],
          )
        )
      )
    );
  }

  Widget _buildQuickInsights() {
    return _buildCardBase(
      title: 'Quick Insights',
      subtitle: '',
      icon: Icons.lightbulb_outline,
      child: Column(
        children: [
          _buildQuickInsightRow(Icons.trending_up, Colors.green, 'Sales are 12.5% higher than last month'),
          const SizedBox(height: 16),
          _buildQuickInsightRow(Icons.inventory_2_outlined, Colors.blue, 'Atta, Rice & Flour is your top category'),
          const SizedBox(height: 16),
          _buildQuickInsightRow(Icons.people_outline, Colors.purple, '856 total customers this month'),
          const SizedBox(height: 16),
          _buildQuickInsightRow(Icons.show_chart, Colors.orange, 'Average order value increased by 4.8%'),
        ],
      ),
    );
  }

  Widget _buildQuickInsightRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textMid))),
      ],
    );
  }

  Widget _buildCardBase({required String title, required String subtitle, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgTint),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textDark),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                    if (subtitle.isNotEmpty) Text(subtitle, style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, size: 18, color: AppColors.textMid),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
