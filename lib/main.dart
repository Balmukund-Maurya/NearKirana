import 'package:flutter/services.dart';
import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'firebase_options.dart';
import 'home_screen.dart';
import 'admin_login_screen.dart';
import 'cart_provider.dart';
import 'notification_service.dart';
import 'search_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_provider.dart';
import 'user_provider.dart';
import 'shop_provider.dart';
import 'wishlist_provider.dart';
import 'admin_dashboard.dart';
import 'app_theme.dart';
import 'modern_loader.dart';
import 'shop_selector_screen.dart';
import 'gateway_screen.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:phone_email_auth/phone_email_auth.dart';
import 'custom_auth_screen.dart';
import 'auth_service.dart';
import 'crash_reporting_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/language_bottom_sheet.dart';

import 'package:flutter/foundation.dart'; // Added for kIsWeb

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashReportingService().init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService().ensureAuthenticated();
  if (!kIsWeb) {
    try {
      PhoneEmail.initializeApp(clientId: '17194425783292968499');
    } catch (e) {
      debugPrint('PhoneEmail init error: $e');
    }
  }

  final shopProvider = ShopProvider();
  await shopProvider.loadCurrentShop();

  // One-time database migration to add 'searchKeywords' for fast substring searching
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool('hasMigratedSearchKeywordsV2') ?? false)) {
    try {
      final docs = await FirebaseUtils.firestore.collection('products').get();
      for (var doc in docs.docs) {
        final data = doc.data();
        if (data.containsKey('name')) {
          await doc.reference.update({
            'searchKeywords': generateSearchKeywords(data['name'].toString()),
            'searchName': FieldValue.delete(), // clean up old field if exists
          });
        }
      }
    } catch (e) {
      debugPrint('SearchKeywords migration skipped/failed: $e');
    } finally {
      await prefs.setBool('hasMigratedSearchKeywordsV2', true);
    }
  }

  // One-time database migration to convert 'category' (String) to 'categories' (List)
  if (!(prefs.getBool('hasMigratedCategoriesV1') ?? false)) {
    try {
      debugPrint('Starting category migration in main...');
      final docs = await FirebaseUtils.firestore.collection('products').get();
      final batch = FirebaseUtils.firestore.batch();
      int migratedCount = 0;
      for (var doc in docs.docs) {
        final data = doc.data();
        if (data.containsKey('category') && !data.containsKey('categories')) {
          final oldCat = data['category'] as String?;
          if (oldCat != null && oldCat.isNotEmpty) {
            batch.update(doc.reference, {
              'categories': [oldCat],
              'category': FieldValue.delete(),
            });
            migratedCount++;
          }
        }
      }
      if (migratedCount > 0) {
        await batch.commit();
        debugPrint(
          'Successfully migrated $migratedCount products to new categories array.',
        );
      }
    } catch (e) {
      debugPrint('Category Migration skipped/failed: $e');
    } finally {
      await prefs.setBool('hasMigratedCategoriesV1', true);
    }
  }

  // Explicitly enable offline persistence
  FirebaseUtils.firestore.settings = const Settings(persistenceEnabled: true);

  // Removed unused savedLanguage variable
  await NotificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: shopProvider),
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => WishlistProvider()),
      ],
      child: const NearKiranaApp(),
    ),
  );
}

