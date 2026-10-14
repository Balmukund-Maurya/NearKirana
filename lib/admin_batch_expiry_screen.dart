import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'batch_models.dart';
import 'batch_service.dart';
import 'shop_provider.dart';
import 'utils/snackbar_helper.dart';
import 'widgets/add_batch_dialog.dart';
import 'widgets/batch_details_dialog.dart';
import 'widgets/dispose_batch_dialog.dart';

/// Admin Screen for Expiry & Batch Tracking (Feature 55: Expiry & Batch Tracking)
class AdminBatchExpiryScreen extends StatefulWidget {
  final BatchService? service;

  const AdminBatchExpiryScreen({super.key, this.service});

  @override
  State<AdminBatchExpiryScreen> createState() => _AdminBatchExpiryScreenState();
}

class _AdminBatchExpiryScreenState extends State<AdminBatchExpiryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late BatchService _service;

  String _searchQuery = '';
  String _alertFilter = 'all'; // 'all', '7d', '15d', '30d', 'expired'
  String _batchStatusFilter = 'all'; // 'all', 'active', 'near_expiry', 'expired', 'depleted'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? BatchService();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getShopId() {
    return Provider.of<ShopProvider>(context, listen: false).currentShopId ?? '';
  }

  Future<void> _openAddBatchModal([String? initialProductId, String? initialProductName]) async {
    HapticFeedback.lightImpact();
    final shopId = _getShopId();
    if (shopId.isEmpty) {
      SnackbarHelper.showErrorSnackBar(context, 'No active shop selected');
      return;
    }

    final batch = await AddBatchDialog.show(
      context,
      shopId: shopId,
      initialProductId: initialProductId,
      initialProductName: initialProductName,
      service: _service,
    );

    if (batch != null && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopId = _getShopId();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expiry & Batch Tracking',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'एक्सपायरी और बैच ट्रैकिंग',
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add New Batch',
            icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
            onPressed: () => _openAddBatchModal(),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textMid,
          indicatorColor: AppColors.primaryDark,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Expiry Alerts'),
            Tab(icon: Icon(Icons.inventory_2_rounded), text: 'All Batches'),
            Tab(icon: Icon(Icons.delete_sweep_rounded), text: 'Waste Log'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Batch (नया बैच)', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openAddBatchModal(),
      ),
      body: shopId.isEmpty
          ? const Center(child: Text('No active shop selected'))
          : Column(
              children: [
                // KPI Header
                _buildKpiHeader(shopId),

                // Tabs View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Expiry Alerts
                      _buildExpiryAlertsTab(shopId),

                      // Tab 2: All Batches
                      _buildAllBatchesTab(shopId),

                      // Tab 3: Waste Log
                      _buildWasteLogTab(shopId),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // =========================================================================
  // 1. KPI Analytics Header
  // =========================================================================
  Widget _buildKpiHeader(String shopId) {
    return FutureBuilder<BatchAnalyticsSummary>(
      future: _service.fetchBatchAnalytics(shopId),
      builder: (context, snapshot) {
        final summary = snapshot.data ?? const BatchAnalyticsSummary();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Near Expiry (15d)',
                      value: '${summary.totalNearExpiryBatches} batches',
                      subvalue: '₹${summary.totalAtRiskCostValue.toStringAsFixed(0)} at risk',
                      icon: Icons.timer_outlined,
                      color: Colors.orange.shade800,
                      bgColor: Colors.orange.shade50,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Expired Stock',
                      value: '${summary.totalExpiredBatches} batches',
                      subvalue: '₹${summary.totalExpiredCostValue.toStringAsFixed(0)} loss',
                      icon: Icons.error_outline_rounded,
                      color: Colors.red.shade800,
                      bgColor: Colors.red.shade50,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Active Batches',
                      value: '${summary.totalActiveBatches}',
                      subvalue: '${summary.safeBatchesCount} fresh batches',
                      icon: Icons.check_circle_outline_rounded,
                      color: Colors.green.shade800,
                      bgColor: Colors.green.shade50,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Waste Written Off',
                      value: '₹${summary.totalDisposedLossValue.toStringAsFixed(0)}',
                      subvalue: '${summary.totalDisposedUnits.toStringAsFixed(0)} units recorded',
                      icon: Icons.delete_outline_rounded,
                      color: Colors.blueGrey.shade800,
                      bgColor: Colors.blueGrey.shade50,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms);
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subvalue,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subvalue,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. Tab 1: Expiry Alerts (अलर्ट्स & नियर एक्सपायरी)
  // =========================================================================
  Widget _buildExpiryAlertsTab(String shopId) {
    return Column(
      children: [
        // Filter Chips Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAlertFilterChip('all', 'All Alerts (सभी अलर्ट)'),
                const SizedBox(width: 8),
                _buildAlertFilterChip('7d', '⚡ Next 7 Days (7 दिन)'),
                const SizedBox(width: 8),
                _buildAlertFilterChip('15d', '⚠️ Next 15 Days (15 दिन)'),
                const SizedBox(width: 8),
                _buildAlertFilterChip('30d', '📅 Next 30 Days (30 दिन)'),
                const SizedBox(width: 8),
                _buildAlertFilterChip('expired', '🚨 Already Expired'),
              ],
            ),
          ),
        ),

        // Batches Alert Stream
        Expanded(
          child: StreamBuilder<List<BatchModel>>(
            stream: _service.streamExpiringAlerts(shopId, daysThreshold: 30),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final now = DateTime.now();
              var alerts = snapshot.data ?? [];

              // Apply Filter
              if (_alertFilter == '7d') {
                alerts = alerts.where((b) {
                  final d = b.daysUntilExpiry(now);
                  return d >= 0 && d <= 7;
                }).toList();
              } else if (_alertFilter == '15d') {
                alerts = alerts.where((b) {
                  final d = b.daysUntilExpiry(now);
                  return d >= 0 && d <= 15;
                }).toList();
              } else if (_alertFilter == '30d') {
                alerts = alerts.where((b) {
                  final d = b.daysUntilExpiry(now);
                  return d >= 0 && d <= 30;
                }).toList();
              } else if (_alertFilter == 'expired') {
                alerts = alerts.where((b) => b.isExpired(now)).toList();
              }

              if (alerts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 64,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Expiry Alerts Found!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'All tracked product batches are safe and fresh.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: alerts.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildUrgentAlertCard(alerts[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlertFilterChip(String key, String label) {
    final isSelected = _alertFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryDark.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryDark : AppColors.textMid,
      ),
      onSelected: (_) => setState(() => _alertFilter = key),
    );
  }

  Widget _buildUrgentAlertCard(BatchModel batch) {
    final now = DateTime.now();
    final days = batch.daysUntilExpiry(now);
    final isExpired = batch.isExpired(now);
    final dateFormat = DateFormat('dd MMM yyyy');

    Color cardBorder;
    Color badgeBg;
    String badgeText;

    if (isExpired) {
      cardBorder = Colors.red.shade400;
      badgeBg = Colors.red.shade700;
      badgeText = 'EXPIRED (${-days}d ago)';
    } else if (days <= 7) {
      cardBorder = Colors.red.shade300;
      badgeBg = Colors.red.shade600;
      badgeText = 'CRITICAL: $days DAYS LEFT';
    } else if (days <= 15) {
      cardBorder = Colors.orange.shade300;
      badgeBg = Colors.orange.shade800;
      badgeText = 'WARNING: $days DAYS LEFT';
    } else {
      cardBorder = Colors.amber.shade300;
      badgeBg = Colors.amber.shade800;
      badgeText = 'EXPIRING IN $days DAYS';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder, width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          BatchDetailsDialog.show(
            context,
            shopId: _getShopId(),
            batch: batch,
            service: _service,
            onUpdated: () => setState(() {}),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Status badge & Days pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    'Batch: ${batch.batchNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Product Name & Stock
              Text(
                batch.productName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),

              // Financial Metrics
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stock: ${batch.quantity} ${batch.unit}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Locked Cost: ₹${batch.inventoryCostValue.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isExpired ? Colors.red.shade800 : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Expiry Date: ${dateFormat.format(batch.expiryDate)}${batch.storageLocation != null ? ' • ${batch.storageLocation}' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),

              const Divider(height: 18),

              // Action Buttons
              Row(
                children: [
                  // Write off stock
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        DisposeBatchDialog.show(
                          context,
                          shopId: _getShopId(),
                          batch: batch,
                          service: _service,
                        ).then((_) => setState(() {}));
                      },
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                      label: const Text('Write-off (नुकसान)', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Clearance Sale (Promo)
                  if (!isExpired)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          final promoPrice = (batch.sellingPrice * 0.7).toStringAsFixed(0);
                          final text = '🚨 *CLEARANCE SALE!* 🚨\n'
                              '*${batch.productName}*\n'
                              'MRP: ₹${batch.sellingPrice.toStringAsFixed(0)} ➡️ *Deal Price: ₹$promoPrice only!* (30% OFF)\n'
                              'Best Before: ${dateFormat.format(batch.expiryDate)}\n'
                              'Hurry, only ${batch.quantity} ${batch.unit} left at Near Kirana!';
                          Clipboard.setData(ClipboardData(text: text));
                          SnackbarHelper.showSuccessSnackBar(
                              context, 'Clearance offer message copied to clipboard!');
                        },
                        icon: const Icon(Icons.percent_rounded, size: 16),
                        label: const Text('Clearance Promo', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 3. Tab 2: All Batches (सभी बैच)
  // =========================================================================
  Widget _buildAllBatchesTab(String shopId) {
    return Column(
      children: [
        // Search & Status Filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search batch by product or batch code...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildBatchStatusChip('all', 'All Statuses'),
                    const SizedBox(width: 8),
                    _buildBatchStatusChip('active', 'Active (सक्रिय)'),
                    const SizedBox(width: 8),
                    _buildBatchStatusChip('near_expiry', 'Near Expiry (जल्द)'),
                    const SizedBox(width: 8),
                    _buildBatchStatusChip('expired', 'Expired (एक्सपायर)'),
                    const SizedBox(width: 8),
                    _buildBatchStatusChip('depleted', 'Depleted (खत्म)'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Batches List
        Expanded(
          child: StreamBuilder<List<BatchModel>>(
            stream: _service.streamBatches(shopId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var batches = snapshot.data ?? [];

              // Search Filter
              if (_searchQuery.isNotEmpty) {
                batches = batches.where((b) {
                  return b.productName.toLowerCase().contains(_searchQuery) ||
                      b.batchNumber.toLowerCase().contains(_searchQuery) ||
                      (b.storageLocation?.toLowerCase().contains(_searchQuery) ?? false);
                }).toList();
              }

              // Status Filter
              if (_batchStatusFilter != 'all') {
                batches = batches.where((b) => b.status.key == _batchStatusFilter).toList();
              }

              if (batches.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No Batches Found',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Text('Tap "+ Add Batch" below to track your product expiry.'),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: batches.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildGeneralBatchCard(batches[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBatchStatusChip(String key, String label) {
    final isSelected = _batchStatusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryDark.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryDark : AppColors.textMid,
      ),
      onSelected: (_) => setState(() => _batchStatusFilter = key),
    );
  }

  Widget _buildGeneralBatchCard(BatchModel batch) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final days = batch.daysUntilExpiry();
    final isExpired = batch.isExpired();

    Color urgencyColor;
    if (isExpired) {
      urgencyColor = Colors.red.shade700;
    } else if (days <= 7) {
      urgencyColor = Colors.red.shade600;
    } else if (days <= 15) {
      urgencyColor = Colors.orange.shade800;
    } else {
      urgencyColor = Colors.green.shade700;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          BatchDetailsDialog.show(
            context,
            shopId: _getShopId(),
            batch: batch,
            service: _service,
            onUpdated: () => setState(() {}),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.qr_code_rounded, size: 18, color: AppColors.primaryDark),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Batch #${batch.batchNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(batch.status.colorValue).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Color(batch.status.colorValue)),
                    ),
                    child: Text(
                      batch.status.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(batch.status.colorValue),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                batch.productName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stock: ${batch.quantity} ${batch.unit}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: batch.quantity > 0 ? AppColors.textDark : Colors.red,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Expires: ${dateFormat.format(batch.expiryDate)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: urgencyColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Cost: ₹${batch.costPrice.toStringAsFixed(2)} • Sell: ₹${batch.sellingPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (batch.storageLocation != null) ...[
                    const Spacer(),
                    Text(
                      batch.storageLocation!,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 4. Tab 3: Waste & Disposal Log (नुकसान / राइट-ऑफ लॉग)
  // =========================================================================
  Widget _buildWasteLogTab(String shopId) {
    return StreamBuilder<List<BatchDisposalRecord>>(
      stream: _service.streamDisposalRecords(shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data ?? [];

        if (records.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.thumb_up_alt_outlined, size: 56, color: Colors.green.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'No Waste Records Found',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No stock has been discarded or written off.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final r = records[index];

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_forever_rounded, color: Colors.red.shade800, size: 22),
                ),
                title: Text(
                  r.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      'Batch: ${r.batchNumber} • Disposed: ${r.quantityDisposed} ${r.unit}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    Text(
                      dateFormat.format(r.disposedAt) +
                          (r.notes != null ? ' • ${r.notes}' : ''),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${r.lossAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.red.shade900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.reason.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
