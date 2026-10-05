import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/sound_service.dart';
import 'package:near_kirana/modern_loader.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/map_selection_screen.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:near_kirana/utils/product_image_widget.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/admin_desktop_dashboard.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';
import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:near_kirana/admin_language_theme_screen.dart';
import 'package:near_kirana/admin_dashboard.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  int _activeTabIndex = 0;
  
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _freeDeliveryThresholdController = TextEditingController();
  final _maxUdhaarController = TextEditingController();
  final _pickupRadiusController = TextEditingController();
  final _deliveryRadiusController = TextEditingController();
  final _storeLatController = TextEditingController();
  final _storeLngController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  final _whatsappMessageController = TextEditingController();
  bool _isStoreOpen = true;
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _deliveryFeeController.dispose();
    _minOrderController.dispose();
    _freeDeliveryThresholdController.dispose();
    _maxUdhaarController.dispose();
    _pickupRadiusController.dispose();
    _deliveryRadiusController.dispose();
    _storeLatController.dispose();
    _storeLngController.dispose();
    _supportPhoneController.dispose();
    _whatsappMessageController.dispose();
    super.dispose();
  }

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
        _shopNameController.text = data['shop_name'] ?? '';
        _ownerNameController.text = data['owner_name'] ?? '';
        _deliveryFeeController.text = (data['delivery_fee'] ?? 20.0).toString();
        _minOrderController.text = (data['minimum_order'] ?? 300.0).toString();
        _freeDeliveryThresholdController.text =
            (data['free_delivery_threshold'] ?? 500.0).toString();
        _isStoreOpen = data['is_store_open'] ?? true;
        _maxUdhaarController.text = (data['max_udhaar_limit'] ?? 2000.0).toString();
        _pickupRadiusController.text = (data['pickup_radius_km'] ?? 25.0).toString();
        _deliveryRadiusController.text = (data['delivery_radius_km'] ?? 5.0).toString();
        _storeLatController.text = (data['store_latitude'] ?? '').toString();
        _storeLngController.text = (data['store_longitude'] ?? '').toString();
        _supportPhoneController.text = data['support_phone'] ?? '';
        _whatsappMessageController.text = data['whatsapp_message_template'] ?? "नमस्ते {shopName}, मेरा नाम {name} है और मेरा मोबाइल नंबर {phone} है। मुझे अपने ऑर्डर / अकाउंट के बारे में कुछ मदद चाहिए।";

        if (data['categories'] != null) {
          _categories = List<String>.from(data['categories']);
        } else if (data['product_categories'] != null) {
          // Fallback if it was stored as product_categories
          _categories = List<String>.from(data['product_categories']);
        }
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
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
            SnackBar(behavior: SnackBarBehavior.floating, content: Text(AppLocalizations.of(context)!.err_negative_values), backgroundColor: AppColors.error),
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
        'shop_name': _shopNameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'delivery_fee': deliveryFee,
        'minimum_order': minOrder,
        'free_delivery_threshold': freeDeliveryThreshold,
        'max_udhaar_limit': maxUdhaar,
        'is_store_open': _isStoreOpen,
        'categories': _categories,
        'pickup_radius_km': pickupRadius,
        'delivery_radius_km': deliveryRadius,
        'store_latitude': double.tryParse(_storeLatController.text),
        'store_longitude': double.tryParse(_storeLngController.text),
        'support_phone': _supportPhoneController.text.trim(),
        'whatsapp_message_template': _whatsappMessageController.text.trim(),
      }, SetOptions(merge: true));

      SoundService().play('save.mp3');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(AppLocalizations.of(context)!.settings_saved), backgroundColor: AppColors.primaryDark),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error saving settings: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        
        if (isDesktop) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            body: Column(
              children: [
                const AdminTopHeader(),
                Expanded(
                  child: _isLoading 
                      ? const Center(child: ModernLoader(color: AppColors.primaryDark))
                      : _buildDesktopLayout(),
                ),
              ],
            ),
          );
        }
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(title: Text(AppLocalizations.of(context)!.store_settings)),
          body: _isLoading 
              ? const Center(child: ModernLoader(color: AppColors.primaryDark))
              : _buildDesktopLayout(), // Reusing for mobile for now with SingleChildScrollView
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(),
          const SizedBox(height: 24),
          _buildTabs(),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Content
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAccountInfoCard(),
                    const SizedBox(height: 24),
                    _buildShopBusinessCard(),
                    const SizedBox(height: 24),
                    _buildFinancialRulesCard(),
                    const SizedBox(height: 24),
                    _buildCategoriesCard(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Content
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAppInfoCard(),
                    const SizedBox(height: 24),
                    _buildQuickActionsCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28)),
        const SizedBox(height: 4),
        Text('Manage your store, account, and application preferences', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
      ],
    );
  }

  Widget _buildTabs() {
    final tabs = ['General', 'Shop & Business', 'Notifications', 'Users & Staff', 'Security', 'System'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isActive = _activeTabIndex == index;
          
          IconData icon;
          switch (label) {
            case 'General': icon = Icons.settings_outlined; break;
            case 'Shop & Business': icon = Icons.storefront_outlined; break;
            case 'Notifications': icon = Icons.notifications_none_outlined; break;
            case 'Users & Staff': icon = Icons.people_outline; break;
            case 'Security': icon = Icons.shield_outlined; break;
            case 'System': icon = Icons.storage_outlined; break;
            default: icon = Icons.circle_outlined;
          }

          return GestureDetector(
            onTap: () {
              if (index == 0) setState(() => _activeTabIndex = index);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryLight.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? AppColors.primaryDark : AppColors.bgTint,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: isActive ? AppColors.primaryDark : AppColors.textMid),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? AppColors.primaryDark : AppColors.textDark,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAccountInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account Information', style: AppTextStyles.heading2(color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text('Update your admin account details', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShopAvatar(shopProvider: Provider.of<ShopProvider>(context)),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildHDField('Full Name *', _ownerNameController, Icons.person_outline, 'Admin User')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildHDField('Phone Number', TextEditingController(text: ''), Icons.phone_outlined, 'N/A', readOnly: true)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShopBusinessCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shop & Business Settings', style: AppTextStyles.heading2(color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text('Manage your shop and business information', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                ],
              ),
              Row(
                children: [
                  Text(_isStoreOpen ? 'Store Open' : 'Store Closed', style: TextStyle(color: _isStoreOpen ? AppColors.primaryDark : AppColors.error, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isStoreOpen,
                    activeColor: AppColors.primaryDark,
                    onChanged: (val) {
                      setState(() => _isStoreOpen = val);
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildHDField('Shop Name *', _shopNameController, Icons.storefront_outlined, 'NearKirana General Store')),
              const SizedBox(width: 16),
              Expanded(child: _buildHDField('Contact Number *', _supportPhoneController, Icons.phone_outlined, '98765 43210', prefixText: '+91 ')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildHDField('Store Latitude', _storeLatController, Icons.location_on_outlined, '28.7041')),
              const SizedBox(width: 16),
              Expanded(child: _buildHDField('Store Longitude', _storeLngController, Icons.location_on_outlined, '77.1025')),
            ],
          ),
          const SizedBox(height: 16),
          _buildHDField('WhatsApp Support Message', _whatsappMessageController, Icons.message_outlined, 'Message', maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildFinancialRulesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Financial & Delivery Rules', style: AppTextStyles.heading2(color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text('Configure delivery fees, minimum order limits, and radius', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildHDField('Delivery Fee (₹)', _deliveryFeeController, Icons.moped_outlined, '20')),
              const SizedBox(width: 16),
              Expanded(child: _buildHDField('Minimum Order (₹)', _minOrderController, Icons.shopping_basket_outlined, '300')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildHDField('Free Delivery Threshold (₹)', _freeDeliveryThresholdController, Icons.card_giftcard_outlined, '500')),
              const SizedBox(width: 16),
              Expanded(child: _buildHDField('Max Udhaar Limit (₹)', _maxUdhaarController, Icons.account_balance_wallet_outlined, '2000')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildHDField('Delivery Radius (km)', _deliveryRadiusController, Icons.map_outlined, '5')),
              const SizedBox(width: 16),
              Expanded(child: _buildHDField('Pickup Radius (km)', _pickupRadiusController, Icons.storefront_outlined, '25')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product Categories', style: AppTextStyles.heading2(color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text('Manage categories shown to customers', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._categories.map((cat) {
                return Chip(
                  label: Text(cat, style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.1),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.red),
                  onDeleted: () => setState(() => _categories.remove(cat)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.3))),
                );
              }),
              ActionChip(
                label: const Text('Add Category'),
                avatar: const Icon(Icons.add, size: 16),
                onPressed: _showAddCategoryDialog,
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.widgets_outlined, size: 20, color: AppColors.textDark),
              const SizedBox(width: 8),
              Text('App Information', style: AppTextStyles.heading2(color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('App Version', 'v1.0.0'),
          const SizedBox(height: 16),
          _buildInfoRow('Last Updated', '15 Aug 2024'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Environment', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Production', style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Platform', 'Web Admin Panel'),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_outlined, size: 20, color: AppColors.textDark),
              const SizedBox(width: 8),
              Text('Quick Actions', style: AppTextStyles.heading2(color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => import_language_theme(context),
            icon: const Icon(Icons.language, size: 18),
            label: const Text('Language & Theme', style: TextStyle(fontSize: 14)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.primaryDark),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void import_language_theme(BuildContext context) {
    // Use the AdminDashboard static callback to navigate to index 11
    // This ensures the screen is rendered inside AdminDesktopDashboard (with sidebar).
    if (AdminDashboard.navCallback != null) {
      AdminDashboard.navCallback!(11);
    } else {
      // Fallback: direct push (no sidebar) if not inside AdminDashboard
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminLanguageThemeScreen()),
      );
    }
  }


  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
        Text(value, style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
      ],
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Category Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _categories.add(controller.text.trim()));
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildHDField(String label, TextEditingController controller, IconData icon, String hint, {String? prefixText, bool readOnly = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySemiBold(color: AppColors.textDark).copyWith(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          style: AppTextStyles.bodyMedium(color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            prefixIcon: Icon(icon, color: AppColors.textMid, size: 20),
            filled: true,
            fillColor: readOnly ? AppColors.bgTint.withValues(alpha: 0.5) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryDark)),
          ),
        ),
      ],
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
        debugPrint('Error: $e');
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
            width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.bgTint),
            child: ClipOval(
              child: _isUploading
                  ? const Center(child: ModernLoader(color: AppColors.primaryDark))
                  : (widget.shopProvider.shopProfilePic != null && widget.shopProvider.shopProfilePic!.isNotEmpty)
                      ? ProductImageWidget(imageUrl: widget.shopProvider.shopProfilePic, width: 100, height: 100)
                      : const Icon(Icons.person, size: 50, color: AppColors.textMid),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: const Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}
