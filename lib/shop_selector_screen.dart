import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'shop_provider.dart';
import 'app_theme.dart';
import 'modern_loader.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'shop_registration_screen.dart';

class ShopSelectorScreen extends StatefulWidget {
  const ShopSelectorScreen({super.key});

  @override
  State<ShopSelectorScreen> createState() => _ShopSelectorScreenState();
}

class _ShopSelectorScreenState extends State<ShopSelectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadExistingShop();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingShop() async {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    await shopProvider.loadCurrentShop();

    if (!mounted) return;
    if (shopProvider.currentShopId != null && shopProvider.currentShopId!.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _scanShopQR() async {
    HapticFeedback.mediumImpact();
    final res = await SimpleBarcodeScanner.scanBarcode(
      context,
      isShowFlashIcon: true,
    );

    if (res is String && res.isNotEmpty && res != '-1' && context.mounted) {
      await _verifyAndEnterShop(res);
    }
  }

  Future<void> _verifyAndEnterShop(String shopId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: ModernLoader(color: AppColors.primaryDark),
      ),
    );

    try {
      final shopDoc = await FirebaseFirestore.instance.collection('shops').doc(shopId).get();

      if (!context.mounted) return;
      Navigator.pop(context);

      if (shopDoc.exists) {
        final data = shopDoc.data() as Map<String, dynamic>;
        final shopName = data['shop_name'] ?? 'Unknown Shop';
        final isActive = data['is_active'] ?? true;
        final address = data['address']?.toString();
        final mobile = data['mobile']?.toString();
        final supportPhone = data['support_phone']?.toString() ?? mobile;
        final bannerUrl = data['banner_image_url']?.toString() ?? data['shop_image_url']?.toString();
        final whatsappTemplate = data['whatsapp_message_template']?.toString();
        final upiId = data['upi_id']?.toString() ?? data['vpa']?.toString();

        if (!isActive) {
          _showError('Yeh dukan abhi platform par active nahi hai.');
          return;
        }

        await Provider.of<ShopProvider>(context, listen: false).setShop(
          shopId,
          shopName,
          address: address,
          mobile: mobile,
          supportPhone: supportPhone,
          bannerUrl: bannerUrl,
          whatsappTemplate: whatsappTemplate,
          upiId: upiId,
        );

        HapticFeedback.heavyImpact();
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        _showError('Dukan nahi mili. Kripya sahi QR Code scan karein.');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showError('Network error: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Icon(
                  Icons.storefront_rounded,
                  size: 80,
                  color: AppColors.primaryDark,
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(curve: Curves.easeOutBack),
                const SizedBox(height: 12),
                Text(
                  langProvider.translate('welcome_title'),
                  style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  langProvider.translate('search_shop_subtitle'),
                  style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: langProvider.translate('search_shop_hint'),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryDark),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _scanShopQR,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(Provider.of<LanguageProvider>(context, listen: false).translate('scan_shop_qr')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.primaryDark, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('shops')
                            .where('is_active', isEqualTo: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              height: 180,
                              child: Center(child: ModernLoader()),
                            );
                          }

                          List<QueryDocumentSnapshot> shops = snapshot.data!.docs;

                          if (_searchQuery.isEmpty) {
                            shops = shops.toList();
                            shops.sort((a, b) {
                              final aData = a.data() as Map<String, dynamic>;
                              final bData = b.data() as Map<String, dynamic>;
                              final aTime = aData['created_at'] as Timestamp?;
                              final bTime = bData['created_at'] as Timestamp?;
                              if (aTime == null && bTime == null) return 0;
                              if (aTime == null) return 1;
                              if (bTime == null) return -1;
                              return bTime.compareTo(aTime);
                            });
                            shops = shops.take(5).toList();
                          } else {
                            shops = shops.where((doc) {
                              final name = (doc['shop_name'] ?? '').toString().toLowerCase();
                              return name.contains(_searchQuery);
                            }).toList();
                          }

                          if (shops.isEmpty) {
                            return SizedBox(
                              height: 180,
                              child: Center(child: Text(Provider.of<LanguageProvider>(context, listen: false).translate('error_no_shop_found'))),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: shops.length,
                            itemBuilder: (context, index) {
                              final shop = shops[index];
                              final data = shop.data() as Map<String, dynamic>;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                                    child: const Icon(Icons.store, color: AppColors.primaryDark),
                                  ),
                                  title: Text(
                                    data['shop_name'] ?? '',
                                    style: AppTextStyles.heading2(color: AppColors.textDark),
                                  ),
                                  subtitle: Text(
                                    data['address'] ?? '',
                                    style: AppTextStyles.captionMedium(color: AppColors.textMid),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                                  onTap: () => _verifyAndEnterShop(shop.id),
                                ),
                              );
                            },
                          );
                        },
                      ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.bgTint, width: 1),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        langProvider.translate('are_you_shop_owner'),
                        style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                      ),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ShopRegistrationScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          langProvider.translate('register_your_shop'),
                          style: AppTextStyles.bodySemiBold(
                            color: AppColors.primaryDark,
                          ).copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
