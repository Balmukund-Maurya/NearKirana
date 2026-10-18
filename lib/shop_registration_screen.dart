import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'language_provider.dart';
import 'modern_loader.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'auth_service.dart';
import 'sound_service.dart';

/// Zepto & Blinkit inspired Merchant Store Registration screen.
/// Allows new store owners to register their Kirana shop, setup live GPS boundaries,
/// upload verification proofs, set delivery & udhaar limits, and create their admin PIN.
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
  final _upiIdController = TextEditingController();

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
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation(
    String Function(String, String, String) t,
  ) async {
    if (!mounted) return;
    setState(() => _isFetchingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showSnackBar(
          t(
            'Location service is off. Please turn on GPS.',
            'लोकेशन सर्विस बंद है। कृपया GPS ऑन करें।',
            'Location service off hai. Kripya GPS on karein.',
          ),
          isError: true,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (!mounted) return;
          _showSnackBar(
            permission == LocationPermission.denied
                ? t(
                    'Location permission denied!',
                    'लोकेशन अनुमति अस्वीकार कर दी गई!',
                    'Location permission deny ho gayi!',
                  )
                : t(
                    'Location permanently denied. Please allow from Settings.',
                    'लोकेशन हमेशा के लिए अस्वीकार है। सेटिंग्स से चालू करें।',
                    'Settings se location permission allow karein.',
                  ),
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
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (!mounted) return;

      if (position == null) {
        _showSnackBar(
          t(
            'Could not get GPS signal. Please try again.',
            'GPS सिग्नल नहीं मिल पाया। कृपया पुनः प्रयास करें।',
            'GPS signal nahi mil paya. Thodi der baad try karein.',
          ),
          isError: true,
        );
        return;
      }

      _shopLatitude = position.latitude;
      _shopLongitude = position.longitude;

      String fullAddress = 'Lat: ${_shopLatitude!.toStringAsFixed(4)}, Lng: ${_shopLongitude!.toStringAsFixed(4)}';
      try {
        final placemarks = await placemarkFromCoordinates(
          _shopLatitude!,
          _shopLongitude!,
        ).timeout(const Duration(seconds: 5));
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
      } catch (_) {}

      setState(() {
        _addressController.text = fullAddress;
      });
      _showSnackBar(
        t(
          'Live shop GPS location locked successfully!',
          'दुकान की लाइव GPS लोकेशन सफलतापूर्वक सुरक्षित हो गई!',
          'Live shop location successfully fetch ho gayi!',
        ),
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        t(
          'Failed to fetch GPS location: $e',
          'GPS लोकेशन प्राप्त करने में त्रुटि: $e',
          'GPS location fetch nahi ho saki: $e',
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _pickShopImage(String Function(String, String, String) t) async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('Capture Live Shop Photo', 'दुकान की लाइव फोटो लें', 'Live Shop Photo Capture'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0C831F)),
                title: Text(t('Take Photo with Camera', 'कैमरे से फोटो लें', 'Camera se photo lein')),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0C831F)),
                title: Text(t('Choose from Gallery', 'गैलरी से चुनें', 'Gallery se chunein')),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;

    final pickedFile = await picker.pickImage(
      source: choice,
      imageQuality: 35,
      maxWidth: 900,
      maxHeight: 900,
    );
    if (pickedFile != null) {
      setState(() => _shopImageFile = File(pickedFile.path));
    }
  }

  Future<void> _pickShopDoc(String Function(String, String, String) t) async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('Upload Store Document', 'दुकान का प्रमाण पत्र अपलोड करें', 'Upload Store Document'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0C831F)),
                title: Text(t('Take Photo with Camera', 'कैमरे से फोटो लें', 'Camera se photo lein')),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0C831F)),
                title: Text(t('Choose from Gallery', 'गैलरी से चुनें', 'Gallery se chunein')),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
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

  Future<void> _registerShop(String Function(String, String, String) t) async {
    if (!_formKey.currentState!.validate()) return;

    if (_addressController.text.trim().isEmpty || _shopLatitude == null) {
      _showSnackBar(
        t(
          'Live GPS location is required. Please tap "Auto-Fetch Live GPS Location".',
          'लाइव GPS लोकेशन आवश्यक है। कृपया "ऑटो-फेच GPS लोकेशन" बटन दबाएं।',
          'Live GPS location zaroori hai. "Auto-Fetch Live GPS" button dabayein.',
        ),
        isError: true,
      );
      return;
    }

    if (_shopImageFile == null) {
      _showSnackBar(
        t(
          'Live shop facade photo is required.',
          'दुकान की सामने की फोटो अपलोड करना अनिवार्य है।',
          'Dukan ki live photo upload karna zaroori hai.',
        ),
        isError: true,
      );
      return;
    }

    // At least one verification document must be provided
    final hasGstin = _gstinController.text.trim().isNotEmpty;
    final hasDoc = _shopDocFile != null;
    if (!hasGstin && !hasDoc) {
      _showSnackBar(
        t(
          'Please provide at least one verification proof: GSTIN, FSSAI, or document upload.',
          'कृपया कम से कम एक सत्यापन प्रमाण दें: GSTIN, FSSAI नंबर या दस्तावेज़ फोटो।',
          'Kripya koi ek verification proof dein: GSTIN/FSSAI ya document photo.',
        ),
        isError: true,
      );
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
        _showSnackBar(
          t(
            'A shop is already registered with this mobile number!',
            'इस मोबाइल नंबर पर पहले से ही दुकान रजिस्टर्ड है!',
            'Is mobile number par pehle se dukan registered hai!',
          ),
          isError: true,
        );
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
        _showSnackBar(
          t('Failed to process photo: $e', 'फोटो प्रोसेस करने में त्रुटि: $e', 'Photo process nahi hui: $e'),
          isError: true,
        );
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
          _showSnackBar(
            t('Failed to process document: $e', 'दस्तावेज़ प्रोसेस करने में त्रुटि: $e', 'Document process nahi hua: $e'),
            isError: true,
          );
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
        'whatsapp_message_template':
            'नमस्ते ${_shopNameController.text.trim()}, मेरा नाम {name} है और मेरा मोबाइल नंबर {phone} है। मुझे अपने ऑर्डर / अकाउंट के बारे में कुछ मदद चाहिए।',
        'upi_id': _upiIdController.text.trim(),
        'banner_image_url': '',
        'owner_uid': AuthService().currentUid ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });

      await AuthService().syncUserProfile(
        phone: phone,
        role: 'shop_owner',
        shopId: shopId,
        name: _ownerNameController.text.trim(),
      );

      SoundService().success();

      if (!mounted) return;

      _showSnackBar(
        t(
          'Registration successful! Your store is under review and will go live shortly.',
          'पंजीकरण सफल! आपकी दुकान समीक्षाधीन है और जल्द ही लाइव हो जाएगी।',
          'Registration successful! Aapki dukan verification ke baad live ho jayegi.',
        ),
        isError: false,
      );

      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(
        t('Network error: $e', 'नेटवर्क त्रुटि: $e', 'Network error: $e'),
        isError: true,
      );
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0C831F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.storefront_rounded, color: Color(0xFF0C831F), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('Register Kirana Store', 'किराना स्टोर पंजीकरण', 'Register Kirana Store'),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  t('NearKirana Merchant Partner', 'नियरकिराना मर्चेंट ऑनबोर्डिंग', 'NearKirana Merchant Partner Onboarding'),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ModernLoader(color: Color(0xFF0C831F)),
                    const SizedBox(height: 16),
                    Text(
                      t(
                        'Setting up your digital store profile...',
                        'आपकी डिजिटल दुकान तैयार की जा रही है...',
                        'Aapki digital store setup ho rahi hai...',
                      ),
                      style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Zepto/Blinkit Partner Hero Banner
                      _buildHeroBanner(t),

                      const SizedBox(height: 20),

                      // Section 1: Store & Owner Identity
                      _buildSectionCard(
                        title: t('Store & Owner Details', 'दुकान व मालिक की जानकारी', 'Store & Owner Details'),
                        icon: Icons.store_rounded,
                        children: [
                          _buildModernTextField(
                            controller: _shopNameController,
                            label: t('Shop Name (e.g. Gupta Kirana)', 'दुकान का नाम (उदा. गुप्ता किराना स्टोर)', 'Shop Name (e.g. Gupta Kirana)'),
                            icon: Icons.storefront_rounded,
                            validator: (val) => val!.trim().isEmpty ? t('Shop name is required', 'दुकान का नाम अनिवार्य है', 'Shop name zaroori hai') : null,
                          ),
                          const SizedBox(height: 14),
                          _buildModernTextField(
                            controller: _ownerNameController,
                            label: t('Owner Full Name', 'दुकानदार का पूरा नाम', 'Owner Full Name'),
                            icon: Icons.person_rounded,
                            validator: (val) => val!.trim().isEmpty ? t('Owner name is required', 'मालिक का नाम अनिवार्य है', 'Owner name zaroori hai') : null,
                          ),
                        ],
                      ).animate().fadeIn(duration: 250.ms),

                      const SizedBox(height: 18),

                      // Section 2: GPS Location & Delivery Address
                      _buildSectionCard(
                        title: t('Live GPS Store Location', 'दुकान की GPS लोकेशन', 'Live GPS Store Location'),
                        icon: Icons.location_on_rounded,
                        children: [
                          Text(
                            t(
                              'NearKirana routes nearby customer orders within 1-2 km using accurate GPS coordinates.',
                              'NearKirana पास के ग्राहकों के ऑर्डर्स 10-20 मिनट में पहुंचाने के लिए सटीक GPS का उपयोग करता है।',
                              'Customer orders 10-20 mins mein deliver karne ke liye accurate GPS zaroori hai.',
                            ),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isFetchingLocation ? null : () => _getCurrentLocation(t),
                              icon: _isFetchingLocation
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.my_location_rounded, size: 18),
                              label: Text(
                                _addressController.text.isEmpty
                                    ? t('Auto-Fetch Live GPS Location', 'लाइव GPS लोकेशन प्राप्त करें', 'Auto-Fetch Live GPS Location')
                                    : t('Update GPS Coordinates', 'GPS लोकेशन अपडेट करें', 'Update GPS Coordinates'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _addressController.text.isEmpty
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF0C831F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          if (_addressController.text.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF0C831F), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t('Location Verified', 'लोकेशन सत्यापित', 'Location Verified'),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF065F46),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _addressController.text,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF047857), height: 1.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ).animate().fadeIn(duration: 250.ms, delay: 100.ms),

                      const SizedBox(height: 18),

                      // Section 3: Legal & Verification Documents
                      _buildSectionCard(
                        title: t('Legal Verification Proof', 'दुकान सत्यापन प्रमाण', 'Legal Verification Proof'),
                        icon: Icons.verified_user_rounded,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Text(
                                  t('At least 1 required', 'कम से कम एक अनिवार्य', 'At least 1 required'),
                                  style: const TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Option A: GSTIN / FSSAI
                          _buildModernTextField(
                            controller: _gstinController,
                            label: t('GSTIN or FSSAI License Number (if any)', 'GSTIN या FSSAI लाइसेंस नंबर (यदि उपलब्ध हो)', 'GSTIN or FSSAI Number (Optional)'),
                            icon: Icons.badge_rounded,
                            validator: null,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  t('OR', 'या', 'OR'),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                                ),
                              ),
                              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Option B: Document Photo Upload
                          GestureDetector(
                            onTap: () => _pickShopDoc(t),
                            child: Container(
                              height: 110,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _shopDocFile != null
                                      ? const Color(0xFF0C831F)
                                      : const Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                              ),
                              child: _shopDocFile != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(13),
                                      child: Stack(
                                        children: [
                                          Image.file(_shopDocFile!, fit: BoxFit.cover, width: double.infinity),
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: GestureDetector(
                                              onTap: () => setState(() => _shopDocFile = null),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.upload_file_rounded, size: 30, color: Color(0xFF0C831F)),
                                        const SizedBox(height: 6),
                                        Text(
                                          t(
                                            'Upload Shop License or Govt. Registration',
                                            'दुकान का लाइसेंस या सरकारी दस्तावेज अपलोड करें',
                                            'Upload Shop License or Govt Document',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                        ),
                                        Text(
                                          t('Tap to take photo or pick file', 'फोटो खींचने या चुनने के लिए टैप करें', 'Tap to capture or pick file'),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 250.ms, delay: 150.ms),

                      const SizedBox(height: 18),

                      // Section 4: Store Delivery & Billing Rules
                      _buildSectionCard(
                        title: t('Delivery & Billing Rules', 'डिलीवरी व उधारी नियम', 'Delivery & Billing Rules'),
                        icon: Icons.tune_rounded,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernTextField(
                                  controller: _deliveryFeeController,
                                  label: t('Delivery Fee (₹)', 'डिलीवरी चार्ज (₹)', 'Delivery Fee (₹)'),
                                  icon: Icons.delivery_dining_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v!.isEmpty ? t('Required', 'अनिवार्य', 'Required') : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModernTextField(
                                  controller: _minOrderController,
                                  label: t('Min Order (₹)', 'न्यूनतम ऑर्डर (₹)', 'Min Order (₹)'),
                                  icon: Icons.shopping_basket_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v!.isEmpty ? t('Required', 'अनिवार्य', 'Required') : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernTextField(
                                  controller: _freeDeliveryThresholdController,
                                  label: t('Free Delivery Above (₹)', 'फ्री डिलीवरी सीमा (₹)', 'Free Delivery Above (₹)'),
                                  icon: Icons.card_giftcard_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v!.isEmpty ? t('Required', 'अनिवार्य', 'Required') : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModernTextField(
                                  controller: _maxUdhaarController,
                                  label: t('Max Udhaar Limit (₹)', 'अधिकतम उधार सीमा (₹)', 'Max Udhaar Limit (₹)'),
                                  icon: Icons.account_balance_wallet_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v!.isEmpty ? t('Required', 'अनिवार्य', 'Required') : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernTextField(
                                  controller: _deliveryRadiusController,
                                  label: t('Delivery Range (km)', 'डिलीवरी दायरा (किमी)', 'Delivery Range (km)'),
                                  icon: Icons.two_wheeler_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v!.isEmpty) return t('Required', 'अनिवार्य', 'Required');
                                    final val = double.tryParse(v);
                                    if (val == null || val > 10) return t('Max 10 km', 'अधिकतम 10 किमी', 'Max 10 km');
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModernTextField(
                                  controller: _pickupRadiusController,
                                  label: t('Pickup Range (km)', 'पिकअप दायरा (किमी)', 'Pickup Range (km)'),
                                  icon: Icons.storefront_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v!.isEmpty) return t('Required', 'अनिवार्य', 'Required');
                                    final val = double.tryParse(v);
                                    if (val == null || val > 25) return t('Max 25 km', 'अधिकतम 25 किमी', 'Max 25 km');
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ).animate().fadeIn(duration: 250.ms, delay: 200.ms),

                      const SizedBox(height: 18),

                      // Section 5: Online Digital Payments (UPI ID)
                      _buildSectionCard(
                        title: t('Digital Payments (UPI)', 'डिजिटल पेमेंट्स (UPI ID)', 'Digital Payments (UPI)'),
                        icon: Icons.qr_code_2_rounded,
                        children: [
                          _buildModernTextField(
                            controller: _upiIdController,
                            label: t('Shop UPI ID (e.g. guptastore@okaxis)', 'दुकान का UPI ID (उदा. guptastore@okaxis)', 'Shop UPI ID (e.g. guptastore@okaxis)'),
                            icon: Icons.payment_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t(
                              'Customers can scan and pay directly to your shop bank account via GPay, PhonePe, Paytm.',
                              'ग्राहक Google Pay, PhonePe, Paytm द्वारा सीधे आपके बैंक खाते में भुगतान कर सकेंगे।',
                              'Customer directly aapke bank account mein GPay, PhonePe, Paytm se pay kar sakenge.',
                            ),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ).animate().fadeIn(duration: 250.ms, delay: 250.ms),

                      const SizedBox(height: 18),

                      // Section 6: Live Shop Photo & Admin PIN
                      _buildSectionCard(
                        title: t('Store Facade Photo & PIN', 'दुकान की फोटो व सुरक्षा पिन', 'Store Photo & Security PIN'),
                        icon: Icons.camera_alt_rounded,
                        children: [
                          GestureDetector(
                            onTap: () => _pickShopImage(t),
                            child: Container(
                              height: 130,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _shopImageFile != null
                                      ? const Color(0xFF0C831F)
                                      : const Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                              ),
                              child: _shopImageFile != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(13),
                                      child: Stack(
                                        children: [
                                          Image.file(_shopImageFile!, fit: BoxFit.cover, width: double.infinity),
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    t('Change', 'बदलें', 'Change'),
                                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_a_photo_rounded, size: 36, color: Color(0xFF0C831F)),
                                        const SizedBox(height: 8),
                                        Text(
                                          t('Tap to Take Live Shop Photo *', 'दुकान की लाइव फोटो लें *', 'Tap to Take Live Shop Photo *'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0C831F),
                                          ),
                                        ),
                                        Text(
                                          t('Customers will recognize your store from this photo', 'ग्राहक इस फोटो से आपकी दुकान को पहचानेंगे', 'Customers will recognize your store from this photo'),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _pinController,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: t('Create Admin Security PIN (4 or 6 digits)', 'एडमिन सुरक्षा पिन बनाएं (4 या 6 अंक)', 'Create Admin PIN (4 or 6 digits)'),
                              prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF0C831F)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () => setState(() => _obscurePin = !_obscurePin),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              filled: true,
                              fillColor: Colors.white,
                              counterText: '',
                            ),
                            validator: (val) => (val == null || val.length < 4)
                                ? t('PIN must be at least 4 digits', 'पिन कम से कम 4 अंकों का होना चाहिए', 'PIN kam se kam 4 digit ka hona chahiye')
                                : null,
                          ),
                        ],
                      ).animate().fadeIn(duration: 250.ms, delay: 300.ms),

                      const SizedBox(height: 28),

                      // Submit Button
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () => _registerShop(t),
                          icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                          label: Text(
                            t('Register & Launch My Store', 'दुकान रजिस्टर करें और शुरू करें', 'Register & Launch My Store'),
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C831F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ).animate().fadeIn(duration: 250.ms, delay: 350.ms),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeroBanner(String Function(String, String, String) t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C831F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('NearKirana Partner', 'NearKirana किराना पार्टनर', 'NearKirana Partner'),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      t('NearKirana Express Grocery Network', 'नियरकिराना एक्सप्रेस नेटवर्क', 'NearKirana Express Grocery Network'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              // Verified Mobile Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C831F).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0C831F)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF4ADE80), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      widget.verifiedPhone.length >= 10
                          ? widget.verifiedPhone.substring(widget.verifiedPhone.length - 10)
                          : widget.verifiedPhone,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t(
              'Start receiving orders from 1000+ local customers in your neighborhood with automated dispatch and instant payments.',
              'अपने इलाके के 1000+ ग्राहकों से ऑनलाइन ऑर्डर्स प्राप्त करें, तत्काल डिस्पैच और सीधे बैंक खाते में भुगतान पाएं।',
              'Apne ilake ke 1000+ customers se orders receive karein, automatic dispatch aur instant payments payein.',
            ),
            style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF0C831F)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        prefixIcon: Icon(icon, color: const Color(0xFF0C831F), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0C831F), width: 1.8),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: validator,
    );
  }
}
