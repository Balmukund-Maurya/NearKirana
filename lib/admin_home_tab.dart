import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'language_provider.dart';
import 'firestore_service.dart';
import 'admin_product_forms.dart';
import 'app_theme.dart';
import 'sound_service.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';

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

      if (product != null) {
        showDialog(
          context: context,
          builder: (context) {
            final langProvider = Provider.of<LanguageProvider>(
              context,
              listen: false,
            );
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    langProvider.translate('product_found'),
                    style: AppTextStyles.heading2(color: AppColors.textDark),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    style: AppTextStyles.heading1(color: AppColors.textDark),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${langProvider.translate('price')}: ₹${product['price']}',
                    style: AppTextStyles.bodySemiBold(color: AppColors.textMid),
                  ),
                  Text(
                    '${langProvider.translate('stock')}: ${product['stock_quantity']}',
                    style: AppTextStyles.bodySemiBold(color: AppColors.textMid),
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
                    langProvider.translate('edit'),
                    style: AppTextStyles.bodySemiBold(color: Colors.blue),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(langProvider.translate('ok_btn')),
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

  Widget _buildDailySalesCard(BuildContext context) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final Timestamp startTimestamp = Timestamp.fromDate(startOfToday);
    final shopId = Provider.of<ShopProvider>(context).currentShopId;

    final todayOrdersQuery = shopId == null || shopId.isEmpty
        ? FirebaseFirestore.instance.collection('orders').limit(0)
        : FirebaseFirestore.instance
              .collection('orders')
              .where('shop_id', isEqualTo: shopId)
              .where('created_at', isGreaterThanOrEqualTo: startTimestamp);

    return StreamBuilder<QuerySnapshot>(
      stream: todayOrdersQuery.snapshots(),
      builder: (context, todaySnapshot) {
        double todayTotal = 0;

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
          }
        }

        final activeOrdersQuery = shopId == null || shopId.isEmpty
            ? FirebaseFirestore.instance.collection('orders').limit(0)
            : FirebaseFirestore.instance
                  .collection('orders')
                  .where('shop_id', isEqualTo: shopId)
                  .where(
                    'status',
                    whereIn: ['Pending', 'Packed', 'Ready', 'Out for Delivery'],
                  );

        return StreamBuilder<QuerySnapshot>(
          stream: activeOrdersQuery.snapshots(),
          builder: (context, activeSnapshot) {
            int activeOrders = 0;
            if (activeSnapshot.hasData) {
              activeOrders = activeSnapshot.data!.docs.length;
            }

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, Color(0xFF1E4B19)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.currency_rupee_rounded,
                              color: AppColors.primaryLight,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Earning Today',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${todayTotal.toStringAsFixed(0)}',
                          style: AppTextStyles.heading1(
                            color: AppColors.white,
                          ).copyWith(fontSize: 32),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
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
                          children: [
                            const Icon(
                              Icons.local_shipping_rounded,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Active',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.textMid,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$activeOrders',
                          style: AppTextStyles.heading1(
                            color: AppColors.textDark,
                          ).copyWith(fontSize: 32),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(langProvider.translate('admin_dashboard')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDailySalesCard(
              context,
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 32),

            // Scanner Card
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Card(
                color: AppColors.accentPink,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                elevation: 4,
                shadowColor: AppColors.accentPink.withValues(alpha: 0.5),
                child: InkWell(
                  onTap: () => _handleBarcodeScan(context),
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 150,
                          color: AppColors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 48,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              langProvider.translate('scan_barcode'),
                              style: AppTextStyles.heading1(
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              langProvider.translate('add_or_update_product'),
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 32),

            // Manual Add Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  AdminProductForms.showManualAddProductForm(context);
                },
                icon: const Icon(Icons.add_rounded, size: 24),
                label: Text(langProvider.translate('add_new_item')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight.withValues(
                    alpha: 0.2,
                  ),
                  foregroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(
                      color: AppColors.primaryLight,
                      width: 1.5,
                    ),
                  ),
                  textStyle: AppTextStyles.button(),
                  elevation: 0,
                ),
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 100), // padding for bottom nav
          ],
        ),
      ),
    );
  }
}