class NearKiranaApp extends StatelessWidget {
  const NearKiranaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, child) {
        return MaterialApp(
          title: 'NearKirana',
          theme: AppTheme.theme,
          debugShowCheckedModeBanner: false,
          locale: langProvider.currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GatewayScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/shop-selector': (context) => const ShopSelectorScreen(),
            '/gateway': (context) => const GatewayScreen(),
          },
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  final bool fromLogout;
  const LoginScreen({super.key, this.fromLogout = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = true;
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!widget.fromLogout) {
      _checkExistingLogin();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _checkExistingLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final bool isAdmin = prefs.getBool('isAdminLoggedIn') ?? false;
    if (isAdmin) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
      return;
    }

    final String? savedName = prefs.getString('customerName');
    final String? savedPhone = prefs.getString('customerPhone');
    final String? savedAddress = prefs.getString('customerAddress');
    final String? savedHouseNo = prefs.getString('customerHouseNo');
    final String? savedLandmark = prefs.getString('customerLandmark');

    if (savedPhone != null && savedPhone.isNotEmpty) {
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUser(
        savedName ?? '',
        savedPhone,
        address: savedAddress ?? '',
        houseNo: savedHouseNo ?? '',
        landmark: savedLandmark ?? '',
      );

      await userProvider.checkServiceability();

      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );

      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }



  void _promptForNameAndRegister(String phone) {
    String newName = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Welcome to NearKirana!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please enter your name to continue.'),
              const SizedBox(height: 16),
              TextField(
                onChanged: (val) => newName = val,
                decoration: const InputDecoration(
                  hintText: 'Your Name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (newName.trim().isNotEmpty) {
                  Navigator.pop(dialogContext);
                  setState(() => _isLoading = true);
                  try {
                    await FirebaseUtils.firestore.collection('customers').add({
                      'name': newName.trim(),
                      'mobile': phone,
                      'pin': 'PHONE_AUTH', // Marks user as Online
                      'total_udhaar': 0,
                      'auto_reminder': false,
                      'created_at': FieldValue.serverTimestamp(),
                    });
                    if (!mounted) return;
                    _completeLogin(newName.trim(), phone);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startCustomPhoneLogin() async {
    try {
      final value = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomAuthScreen()),
      );
      if (value != null && value[AppConstant.authResponse] != null) {
        final loginData = value[AppConstant.authResponse] as LoginModel;
        if (loginData.accessTokenn != null &&
            loginData.accessTokenn!.isNotEmpty) {
          _handlePhoneEmailAuth(loginData.accessTokenn!);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OTP Failed: $e')));
    }
  }

  Future<void> _handleWebLoginFallback(String phone) async {
    setState(() => _isLoading = true);
    try {
      final querySnapshot = await FirebaseUtils.firestore
          .collection('customers')
          .where('mobile', isEqualTo: phone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final dbName = data['name'] as String? ?? 'User';
        if (!data.containsKey('pin')) {
          await doc.reference.update({'pin': 'PHONE_AUTH'});
        }
        _completeLogin(dbName, phone);
      } else {
        setState(() => _isLoading = false);
        _promptForNameAndRegister(phone);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _handlePhoneEmailAuth(String accessToken) {
    setState(() => _isLoading = true);
    PhoneEmail.getUserInfo(
      accessToken: accessToken,
      clientId: '17194425783292968499',
      onSuccess: (userData) async {
        if (!mounted) return;
        String? rawPhone = userData.phoneNumber;
        if (rawPhone == null || rawPhone.isEmpty) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to retrieve phone number.')),
          );
          return;
        }

        // Normalize to exactly 10 digits to match existing db records
        String phone = rawPhone.replaceAll(RegExp(r'\D'), '');
        if (phone.length > 10) {
          phone = phone.substring(phone.length - 10);
        }

        try {
          final querySnapshot = await FirebaseUtils.firestore
              .collection('customers')
              .where('mobile', isEqualTo: phone)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final doc = querySnapshot.docs.first;
            final data = doc.data();
            final dbName = data['name'] as String? ?? 'User';

            // If user was offline (created by Admin without PIN), mark them as online
            if (!data.containsKey('pin')) {
              await doc.reference.update({'pin': 'PHONE_AUTH'});
            }

            _completeLogin(dbName, phone);
          } else {
            setState(() => _isLoading = false);
            _promptForNameAndRegister(phone);
          }
        } catch (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      },
    );
  }

  Future<void> _completeLogin(String name, String phone) async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customerName', name);
    await prefs.setString('customerPhone', phone);

    if (mounted) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUser(name, phone);
      await userProvider.checkServiceability();

      if (mounted) {
        final navigator = Navigator.of(context);
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);
    final size = MediaQuery.of(context).size;
    final shopName =
        shopProvider.shopName ?? AppLocalizations.of(context)!.app_name;
    final isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                        width: 70,
                        height: 70,
                        decoration: AppDecorations.primaryGradient(radius: 20),
                        child: const Icon(
                          Icons.shopping_basket_rounded,
                          color: AppColors.white,
                          size: 36,
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(
                        begin: 1.0,
                        end: 1.1,
                        duration: 700.ms,
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(height: 24),
                  ModernLoader(color: AppColors.primaryDark),
                ],
              ),
            )
          : SafeArea(
              child: isDesktop
                  ? _buildDesktopLayout(context, size, langProvider, shopName)
                  : _buildMobileLayout(context, size, langProvider, shopName),
            ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    Size size,
    LanguageProvider langProvider,
    String shopName,
  ) {
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
                    )
                    .animate()
                    .fadeIn(duration: 800.ms)
                    .scale(
                      begin: const Offset(1.05, 1.05),
                      end: const Offset(1, 1),
                      duration: 800.ms,
                    ),

                // Overlay for better text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
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
                      _buildFeatureCard(
                        Icons.local_shipping_rounded,
                        'Fast Delivery',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureCard(
                        Icons.verified_rounded,
                        'Trusted Quality',
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildAuthCard(
                      context,
                      langProvider,
                      shopName,
                      true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    Size size,
    LanguageProvider langProvider,
    String shopName,
  ) {
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
                      colors: [
                        AppColors.surface,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                      ],
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
            child: _buildAuthCard(context, langProvider, shopName, false),
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
              ),
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
        )
        .animate()
        .slideX(begin: -0.2, end: 0, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildTrustBadge({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildAuthCard(
    BuildContext context,
    LanguageProvider langProvider,
    String shopName,
    bool isDesktop,
  ) {
    final lang = langProvider.currentLanguage;
    final isHindi = langProvider.isHindi;
    final isHinglish = langProvider.isHinglish;

    final String brandSubtitle = isHindi
        ? 'ताज़ा किराना व सामान आपके दरवाज़े पर'
        : (isHinglish
            ? 'Fresh groceries aur daily items seedhe ghar par'
            : 'Fresh Groceries & Daily Essentials');

    final String featDelivery = isHindi
        ? '10-25 मिनट'
        : (isHinglish ? '10-25 Mins' : '10-25 Mins');

    final String featPrice = isHindi
        ? 'सर्वोत्तम दाम'
        : (isHinglish ? 'Best Prices' : 'Best Prices');

    final String featSafety = isHindi
        ? '100% सुरक्षित'
        : (isHinglish ? '100% Safe' : '100% Safe');

    final String phoneLabel = isHindi
        ? 'अपना मोबाइल नंबर दर्ज करें'
        : (isHinglish
            ? 'Apna mobile number dalein'
            : 'Enter your mobile number');

    final String phoneHint = isHindi
        ? '10 अंकों का नंबर'
        : (isHinglish
            ? '10-digit mobile number'
            : 'Enter 10-digit number');

    final String continueBtnText = isHindi
        ? 'आगे बढ़ें (Continue)'
        : (isHinglish ? 'Aage Badhein' : 'Continue');

    final String termsText = isHindi
        ? 'जारी रखकर आप हमारी सेवा की शर्तों और गोपनीयता नीति से सहमत हैं'
        : (isHinglish
            ? 'Continue karke aap hamari Terms of Service & Privacy Policy se agree karte hain'
            : 'By continuing, you agree to our Terms of Service & Privacy Policy');

    final String orDivider = isHindi
        ? 'या'
        : (isHinglish ? 'ya' : 'or');

    final String ownerLoginText = isHindi
        ? 'दुकानदार लॉगिन'
        : (isHinglish ? 'Shop Owner Login' : 'Shop Owner Login');

    final String changeShopText = isHindi
        ? 'दुकान बदलें'
        : (isHinglish ? 'Change Shop' : 'Change Shop');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 36 : 20,
        vertical: isDesktop ? 36 : 22,
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
          // Top Language Toggle Pill
          Align(
            alignment: Alignment.topRight,
            child: const LanguageTogglePill(),
          ),
          const SizedBox(height: 6),

          // Zepto Brand Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF047857), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF047857).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ).animate().scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                duration: 450.ms,
                curve: Curves.easeOutBack,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName.isNotEmpty && shopName != 'NearKirana'
                        ? shopName
                        : 'NearKirana',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF047857),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Instant Local Delivery',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.1, end: 0),
            ],
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text(
            brandSubtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
              height: 1.3,
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 16),

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

          const SizedBox(height: 24),

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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08, end: 0),

          const SizedBox(height: 20),

          // Full-Width Zepto Green Continue Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (_phoneController.text.length != 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        lang == 'hi'
                            ? 'कृपया 10 अंकों का वैध मोबाइल नंबर दर्ज करें'
                            : (lang == 'hinglish'
                                ? 'Kripya 10-digit ka valid mobile number dalein'
                                : 'Please enter a valid 10-digit mobile number'),
                      ),
                      backgroundColor: const Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                // Call existing auth
                if (kIsWeb) {
                  _handleWebLoginFallback(_phoneController.text.trim());
                } else {
                  _startCustomPhoneLogin();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: const Color(0xFF047857).withValues(alpha: 0.35),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.08, end: 0),

          const SizedBox(height: 14),

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

          const SizedBox(height: 20),

          // Divider
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  orDivider,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
            ],
          ).animate().fadeIn(delay: 550.ms),

          const SizedBox(height: 16),

          // Admin/Owner login
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: Text(
              ownerLoginText,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
            ),
          ).animate().fadeIn(delay: 600.ms),

          const SizedBox(height: 8),

          // Change Shop Button
          TextButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    lang == 'hi'
                        ? 'दुकान बदलें?'
                        : (lang == 'hinglish' ? 'Shop badlein?' : 'Change Shop?'),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                  content: Text(
                    lang == 'hi'
                        ? 'क्या आप इस दुकान से बाहर निकलकर दूसरी दुकान चुनना चाहते हैं? आपकी कार्ट खाली हो जाएगी।'
                        : (lang == 'hinglish'
                            ? 'Kya aap doosri shop choose karna chahte hain? Aapka cart khali ho jayega.'
                            : 'Do you want to leave this shop and choose another? Your cart will be cleared.'),
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        lang == 'hi' ? 'रद्द करें' : 'Cancel',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                      ),
                      child: Text(
                        lang == 'hi' ? 'हाँ, दुकान बदलें' : 'Yes, Change Shop',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await Provider.of<ShopProvider>(
                  context,
                  listen: false,
                ).clearShop();
                if (context.mounted) {
                  Provider.of<CartProvider>(context, listen: false).clearCart();
                }
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ShopSelectorScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: Text(
              changeShopText,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF047857),
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF047857)),
          ).animate().fadeIn(delay: 650.ms),
        ],
      ),
    );
  }
}
