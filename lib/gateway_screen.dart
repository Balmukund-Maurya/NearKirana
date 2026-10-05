import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
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
  final TextEditingController _phoneController = TextEditingController();

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
      final size = MediaQuery.of(context).size;
      final isDesktop = size.width >= 900;
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: isDesktop 
              ? _buildDesktopLayout(context, size) 
              : _buildMobileLayout(context, size),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: isDesktop 
            ? _buildRoleSelectionDesktop(context, size)
            : _buildRoleSelectionMobile(context, size),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Color? backgroundColor,
    required VoidCallback onTap,
    required Duration delay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
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

  Widget _buildDesktopLayout(BuildContext context, Size size) {
    return Row(
      children: [
        // LEFT SIDE: 3D Illustration
        Expanded(
          flex: 5,
          child: Container(
            color: AppColors.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Main Illustration
                Image.asset(
                  'assets/images/kirana_web_hero.jpg',
                  fit: BoxFit.cover,
                ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(1.05, 1.05), end: const Offset(1, 1), duration: 800.ms),
                
                // Overlay for better text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                
                // Feature Cards
                Positioned(
                  left: 40,
                  bottom: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeatureCard(Icons.eco_rounded, 'Fresh Products'),
                      const SizedBox(height: 16),
                      _buildFeatureCard(Icons.local_shipping_rounded, 'Fast Delivery'),
                      const SizedBox(height: 16),
                      _buildFeatureCard(Icons.verified_rounded, 'Trusted Quality'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // RIGHT SIDE: Glassmorphic Auth Card
        Expanded(
          flex: 4,
          child: Container(
            color: AppColors.surface,
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildAuthCard(context, true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, Size size) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Illustration Half
          SizedBox(
            height: size.height * 0.35,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/kirana_web_hero.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.surface, Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Auth Half
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: _buildAuthCard(context, false),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
          ),
        ],
      ),
    ).animate().slideX(begin: -0.2, end: 0, duration: 600.ms).fadeIn(duration: 600.ms);
  }

  Widget _buildAuthCard(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDesktop ? 0.9 : 1.0),
        borderRadius: BorderRadius.circular(32),
        border: isDesktop ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5) : null,
        boxShadow: isDesktop ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo & Branding
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: AppDecorations.primaryGradient(radius: 16),
                child: const Icon(
                  Icons.shopping_basket_rounded,
                  color: AppColors.white,
                  size: 32,
                ),
              ).animate().scale(begin: const Offset(0,0), end: const Offset(1,1), duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(width: 16),
              Text(
                'NearKirana',
                style: AppTextStyles.display(color: AppColors.primaryDark).copyWith(fontSize: 32),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            'Fresh Groceries\nAt Your Doorstep',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading2(color: AppColors.textDark),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: 48),
          
          // Input Field
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Enter your mobile number',
              style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
            ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 12),
          
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, size: 20, color: AppColors.textMid),
                      const SizedBox(width: 8),
                      Text('+91', style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
                    ],
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3)),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Enter mobile number',
                      hintStyle: AppTextStyles.bodyMedium(color: AppColors.textMid),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: 24),
          
          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: () {
                if (_phoneController.text.length != 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
                  );
                  return;
                }
                // Auth call
                if (kIsWeb) {
                  final phone = _phoneController.text.trim();
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setString('global_phone', phone);
                    setState(() {
                      _globalPhone = phone;
                    });
                  });
                } else {
                  _forceLogin();
                }
              },
              style: AppButtonStyles.primary(radius: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildRoleSelectionDesktop(BuildContext context, Size size) {
    return Row(
      children: [
        // LEFT SIDE: 3D Illustration
        Expanded(
          flex: 5,
          child: Container(
            color: AppColors.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Illustration
                Image.asset(
                  'assets/images/kirana_web_hero.jpg',
                  fit: BoxFit.cover,
                ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.05, end: 0, duration: 800.ms),
                // Foreground leaves/depth effect could be added here if assets available
              ],
            ),
          ),
        ),
        
        // RIGHT SIDE: Glass Role Panel
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFFDFBF7), // Warm Cream / Ivory
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _buildRolePanel(context, true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelectionMobile(BuildContext context, Size size) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Illustration Half
          SizedBox(
            height: size.height * 0.4,
            width: double.infinity,
            child: Image.asset(
              'assets/images/kirana_web_hero.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          
          // Panel Half
          Container(
            color: const Color(0xFFFDFBF7),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: _buildRolePanel(context, false),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePanel(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 48 : 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Storefront Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 40,
            ),
          ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),
          
          const SizedBox(height: 24),
          
          // Heading
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 32),
              children: [
                const TextSpan(text: 'Welcome to '),
                TextSpan(
                  text: 'NearKirana',
                  style: TextStyle(color: AppColors.primaryDark),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: 12),
          
          // Subtitle
          Text(
            'Choose your role',
            style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms),
          
          const SizedBox(height: 48),
          
          // Role Cards
          _buildRoleCard(
            title: 'I am a Customer',
            subtitle: 'Order items from nearby shops',
            icon: Icons.shopping_basket_rounded,
            color: AppColors.primaryDark,
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            onTap: _selectCustomerRole,
            delay: 400.ms,
          ),
          
          const SizedBox(height: 24),
          
          _buildRoleCard(
            title: 'I am a Shop Owner',
            subtitle: 'Register your shop and take orders online',
            icon: Icons.store_mall_directory_rounded,
            color: AppColors.accentPink, // Soft pink/saffron
            backgroundColor: AppColors.accentPink.withValues(alpha: 0.05),
            onTap: _selectAdminRole,
            delay: 500.ms,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideX(begin: 0.05, end: 0, duration: 800.ms);
  }
}
