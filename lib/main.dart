import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import 'map_selection_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final shopProvider = ShopProvider();
  await shopProvider.loadCurrentShop();

  // One-time database migration to add 'searchKeywords' for fast substring searching
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool('hasMigratedSearchKeywordsV2') ?? false)) {
    try {
      final docs = await FirebaseFirestore.instance
          .collection('products')
          .get();
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
      final docs = await FirebaseFirestore.instance.collection('products').get();
      final batch = FirebaseFirestore.instance.batch();
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
        debugPrint('Successfully migrated $migratedCount products to new categories array.');
      }
      await prefs.setBool('hasMigratedCategoriesV1', true);
    } catch (e) {
      debugPrint('Category Migration failed: $e');
    }
  }

  // Explicitly enable offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

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
      child: const AlwaysProApp(),
    ),
  );
}

class AlwaysProApp extends StatelessWidget {
  const AlwaysProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop App',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: Consumer<ShopProvider>(
        builder: (context, shopProvider, child) {
          if (shopProvider.currentShopId != null && shopProvider.currentShopId!.isNotEmpty) {
            return const LoginScreen();
          }
          return const ShopSelectorScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/shop-selector': (context) => const ShopSelectorScreen(),
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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
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

      if (userProvider.deliveryAddress.isEmpty) {
        navigator.push(
          MaterialPageRoute(
            builder: (context) => const MapSelectionScreen(
              initialLat: 0.0,
              initialLng: 0.0,
            ),
          ),
        );
      }
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
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? prefixText,
    TextInputType? keyboardType,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgTint, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.body(color: AppColors.textLight),
          prefixIcon: Icon(icon, color: AppColors.primaryDark, size: 22),
          prefixText: prefixText,
          prefixStyle: AppTextStyles.bodyMedium(color: AppColors.textDark),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          counterText: "",
        ),
        keyboardType: keyboardType,
        maxLength: maxLength,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: AppTextStyles.bodyMedium(),
      ),
    );
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
                        langProvider.translate('language'),
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

  Future<void> _handleLogin(String name, String phone) async {
    setState(() => _isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('mobile', isEqualTo: phone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        
        String finalName = name;
        final dbName = data['name'] as String? ?? '';
        final nameChangeCount = (data['name_change_count'] as num?)?.toInt() ?? 0;
        
        if (dbName.isNotEmpty && dbName != name) {
          if (nameChangeCount < 3) {
            await doc.reference.update({
              'name': name,
              'name_change_count': FieldValue.increment(1)
            });
            finalName = name;
          } else {
            finalName = dbName;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(behavior: SnackBarBehavior.floating, content: Text('Name change limit (3) reached. Logging in as $dbName.'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        } else {
          finalName = dbName.isNotEmpty ? dbName : name;
        }

        if (data.containsKey('pin') && data['pin'] != null) {
          // Returning user with PIN
          setState(() => _isLoading = false);
          _showPinDialog(
            finalName,
            phone,
            data['pin'],
            isNewUser: false,
            docRef: doc.reference,
          );
        } else {
          // Returning user (created by Admin) without PIN
          setState(() => _isLoading = false);
          _showPinDialog(
            finalName,
            phone,
            null,
            isNewUser: true,
            docRef: doc.reference,
          );
        }
      } else {
        // Completely new user
        setState(() => _isLoading = false);
        _showPinDialog(name, phone, null, isNewUser: true, docRef: null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error connecting to server. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPinDialog(
    String name,
    String phone,
    String? existingPin, {
    required bool isNewUser,
    DocumentReference? docRef,
  }) {
    final TextEditingController pinController = TextEditingController();
    bool isError = false;
    // FIX-7: Brute force protection
    int wrongAttempts = 0;
    bool isLockedOut = false;
    int lockoutSecondsRemaining = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: Text(
                isNewUser ? 'Create 4-Digit PIN' : 'Enter 4-Digit PIN',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isNewUser
                        ? 'Please create a 4-digit PIN to secure your account. Only you can order using this number.'
                        : 'Enter your 4-digit PIN to log in.',
                  ),
                  const SizedBox(height: 16),
                  // FIX-7: Show lockout message or PIN field
                  if (isLockedOut)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.lock_clock, color: Colors.red, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Too many wrong attempts!\nPlease wait $lockoutSecondsRemaining seconds.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else
                    TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      enabled: !isLockedOut,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        counterText: '',
                        errorText: isError ? 'Galat PIN hai' : null,
                      ),
                    ),
                  // FIX-7: Show attempt count warning
                  if (!isNewUser && wrongAttempts > 0 && !isLockedOut)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '$wrongAttempts/5 galat attempts. ${5 - wrongAttempts} baaki.',
                        style: TextStyle(
                          color: wrongAttempts >= 3 ? Colors.red : Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLockedOut ? null : () async {
                    if (pinController.text.length != 4) return;

                    if (isNewUser) {
                      // Save new PIN
                      Navigator.pop(dialogContext);
                      setState(() => _isLoading = true);

                      try {
                        if (docRef != null) {
                          await docRef.update({'pin': pinController.text});
                        } else {
                          await FirebaseFirestore.instance
                              .collection('customers')
                              .add({
                                'name': name,
                                'mobile': phone,
                                'pin': pinController.text,
                                'total_udhaar': 0,
                                'auto_reminder': false,
                                'created_at': FieldValue.serverTimestamp(),
                              });
                        }
                        _completeLogin(name, phone);
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error: $e')));
                      }
                    } else {
                      // Verify existing PIN
                      if (pinController.text == existingPin) {
                        Navigator.pop(dialogContext);
                        _completeLogin(name, phone);
                      } else {
                        setDialogState(() {
                          isError = true;
                          wrongAttempts++;
                          pinController.clear();
                        });

                        // FIX-7: Lockout after 5 wrong attempts
                        if (wrongAttempts >= 5) {
                          setDialogState(() {
                            isLockedOut = true;
                            lockoutSecondsRemaining = 30;
                          });
                          // Countdown timer
                          Future.doWhile(() async {
                            await Future.delayed(const Duration(seconds: 1));
                            if (!dialogContext.mounted) return false;
                            setDialogState(() {
                              lockoutSecondsRemaining--;
                            });
                            if (lockoutSecondsRemaining <= 0) {
                              setDialogState(() {
                                isLockedOut = false;
                                wrongAttempts = 0;
                                isError = false;
                              });
                              return false;
                            }
                            return true;
                          });
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isNewUser ? 'Save PIN' : 'Login'),
                ),
              ],
            );
          },
        );
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
        
        if (userProvider.deliveryAddress.isEmpty) {
          navigator.push(
            MaterialPageRoute(
              builder: (context) => const MapSelectionScreen(
                initialLat: 0.0,
                initialLng: 0.0,
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);
    final size = MediaQuery.of(context).size;
    final shopName = shopProvider.shopName ?? langProvider.translate('app_name');

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
                                  langProvider.translate('subtitle'),
                                  style: AppTextStyles.captionMedium(
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ).animate(delay: 250.ms).fadeIn(duration: 400.ms),

                              const SizedBox(height: 48),

                              _buildInputField(
                                    controller: _nameController,
                                    hintText: langProvider.translate(
                                      'name_hint',
                                    ),
                                    icon: Icons.person_outline_rounded,
                                    textCapitalization:
                                        TextCapitalization.words,
                                  )
                                  .animate(delay: 350.ms)
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: 0.15, end: 0),

                              const SizedBox(height: 16),

                              _buildInputField(
                                    controller: _mobileController,
                                    hintText: langProvider.translate(
                                      'mobile_hint',
                                    ),
                                    icon: Icons.phone_android_rounded,
                                    prefixText: '+91 ',
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  )
                                  .animate(delay: 450.ms)
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: 0.15, end: 0),

                              const SizedBox(height: 24),

                              SizedBox(
                                    width: double.infinity,
                                    height: 58,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final name = _nameController.text
                                            .trim();
                                        final phone = _mobileController.text
                                            .trim();
                                        if (phone.length == 10 &&
                                            name.isNotEmpty) {
                                          _handleLogin(name, phone);
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                                langProvider.translate(
                                                          'enter_button',
                                                        ) ==
                                                        'Enter'
                                                    ? 'Please enter your name and 10-digit mobile number'
                                                    : 'Kripya apna naam aur 10-digit mobile number dalein',
                                              ),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      },
                                      style: AppButtonStyles.primary(
                                        radius: 16,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.storefront_rounded,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            langProvider.translate(
                                              'enter_button',
                                            ),
                                            style: AppTextStyles.button(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .animate(delay: 550.ms)
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: 0.2, end: 0),

                              const SizedBox(height: 12),

                              TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Dukan Badlein?'),
                                      content: const Text(
                                        'Kya aap is dukan se bahar aakar doosri dukan chunna chahte hain? Aapka cart clear ho jayega.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                                          child: const Text('Haan, Badlein'),
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
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryDark,
                                ),
                              ).animate(delay: 600.ms).fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),

                              const SizedBox(height: 20),

                              Text(
                                langProvider.translate('terms'),
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
                                      langProvider.translate('or_divider'),
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
                                  langProvider.translate('owner_login'),
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
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
