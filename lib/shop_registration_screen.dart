import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'app_theme.dart';
import 'modern_loader.dart';
import 'package:near_kirana/firebase_utils.dart';

class ShopRegistrationScreen extends StatefulWidget {
  final String verifiedPhone;
  const ShopRegistrationScreen({super.key, required this.verifiedPhone});

  @override
  State<ShopRegistrationScreen> createState() => _ShopRegistrationScreenState();
}

class _ShopRegistrationScreenState extends State<ShopRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinController = TextEditingController();
  final _gstinController = TextEditingController(); // FSSAI or GSTIN
  final _deliveryRadiusController = TextEditingController(text: '1');
  final _pickupRadiusController = TextEditingController(text: '1');

  bool _isLoading = false;
  bool _obscurePin = true;
  double? _shopLatitude;
  double? _shopLongitude;
  bool _isFetchingLocation = false;
  
  File? _shopImageFile;

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    _gstinController.dispose();
    _deliveryRadiusController.dispose();
    _pickupRadiusController.dispose();
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

      if (!mounted) return;

      if (position == null) {
        _showSnackBar('Location fetch nahi ho paya. GPS signal thodi der baad try karein.', isError: true);
        return;
      }

      _shopLatitude = position.latitude;
      _shopLongitude = position.longitude;

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

  Future<void> _pickShopImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera, 
      imageQuality: 30, // High compression to save space
      maxWidth: 800,
      maxHeight: 800,
    );

    if (pickedFile != null) {
      setState(() {
        _shopImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _registerShop() async {
    if (!_formKey.currentState!.validate()) return;
    if (_addressController.text.isEmpty) {
      _showSnackBar('Live location (GPS) fetch karna zaroori hai (Tap the Auto-Fetch Location button)', isError: true);
      return;
    }
    if (_shopImageFile == null) {
      _showSnackBar('Dukaan ki live photo kheenchna zaroori hai', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final phone = widget.verifiedPhone;

      final existingShop = await FirebaseUtils.firestore
          .collection('shops')
          .where('mobile', isEqualTo: phone)
          .get();

      if (existingShop.docs.isNotEmpty) {
        _showSnackBar('Is mobile number se pehle hi ek dukan registered hai!', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final String shopId = 'SHOP_${DateTime.now().millisecondsSinceEpoch}';

      // Convert image to Base64 to save directly in Firestore (100% Free)
      String base64Image = '';
      try {
        final bytes = await _shopImageFile!.readAsBytes();
        base64Image = base64Encode(bytes);
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnackBar('Photo process fail ho gayi: $e', isError: true);
        return;
      }

      await FirebaseUtils.firestore.collection('shops').doc(shopId).set({
        'shop_id': shopId,
        'shop_name': _shopNameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'mobile': phone,
        'support_phone': phone,
        'address': _addressController.text.trim(),
        'gstin_fssai': _gstinController.text.trim(),
        'shop_image_base64': base64Image,
        'lat': _shopLatitude,
        'lng': _shopLongitude,
        'admin_pin': _pinController.text.trim(),
        'is_active': false,
        'status': 'pending',
        'delivery_fee': 20.0,
        'minimum_order': 300.0,
        'free_delivery_threshold': 500.0,
        'delivery_radius_km': double.tryParse(_deliveryRadiusController.text.trim()) ?? 1.0,
        'pickup_radius_km': double.tryParse(_pickupRadiusController.text.trim()) ?? 1.0,
        'whatsapp_message_template': 'नमस्ते {shopName}, मेरा नाम {name} है और मेरा मोबाइल नंबर {phone} है। मुझे अपने ऑर्डर / अकाउंट के बारे में कुछ मदद चाहिए।',
        'upi_id': '',
        'banner_image_url': '',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnackBar('Registration successful! Aapki dukan abhi pending approval hai. Admin ke verify karne ke baad ye live ho jayegi.', isError: false);

      await Future.delayed(const Duration(seconds: 4));

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
    final langProvider = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(langProvider.register_shop_title),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ModernLoader(color: AppColors.primaryDark),
                    const SizedBox(height: 16),
                    Text(langProvider.shop_setting_up, style: const TextStyle(color: AppColors.textMid)),
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
                                ? 'Auto-Fetch Live GPS Location'
                                : 'Live Location Fetched ✓',
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
                      _buildTextField(
                        controller: _gstinController,
                        label: 'FSSAI License / GSTIN',
                        icon: Icons.verified_rounded,
                        validator: (val) => val!.isEmpty ? 'FSSAI ya GST number zaruri hai' : null,
                      ).animate().fadeIn(delay: 450.ms),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _deliveryRadiusController,
                              label: 'Delivery Range (km)',
                              icon: Icons.delivery_dining_rounded,
                              keyboardType: TextInputType.number,
                              validator: (val) => val!.isEmpty ? 'Zaroori' : null,
                            ).animate().fadeIn(delay: 460.ms),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _pickupRadiusController,
                              label: 'Pickup Range (km)',
                              icon: Icons.store_mall_directory_rounded,
                              keyboardType: TextInputType.number,
                              validator: (val) => val!.isEmpty ? 'Zaroori' : null,
                            ).animate().fadeIn(delay: 470.ms),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Image Picker UI
                      GestureDetector(
                        onTap: _pickShopImage,
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.5), width: 1.5, style: BorderStyle.solid),
                          ),
                          child: _shopImageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(_shopImageFile!, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.camera_alt_rounded, size: 40, color: AppColors.primaryDark),
                                    const SizedBox(height: 8),
                                    Text('Tap to Take Live Shop Photo', style: AppTextStyles.bodySemiBold(color: AppColors.primaryDark)),
                                  ],
                                ),
                        ),
                      ).animate().fadeIn(delay: 480.ms),
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
                        child: Text(langProvider.register_shop_title, style: AppTextStyles.heading2(color: AppColors.white)),
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
