import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';

import 'admin_dashboard.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'app_theme.dart';
import 'shop_selector_screen.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'widgets/custom_pin_pad.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  bool _isLoadingPin = true;
  String? _adminPinHash;

  @override
  void initState() {
    super.initState();
    _fetchAdminPin();
  }

  Future<void> _fetchAdminPin() async {
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    if (shopId != null && shopId.isNotEmpty) {
      final shopDoc = await FirebaseUtils.firestore.collection('shops').doc(shopId).get();
      if (mounted && shopDoc.exists) {
        setState(() {
          _adminPinHash = shopDoc.data()?['admin_pin']?.toString();
          _isLoadingPin = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingPin = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingPin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).translate('owner_login')),
      ),
      body: _isLoadingPin
          ? const Center(child: ModernLoader(color: AppColors.primaryDark))
          : Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomPinPad(
                      isNewUser: false,
                      title: 'Dukaan Malik PIN',
                      subtitle: 'Login karne ke liye apna 4-digit PIN dalein',
                      existingPinHash: _adminPinHash,
                      onPinEntered: (pinOrHash) async {
                        final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
                        
                        // If legacy plaintext pin was used, upgrade it to hash
                        if (pinOrHash != _adminPinHash && pinOrHash != "BIOMETRIC_SUCCESS" && shopId != null) {
                           await FirebaseUtils.firestore.collection('shops').doc(shopId).update({
                             'admin_pin': pinOrHash
                           });
                        }

                        HapticFeedback.heavyImpact();
                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminDashboard()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(Provider.of<LanguageProvider>(context, listen: false).translate('dukan_badlein_title')),
                            content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('dukan_badlein_desc')),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(Provider.of<LanguageProvider>(context, listen: false).translate('cancel')),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                                child: Text(Provider.of<LanguageProvider>(context, listen: false).translate('yes_change')),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          await Provider.of<ShopProvider>(context, listen: false).clearShop();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const ShopSelectorScreen()),
                              (route) => false,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: Text(Provider.of<LanguageProvider>(context, listen: false).translate('change_shop_btn')),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
