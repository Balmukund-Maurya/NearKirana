import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'analytics_models.dart';
import 'analytics_service.dart';
import 'app_theme.dart';
import 'shop_provider.dart';
import 'widgets/admin_top_header.dart';
import 'widgets/add_expense_dialog.dart';
import 'utils/snackbar_helper.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> with SingleTickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();
  final NumberFormat _currencyFormat = NumberFormat('#,##,###.##');

  late TabController _tabController;
  AnalyticsTimePeriod _selectedPeriod = AnalyticsTimePeriod.thisMonth;
  bool _isLoading = true;
  AdvancedAnalyticsSummary? _summary;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    if (shopId == null || shopId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No active shop selected. Please select a shop first.';
        });
      }
      return;
    }

    try {
      final summary = await _analyticsService.fetchAnalyticsSummary(
        shopId: shopId,
        period: _selectedPeriod,
      );

      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load analytics: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onPeriodChanged(AnalyticsTimePeriod period) {
    if (_selectedPeriod == period) return;
    setState(() {
      _selectedPeriod = period;
    });
    _loadAnalytics();
  }

  Future<void> _openAddExpense() async {
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    if (shopId == null) return;

    final added = await AddExpenseDialog.show(context, shopId: shopId);
    if (added == true) {
      _loadAnalytics();
    }
  }

  Future<void> _deleteExpense(ShopExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Delete "${expense.title}" of ₹${expense.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _analyticsService.deleteExpense(expense.id);
        if (mounted) {
          SnackbarHelper.showSnackBar(context, 'Expense deleted successfully');
          _loadAnalytics();
        }
      } catch (e) {
        if (mounted) {
          SnackbarHelper.showSnackBar(context, 'Error deleting expense: $e', isError: true);
        }
      }
    }
  }

  Future<void> _showUpdateCostDialog(ProductMarginMetric product) async {
    final costController = TextEditingController(
      text: product.isPurchaseCostEstimated ? '' : product.unitPurchaseCost.toStringAsFixed(2),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update Purchase Cost', style: AppTextStyles.heading2(color: AppColors.textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.productName, style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(
              'Selling Price: ₹${product.unitSellingPrice.toStringAsFixed(2)}',
              style: AppTextStyles.bodyMedium(color: AppColors.textMid),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Unit Purchase Cost (₹) *',
                hintText: 'e.g. 210.00',
                prefixText: '₹ ',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accurate purchase costs guarantee precise gross and net profit figures.',
              style: AppTextStyles.captionMedium(color: AppColors.textMid),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newCost = double.tryParse(costController.text.trim());
              if (newCost == null || newCost <= 0) {
                SnackbarHelper.showSnackBar(ctx, 'Enter a valid cost > 0', isError: true);
                return;
              }
              Navigator.pop(ctx, true);
              try {
                await _analyticsService.updateProductPurchasePrice(
                  productId: product.productId,
                  purchasePrice: newCost,
                );
                if (mounted) {
                  SnackbarHelper.showSnackBar(context, 'Purchase cost updated!');
                  _loadAnalytics();
                }
              } catch (e) {
                if (mounted) {
                  SnackbarHelper.showSnackBar(context, 'Error updating cost: $e', isError: true);
                }
              }
            },
            child: const Text('Save Cost'),
          ),
        ],
      ),
    );

    costController.dispose();
    if (saved == true) _loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Sales & Profit Analytics',
                style: AppTextStyles.heading2(color: AppColors.textDark),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primaryDark),
                  tooltip: 'Refresh Analytics',
                  onPressed: _loadAnalytics,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          if (!canPop) const AdminTopHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primaryDark),
                        SizedBox(height: 16),
                        Text('Calculating sales, COGS & margins...'),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadAnalytics,
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildDashboardContent(isDesktop),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(bool isDesktop) {
    final summary = _summary ?? AdvancedAnalyticsSummary.empty(period: _selectedPeriod);

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header with Timeframe selectors
            _buildPageHeader(isDesktop),
            const SizedBox(height: 16),

            // Low-margin or Missing purchase prices alert banner
            if (summary.productsMissingPurchasePrice > 0)
              _buildMissingCostWarningBanner(summary),

            if (summary.lowMarginProducts.isNotEmpty)
              _buildLowMarginAlertBanner(summary),

            const SizedBox(height: 16),

            // Executive KPI Cards (Revenue, Gross Profit, Expenses, Net Profit, Orders, AOV)
            _buildExecutiveKpiSection(summary, isDesktop),
            const SizedBox(height: 24),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgTint),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: AppColors.textMid,
                indicatorColor: AppColors.primaryDark,
                indicatorWeight: 3,
                isScrollable: !isDesktop,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.trending_up, size: 20),
                    text: 'Overview & Trends',
                  ),
                  const Tab(
                    icon: Icon(Icons.pie_chart_outline, size: 20),
                    text: 'Profit & Margins',
                  ),
                  Tab(
                    icon: const Icon(Icons.warning_amber_rounded, size: 20),
                    text: 'Best Sellers & Alerts (${summary.lowMarginProducts.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                    text: 'Expenses Ledger (${summary.expenses.length})',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Views Content
            SizedBox(
              height: isDesktop ? 620 : 750,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTrendsTab(summary, isDesktop),
                  _buildProfitMarginsTab(summary, isDesktop),
                  _buildBestSellersAlertsTab(summary, isDesktop),
                  _buildExpensesLedgerTab(summary, isDesktop),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales & Profit Analytics',
                    style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(
                      fontSize: isDesktop ? 26 : 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analyze actual business performance, cost of goods sold (COGS) & store net profit',
                    style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(
                      fontSize: isDesktop ? 14 : 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _openAddExpense,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Add Store Expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        // Time Period Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTimeChip(AnalyticsTimePeriod.today),
              const SizedBox(width: 8),
              _buildTimeChip(AnalyticsTimePeriod.thisWeek),
              const SizedBox(width: 8),
              _buildTimeChip(AnalyticsTimePeriod.thisMonth),
              const SizedBox(width: 8),
              _buildTimeChip(AnalyticsTimePeriod.last30Days),
              const SizedBox(width: 8),
              _buildTimeChip(AnalyticsTimePeriod.allTime),
              if (!isDesktop) ...[
                const SizedBox(width: 12),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
                  backgroundColor: AppColors.primaryDark,
                  onPressed: _openAddExpense,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeChip(AnalyticsTimePeriod period) {
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(period.displayName),
      selected: isSelected,
      onSelected: (_) => _onPeriodChanged(period),
      selectedColor: AppColors.primaryDark,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textDark,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primaryDark : AppColors.bgTint,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildMissingCostWarningBanner(AdvancedAnalyticsSummary summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade800, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${summary.productsMissingPurchasePrice} sold items have no purchase cost recorded. An estimated fallback (15% margin) was used. Add purchase prices for 100% accurate profit.',
              style: TextStyle(
                color: Colors.blue.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowMarginAlertBanner(AdvancedAnalyticsSummary summary) {
    final count = summary.lowMarginProducts.length;
    final topLow = summary.lowMarginProducts.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                children: [
                  TextSpan(
                    text: 'Low Margin Alert: ',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange.shade900),
                  ),
                  TextSpan(
                    text: '$count products are selling fast with slim margins (< 8%), e.g., "${topLow.productName}" has only ${topLow.marginPercent.toStringAsFixed(1)}% margin. Consider raising selling prices or negotiating supplier rates.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              _tabController.animateTo(2); // Switch to Best Sellers & Alerts tab
            },
            child: const Text('View Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveKpiSection(AdvancedAnalyticsSummary summary, bool isDesktop) {
    final cards = [
      _buildExecutiveKpiCard(
        title: 'Total Revenue',
        value: '₹${_currencyFormat.format(summary.totalRevenue)}',
        badge: '${summary.deliveredOrders} delivered',
        badgeColor: Colors.blue,
        icon: Icons.currency_rupee,
        subtitle: 'From ${summary.totalOrders} total orders',
      ),
      _buildExecutiveKpiCard(
        title: 'Gross Profit',
        value: '₹${_currencyFormat.format(summary.grossProfit)}',
        badge: '${summary.grossMarginPercent.toStringAsFixed(1)}% margin',
        badgeColor: summary.grossMarginPercent >= 15 ? Colors.green : Colors.orange,
        icon: Icons.bar_chart,
        subtitle: 'Revenue minus COGS (₹${_currencyFormat.format(summary.totalCOGS)})',
      ),
      _buildExecutiveKpiCard(
        title: 'Store Expenses',
        value: '₹${_currencyFormat.format(summary.totalExpenses)}',
        badge: '${summary.expenses.length} records',
        badgeColor: Colors.purple,
        icon: Icons.receipt_long_outlined,
        subtitle: 'Operating costs deducted',
      ),
      _buildExecutiveKpiCard(
        title: 'Net Profit',
        value: '₹${_currencyFormat.format(summary.netProfit)}',
        badge: '${summary.netMarginPercent.toStringAsFixed(1)}% net',
        badgeColor: summary.netProfit >= 0 ? Colors.teal : Colors.red,
        icon: Icons.account_balance_wallet_outlined,
        subtitle: 'Gross profit minus expenses',
      ),
      _buildExecutiveKpiCard(
        title: 'Total Orders',
        value: '${summary.totalOrders}',
        badge: '${summary.deliveredOrders} done',
        badgeColor: Colors.indigo,
        icon: Icons.shopping_bag_outlined,
        subtitle: '${summary.processingOrders} active | ${summary.cancelledOrders} cancelled',
      ),
      _buildExecutiveKpiCard(
        title: 'Avg Order Value',
        value: '₹${_currencyFormat.format(summary.averageOrderValue)}',
        badge: 'AOV',
        badgeColor: Colors.brown,
        icon: Icons.shopping_cart_outlined,
        subtitle: 'Discounts: ₹${_currencyFormat.format(summary.totalDiscounts)}',
      ),
    ];

    if (isDesktop) {
      return GridView.count(
        crossAxisCount: 6,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.15,
        children: cards,
      );
    } else {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.35,
        children: cards,
      );
    }
  }

  Widget _buildExecutiveKpiCard({
    required String title,
    required String value,
    required String badge,
    required MaterialColor badgeColor,
    required IconData icon,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgTint),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: badgeColor.shade700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeColor.shade800,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppColors.textMid, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppColors.textLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: OVERVIEW & TRENDS
  // ==========================================
  Widget _buildOverviewTrendsTab(AdvancedAnalyticsSummary summary, bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: _buildDailySalesChartCard(summary)),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: _buildProfitWalkthroughCard(summary)),
        ],
      );
    } else {
      return ListView(
        children: [
          _buildDailySalesChartCard(summary),
          const SizedBox(height: 16),
          _buildProfitWalkthroughCard(summary),
        ],
      );
    }
  }

  Widget _buildDailySalesChartCard(AdvancedAnalyticsSummary summary) {
    final daily = summary.dailyTrends;
    final double maxRevenue = daily.fold(0.0, (m, d) => d.revenue > m ? d.revenue : m);
    final double maxY = maxRevenue > 0 ? (maxRevenue * 1.2) : 1000.0;

    return _buildCardWrapper(
      title: 'Daily Sales & Profit Trend',
      subtitle: 'Revenue (bars) and Gross Profit (dots) across time period',
      icon: Icons.stacked_bar_chart_rounded,
      child: daily.isEmpty
          ? const Center(child: Text('No daily sales data in this period'))
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildLegendItem(Colors.green.shade400, 'Revenue'),
                    const SizedBox(width: 16),
                    _buildLegendItem(AppColors.primaryDark, 'Gross Profit'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 280,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final point = daily[group.x];
                            return BarTooltipItem(
                              '${point.label}\n'
                              'Sales: ₹${point.revenue.toStringAsFixed(0)}\n'
                              'Profit: ₹${point.grossProfit.toStringAsFixed(0)}\n'
                              'Orders: ${point.orderCount}',
                              const TextStyle(color: Colors.white, fontSize: 11),
                            );
                          },
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
                            getTitlesWidget: (v, _) => Text(
                              '₹${(v / 1000).toStringAsFixed(0)}k',
                              style: const TextStyle(fontSize: 10, color: AppColors.textMid),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (daily.length / 7).clamp(1.0, 10.0),
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx >= 0 && idx < daily.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    daily[idx].label,
                                    style: const TextStyle(fontSize: 10, color: AppColors.textMid),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: AppColors.bgTint,
                          strokeWidth: 1,
                        ),
                      ),
                      barGroups: List.generate(daily.length, (i) {
                        final pt = daily[i];
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: pt.revenue,
                              color: Colors.green.shade300,
                              width: (260 / (daily.length + 1)).clamp(4.0, 18.0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            BarChartRodData(
                              toY: pt.grossProfit.clamp(0, maxY),
                              color: AppColors.primaryDark,
                              width: (260 / (daily.length + 1)).clamp(4.0, 18.0),
                              borderRadius: BorderRadius.circular(4),
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMid)),
      ],
    );
  }

  Widget _buildProfitWalkthroughCard(AdvancedAnalyticsSummary summary) {
    return _buildCardWrapper(
      title: 'P&L Waterfall Breakdown',
      subtitle: 'Step-by-step walk from gross revenue to net pocket profit',
      icon: Icons.account_balance_rounded,
      child: Column(
        children: [
          _buildWaterfallRow(
            label: 'Gross Sales / Revenue',
            amount: summary.totalRevenue,
            isPositive: true,
            icon: Icons.add_circle_outline,
            iconColor: Colors.blue,
            subtitle: 'From delivered and confirmed orders',
          ),
          const Divider(height: 20, color: AppColors.bgTint),
          _buildWaterfallRow(
            label: 'Cost of Goods Sold (COGS)',
            amount: summary.totalCOGS,
            isPositive: false,
            icon: Icons.remove_circle_outline,
            iconColor: Colors.orange,
            subtitle: 'Purchase costs paid to suppliers/wholesalers',
          ),
          const Divider(height: 20, color: AppColors.bgTint),
          _buildWaterfallRow(
            label: 'Gross Profit',
            amount: summary.grossProfit,
            isPositive: summary.grossProfit >= 0,
            icon: Icons.check_circle_outline,
            iconColor: Colors.green,
            subtitle: 'Gross Margin: ${summary.grossMarginPercent.toStringAsFixed(1)}%',
            isHighlight: true,
          ),
          const Divider(height: 20, color: AppColors.bgTint),
          _buildWaterfallRow(
            label: 'Operating & Store Expenses',
            amount: summary.totalExpenses,
            isPositive: false,
            icon: Icons.remove_circle_outline,
            iconColor: Colors.purple,
            subtitle: 'Rent, electricity, packaging, wages, etc.',
          ),
          const Divider(height: 20, color: AppColors.bgTint),
          _buildWaterfallRow(
            label: 'Net Profit (In Hand)',
            amount: summary.netProfit,
            isPositive: summary.netProfit >= 0,
            icon: Icons.savings_outlined,
            iconColor: summary.netProfit >= 0 ? Colors.teal : Colors.red,
            subtitle: 'Net Margin: ${summary.netMarginPercent.toStringAsFixed(1)}%',
            isHighlight: true,
            isFinal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWaterfallRow({
    required String label,
    required double amount,
    required bool isPositive,
    required IconData icon,
    required Color iconColor,
    required String subtitle,
    bool isHighlight = false,
    bool isFinal = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isFinal ? 14 : (isHighlight ? 13 : 12),
                  fontWeight: (isHighlight || isFinal) ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
            ],
          ),
        ),
        Text(
          '${isPositive ? "" : "-"}₹${_currencyFormat.format(amount)}',
          style: TextStyle(
            fontSize: isFinal ? 16 : 14,
            fontWeight: FontWeight.w800,
            color: isFinal
                ? (amount >= 0 ? Colors.teal.shade800 : Colors.red.shade800)
                : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: PROFIT & MARGINS BY CATEGORY
  // ==========================================
  Widget _buildProfitMarginsTab(AdvancedAnalyticsSummary summary, bool isDesktop) {
    final categories = summary.categoryMetrics;

    return _buildCardWrapper(
      title: 'Category Margin Performance',
      subtitle: 'Compare profitability, sales, and margin percentages across product categories',
      icon: Icons.category_rounded,
      child: categories.isEmpty
          ? const Center(child: Text('No categorized sales data available yet'))
          : ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (_, _) => const Divider(height: 24, color: AppColors.bgTint),
              itemBuilder: (ctx, index) {
                final cat = categories[index];
                final isLow = cat.isLowMargin;
                final isHealthy = cat.marginPercent >= 18;

                Color barColor = isLow ? Colors.orange : (isHealthy ? Colors.green : Colors.blue);

                return Column(
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
                                color: barColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.inventory_2_outlined, size: 16, color: barColor),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              cat.categoryName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (isLow) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Low Margin <8%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${_currencyFormat.format(cat.grossProfit)} profit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: barColor,
                              ),
                            ),
                            Text(
                              '${cat.marginPercent.toStringAsFixed(1)}% margin',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMid),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (cat.marginPercent / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Revenue: ₹${_currencyFormat.format(cat.totalRevenue)} (${cat.itemsSoldCount.toStringAsFixed(0)} items sold)',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMid),
                        ),
                        Text(
                          'COGS: ₹${_currencyFormat.format(cat.totalCOGS)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMid),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ==========================================
  // TAB 3: BEST SELLERS & LOW MARGIN ALERTS
  // ==========================================
  Widget _buildBestSellersAlertsTab(AdvancedAnalyticsSummary summary, bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildBestSellersCard(summary)),
          const SizedBox(width: 16),
          Expanded(child: _buildLowMarginAlertsCard(summary)),
        ],
      );
    } else {
      return ListView(
        children: [
          _buildLowMarginAlertsCard(summary),
          const SizedBox(height: 16),
          _buildBestSellersCard(summary),
        ],
      );
    }
  }

  Widget _buildBestSellersCard(AdvancedAnalyticsSummary summary) {
    final top = summary.topProducts;

    return _buildCardWrapper(
      title: 'Top Performing Products',
      subtitle: 'Ranked by total revenue and units sold',
      icon: Icons.star_border_rounded,
      child: top.isEmpty
          ? const Center(child: Text('No product sales recorded yet'))
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: top.length > 8 ? 8 : top.length,
              separatorBuilder: (_, _) => const Divider(height: 16, color: AppColors.bgTint),
              itemBuilder: (ctx, idx) {
                final p = top[idx];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: idx < 3 ? Colors.amber.shade100 : Colors.grey.shade100,
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: idx < 3 ? Colors.orange.shade900 : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.productName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${p.unitsSold.toStringAsFixed(0)} sold • ₹${p.unitSellingPrice.toStringAsFixed(0)}/ea',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMid),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${_currencyFormat.format(p.totalRevenue)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${p.marginPercent.toStringAsFixed(1)}% margin',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: p.isLowMargin ? Colors.orange : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildLowMarginAlertsCard(AdvancedAnalyticsSummary summary) {
    final low = summary.lowMarginProducts;

    return _buildCardWrapper(
      title: 'Low Margin Watchlist (< 8%)',
      subtitle: 'High sales volume with slim margins — update cost or adjust price',
      icon: Icons.warning_amber_rounded,
      child: low.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_outlined, size: 40, color: Colors.green.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      'All sold products have healthy margins (>8%)!',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: low.length,
              separatorBuilder: (_, _) => const Divider(height: 16, color: AppColors.bgTint),
              itemBuilder: (ctx, idx) {
                final p = low[idx];
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.trending_down, size: 16, color: Colors.red),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.productName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Sell: ₹${p.unitSellingPrice.toStringAsFixed(1)} | Cost: ₹${p.unitPurchaseCost.toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMid),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${p.marginPercent.toStringAsFixed(1)}% margin',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showUpdateCostDialog(p),
                          child: const Text('Edit Cost', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ==========================================
  // TAB 4: STORE EXPENSES LEDGER
  // ==========================================
  Widget _buildExpensesLedgerTab(AdvancedAnalyticsSummary summary, bool isDesktop) {
    final expenses = summary.expenses;

    return _buildCardWrapper(
      title: 'Store Operating Expenses Ledger',
      subtitle: 'Recorded rent, electricity bills, staff wages, and logistics costs',
      icon: Icons.receipt_long_rounded,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Expenses: ₹${_currencyFormat.format(summary.totalExpenses)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              ElevatedButton.icon(
                onPressed: _openAddExpense,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: expenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text(
                          'No operating expenses recorded for this timeframe.',
                          style: TextStyle(color: AppColors.textMid),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _openAddExpense,
                          child: const Text('Record First Expense'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: expenses.length,
                    separatorBuilder: (_, _) => const Divider(height: 16, color: AppColors.bgTint),
                    itemBuilder: (ctx, idx) {
                      final exp = expenses[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.receipt_long, color: Colors.purple.shade700, size: 20),
                        ),
                        title: Text(
                          exp.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${exp.category} • ${DateFormat('dd MMM yyyy').format(exp.date)}'
                          '${exp.notes != null ? " • ${exp.notes}" : ""}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹${_currencyFormat.format(exp.amount)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.redAccent,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              onPressed: () => _deleteExpense(exp),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWrapper({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgTint),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.captionMedium(color: AppColors.textMid),
          ),
          const Divider(height: 24, color: AppColors.bgTint),
          Expanded(child: child),
        ],
      ),
    );
  }
}
