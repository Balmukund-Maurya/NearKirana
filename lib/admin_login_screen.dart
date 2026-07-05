import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_dashboard.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'app_theme.dart';
import 'shop_selector_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'sound_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _hasError = false;
  bool _isLoading = false;
  bool _isBlocked = false;
  int _remainingMinutes = 0;

  @override
  void initState() {
    super.initState();
    _checkBlockStatus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBlockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    if (shopId == null || shopId.isEmpty) return;

    final blockedUntilMillis = prefs.getInt('admin_blocked_until_$shopId') ?? 0;
    if (blockedUntilMillis == 0) {
      if (mounted) {
        setState(() => _isBlocked = false);
      }
      return;
    }

    final blockedUntil = DateTime.fromMillisecondsSinceEpoch(blockedUntilMillis);
    if (DateTime.now().isBefore(blockedUntil)) {
      final minutesRemaining = blockedUntil.difference(DateTime.now()).inMinutes + 1;
      if (mounted) {
        setState(() {
          _isBlocked = true;
          _remainingMinutes = minutesRemaining;
        });
      }
    } else {
      await prefs.remove('admin_blocked_until_$shopId');
      await prefs.remove('admin_attempts_$shopId');
      if (mounted) {
        setState(() {
          _isBlocked = false;
          _remainingMinutes = 0;
        });
      }
    }
  }

  Future<void> _verifyAdminPIN(String enteredPin) async {
    if (enteredPin.isEmpty) return;

    await _checkBlockStatus();
    if (_isBlocked) {
      final msg = Provider.of<LanguageProvider>(context, listen: false).translate('login_blocked').replaceAll('{minutes}', _remainingMinutes.toString());
      _showSnackBar(msg, isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      if (shopId == null || shopId.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final msg = Provider.of<LanguageProvider>(context, listen: false).translate('select_shop_first');
        _showSnackBar(msg, isError: true);
        return;
      }

      final shopDoc = await FirebaseFirestore.instance.collection('shops').doc(shopId).get();
      if (!shopDoc.exists) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final msg = Provider.of<LanguageProvider>(context, listen: false).translate('shop_data_not_found');
        _showSnackBar(msg, isError: true);
        return;
      }

      final data = shopDoc.data();
      final correctAdminPin = data?['admin_pin']?.toString() ?? '';
      final prefs = await SharedPreferences.getInstance();

      if (enteredPin.trim() == correctAdminPin) {
        await prefs.remove('admin_attempts_$shopId');
        await prefs.remove('admin_blocked_until_$shopId');
        HapticFeedback.heavyImpact();
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboard()),
        );
      } else {
        final currentAttempts = (prefs.getInt('admin_attempts_$shopId') ?? 0) + 1;
        await prefs.setInt('admin_attempts_$shopId', currentAttempts);
        HapticFeedback.vibrate();
        SoundService().wrongPin();
        if (mounted) setState(() => _hasError = true);

        if (currentAttempts >= 3) {
          final blockUntil = DateTime.now().add(const Duration(hours: 1));
          await prefs.setInt('admin_blocked_until_$shopId', blockUntil.millisecondsSinceEpoch);
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isBlocked = true;
              _remainingMinutes = 60;
            });
          }
          final msg = Provider.of<LanguageProvider>(context, listen: false).translate('login_blocked_1_hour');
          _showSnackBar(msg, isError: true);
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          final attemptsLeft = 3 - currentAttempts;
          final msg = Provider.of<LanguageProvider>(context, listen: false).translate('wrong_pin_attempts').replaceAll('{attempts}', attemptsLeft.toString());
          _showSnackBar(msg, isError: true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = Provider.of<LanguageProvider>(context, listen: false).translate('network_error').replaceAll('{error}', e.toString());
      _showSnackBar(msg, isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).translate('owner_login')),
      ),
      body: _isLoading
          ? const Center(child: ModernLoader(color: AppColors.primaryDark))
          : Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 80, color: AppColors.primaryDark),
                    const SizedBox(height: 24),
                    Text(
                      'Dukaan Malik PIN',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kripya 4-digit PIN dalein',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _hasError ? Colors.red : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        enabled: !_isBlocked,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        onChanged: (value) {
                          if (value.length == 4) {
                            _verifyAdminPIN(value);
                          }
                          if (_hasError) {
                            setState(() => _hasError = false);
                          }
                        },
                      ),
                    ).animate(target: _hasError ? 1 : 0).shakeX(duration: 400.ms),
                    const SizedBox(height: 16),
                    if (_isBlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'Unlock hone mein $_remainingMinutes min',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 200,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isBlocked
                            ? null
                            : () => _verifyAdminPIN(_pinController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Login',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
            ),
    );
  }
}
