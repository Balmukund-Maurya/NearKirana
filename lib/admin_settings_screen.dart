import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'sound_service.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'language_provider.dart';
import 'map_selection_screen.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'utils/product_image_widget.dart';
import 'package:near_kirana/firebase_utils.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _deliveryFeeController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _freeDeliveryThresholdController = TextEditingController();
  final _maxUdhaarController = TextEditingController();
  final _pickupRadiusController = TextEditingController(); // FIX-3: Pickup radius
  final _deliveryRadiusController = TextEditingController(); // FIX-32: Delivery radius
  final _storeLatController = TextEditingController(); // FIX-32: Store Lat
  final _storeLngController = TextEditingController(); // FIX-32: Store Lng
  final _supportPhoneController = TextEditingController();
  final _whatsappMessageController = TextEditingController();
  bool _isStoreOpen = true;
  List<String> _categories = [
    'Dal',
    'Rice',
    'Spices',
    'Oil',
    'Snacks',
    'Soap',
    'Loose',
  ];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      final doc = shopId != null && shopId.isNotEmpty
          ? await FirebaseUtils.firestore.collection('shops').doc(shopId).get()
          : await FirebaseUtils.firestore.collection('settings').doc('app_config').get();
      if (doc.exists) {
        final data = doc.data()!;
        _deliveryFeeController.text = (data['delivery_fee'] ?? 20.0).toString();
        _minOrderController.text = (data['minimum_order'] ?? 300.0).toString();
        _freeDeliveryThresholdController.text =
            (data['free_delivery_threshold'] ?? 500.0).toString();
        _isStoreOpen = data['is_store_open'] ?? true;
        _maxUdhaarController.text = (data['max_udhaar_limit'] ?? 2000.0)
            .toString();
        // FIX-3: Load pickup radius (default 25km)
        _pickupRadiusController.text = (data['pickup_radius_km'] ?? 25.0).toString();
        // FIX-32: Load geo-fencing data
        _deliveryRadiusController.text = (data['delivery_radius_km'] ?? 5.0).toString();
        _storeLatController.text = (data['store_latitude'] ?? '').toString();
        _storeLngController.text = (data['store_longitude'] ?? '').toString();
        _supportPhoneController.text = data['support_phone'] ?? '';
        _whatsappMessageController.text = data['whatsapp_message_template'] ?? "नमस्ते {shopName}, मेरा नाम {name} है और मेरा मोबाइल नंबर {phone} है। मुझे अपने ऑर्डर / अकाउंट के बारे में कुछ मदद चाहिए।";

        if (data['categories'] != null) {
          _categories = List<String>.from(data['categories']);
        }
      } else {
        _deliveryFeeController.text = '20.0';
        _minOrderController.text = '300.0';
        _freeDeliveryThresholdController.text = '500.0';
        _maxUdhaarController.text = '2000.0';
        _pickupRadiusController.text = '25.0'; // FIX-3
        _deliveryRadiusController.text = '5.0'; // FIX-32
        _storeLatController.text = '';
        _storeLngController.text = '';
        _supportPhoneController.text = '';
        _whatsappMessageController.text = "नमस्ते {shopName}, मेरा नाम {name} है और मेरा मोबाइल नंबर {phone} है। मुझे अपने ऑर्डर / अकाउंट के बारे में कुछ मदद चाहिए।";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('err_loading_settings').replaceAll('{error}', e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      final double deliveryFee = double.tryParse(_deliveryFeeController.text) ?? 20.0;
      final double minOrder = double.tryParse(_minOrderController.text) ?? 300.0;
      final double freeDeliveryThreshold = double.tryParse(_freeDeliveryThresholdController.text) ?? 500.0;
      final double maxUdhaar = double.tryParse(_maxUdhaarController.text) ?? 2000.0;
      final double pickupRadius = double.tryParse(_pickupRadiusController.text) ?? 25.0;
      final double deliveryRadius = double.tryParse(_deliveryRadiusController.text) ?? 5.0;

      if (deliveryFee < 0 || minOrder < 0 || freeDeliveryThreshold < 0 || maxUdhaar < 0 || pickupRadius < 0 || deliveryRadius < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('err_negative_values')), backgroundColor: AppColors.error),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      final settingsRef = shopId != null && shopId.isNotEmpty
          ? FirebaseUtils.firestore.collection('shops').doc(shopId)
          : FirebaseUtils.firestore.collection('settings').doc('app_config');

      await settingsRef.set({
            'delivery_fee': deliveryFee,
            'minimum_order': minOrder,
            'free_delivery_threshold': freeDeliveryThreshold,
            'max_udhaar_limit': maxUdhaar,
            'is_store_open': _isStoreOpen,
            'categories': _categories,
            // FIX-3: Save pickup radius
            'pickup_radius_km': pickupRadius,
            // FIX-32: Save delivery geo-fencing
            'delivery_radius_km': deliveryRadius,
            'store_latitude': double.tryParse(_storeLatController.text),
            'store_longitude': double.tryParse(_storeLngController.text),
            'support_phone': _supportPhoneController.text.trim(),
            'whatsapp_message_template': _whatsappMessageController.text.trim(),
          }, SetOptions(merge: true));

      SoundService().play('save.mp3');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('settings_saved')),
            backgroundColor: AppColors.primaryDark,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('err_saving_settings').replaceAll('{error}', e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(Provider.of<LanguageProvider>(context).translate('store_settings')),
      ),
      body: _isLoading
          ? const Center(
              child: ModernLoader(color: AppColors.primaryDark),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _ShopAvatar(shopProvider: Provider.of<ShopProvider>(context)),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  // Store Status
                  Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isStoreOpen
                                ? AppColors.primaryDark.withValues(alpha: 0.3)
                                : AppColors.error.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Provider.of<LanguageProvider>(context).translate('store_is_open'),
                                  style: AppTextStyles.heading2(
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isStoreOpen
                                      ? 'Accepting new orders'
                                      : 'Store is closed right now',
                                  style: AppTextStyles.bodyMedium(
                                    color: _isStoreOpen
                                        ? AppColors.primaryDark
                                        : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _isStoreOpen,
                              activeThumbColor: AppColors.primaryDark,
                              inactiveTrackColor: AppColors.error.withValues(
                                alpha: 0.3,
                              ),
                              inactiveThumbColor: AppColors.error,
                              onChanged: (val) {
                                HapticFeedback.lightImpact();
                                setState(() => _isStoreOpen = val);
                              },
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 32),

                  // Financial Rules
                  Text(
                    Provider.of<LanguageProvider>(context).translate('financial_rules'),
                    style: AppTextStyles.heading2(color: AppColors.textDark),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.bgTint, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        _buildConfigField(
                          'Delivery Fee (₹)',
                          _deliveryFeeController,
                          'e.g. 20',
                          Icons.moped_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildConfigField(
                          'Minimum Order Amount (₹)',
                          _minOrderController,
                          'e.g. 300',
                          Icons.shopping_basket_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildConfigField(
                          'Free Delivery Threshold (₹)',
                          _freeDeliveryThresholdController,
                          'e.g. 500',
                          Icons.card_giftcard_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildConfigField(
                          'Maximum Udhaar Limit (₹)',
                          _maxUdhaarController,
                          'e.g. 2000',
                          Icons.account_balance_wallet_rounded,
                        ),
                        const SizedBox(height: 16),
                        // FIX-3: Pickup radius setting
                        _buildConfigField(
                          'Pickup Order Radius (km)',
                          _pickupRadiusController,
                          'e.g. 25',
                          Icons.storefront_rounded,
                        ),
                        const SizedBox(height: 16),
                        // FIX-32: Delivery Geo-fencing
                        _buildConfigField(
                          'Delivery Radius (km)',
                          _deliveryRadiusController,
                          'e.g. 5',
                          Icons.map_rounded,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _buildConfigField(
                                    'Store Latitude',
                                    _storeLatController,
                                    'e.g. 28.7041',
                                    Icons.location_on_rounded,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildConfigField(
                                    'Store Longitude',
                                    _storeLngController,
                                    'e.g. 77.1025',
                                    Icons.location_on_rounded,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              height: 120, // matches height of two fields + spacing
                              child: ElevatedButton(
                                onPressed: () async {
                                  final currentLat = double.tryParse(_storeLatController.text) ?? 0.0;
                                  final currentLng = double.tryParse(_storeLngController.text) ?? 0.0;
                                  final dynamic pickedLocation = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MapSelectionScreen(
                                        initialLat: currentLat,
                                        initialLng: currentLng,
                                        isPickingOnly: true,
                                      ),
                                    ),
                                  );
                                  if (!context.mounted) return;
                                  if (pickedLocation != null) {
                                    try {
                                      setState(() {
                                        _storeLatController.text = pickedLocation.latitude.toString();
                                        _storeLngController.text = pickedLocation.longitude.toString();
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('location_picked')), backgroundColor: AppColors.primaryDark),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('err_reading_location').replaceAll('{error}', e.toString())), backgroundColor: AppColors.error),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('err_no_location')), backgroundColor: AppColors.error),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.map_rounded, size: 28),
                                    SizedBox(height: 8),
                                    Text('Pick on\nMap', textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildConfigField(
                          'Support Phone Number',
                          _supportPhoneController,
                          'e.g. 9876543210 (10 digits)',
                          Icons.support_agent_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildConfigField(
                          'WhatsApp Support Message',
                          _whatsappMessageController,
                          'Use {name} and {phone} as placeholders',
                          Icons.message_rounded,
                          keyboardType: TextInputType.multiline,
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 32),

                  // Categories
                  Text(
                    'Product Categories',
                    style: AppTextStyles.heading2(color: AppColors.textDark),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.bgTint, width: 1.5),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._categories.map(
                          (cat) => Chip(
                            label: Text(
                              cat,
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.primaryDark,
                              ),
                            ),
                            backgroundColor: AppColors.primaryLight.withValues(
                              alpha: 0.2,
                            ),
                            deleteIconColor: AppColors.primaryDark,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onDeleted: () {
                              HapticFeedback.lightImpact();
                              setState(() => _categories.remove(cat));
                            },
                          ),
                        ),
                        ActionChip(
                          label: Text(
                            'Add Category',
                            style: AppTextStyles.bodySemiBold(
                              color: AppColors.white,
                            ),
                          ),
                          avatar: const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: AppColors.white,
                          ),
                          backgroundColor: AppColors.primaryDark,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _showAddCategoryDialog();
                          },
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 48),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Add Category',
          style: AppTextStyles.heading2(color: AppColors.textDark),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'e.g. Stationery',
            hintStyle: AppTextStyles.bodyMedium(color: AppColors.textMid),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodySemiBold(color: AppColors.textMid),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _categories.add(controller.text.trim()));
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigField(
    String label,
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.number,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTextStyles.bodyMedium(color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.captionMedium(color: AppColors.textMid),
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium(color: AppColors.textLight),
        prefixIcon: Icon(icon, color: AppColors.primaryDark, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgTint),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.bgTint),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
        filled: true,
        fillColor: AppColors.surface,
      ),
    );
  }
}

class _ShopAvatar extends StatefulWidget {
  final ShopProvider shopProvider;
  const _ShopAvatar({required this.shopProvider});
  @override
  State<_ShopAvatar> createState() => _ShopAvatarState();
}

class _ShopAvatarState extends State<_ShopAvatar> {
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        final finalImageUrl = 'data:image/jpeg;base64,$base64String';
        await widget.shopProvider.updateShopProfilePic(finalImageUrl);
      } catch (e) {
        debugPrint('Error uploading shop profile pic: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight.withValues(alpha: 0.2),
              border: Border.all(
                color: AppColors.primaryLight,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: _isUploading
                  ? const Center(child: ModernLoader(color: AppColors.primaryDark))
                  : (widget.shopProvider.shopProfilePic != null && widget.shopProvider.shopProfilePic!.isNotEmpty)
                      ? ProductImageWidget(imageUrl: widget.shopProvider.shopProfilePic, width: 100, height: 100)
                      : const Icon(
                          Icons.store_rounded,
                          size: 50,
                          color: AppColors.primaryDark,
                        ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }
}
