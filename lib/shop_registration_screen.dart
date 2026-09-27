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
  final _deliveryFeeController = TextEditingController(text: '20.0');
  final _minOrderController = TextEditingController(text: '300.0');
  final _freeDeliveryThresholdController = TextEditingController(text: '500.0');
  final _maxUdhaarController = TextEditingController(text: '2000.0');

  bool _isLoading = false;
  bool _obscurePin = true;
  double? _shopLatitude;
  double? _shopLongitude;
  bool _isFetchingLocation = false;
  
  File? _shopImageFile;
  File? _shopDocFile; // Shop verification document

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    _gstinController.dispose();
    _deliveryRadiusController.dispose();
    _pickupRadiusController.dispose();
    _deliveryFeeController.dispose();
    _minOrderController.dispose();
    _freeDeliveryThresholdController.dispose();
    _maxUdhaarController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isFetchingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showSnackBar('Location service is off. Please enable GPS and try again.', isError: true);
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
                : 'Location permission permanently denied. Please allow from App Settings.',
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
      _showSnackBar('Location fetched successfully!', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Location nahi mil payi. Please enable GPS/Location.', isError: true);
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
      imageQuality: 30,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (pickedFile != null) {
      setState(() => _shopImageFile = File(pickedFile.path));
    }
  }

  Future<void> _pickShopDoc() async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryDark),
              title: const Text('Take Photo with Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryDark),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final pickedFile = await picker.pickImage(
      source: choice,
      imageQuality: 50,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (pickedFile != null) {
      setState(() => _shopDocFile = File(pickedFile.path));
    }
  }

  Future<void> _registerShop() async {
    if (!_formKey.currentState!.validate()) return;
    if (_addressController.text.isEmpty) {
      _showSnackBar('Live GPS location is required. Tap the Auto-Fetch Location button.', isError: true);
      return;
    }
    if (_shopImageFile == null) {
      _showSnackBar('Live shop photo is required', isError: true);
      return;
    }
    // At least one verification document must be provided
    final hasGstin = _gstinController.text.trim().isNotEmpty;
    final hasDoc = _shopDocFile != null;
    if (!hasGstin && !hasDoc) {
      _showSnackBar('At least one verification document is required: GSTIN, FSSAI, or a document upload', isError: true);
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
        _showSnackBar('A shop is already registered with this mobile number!', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final String shopId = 'SHOP_${DateTime.now().millisecondsSinceEpoch}';

      // Convert shop image to Base64
      String base64Image = '';
      try {
        final bytes = await _shopImageFile!.readAsBytes();
        base64Image = base64Encode(bytes);
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to process photo: $e', isError: true);
        return;
      }

      // Convert verification document to Base64 (if provided)
      String base64Doc = '';
      if (_shopDocFile != null) {
        try {
          final bytes = await _shopDocFile!.readAsBytes();
          base64Doc = base64Encode(bytes);
        } catch (e) {
          setState(() => _isLoading = false);
          _showSnackBar('Failed to process document: $e', isError: true);
          return;
        }
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
        'shop_doc_image_base64': base64Doc,
        'lat': _shopLatitude,
        'lng': _shopLongitude,
        'admin_pin': _pinController.text.trim(),
        'is_active': false,
        'status': 'pending',
        'delivery_fee': double.tryParse(_deliveryFeeController.text.trim()) ?? 20.0,
        'minimum_order': double.tryParse(_minOrderController.text.trim()) ?? 300.0,
        'free_delivery_threshold': double.tryParse(_freeDeliveryThresholdController.text.trim()) ?? 500.0,
        'max_udhaar_limit': double.tryParse(_maxUdhaarController.text.trim()) ?? 2000.0,
        'delivery_radius_km': double.tryParse(_deliveryRadiusController.text.trim()) ?? 1.0,
        'pickup_radius_km': double.tryParse(_pickupRadiusController.text.trim()) ?? 1.0,
        'whatsapp_message_template': 'नमस्ते {shopName}, मेरा नाम {name} है और मेरा मोबाइल नंबर {phone} है। मुझे अपने ऑर्डर / अकाउंट के बारे में कुछ मदद चाहिए।',
        'upi_id': '',
        'banner_image_url': '',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnackBar('Registration successful! Your shop is pending approval. It will go live after admin verification.', isError: false);

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
                        'Join the NearKirana Platform',
                        style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 22),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _buildTextField(
                        controller: _shopNameController,
                        label: 'Shop Name',
                        icon: Icons.storefront_rounded,
                        validator: (val) => val!.isEmpty ? 'Shop name is required' : null,
                      ).animate().fadeIn(delay: 100.ms),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _ownerNameController,
                        label: 'Your Full Name',
                        icon: Icons.person_rounded,
                        validator: (val) => val!.isEmpty ? 'Name is required' : null,
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
                      // ── Verification Section ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (_gstinController.text.trim().isNotEmpty || _shopDocFile != null)
                                ? Colors.green
                                : AppColors.primaryDark.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Icon(Icons.verified_user_rounded,
                                    color: (_gstinController.text.trim().isNotEmpty || _shopDocFile != null)
                                        ? Colors.green
                                        : AppColors.primaryDark,
                                    size: 20),
                                Text('Shop Verification *',
                                    style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('at least one required',
                                      style: TextStyle(color: Colors.orange.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Option 1: GSTIN / FSSAI (single combined field)
                            TextFormField(
                              controller: _gstinController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'GSTIN / FSSAI Number (if available)',
                                hintText: 'Enter your GSTIN or FSSAI license number',
                                prefixIcon: const Icon(Icons.verified_rounded, color: AppColors.primaryDark),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('OR', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ]),
                            const SizedBox(height: 8),
                            // Option 3: Document Upload
                            GestureDetector(
                              onTap: _pickShopDoc,
                              child: Container(
                                height: 100,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _shopDocFile != null ? Colors.green : Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                ),
                                child: _shopDocFile != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: Stack(
                                          children: [
                                            Image.file(_shopDocFile!, fit: BoxFit.cover, width: double.infinity),
                                            Positioned(
                                              top: 4, right: 4,
                                              child: GestureDetector(
                                                onTap: () => setState(() => _shopDocFile = null),
                                                child: const CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor: Colors.red,
                                                  child: Icon(Icons.close, size: 14, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.upload_file_rounded, size: 32, color: AppColors.primaryDark),
                                          const SizedBox(height: 4),
                                          Text('Upload Shop Registration Certificate or any Govt. Document',
                                              style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                                              textAlign: TextAlign.center),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 450.ms),
                      const SizedBox(height: 16),
                      // Store Config fields
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _deliveryFeeController,
                              label: 'Delivery Fee (₹)',
                              icon: Icons.delivery_dining_rounded,
                              keyboardType: TextInputType.number,
                              validator: (val) => val!.isEmpty ? 'Required' : null,
                            ).animate().fadeIn(delay: 452.ms),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _minOrderController,
                              label: 'Min Order (₹)',
                              icon: Icons.shopping_basket_rounded,
                              keyboardType: TextInputType.number,
                              validator: (val) => val!.isEmpty ? 'Required' : null,
                            ).animate().fadeIn(delay: 454.ms),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _freeDeliveryThresholdController,
                              label: 'Free Delivery (₹)',
                              icon: Icons.card_giftcard_rounded,
                              keyboardType: TextInputType.number,
                              validator: (val) => val!.isEmpty ? 'Required' : null,
                            ).animate().fadeIn(delay: 456.ms),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _maxUdhaarController,
                              label: 'Max Udhaar (₹)',
                              icon: Icons.account_balance_wallet_rounded,
                              keyboardType: TextInputType.number,
                              validator: (val) => val!.isEmpty ? 'Required' : null,
                            ).animate().fadeIn(delay: 458.ms),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _deliveryRadiusController,
                              label: 'Delivery Range (km)',
                              icon: Icons.delivery_dining_rounded,
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val!.isEmpty) return 'Required';
                                final numVal = double.tryParse(val);
                                if (numVal == null || numVal > 10) return 'Max 10 km';
                                return null;
                              },
                            ).animate().fadeIn(delay: 460.ms),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _pickupRadiusController,
                              label: 'Pickup Range (km)',
                              icon: Icons.store_mall_directory_rounded,
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val!.isEmpty) return 'Required';
                                final numVal = double.tryParse(val);
                                if (numVal == null || numVal > 25) return 'Max 25 km';
                                return null;
                              },
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
                          labelText: 'Create Admin PIN (4 or 6 digits)',
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
                        validator: (val) => (val!.length < 4) ? 'PIN must be at least 4 digits' : null,
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
