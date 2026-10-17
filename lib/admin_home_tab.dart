import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'firestore_service.dart';
import 'admin_product_forms.dart';
import 'app_theme.dart';
import 'sound_service.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'language_provider.dart';
import 'admin_dashboard.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'widgets/weekly_sales_chart.dart';

class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  Future<void> _handleBarcodeScan(BuildContext context) async {
    HapticFeedback.mediumImpact();
    var res = await SimpleBarcodeScanner.scanBarcode(
      context,
      isShowFlashIcon: true,
    );

    if (res is String && res.isNotEmpty && res != '-1' && context.mounted) {
      SoundService().play('scan_beep.mp3');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: ModernLoader(color: AppColors.primaryDark)),
      );

      final firestoreService = FirestoreService();
      final product = await firestoreService.getProduct(res);

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading indicator

      final lang = Provider.of<LanguageProvider>(context, listen: false);
      String t(String en, String hi, String hinglish) {
        if (lang.isHindi) return hi;
        if (lang.isHinglish) return hinglish;
        return en;
      }

      if (product != null) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF0C831F),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t('Product Found', 'उत्पाद मिला', 'Product Mil Gaya'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${t('Price', 'कीमत', 'Price')}: ₹${product['price']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0C831F),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${t('Stock', 'स्टॉक', 'Stock')}: ${product['stock_quantity']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    AdminProductForms.showEditProductDialog(context, res);
                  },
                  child: Text(
                    t('Edit Product', 'बदलें', 'Edit Karein'),
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C831F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(t('OK', 'ठीक है', 'Done')),
                ),
              ],
            );
          },
        );
      } else {
        AdminProductForms.showEditProductDialog(context, res);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = Provider.of<ShopProvider>(context);
    final shopId = shopProvider.currentShopId;
    final lang = Provider.of<LanguageProvider>(context);

    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final Timestamp startTimestamp = Timestamp.fromDate(startOfToday);

    // Query 1: Today's Orders
    final todayOrdersQuery = shopId == null || shopId.isEmpty
        ? FirebaseUtils.firestore.collection('orders').limit(0)
        : FirebaseUtils.firestore
            .collection('orders')
            .where('shop_id', isEqualTo: shopId)
            .where('created_at', isGreaterThanOrEqualTo: startTimestamp);

    // Query 2: Active In-Progress Orders
    final activeOrdersQuery = shopId == null || shopId.isEmpty
        ? FirebaseUtils.firestore.collection('orders').limit(0)
        : FirebaseUtils.firestore
            .collection('orders')
            .where('shop_id', isEqualTo: shopId)
            .where(
              'status',
              whereIn: const [
                'Pending',
                'Accepted',
                'Packing',
                'Packed',
                'Ready',
                'Out for Delivery',
                'Delivery_Failed',
              ],
            );

    // Query 3: Low Stock / Out of Stock Products
    final lowStockQuery = shopId == null || shopId.isEmpty
        ? FirebaseUtils.firestore.collection('products').limit(0)
        : FirebaseUtils.firestore
            .collection('products')
            .where('shop_id', isEqualTo: shopId);

    // Query 4: Khata Customers
    final khataQuery = shopId == null || shopId.isEmpty
        ? FirebaseUtils.firestore.collection('customers').limit(0)
        : FirebaseUtils.firestore
            .collection('customers')
            .where('shop_ids', arrayContains: shopId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFF0C831F),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          shopProvider.shopName ?? t('Kirana Store', 'किराना स्टोर', 'Kirana Store'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Color(0xFF0C831F),
                      ),
                    ],
                  ),
                  Text(
                    t('Merchant Partner Dashboard', 'मर्चेंट पार्टनर डैशबोर्ड', 'Merchant Partner Dashboard'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            // Live Status Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: shopProvider.isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: shopProvider.isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: shopProvider.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    shopProvider.isActive
                        ? t('ONLINE', 'ऑनलाइन', 'ONLINE')
                        : t('OFFLINE', 'ऑफलाइन', 'OFFLINE'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: shopProvider.isActive ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending Verification Banner if shop is not active yet
            if (!shopProvider.isActive)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pending_actions_rounded,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t(
                          'Your store is currently undergoing partner verification. You can add inventory and set up bills.',
                          'आपकी दुकान अभी वेरिफिकेशन में है। आप सामान जोड़ सकते हैं और बिल बना सकते हैं।',
                          'Aapki dukan partner verification me hai. Aap inventory add aur bill setup kar sakte hain.',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05, end: 0),

            // 4-Tile Quick-Commerce Analytics Grid
            StreamBuilder<QuerySnapshot>(
              stream: todayOrdersQuery.snapshots(),
              builder: (context, todaySnapshot) {
                double todayTotal = 0;
                int todayOrdersCount = 0;

                if (todaySnapshot.hasData) {
                  for (var doc in todaySnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? '';
                    if ([
                      'Packed',
                      'Ready',
                      'Out for Delivery',
                      'Delivered',
                    ].contains(status)) {
                      todayTotal +=
                          double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0;
                    }
                    if (status != 'Cancelled' && status != 'Rejected') {
                      todayOrdersCount++;
                    }
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: activeOrdersQuery.snapshots(),
                  builder: (context, activeSnapshot) {
                    int activeCount = 0;
                    if (activeSnapshot.hasData) {
                      activeCount = activeSnapshot.data!.docs.length;
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: lowStockQuery.snapshots(),
                      builder: (context, productSnapshot) {
                        int lowStockCount = 0;
                        if (productSnapshot.hasData) {
                          for (var doc in productSnapshot.data!.docs) {
                            final pData = doc.data() as Map<String, dynamic>;
                            final stock = (pData['stock_quantity'] as num?)?.toInt() ?? 0;
                            if (stock <= 5) {
                              lowStockCount++;
                            }
                          }
                        }

                        return StreamBuilder<QuerySnapshot>(
                          stream: khataQuery.snapshots(),
                          builder: (context, khataSnapshot) {
                            double totalUdhaar = 0.0;
                            if (khataSnapshot.hasData) {
                              for (var doc in khataSnapshot.data!.docs) {
                                final cData = doc.data() as Map<String, dynamic>;
                                final balances = cData['shop_balances'] as Map<String, dynamic>?;
                                if (balances != null && balances.containsKey(shopId)) {
                                  totalUdhaar += (balances[shopId] as num?)?.toDouble() ?? 0.0;
                                } else {
                                  totalUdhaar += (cData['total_udhaar'] as num?)?.toDouble() ?? 0.0;
                                }
                              }
                            }

                            return _buildAnalyticsGrid(
                              context: context,
                              t: t,
                              todayTotal: todayTotal,
                              todayOrdersCount: todayOrdersCount,
                              activeCount: activeCount,
                              lowStockCount: lowStockCount,
                              totalUdhaar: totalUdhaar,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 20),

            // Weekly Sales Line Chart
            const WeeklySalesChart().animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 20),

            // Quick POS Scanner Banner (Zepto / Blinkit merchant partner aesthetic)
            _buildQuickPOSCard(context, t).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 14),

            // Operations Quick Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      AdminProductForms.showManualAddProductForm(context);
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: Text(
                      t('Add Product', 'नया सामान जोड़ें', 'Add Product'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C831F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      AdminDashboard.navCallback?.call(2); // Switches to Inventory/Stock Tab
                    },
                    icon: const Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF0F172A)),
                    label: Text(
                      t('Stock Adjust', 'स्टॉक बदलें', 'Stock Adjust'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 100), // bottom nav clearance
          ],
        ),
      ),
    );
  }

  // 4-Tile Analytics Grid
  Widget _buildAnalyticsGrid({
    required BuildContext context,
    required String Function(String, String, String) t,
    required double todayTotal,
    required int todayOrdersCount,
    required int activeCount,
    required int lowStockCount,
    required double totalUdhaar,
  }) {
    return Column(
      children: [
        // Row 1: Today's Revenue + Active Orders
        Row(
          children: [
            // Tile 1: Today's Sales
            Expanded(
              child: _buildMetricTile(
                icon: Icons.currency_rupee_rounded,
                iconColor: const Color(0xFF0C831F),
                iconBg: const Color(0xFFDCFCE7),
                title: t('Today Sales', 'आज की बिक्री', 'Today Sales'),
                value: '₹${todayTotal.toStringAsFixed(0)}',
                subtitle: '$todayOrdersCount ${t('orders today', 'ऑर्डर्स आज', 'orders aaj')}',
                onTap: () => AdminDashboard.navCallback?.call(1),
              ),
            ),
            const SizedBox(width: 12),
            // Tile 2: Active Orders
            Expanded(
              child: _buildMetricTile(
                icon: Icons.local_shipping_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFDBEAFE),
                title: t('Active Orders', 'चालू ऑर्डर्स', 'Active Orders'),
                value: '$activeCount',
                subtitle: activeCount > 0
                    ? t('Processing now', 'तैयार करें', 'Action Chahiye')
                    : t('All done', 'कोई ऑर्डर नहीं', 'Sab complete'),
                isLive: activeCount > 0,
                onTap: () => AdminDashboard.navCallback?.call(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Low Stock Alert + Khata Market Outstanding
        Row(
          children: [
            // Tile 3: Low Stock Alert
            Expanded(
              child: _buildMetricTile(
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFEF3C7),
                title: t('Low Stock Alert', 'कम स्टॉक अलर्ट', 'Low Stock Alert'),
                value: '$lowStockCount',
                subtitle: t('Items ≤ 5 qty', 'कम स्टॉक सामान', 'Items ≤ 5 stock'),
                onTap: () => AdminDashboard.navCallback?.call(2), // Inventory
              ),
            ),
            const SizedBox(width: 12),
            // Tile 4: Khata Udhaar Outstanding
            Expanded(
              child: _buildMetricTile(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFEDE9FE),
                title: t('Khata Dues', 'खाता उधारी', 'Khata Udhaar'),
                value: '₹${totalUdhaar.toStringAsFixed(0)}',
                subtitle: t('Collectable dues', 'मार्केट उधारी', 'Pending collection'),
                onTap: () => AdminDashboard.navCallback?.call(3), // Khata
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subtitle,
    bool isLive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                if (isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Color(0xFFCBD5E1),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Quick POS / Scanner Card (Zepto / Blinkit merchant partner high-contrast design)
  Widget _buildQuickPOSCard(BuildContext context, String Function(String, String, String) t) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Dark slate
            Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleBarcodeScan(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Frosted scanner icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C831F),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0C831F).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C831F).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 13,
                              color: Color(0xFF4ADE80),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              t('FAST BILLING', 'फास्ट बिलिंग', 'FAST BILLING'),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4ADE80),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t('Scan Barcode / New Bill', 'बारकोड स्कैन / नया बिल', 'Scan Barcode / Naya Bill'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(
                          'Scan to sell, re-stock or edit pricing',
                          'सामान बेचने या कीमत बदलने के लिए स्कैन करें',
                          'Item bechne ya price update karne ke liye scan karein',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF64748B),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

