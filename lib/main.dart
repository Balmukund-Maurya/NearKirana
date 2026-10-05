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
import 'sound_service.dart';
import 'modern_loader.dart';
import 'shop_selector_screen.dart';
import 'gateway_screen.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:phone_email_auth/phone_email_auth.dart';
import 'custom_auth_screen.dart';

import 'package:flutter/foundation.dart'; // Added for kIsWeb

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      await prefs.setBool('hasMigratedSearchKeywordsV2', true);
    } catch (e) {
      debugPrint('Migration failed: $e');
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
      await prefs.setBool('hasMigratedCategoriesV1', true);
    } catch (e) {
      debugPrint('Category Migration failed: $e');
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
          locale: Locale(langProvider.currentLanguage),
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



  void _showLanguageBottomSheet(BuildContext context) {
    SoundService().languageSwitch();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final langProvider = Provider.of<LanguageProvider>(context);
        return Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.bgTint,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        AppLocalizations.of(context)!.language,
                        style: AppTextStyles.heading2(),
                      ),
                      const SizedBox(height: 20),
                      _buildLangOption(
                        context,
                        langProvider,
                        'hinglish',
                        'Hinglish',
                        '🇮🇳',
                        'Roman Hindi',
                      ),
                      _buildLangOption(
                        context,
                        langProvider,
                        'hi',
                        'हिंदी',
                        '🔤',
                        'Devanagari',
                      ),
                      _buildLangOption(
                        context,
                        langProvider,
                        'en',
                        'English',
                        '🌐',
                        'English',
                      ),
                    ],
                  ),
                ),
              ),
            )
            .animate()
            .slideY(begin: 0.3, end: 0, duration: 350.ms, curve: Curves.easeOut)
            .fadeIn(duration: 300.ms);
      },
    );
  }

  Widget _buildLangOption(
    BuildContext context,
    LanguageProvider langProvider,
    String code,
    String label,
    String emoji,
    String desc,
  ) {
    final isSelected = langProvider.currentLanguage == code;
    return GestureDetector(
      onTap: () {
        langProvider.setLanguage(code);
        SoundService().languageSwitch();
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.3)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySemiBold(
                    color: isSelected
                        ? AppColors.primaryDark
                        : AppColors.textDark,
                  ),
                ),
                Text(desc, style: AppTextStyles.caption()),
              ],
            ),
            const Spacer(),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.white,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Continue'),
            )
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
        if (loginData.accessTokenn != null && loginData.accessTokenn!.isNotEmpty) {
          _handlePhoneEmailAuth(loginData.accessTokenn!);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP Failed: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
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
    final shopName = shopProvider.shopName ?? AppLocalizations.of(context)!.app_name;
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

  Widget _buildDesktopLayout(BuildContext context, Size size, LanguageProvider langProvider, String shopName) {
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
                    child: _buildAuthCard(context, langProvider, shopName, true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, Size size, LanguageProvider langProvider, String shopName) {
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

  Widget _buildAuthCard(BuildContext context, LanguageProvider langProvider, String shopName, bool isDesktop) {
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
          // Language toggle (top right)
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => _showLanguageBottomSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌐', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      langProvider.currentLanguage == 'hi'
                          ? 'हिं'
                          : langProvider.currentLanguage == 'en'
                              ? 'EN'
                              : 'Hi',
                      style: AppTextStyles.captionMedium(
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: AppColors.textMid,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                  child: TextField(
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
                
                // Call existing auth
                if (kIsWeb) {
                  _handleWebLoginFallback(_phoneController.text.trim());
                } else {
                  _startCustomPhoneLogin();
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
          
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.bgTint, thickness: 1.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(AppLocalizations.of(context)!.or_divider, style: AppTextStyles.caption()),
              ),
              Expanded(child: Divider(color: AppColors.bgTint, thickness: 1.5)),
            ],
          ).animate().fadeIn(delay: 650.ms),
          
          const SizedBox(height: 24),
          
          // Admin/Owner login
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: Text(AppLocalizations.of(context)!.owner_login),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMid),
          ).animate().fadeIn(delay: 700.ms),
          
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Change Shop?'),
                  content: const Text('Do you want to leave this shop and choose another? Your cart will be cleared.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                      child: const Text('Yes, Change Shop'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await Provider.of<ShopProvider>(context, listen: false).clearShop();
                if (context.mounted) {
                  Provider.of<CartProvider>(context, listen: false).clearCart();
                }
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
            label: const Text('Change Shop'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
          ).animate().fadeIn(delay: 750.ms),
          
        ],
      ),
    );
  }
}
