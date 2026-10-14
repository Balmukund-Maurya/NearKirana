import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'shop_provider.dart';
import 'supplier_models.dart';
import 'supplier_service.dart';
import 'utils/snackbar_helper.dart';
import 'widgets/add_supplier_dialog.dart';
import 'widgets/record_purchase_dialog.dart';
import 'widgets/record_supplier_payment_dialog.dart';
import 'widgets/purchase_order_details_dialog.dart';

/// Primary Admin Screen for Feature 54: Supplier & Purchase Management
class AdminSuppliersScreen extends StatefulWidget {
  final SupplierService? service;

  const AdminSuppliersScreen({super.key, this.service});

  @override
  State<AdminSuppliersScreen> createState() => _AdminSuppliersScreenState();
}

class _AdminSuppliersScreenState extends State<AdminSuppliersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SupplierService _service;

  // Search & Filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _invoiceFilter = 'All'; // 'All', 'Received', 'Pending', 'Due'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _service = widget.service ?? SupplierService();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _shopId {
    return Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'SHOP_DEFAULT';
  }

  Future<void> _handleNewPurchase([SupplierModel? preselected]) async {
    HapticFeedback.lightImpact();
    await RecordPurchaseDialog.show(
      context,
      shopId: _shopId,
      preselectedSupplier: preselected,
      service: _service,
    );
  }

  Future<void> _handleNewSupplier() async {
    HapticFeedback.lightImpact();
    await AddSupplierDialog.show(
      context,
      shopId: _shopId,
      service: _service,
    );
  }

  Future<void> _launchCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) SnackbarHelper.showErrorSnackBar(context, 'Could not launch dialer');
    }
  }

  Future<void> _launchWhatsApp(String phone, String supplierName) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/91$cleanPhone?text=${Uri.encodeComponent('Namaste $supplierName ji, NearKirana store se sampark kar rahe hain.')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) SnackbarHelper.showErrorSnackBar(context, 'Could not open WhatsApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Suppliers & Purchases (सप्लायर और खरीद)'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Add Supplier',
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryDark),
            onPressed: _handleNewSupplier,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textMid,
          indicatorColor: AppColors.primaryDark,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Purchases (खरीद)'),
            Tab(icon: Icon(Icons.storefront_rounded), text: 'Suppliers & Dues (उधारी)'),
            Tab(icon: Icon(Icons.payments_rounded), text: 'Payment Ledger (लेज़र)'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('New Purchase (नई खरीद)'),
        onPressed: () => _handleNewPurchase(),
      ),
      body: Column(
        children: [
          // Executive KPI Summary Header
          _buildKpiHeader(isDesktop),

          // Main Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPurchasesTab(),
                _buildSuppliersTab(),
                _buildPaymentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. EXECUTIVE KPI SUMMARY HEADER
  // =========================================================================
  Widget _buildKpiHeader(bool isDesktop) {
    return FutureBuilder<SupplierAnalyticsSummary>(
      future: _service.fetchSupplierAnalytics(_shopId),
      builder: (context, snapshot) {
        final summary = snapshot.data ?? SupplierAnalyticsSummary.empty();

        final cards = [
          _buildKpiCard(
            title: 'Total Supplier Dues (बाकी उधारी)',
            value: '₹${summary.totalOutstandingDues.toStringAsFixed(0)}',
            subtitle: '${summary.suppliersWithDuesCount} suppliers pending',
            icon: Icons.account_balance_wallet_rounded,
            color: summary.totalOutstandingDues > 0 ? Colors.red.shade700 : Colors.green.shade700,
            bgColor: summary.totalOutstandingDues > 0 ? Colors.red.shade50 : Colors.green.shade50,
          ),
          _buildKpiCard(
            title: 'Purchases (कुल खरीद)',
            value: '₹${summary.totalPurchasesAmount.toStringAsFixed(0)}',
            subtitle: '${summary.totalPurchaseOrdersCount} invoices recorded',
            icon: Icons.shopping_bag_rounded,
            color: Colors.blue.shade700,
            bgColor: Colors.blue.shade50,
          ),
          _buildKpiCard(
            title: 'Wholesalers (सप्लायर्स)',
            value: '${summary.totalSuppliersCount}',
            subtitle: 'Active distributors',
            icon: Icons.storefront_rounded,
            color: Colors.purple.shade700,
            bgColor: Colors.purple.shade50,
          ),
          _buildKpiCard(
            title: 'Pending Stock (आने वाला माल)',
            value: '${summary.pendingOrdersCount}',
            subtitle: 'Orders to verify',
            icon: Icons.local_shipping_rounded,
            color: summary.pendingOrdersCount > 0 ? Colors.amber.shade800 : Colors.teal.shade700,
            bgColor: summary.pendingOrdersCount > 0 ? Colors.amber.shade50 : Colors.teal.shade50,
          ),
        ];

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: Colors.white,
          child: isDesktop
              ? Row(
                  children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: cards.map((c) => SizedBox(width: 175, child: Padding(padding: const EdgeInsets.only(right: 10), child: c))).toList(),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. TAB 1: PURCHASES & INVOICES
  // =========================================================================
  Widget _buildPurchasesTab() {
    return Column(
      children: [
        // Filter Chips & Search Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by bill number, supplier or item...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'All Invoices'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Received', 'Stock Received'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', 'Pending Delivery'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Due', 'Unpaid / Due'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Stream of Purchase Orders
        Expanded(
          child: StreamBuilder<List<PurchaseOrderModel>>(
            stream: _service.streamPurchaseOrders(_shopId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
              }

              final allOrders = snapshot.data ?? [];

              // Apply search & status filter
              final filtered = allOrders.where((po) {
                // Status Filter
                if (_invoiceFilter == 'Received' && po.status != PurchaseOrderStatus.received) return false;
                if (_invoiceFilter == 'Pending' && po.status != PurchaseOrderStatus.ordered && po.status != PurchaseOrderStatus.draft) return false;
                if (_invoiceFilter == 'Due' && po.balanceDue <= 0.01) return false;

                // Search Query
                if (_searchQuery.isNotEmpty) {
                  final matchInvoice = po.invoiceNumber.toLowerCase().contains(_searchQuery);
                  final matchSupplier = po.supplierName.toLowerCase().contains(_searchQuery);
                  final matchItems = po.items.any((it) => it.productName.toLowerCase().contains(_searchQuery));
                  return matchInvoice || matchSupplier || matchItems;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        allOrders.isEmpty
                            ? 'No purchase invoices recorded yet'
                            : 'No purchase invoices match your filter',
                        style: AppTextStyles.bodySemiBold(color: AppColors.textMid),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _handleNewPurchase(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Record First Purchase'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildPurchaseCard(filtered[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _invoiceFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryDark.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryDark : AppColors.textMid,
      ),
      onSelected: (_) => setState(() => _invoiceFilter = key),
    );
  }

  Widget _buildPurchaseCard(PurchaseOrderModel po) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          PurchaseOrderDetailsDialog.show(
            context,
            shopId: _shopId,
            purchaseOrder: po,
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
              // Top Row: Bill No & Status Pill
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
                        child: const Icon(Icons.receipt_rounded, size: 18, color: AppColors.primaryDark),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bill #${po.invoiceNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(po.status.colorValue).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Color(po.status.colorValue)),
                    ),
                    child: Text(
                      po.status.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(po.status.colorValue),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Supplier Name & Purchase Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      po.supplierName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    dateFormat.format(po.purchaseDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Items preview
              Text(
                '${po.items.length} items (${po.totalItemUnits} units): ${po.items.take(3).map((it) => it.productName).join(', ')}${po.items.length > 3 ? '...' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(height: 18),

              // Bottom Row: Financials & Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Bill', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('₹${po.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  if (po.paidAmount > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Paid', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text('₹${po.paidAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.teal)),
                      ],
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Balance Due', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        po.balanceDue > 0 ? '₹${po.balanceDue.toStringAsFixed(2)}' : 'Fully Paid',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: po.balanceDue > 0 ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 3. TAB 2: SUPPLIERS & DUES DIRECTORY
  // =========================================================================
  Widget _buildSuppliersTab() {
    return Column(
      children: [
        // Search & Add Supplier Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search supplier by name, phone or category...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleNewSupplier,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Supplier'),
              ),
            ],
          ),
        ),

        // Stream of Suppliers
        Expanded(
          child: StreamBuilder<List<SupplierModel>>(
            stream: _service.streamSuppliers(_shopId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
              }

              final allSuppliers = snapshot.data ?? [];

              final filtered = allSuppliers.where((s) {
                if (_searchQuery.isEmpty) return true;
                return s.name.toLowerCase().contains(_searchQuery) ||
                    s.phone.contains(_searchQuery) ||
                    s.category.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No suppliers registered yet',
                          style: AppTextStyles.bodySemiBold(color: AppColors.textMid)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _handleNewSupplier,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Wholesaler / Supplier'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildSupplierCard(filtered[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierCard(SupplierModel sup) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Name, Category, Balance Due Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sup.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (sup.contactPerson != null && sup.contactPerson!.isNotEmpty) ...[
                            Text(
                              sup.contactPerson!,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              sup.category,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Balance Due Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sup.hasOutstandingDue ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sup.hasOutstandingDue ? Colors.red.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        sup.hasOutstandingDue ? 'Due (बाकी उधारी)' : 'No Due',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: sup.hasOutstandingDue ? Colors.red.shade800 : Colors.green.shade800,
                        ),
                      ),
                      Text(
                        '₹${sup.balanceDue.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: sup.hasOutstandingDue ? Colors.red.shade900 : Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Purchasing stats & Phone
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(sup.phone, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const Spacer(),
                Text(
                  'Purchased: ₹${sup.totalPurchased.toStringAsFixed(0)}  •  Paid: ₹${sup.totalPaid.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const Divider(height: 20),

            // Action Buttons Row
            Row(
              children: [
                // Quick Call
                IconButton.filledTonal(
                  tooltip: 'Call Supplier',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(Icons.phone_rounded, color: Colors.blue.shade700, size: 18),
                  onPressed: () => _launchCall(sup.phone),
                ),
                const SizedBox(width: 6),

                // Quick WhatsApp
                IconButton.filledTonal(
                  tooltip: 'WhatsApp Supplier',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(Icons.chat_bubble_outline_rounded, color: Colors.green.shade800, size: 18),
                  onPressed: () => _launchWhatsApp(sup.phone, sup.name),
                ),
                const Spacer(),

                // Record Payment Button
                if (sup.hasOutstandingDue) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade800,
                      side: BorderSide(color: Colors.green.shade400),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await RecordSupplierPaymentDialog.show(
                        context,
                        shopId: _shopId,
                        supplier: sup,
                        service: _service,
                      );
                    },
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Pay Due'),
                  ),
                  const SizedBox(width: 8),
                ],

                // New Purchase from this supplier
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _handleNewPurchase(sup),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: const Text('+ Purchase'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. TAB 3: PAYMENT LEDGER
  // =========================================================================
  Widget _buildPaymentsTab() {
    return StreamBuilder<List<SupplierPaymentModel>>(
      stream: _service.streamSupplierPayments(_shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
        }

        final payments = snapshot.data ?? [];

        if (payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('No supplier payments recorded yet',
                    style: AppTextStyles.bodySemiBold(color: AppColors.textMid)),
                const SizedBox(height: 6),
                Text(
                  'Payments made to wholesalers will appear here in chronological ledger',
                  style: AppTextStyles.caption(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final p = payments[index];

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 22),
                ),
                title: Text(
                  p.supplierName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dateFormat.format(p.paymentDate)} • ${p.paymentMethod.displayName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (p.referenceNumber != null && p.referenceNumber!.isNotEmpty)
                      Text(
                        'Ref: ${p.referenceNumber}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                  ],
                ),
                trailing: Text(
                  '₹${p.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
