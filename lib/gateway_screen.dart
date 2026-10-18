import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
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
import 'auth_service.dart';
import 'delivery_partner_screen.dart';
import 'language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/language_bottom_sheet.dart';

class GatewayScreen extends StatefulWidget {
  final bool forceSelectRole;
  const GatewayScreen({super.key, this.forceSelectRole = false});

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

    if (widget.forceSelectRole) {
      setState(() => _isLoading = false);
      return;
    }

    if (_globalPhone != null && _globalPhone!.isNotEmpty) {
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final currentShopId = shopProvider.currentShopId;
      await AuthService().syncUserProfile(
        phone: _globalPhone!,
        role: role == 'admin' ? 'shop_owner' : 'customer',
        shopId: role == 'admin' ? currentShopId : null,
      );
      if (!mounted) return;
      if (role == 'customer') {
        if (shopProvider.currentShopId != null && shopProvider.currentShopId!.isNotEmpty) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ShopSelectorScreen()));
        }
      } else if (role == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
      } else if (role == 'delivery_partner') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DeliveryPartnerScreen(initialPhone: _globalPhone)));
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
        await AuthService().syncUserProfile(
          phone: _globalPhone!,
          role: 'customer',
          name: name,
        );
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
      await AuthService().syncUserProfile(
        phone: _globalPhone!,
        role: 'shop_owner',
        shopId: shopId,
        name: ownerName,
      );
      
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

  Future<void> _selectDeliveryPartnerRole() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_role', 'delivery_partner');
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryPartnerScreen(
          initialPhone: _globalPhone,
        ),
      ),
    );
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
    String? badgeText,
    Color? badgeColor,
    Color? badgeBgColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.22), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBgColor ?? color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: badgeColor ?? color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.08, end: 0);
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
    LanguageProvider? langProvider;
    try {
      langProvider = Provider.of<LanguageProvider>(context);
    } catch (_) {}
    final isHindi = langProvider?.isHindi ?? false;
    final isHinglish = langProvider?.isHinglish ?? false;

    final deliveryBadgeText = isHindi
        ? '10-25 मिनट में तेज़ डिलीवरी'
        : (isHinglish ? '10-25 Mins me Tez Delivery' : '10-25 MINS DELIVERY');

    return Column(
      children: [
        // Top Bar with Speed Badge & Language Pill (Zepto/Blinkit style)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF047857).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFF047857),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deliveryBadgeText,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
              const LanguageTogglePill(),
            ],
          ),
        ),

        // Auth Card Centered & Scrollable
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _buildAuthCard(context, false),
              ),
            ),
          ),
        ),
      ],
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
    LanguageProvider? langProvider;
    try {
      langProvider = Provider.of<LanguageProvider>(context);
    } catch (_) {}
    final isHindi = langProvider?.isHindi ?? false;
    final isHinglish = langProvider?.isHinglish ?? false;

    final String brandSubtitle = isHindi
        ? 'ताज़ा किराना व सामान आपके दरवाज़े पर'
        : (isHinglish
            ? 'Fresh groceries aur daily items seedhe ghar par'
            : 'Fresh Groceries & Daily Essentials');

    final String featDelivery = isHindi
        ? '10-25 मिनट'
        : (isHinglish ? '10-25 Mins' : '10-25 Mins');

    final String featPrice = isHindi
        ? 'किफायती दाम'
        : (isHinglish ? 'Best Prices' : 'Best Prices');

    final String featSafety = isHindi
        ? 'सुरक्षित व आसान'
        : (isHinglish ? '100% Safe' : '100% Safe');

    final String phoneLabel = isHindi
        ? 'अपना मोबाइल नंबर दर्ज करें'
        : (isHinglish
            ? 'Apna mobile number daalein'
            : 'Enter your mobile number');

    final String phoneHint = isHindi
        ? '10 अंकों का नंबर'
        : (isHinglish
            ? '10-digit mobile number'
            : 'Enter 10-digit mobile number');

    final String continueBtnText = isHindi
        ? 'आगे बढ़ें'
        : (isHinglish ? 'Continue Karein' : 'Continue');

    final String termsText = isHindi
        ? 'जारी रखकर आप हमारी सेवा की शर्तों और गोपनीयता नीति से सहमत हैं'
        : (isHinglish
            ? 'Continue karke aap hamari Terms of Service & Privacy Policy se agree karte hain'
            : 'By continuing, you agree to our Terms of Service & Privacy Policy');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 36 : 18,
        vertical: isDesktop ? 36 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDesktop ? 0.95 : 1.0),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDesktop ? Colors.grey.shade200 : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isDesktop) ...[
            Align(
              alignment: Alignment.topRight,
              child: const LanguageTogglePill(),
            ),
            const SizedBox(height: 8),
          ],

          // Zepto / Blinkit Brand Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF047857), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF047857).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ).animate().scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NearKirana',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF047857),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Instant Local Delivery',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.1, end: 0),
            ],
          ),
          const SizedBox(height: 14),

          // Subtitle
          Text(
            brandSubtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
              height: 1.3,
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 18),

          // Zepto/Blinkit Style 3 Trust Feature Badges
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildTrustBadge(
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFFD97706),
                label: featDelivery,
                bgColor: const Color(0xFFFEF3C7),
              ),
              _buildTrustBadge(
                icon: Icons.verified_rounded,
                iconColor: const Color(0xFF059669),
                label: featPrice,
                bgColor: const Color(0xFFD1FAE5),
              ),
              _buildTrustBadge(
                icon: Icons.security_rounded,
                iconColor: const Color(0xFF2563EB),
                label: featSafety,
                bgColor: const Color(0xFFDBEAFE),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 28),

          // Input Field Title
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              phoneLabel,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
          ).animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 8),

          // Modern Rounded Phone Input Container
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.phone_android_rounded,
                        size: 20,
                        color: Color(0xFF047857),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+91',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1.2,
                  height: 24,
                  color: const Color(0xFFCBD5E1),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: GoogleFonts.poppins(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                      letterSpacing: 1.2,
                    ),
                    decoration: InputDecoration(
                      hintText: phoneHint,
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade400,
                        letterSpacing: 0,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08, end: 0),

          const SizedBox(height: 22),

          // Continue Button (Zepto / Blinkit Vibrant Green Button)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                if (_phoneController.text.length != 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid 10-digit mobile number'),
                    ),
                  );
                  return;
                }
                // Auth call
                if (kIsWeb || kDebugMode) {
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    continueBtnText,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.08, end: 0),

          const SizedBox(height: 18),

          // Terms and Privacy Footer (With lock icon, NO emojis)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 13,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  termsText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildTrustBadge({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
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
    LanguageProvider? langProvider;
    try {
      langProvider = Provider.of<LanguageProvider>(context);
    } catch (_) {}
    final isHindi = langProvider?.isHindi ?? false;
    final isHinglish = langProvider?.isHinglish ?? false;

    final speedText = isHindi
        ? '10-25 मिनट में तेज़ डिलीवरी'
        : (isHinglish ? '10-25 Mins Tez Delivery' : '10-25 MINS DELIVERY');

    return Column(
      children: [
        // Top Bar with Speed Badge & Language Pill (Zepto/Blinkit style)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF047857).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFF047857),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      speedText,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
              const LanguageTogglePill(),
            ],
          ),
        ),

        // Role Panel Centered & Scrollable
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _buildRolePanel(context, false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRolePanel(BuildContext context, bool isDesktop) {
    LanguageProvider? langProvider;
    try {
      langProvider = Provider.of<LanguageProvider>(context);
    } catch (_) {}
    final isHindi = langProvider?.isHindi ?? false;
    final isHinglish = langProvider?.isHinglish ?? false;

    final String heading = isHindi
        ? 'NearKirana में आपका स्वागत है'
        : (isHinglish ? 'NearKirana me Welcome' : 'Welcome to NearKirana');

    final String subtitle = isHindi
        ? 'आगे बढ़ने के लिए अपनी भूमिका चुनें'
        : (isHinglish ? 'Aage badhne ke liye apna role chunein' : 'Select how you would like to proceed');

    // Role translations
    final String custTitle = isHindi ? 'ग्राहक (Customer)' : (isHinglish ? 'Customer (Grahak)' : 'I am a Customer');
    final String custSub = isHindi
        ? 'पास की दुकानों से ताज़ा किराना ऑर्डर करें'
        : (isHinglish ? 'Aas-paas ki kirana dukano se order mangwayein' : 'Order groceries & essentials from nearby shops');
    final String custBadge = isHindi ? '⚡ 10-25 मिनट' : (isHinglish ? '⚡ 10-25 Mins' : '⚡ 10-25 Mins');

    final String shopTitle = isHindi ? 'दुकानदार (Shop Owner)' : (isHinglish ? 'Shop Owner (Dukandar)' : 'I am a Shop Owner');
    final String shopSub = isHindi
        ? 'दुकान रजिस्टर करें और ऑनलाइन ऑर्डर स्वीकार करें'
        : (isHinglish ? 'Apni dukan register karein aur online orders lein' : 'Register your shop & receive online orders');
    final String shopBadge = isHindi ? '📈 बिज़नेस बढ़ाएं' : (isHinglish ? '📈 Grow Business' : '📈 Grow Business');

    final String riderTitle = isHindi ? 'डिलीवरी पार्टनर (Rider)' : (isHinglish ? 'Delivery Partner (Rider)' : 'I am a Delivery Partner');
    final String riderSub = isHindi
        ? 'स्थानीय दुकानों के ऑर्डर पहुंचाएं व रोज़ कमाएं'
        : (isHinglish ? 'Local shops ke orders deliver karein aur daily kamayein' : 'Deliver orders for local kiranas & earn daily');
    final String riderBadge = isHindi ? '🛵 दैनिक कमाई' : (isHinglish ? '🛵 Daily Payouts' : '🛵 Daily Payouts');

    return Container(
      padding: EdgeInsets.all(isDesktop ? 36 : 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Storefront Icon Pill
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 30,
            ),
          ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms),
          
          const SizedBox(height: 14),
          
          // Heading
          Text(
            heading,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: isDesktop ? 26 : 21,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.15, end: 0),
          
          const SizedBox(height: 4),
          
          // Subtitle
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),

          if (_globalPhone != null && _globalPhone!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF047857),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+91 $_globalPhone',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('global_phone');
                      await prefs.remove('app_role');
                      if (context.mounted) {
                        setState(() {
                          _globalPhone = null;
                        });
                      }
                    },
                    child: Text(
                      isHindi ? 'नंबर बदलें' : (isHinglish ? 'Change' : 'Change'),
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF047857),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 18),
          
          // Customer Role Card
          _buildRoleCard(
            title: custTitle,
            subtitle: custSub,
            icon: Icons.shopping_bag_rounded,
            color: const Color(0xFF047857),
            backgroundColor: const Color(0xFFF0FDF4),
            badgeText: custBadge,
            badgeColor: const Color(0xFF047857),
            badgeBgColor: const Color(0xFFD1FAE5),
            onTap: _selectCustomerRole,
            delay: 250.ms,
          ),
          
          const SizedBox(height: 12),
          
          // Shop Owner Role Card
          _buildRoleCard(
            title: shopTitle,
            subtitle: shopSub,
            icon: Icons.store_mall_directory_rounded,
            color: const Color(0xFF7C3AED), // Vibrant purple
            backgroundColor: const Color(0xFFFAF5FF),
            badgeText: shopBadge,
            badgeColor: const Color(0xFF7C3AED),
            badgeBgColor: const Color(0xFFEDE9FE),
            onTap: _selectAdminRole,
            delay: 350.ms,
          ),
          
          const SizedBox(height: 12),
          
          // Delivery Partner Role Card
          _buildRoleCard(
            title: riderTitle,
            subtitle: riderSub,
            icon: Icons.two_wheeler_rounded,
            color: const Color(0xFFEA580C), // Orange
            backgroundColor: const Color(0xFFFFF7ED),
            badgeText: riderBadge,
            badgeColor: const Color(0xFFEA580C),
            badgeBgColor: const Color(0xFFFFEDD5),
            onTap: _selectDeliveryPartnerRole,
            delay: 450.ms,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0, duration: 600.ms);
  }
}
