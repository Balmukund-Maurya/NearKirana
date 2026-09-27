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
    final shopName =
        shopProvider.shopName ?? AppLocalizations.of(context)!.app_name;

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
          : Stack(
              children: [
                // Background blobs
                Positioned(
                  top: -60,
                  right: -60,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -80,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: AppColors.accentPink.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: size.height * 0.4,
                  right: -30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.warmCard.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                SafeArea(
                  child: Column(
                    children: [
                      // Language toggle (top right)
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child:
                              GestureDetector(
                                    onTap: () =>
                                        _showLanguageBottomSheet(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.06,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '🌐',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            langProvider.currentLanguage == 'hi'
                                                ? 'हिं'
                                                : langProvider
                                                          .currentLanguage ==
                                                      'en'
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
                                  )
                                  .animate(delay: 200.ms)
                                  .fadeIn(duration: 400.ms)
                                  .slideX(begin: 0.2, end: 0),
                        ),
                      ),

                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 450),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 16),
                                  
                                  // Logo
                              Container(
                                    width: 90,
                                    height: 90,
                                    decoration: AppDecorations.primaryGradient(
                                      radius: 24,
                                    ),
                                    child: const Icon(
                                      Icons.shopping_basket_rounded,
                                      color: AppColors.white,
                                      size: 44,
                                    ),
                                  )
                                  .animate()
                                  .scale(
                                    begin: const Offset(0, 0),
                                    end: const Offset(1, 1),
                                    duration: 600.ms,
                                    curve: Curves.elasticOut,
                                  )
                                  .fadeIn(duration: 400.ms),

                              const SizedBox(height: 24),

                              Text(
                                    shopName,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.display(),
                                  )
                                  .animate(delay: 150.ms)
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: 0.2, end: 0),

                              const SizedBox(height: 8),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: AppDecorations.pill(
                                  color: AppColors.bgTint,
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.subtitle,
                                  style: AppTextStyles.captionMedium(
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ).animate(delay: 250.ms).fadeIn(duration: 400.ms),

                              const SizedBox(height: 48),

                              SizedBox(
                                    width: double.infinity,
                                    height: 58,
                                    child: kIsWeb
                                        ? ElevatedButton(
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Phone.email authentication is currently not supported on Web. Please use the mobile app.'),
                                                ),
                                              );
                                            },
                                            style: AppButtonStyles.primary(radius: 16),
                                            child: const Text('Sign in with Phone (Web Not Supported)'),
                                          )
                                        : ElevatedButton(
                                            onPressed: _startCustomPhoneLogin,
                                            style: AppButtonStyles.primary(radius: 16),
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.phone, color: Colors.white, size: 20),
                                                SizedBox(width: 8),
                                                Text('Sign in with Phone', style: TextStyle(color: Colors.white, fontSize: 16)),
                                              ],
                                            ),
                                          ),
                                  )
                                  .animate(delay: 350.ms)
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: 0.15, end: 0),
                              
                              const SizedBox(height: 12),

                              TextButton.icon(
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Change Shop?'),
                                          content: const Text(
                                            'Do you want to leave this shop and choose another? Your cart will be cleared.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.primaryDark,
                                              ),
                                              child: const Text(
                                                'Yes, Change Shop',
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
                                          Provider.of<CartProvider>(
                                            context,
                                            listen: false,
                                          ).clearCart();
                                        }
                                        if (context.mounted) {
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const ShopSelectorScreen(),
                                            ),
                                            (route) => false,
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.swap_horiz_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Change Shop'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primaryDark,
                                    ),
                                  )
                                  .animate(delay: 600.ms)
                                  .fadeIn(duration: 300.ms)
                                  .slideY(begin: 0.05, end: 0),

                              const SizedBox(height: 20),

                              Text(
                                AppLocalizations.of(context)!.terms,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.caption(),
                              ).animate(delay: 650.ms).fadeIn(duration: 400.ms),

                              const SizedBox(height: 32),

                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: AppColors.bgTint,
                                      thickness: 1.5,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      // FIX-13: Translated divider text
                                      AppLocalizations.of(context)!.or_divider,
                                      style: AppTextStyles.caption(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: AppColors.bgTint,
                                      thickness: 1.5,
                                    ),
                                  ),
                                ],
                              ).animate(delay: 700.ms).fadeIn(duration: 400.ms),

                              const SizedBox(height: 16),

                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminLoginScreen(),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  AppLocalizations.of(context)!.owner_login,
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textMid,
                                ),
                              ).animate(delay: 750.ms).fadeIn(duration: 400.ms),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
