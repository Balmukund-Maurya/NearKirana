import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'app_theme.dart';
import 'modern_loader.dart';
import 'package:latlong2/latlong.dart';
import 'map_selection_screen.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';

class ShopRegistrationScreen extends StatefulWidget {
  const ShopRegistrationScreen({super.key});

  @override
  State<ShopRegistrationScreen> createState() => _ShopRegistrationScreenState();
}

class _ShopRegistrationScreenState extends State<ShopRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePin = true;
  double? _shopLatitude;
  double? _shopLongitude;
  bool _isFetchingLocation = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isFetchingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showSnackBar('Location service off hai. GPS on karke dobara try karein.', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          if (!mounted) return;
          _showSnackBar(
            permission == LocationPermission.denied
                ? 'Location permission denied!'
                : 'Location permission permanently denied. App settings se allow karein.',
            isError: true,
          );
          if (permission == LocationPermission.deniedForever) {
            await Geolocator.openAppSettings();
          }
          return;
        }
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (!mounted) return;

      if (position == null) {
        _showSnackBar('Location fetch nahi ho paya. GPS signal thodi der baad try karein.', isError: true);
        return;
      }

      // Open MapSelectionScreen for fine tuning
      final LatLng? pickedLocation = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapSelectionScreen(
            initialLat: position!.latitude,
            initialLng: position.longitude,
            isPickingOnly: true,
          ),
        ),
      );

      if (!mounted) return;
      if (pickedLocation == null) {
        _showSnackBar('Location selection cancelled.', isError: true);
        return;
      }

      _shopLatitude = pickedLocation.latitude;
      _shopLongitude = pickedLocation.longitude;

      String fullAddress = 'Location selected on map';
      try {
        final placemarks = await placemarkFromCoordinates(_shopLatitude!, _shopLongitude!);
        if (!mounted) return;

        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          fullAddress = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.postalCode,
          ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
        }
      } catch (_) {
        fullAddress = 'Location selected on map';
      }

      setState(() {
        _addressController.text = fullAddress;
      });
      _showSnackBar('Location fetch ho gayi!', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Location nahi mil payi. Kripya apna GPS/Location on karein.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _registerShop() async {
    if (!_formKey.currentState!.validate()) return;
    if (_addressController.text.isEmpty) {
      _showSnackBar('Location pick karna zaroori hai (Tap the Pick Location button)', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final phone = _phoneController.text.trim();

      final existingShop = await FirebaseFirestore.instance
          .collection('shops')
          .where('mobile', isEqualTo: phone)
          .get();

      if (existingShop.docs.isNotEmpty) {
        _showSnackBar('Is mobile number se pehle hi ek dukan registered hai!', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final String shopId = 'SHOP_${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance.collection('shops').doc(shopId).set({
        'shop_id': shopId,
        'shop_name': _shopNameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'mobile': phone,
        'support_phone': phone,
        'address': _addressController.text.trim(),
        'lat': _shopLatitude,
        'lng': _shopLongitude,
        'admin_pin': _pinController.text.trim(),
        'is_active': true,
        'delivery_fee': 20.0,
        'minimum_order': 300.0,
        'free_delivery_threshold': 500.0,
        'whatsapp_message_template': 'नमस्ते {shopName}, मेरा नाम {name} है और मेरा मोबाइल नंबर {phone} है। मुझे अपने ऑर्डर / अकाउंट के बारे में कुछ मदद चाहिए।',
        'upi_id': '',
        'banner_image_url': '',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnackBar('Badhai ho! Aapki Dukan platform par live ho gayi hai.', isError: false);

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Network error: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(langProvider.translate('register_shop_title')),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ModernLoader(color: AppColors.primaryDark),
                    const SizedBox(height: 16),
                    Text(langProvider.translate('shop_setting_up'), style: const TextStyle(color: AppColors.textMid)),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.store_mall_directory_rounded, size: 64, color: AppColors.primaryDark)
                          .animate()
                          .scale(curve: Curves.easeOutBack, duration: 500.ms),
                      const SizedBox(height: 16),
                      Text(
                        'NearKirana Platform Par Judhein',
                        style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 22),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _buildTextField(
                        controller: _shopNameController,
                        label: 'Dukan Ka Naam',
                        icon: Icons.storefront_rounded,
                        validator: (val) => val!.isEmpty ? 'Dukan ka naam zaroori hai' : null,
                      ).animate().fadeIn(delay: 100.ms),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _ownerNameController,
                        label: 'Aapka Pura Naam',
                        icon: Icons.person_rounded,
                        validator: (val) => val!.isEmpty ? 'Naam zaroori hai' : null,
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Mobile Number (Yahi Login ID hogi)',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        validator: (val) => val!.length != 10 ? 'Sahi 10-digit number dalein' : null,
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: _isFetchingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.location_on_rounded, color: Colors.white),
                          label: Text(
                            _addressController.text.isEmpty
                                ? 'Pick Shop Location'
                                : 'Location Selected. ( Tap to change )',
                            style: AppTextStyles.bodySemiBold(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _addressController.text.isEmpty ? Colors.blue : Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pinController,
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'Admin PIN Banayein (4 ya 6 digit)',
                          prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.primaryDark),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppColors.textMid,
                            ),
                            onPressed: () => setState(() => _obscurePin = !_obscurePin),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        validator: (val) => (val!.length < 4) ? 'Kam se kam 4 digit ka PIN banayein' : null,
                      ).animate().fadeIn(delay: 500.ms),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _registerShop,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(langProvider.translate('register_shop_title'), style: AppTextStyles.heading2(color: AppColors.white)),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryDark),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: AppColors.white,
        counterText: '',
      ),
      validator: validator,
    );
  }
}
