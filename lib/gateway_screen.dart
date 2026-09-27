import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'shop_selector_screen.dart';
import 'shop_registration_screen.dart';
import 'admin_dashboard.dart';
import 'custom_auth_screen.dart';
import 'package:phone_email_auth/phone_email_auth.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart' show LoginScreen;
import 'user_provider.dart';

class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});

  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  bool _isLoading = true;
  String? _globalPhone;

  @override
  void initState() {
    super.initState();
    _checkSavedRole();
  }

  Future<void> _checkSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('app_role');
    _globalPhone = prefs.getString('global_phone');
    
    if (!mounted) return;

    if (_globalPhone != null && _globalPhone!.isNotEmpty) {
      if (role == 'customer') {
        final shopProvider = Provider.of<ShopProvider>(context, listen: false);
        if (shopProvider.currentShopId != null && shopProvider.currentShopId!.isNotEmpty) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ShopSelectorScreen()));
        }
      } else if (role == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      // Force OTP first
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forceLogin() async {
    try {
      final value = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomAuthScreen()),
      );

      if (value != null && value[AppConstant.authResponse] != null) {
        final loginData = value[AppConstant.authResponse] as LoginModel;
        final accessToken = loginData.accessTokenn;
        if (accessToken != null && accessToken.isNotEmpty) {
          _handlePhoneEmailAuthForGlobal(accessToken);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP Auth Failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _handlePhoneEmailAuthForGlobal(String accessToken) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: ModernLoader(color: AppColors.primaryDark)),
    );

    PhoneEmail.getUserInfo(
      accessToken: accessToken,
      clientId: '17194425783292968499',
      onSuccess: (userData) async {
        if (!mounted) return;
        String? rawPhone = userData.phoneNumber;
        if (rawPhone == null || rawPhone.isEmpty) {
          Navigator.pop(context); // hide loader
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to retrieve phone number.'), backgroundColor: AppColors.error),
          );
          return;
        }

        String phone = rawPhone.replaceAll(RegExp(r'\D'), '');
        if (phone.length > 10) {
          phone = phone.substring(phone.length - 10);
        }

        if (!mounted) return;
        Navigator.pop(context); // hide loader

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('global_phone', phone);
        
        if (!mounted) return;
        setState(() {
          _globalPhone = phone;
        });
      },
    );
  }

  Future<void> _selectCustomerRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_role', 'customer');
    if (_globalPhone == null || _globalPhone!.isEmpty) return;
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: ModernLoader(color: AppColors.primaryDark)),
    );

    try {
      final existingCustomer = await FirebaseUtils.firestore
          .collection('customers')
          .where('mobile', isEqualTo: _globalPhone)
          .limit(1)
          .get();

      if (!mounted) return;
      Navigator.pop(context); // hide loader

      if (existingCustomer.docs.isNotEmpty) {
        final doc = existingCustomer.docs.first;
        final data = doc.data();
        final dbName = data['name'] as String? ?? 'User';
        
        await prefs.setString('customerName', dbName);
        await prefs.setString('customerPhone', _globalPhone!);
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false).setUser(dbName, _globalPhone!);
        }
      } else {
        final name = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final ctrl = TextEditingController();
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded, size: 40, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome!',
                      style: AppTextStyles.heading2(color: AppColors.textDark),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'What should we call you?',
                      style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: ctrl,
                      textCapitalization: TextCapitalization.words,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading2(color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        hintStyle: AppTextStyles.heading2(color: AppColors.textLight),
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Cancel', style: AppTextStyles.bodySemiBold(color: AppColors.textMid)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (ctrl.text.trim().isNotEmpty) {
                                Navigator.pop(context, ctrl.text.trim());
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter your name'), backgroundColor: AppColors.error),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text('Save', style: AppTextStyles.bodySemiBold(color: AppColors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );

        if (name == null || name.isEmpty) return; // User cancelled or didn't enter name, stop flow.
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: ModernLoader(color: AppColors.primaryDark)),
        );

        await FirebaseUtils.firestore.collection('customers').add({
          'name': name,
          'mobile': _globalPhone,
          'pin': 'PHONE_AUTH',
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pop(context); // hide loader

        await prefs.setString('customerName', name);
        await prefs.setString('customerPhone', _globalPhone!);
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false).setUser(name, _globalPhone!);
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      return;
    }
    
    if (!mounted) return;
    
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    if (shopProvider.currentShopId != null && shopProvider.currentShopId!.isNotEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ShopSelectorScreen()));
    }
  }

  Future<void> _selectAdminRole() async {
    if (_globalPhone == null || _globalPhone!.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: ModernLoader(color: AppColors.primaryDark)),
    );

    final existingShop = await FirebaseUtils.firestore
        .collection('shops')
        .where('mobile', isEqualTo: _globalPhone)
        .get();

    if (!mounted) return;
    Navigator.pop(context); // hide loader

    final prefs = await SharedPreferences.getInstance();

    if (existingShop.docs.isNotEmpty) {
      final shopDoc = existingShop.docs.first;
      final shopData = shopDoc.data();
      final dbPin = shopData['admin_pin'] as String?;
      final shopName = shopData['shop_name'] as String? ?? 'Your Shop';
      final ownerName = shopData['owner_name'] as String? ?? 'Owner';

      if (dbPin != null && dbPin.isNotEmpty) {
        if (!mounted) return;
        final enteredPin = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final ctrl = TextEditingController();
            bool obscure = true;
            return StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  backgroundColor: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded, size: 40, color: AppColors.primaryDark),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          shopName,
                          style: AppTextStyles.heading2(color: AppColors.textDark),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome back, $ownerName',
                          style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          obscureText: obscure,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(letterSpacing: 8),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                            hintStyle: AppTextStyles.heading2(color: AppColors.textLight).copyWith(letterSpacing: 8),
                            filled: true,
                            fillColor: AppColors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textMid),
                              onPressed: () => setState(() => obscure = !obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Cancel', style: AppTextStyles.bodySemiBold(color: AppColors.textMid)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context, ctrl.text),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  foregroundColor: AppColors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: Text('Login', style: AppTextStyles.bodySemiBold(color: AppColors.white)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
            );
          }
        );

        if (enteredPin == null) return; // User cancelled
        if (enteredPin != dbPin) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect PIN'), backgroundColor: AppColors.error),
          );
          return;
        }
      }

      final shopId = shopDoc.id;
      
      if (!mounted) return;
      await Provider.of<ShopProvider>(context, listen: false).setShop(shopId, shopDoc.data()['shop_name'] ?? '');
      await prefs.setString('app_role', 'admin');
      
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
    } else {
      // New shop owner
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShopRegistrationScreen(verifiedPhone: _globalPhone!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: ModernLoader(color: AppColors.primaryDark)),
      );
    }

    if (_globalPhone == null || _globalPhone!.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(Icons.storefront_rounded, size: 120, color: AppColors.primaryDark)
                    .animate()
                    .scale(curve: Curves.easeOutBack, duration: 600.ms),
                const SizedBox(height: 32),
                Text(
                  'Welcome to NearKirana',
                  style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 32),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 16),
                Text(
                  'Please verify your phone number to get started.',
                  style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms),
                const Spacer(),
                ElevatedButton(
                  onPressed: _forceLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Login to Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.storefront_rounded, size: 100, color: AppColors.primaryDark)
                  .animate()
                  .scale(curve: Curves.easeOutBack, duration: 600.ms),
              const SizedBox(height: 24),
              Text(
                'Welcome to NearKirana',
                style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 12),
              Text(
                'Choose your role',
                style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 18),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              const Spacer(),
              _buildRoleCard(
                title: 'I am a Customer',
                subtitle: 'Order items from nearby shops',
                icon: Icons.shopping_basket_rounded,
                color: AppColors.primaryDark,
                onTap: _selectCustomerRole,
                delay: 400.ms,
              ),
              const SizedBox(height: 20),
              _buildRoleCard(
                title: 'I am a Shop Owner',
                subtitle: 'Register your shop and take orders online',
                icon: Icons.store_mall_directory_rounded,
                color: AppColors.accentPink,
                onTap: _selectAdminRole,
                delay: 500.ms,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required Duration delay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading2(color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.captionMedium(color: AppColors.textMid),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 20),
          ],
        ),
      ).animate().fadeIn(delay: delay).slideX(begin: 0.1, end: 0),
    );
  }
}
