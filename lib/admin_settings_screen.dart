import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:near_kirana/sound_service.dart';
import 'package:near_kirana/modern_loader.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/language_provider.dart';
import 'package:near_kirana/utils/product_image_widget.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  int _activeTabIndex = 0;

  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _freeDeliveryThresholdController = TextEditingController();
  final _maxUdhaarController = TextEditingController();
  final _pickupRadiusController = TextEditingController();
  final _deliveryRadiusController = TextEditingController();
  final _storeLatController = TextEditingController();
  final _storeLngController = TextEditingController();
  final _basePrepTimeController = TextEditingController(text: '15');
  final _upiIdController = TextEditingController();
  final _razorpayKeyIdController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  final _whatsappMessageController = TextEditingController();
  bool _isStoreOpen = true;
  List<String> _categories = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _deliveryFeeController.dispose();
    _minOrderController.dispose();
    _freeDeliveryThresholdController.dispose();
    _maxUdhaarController.dispose();
    _pickupRadiusController.dispose();
    _deliveryRadiusController.dispose();
    _storeLatController.dispose();
    _storeLngController.dispose();
    _basePrepTimeController.dispose();
    _upiIdController.dispose();
    _razorpayKeyIdController.dispose();
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
        _phoneController.text = data['phone'] ?? data['owner_phone'] ?? data['support_phone'] ?? '';
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
        _basePrepTimeController.text = (data['base_prep_time_minutes'] ?? data['prep_time_minutes'] ?? 15).toString();
        _upiIdController.text = data['upi_id'] ?? data['vpa'] ?? '';
        _razorpayKeyIdController.text = data['razorpay_key_id'] ?? '';
        _supportPhoneController.text = data['support_phone'] ?? '';
        _whatsappMessageController.text = data['whatsapp_message_template'] ?? "नमस्ते {shopName}, मेरा नाम {name} है और मेरा मोबाइल नंबर {phone} है। मुझे अपने ऑर्डर / अकाउंट के बारे में कुछ मदद चाहिए।";

        if (data['categories'] != null) {
          _categories = List<String>.from(data['categories']);
        } else if (data['product_categories'] != null) {
          _categories = List<String>.from(data['product_categories']);
        }
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings(String Function(String, String, String) t) async {
    if (_isSaving) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
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
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(t('Negative values are not allowed', 'नकारात्मक मान की अनुमति नहीं है', 'Negative values allow nahi hain')),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
          setState(() => _isSaving = false);
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
        'base_prep_time_minutes': int.tryParse(_basePrepTimeController.text) ?? 15,
        'support_phone': _supportPhoneController.text.trim(),
        'whatsapp_message_template': _whatsappMessageController.text.trim(),
        'upi_id': _upiIdController.text.trim(),
        'razorpay_key_id': _razorpayKeyIdController.text.trim(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));

      SoundService().productSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(t('Settings saved successfully', 'सेटिंग्स सुरक्षित हो गईं', 'Settings successfully save ho gayi')),
            backgroundColor: const Color(0xFF0C831F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Error saving settings: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Column(
              children: [
                const AdminTopHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: ModernLoader(color: Color(0xFF0C831F)))
                      : _buildDesktopLayout(t),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Store Settings', 'दुकान की सेटिंग्स', 'Store Settings'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                Text(
                  t('Partner Configuration', 'पार्टनर संचालन नियम', 'Partner Configuration'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _isSaving ? null : () => _saveSettings(t),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0C831F)),
                      )
                    : const Icon(Icons.check_rounded, color: Color(0xFF0C831F), size: 24),
                tooltip: t('Save Settings', 'सुरक्षित करें', 'Save Settings'),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: ModernLoader(color: Color(0xFF0C831F)))
              : _buildMobileLayout(t),
        );
      },
    );
  }

  Widget _buildMobileLayout(String Function(String, String, String) t) {
    return Column(
      children: [
        // Tabs
        _buildTabs(t),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Tab Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_activeTabIndex == 0) _buildGeneralTab(t),
                if (_activeTabIndex == 1) _buildDeliveryTab(t),
                if (_activeTabIndex == 2) _buildPaymentsTab(t),
                if (_activeTabIndex == 3) _buildLocationWhatsAppTab(t),
                if (_activeTabIndex == 4) _buildCategoriesTab(t),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _saveSettings(t),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      _isSaving
                          ? t('Saving...', 'सुरक्षित किया जा रहा है...', 'Saving...')
                          : t('Save All Settings', 'सभी सेटिंग्स सुरक्षित करें', 'Save All Settings'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C831F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(String Function(String, String, String) t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Store Settings', 'दुकान की सेटिंग्स', 'Store Settings'),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t(
                      'Manage delivery radius, timings, UPI, and store profile',
                      'दुकान का विवरण, डिलीवरी दूरी और यूपीआई भुगतान प्रबंधित करें',
                      'Manage delivery radius, timings, UPI and store profile',
                    ),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveSettings(t),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(t('Save Settings', 'सुरक्षित करें', 'Save Settings')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C831F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTabs(t),
          const SizedBox(height: 24),
          if (_activeTabIndex == 0) _buildGeneralTab(t),
          if (_activeTabIndex == 1) _buildDeliveryTab(t),
          if (_activeTabIndex == 2) _buildPaymentsTab(t),
          if (_activeTabIndex == 3) _buildLocationWhatsAppTab(t),
          if (_activeTabIndex == 4) _buildCategoriesTab(t),
        ],
      ),
    );
  }

  Widget _buildTabs(String Function(String, String, String) t) {
    final tabs = [
      {'label': t('General', 'सामान्य', 'General'), 'icon': Icons.storefront_rounded},
      {'label': t('Delivery & Prep', 'डिलीवरी व समय', 'Delivery & Prep'), 'icon': Icons.two_wheeler_rounded},
      {'label': t('Payments & UPI', 'यूपीआई व भुगतान', 'Payments & UPI'), 'icon': Icons.payment_rounded},
      {'label': t('Location & Chat', 'लोकेशन व व्हाट्सएप', 'Location & Chat'), 'icon': Icons.pin_drop_rounded},
      {'label': t('Categories', 'कैटेगरी', 'Categories'), 'icon': Icons.category_rounded},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isActive = _activeTabIndex == index;
            final icon = item['icon'] as IconData;
            final label = item['label'] as String;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  icon,
                  size: 16,
                  color: isActive ? Colors.white : const Color(0xFF64748B),
                ),
                label: Text(label),
                selected: isActive,
                selectedColor: const Color(0xFF0C831F),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF334155),
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isActive ? const Color(0xFF0C831F) : Colors.transparent,
                  ),
                ),
                showCheckmark: false,
                onSelected: (selected) {
                  if (selected) {
                    HapticFeedback.selectionClick();
                    setState(() => _activeTabIndex = index);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGeneralTab(String Function(String, String, String) t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, color: Color(0xFF0C831F), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Store Profile', 'दुकान की मुख्य जानकारी', 'Store Profile'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    t('Shop name, owner & open status', 'नाम, मालिक व चालू/बंद स्थिति', 'Shop name & status'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Open/Close toggle banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _isStoreOpen ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isStoreOpen ? const Color(0xFFA5D6A7) : const Color(0xFFFECACA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isStoreOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isStoreOpen
                              ? t('Store is Online (Accepting Orders)', 'दुकान खुली है (ऑर्डर चालू)', 'Store Online (Orders ON)')
                              : t('Store is Closed (Offline)', 'दुकान बंद है (ऑर्डर बंद)', 'Store Closed (Offline)'),
                          style: TextStyle(
                            color: _isStoreOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _isStoreOpen
                              ? t('Customers can order from your shop', 'ग्राहक ऐप से सामान ऑर्डर कर सकते हैं', 'Customers can place orders')
                              : t('Ordering is temporarily paused', 'ग्राहक अभी ऑर्डर नहीं दे सकते', 'Orders temporarily paused'),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _isStoreOpen,
                  activeThumbColor: const Color(0xFF0C831F),
                  onChanged: (val) {
                    setState(() => _isStoreOpen = val);
                    HapticFeedback.lightImpact();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Shop Avatar
          Center(
            child: _ShopAvatar(shopProvider: Provider.of<ShopProvider>(context)),
          ),
          const SizedBox(height: 18),

          _buildZeptoField(
            label: t('Store Name *', 'दुकान का नाम *', 'Store Name *'),
            controller: _shopNameController,
            icon: Icons.storefront_rounded,
            hint: 'Ravi Kirana Store',
          ),
          const SizedBox(height: 14),

          _buildZeptoField(
            label: t('Owner / Merchant Name *', 'मालिक का नाम *', 'Owner Name *'),
            controller: _ownerNameController,
            icon: Icons.person_rounded,
            hint: 'Ravi Verma',
          ),
          const SizedBox(height: 14),

          _buildZeptoField(
            label: t('Registered Mobile Number', 'पंजीकृत मोबाइल नंबर', 'Registered Phone Number'),
            controller: _phoneController,
            icon: Icons.phone_rounded,
            hint: '9876543210',
            readOnly: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTab(String Function(String, String, String) t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFEA580C), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Delivery & Timings', 'डिलीवरी फीस व समय', 'Delivery & Timings'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    t('Radius, fee, min order & pack time', 'डिलीवरी दायरा, न्यूनतम ऑर्डर व पैकिंग समय', 'Radius, fees & prep time'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildZeptoField(
                  label: t('Delivery Fee (₹)', 'डिलीवरी शुल्क (₹)', 'Delivery Fee (₹)'),
                  controller: _deliveryFeeController,
                  icon: Icons.currency_rupee_rounded,
                  hint: '20',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildZeptoField(
                  label: t('Min Order (₹)', 'न्यूनतम ऑर्डर (₹)', 'Min Order (₹)'),
                  controller: _minOrderController,
                  icon: Icons.shopping_bag_rounded,
                  hint: '100',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildZeptoField(
            label: t('Free Delivery Above (₹)', 'मुफ़्त डिलीवरी कितने रुपये पर (₹)', 'Free Delivery Above (₹)'),
            controller: _freeDeliveryThresholdController,
            icon: Icons.local_offer_rounded,
            hint: '500',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildZeptoField(
                  label: t('Delivery Radius (km)', 'डिलीवरी दायरा (किमी)', 'Delivery Radius (km)'),
                  controller: _deliveryRadiusController,
                  icon: Icons.map_rounded,
                  hint: '5',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildZeptoField(
                  label: t('Prep Time (minutes)', 'पैकिंग समय (मिनट)', 'Prep Time (mins)'),
                  controller: _basePrepTimeController,
                  icon: Icons.timer_rounded,
                  hint: '15',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildZeptoField(
            label: t('Pickup Radius Limit (km)', 'पिकअप अधिकतम दायरा (किमी)', 'Pickup Radius Limit (km)'),
            controller: _pickupRadiusController,
            icon: Icons.storefront_rounded,
            hint: '25',
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab(String Function(String, String, String) t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payment_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('UPI & Payments Setup', 'यूपीआई व पेमेंट सेटिंग्स', 'UPI & Payments Setup'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    t('Direct QR, Razorpay key & Udhaar limit', 'दुकान का QR, रेज़रपे व उधार सीमा', 'Direct QR, Razorpay & Udhaar'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          _buildZeptoField(
            label: t('Store UPI ID / VPA', 'दुकान की UPI आईडी / VPA', 'Store UPI ID / VPA'),
            controller: _upiIdController,
            icon: Icons.qr_code_2_rounded,
            hint: 'merchant@okhdfcbank',
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'Customers scanning your shop QR or paying via UPI will credit directly to this ID.',
              'ग्राहक आपके दुकान के क्यूआर या यूपीआई से सीधे इस खाते में भुगतान करेंगे।',
              'Direct payments from customers will settle to this UPI VPA.',
            ),
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          _buildZeptoField(
            label: t('Max Udhaar Limit Per Customer (₹)', 'प्रति ग्राहक अधिकतम उधार सीमा (₹)', 'Max Udhaar Limit (₹)'),
            controller: _maxUdhaarController,
            icon: Icons.account_balance_wallet_rounded,
            hint: '2000',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          _buildZeptoField(
            label: t('Razorpay Key ID (Online Payment Gateway)', 'रेज़रपे की आईडी (ऑनलाइन कार्ड/नेटबैंकिंग)', 'Razorpay Key ID'),
            controller: _razorpayKeyIdController,
            icon: Icons.vpn_key_rounded,
            hint: 'rzp_live_... or rzp_test_...',
          ),
        ],
      ),
    );
  }

  Widget _buildLocationWhatsAppTab(String Function(String, String, String) t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pin_drop_rounded, color: Color(0xFF0D9488), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Location & WhatsApp Support', 'दुकान की लोकेशन व व्हाट्सएप', 'Location & WhatsApp'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    t('GPS Coordinates & automated message', 'दुकान के जीपीएस निर्देशांक व मैसेज', 'GPS coordinates & templates'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          _buildZeptoField(
            label: t('Customer Support Number', 'कस्टमर सपोर्ट मोबाइल नंबर', 'Support Phone Number'),
            controller: _supportPhoneController,
            icon: Icons.headset_mic_rounded,
            hint: '9876543210',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildZeptoField(
                  label: t('Store Latitude', 'दुकान अक्षांश (Lat)', 'Store Latitude'),
                  controller: _storeLatController,
                  icon: Icons.location_on_rounded,
                  hint: '28.7041',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildZeptoField(
                  label: t('Store Longitude', 'दुकान देशांतर (Lng)', 'Store Longitude'),
                  controller: _storeLngController,
                  icon: Icons.location_on_rounded,
                  hint: '77.1025',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildZeptoField(
            label: t('WhatsApp Support Template', 'व्हाट्सएप सपोर्ट मैसेज प्रारूप', 'WhatsApp Support Message'),
            controller: _whatsappMessageController,
            icon: Icons.chat_rounded,
            hint: 'नमस्ते {shopName}...',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab(String Function(String, String, String) t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.category_rounded, color: Color(0xFF7C3AED), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Product Categories', 'सामान की श्रेणियां', 'Product Categories'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        t('Organize items on customer catalog', 'ग्राहकों को दिखने वाली कैटेगरी', 'Catalog category pills'),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton.filledTonal(
                onPressed: () => _showAddCategoryDialog(t),
                icon: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF0C831F)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0C831F).withValues(alpha: 0.1),
                ),
                tooltip: t('Add Category', 'नई कैटेगरी जोड़ें', 'Add Category'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          if (_categories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t('No categories configured. Tap + to add.', 'कोई कैटेगरी नहीं है। + दबाकर जोड़ें।', 'No categories. Tap + to add.'),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                return Chip(
                  label: Text(
                    cat,
                    style: const TextStyle(color: Color(0xFF0C831F), fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  backgroundColor: const Color(0xFF0C831F).withValues(alpha: 0.08),
                  deleteIcon: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFDC2626)),
                  onDeleted: () => setState(() => _categories.remove(cat)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: const Color(0xFF0C831F).withValues(alpha: 0.2)),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(String Function(String, String, String) t) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          t('Add New Category', 'नई कैटेगरी जोड़ें', 'Add New Category'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: t('e.g. Dairy & Eggs, Snacks', 'उदा. दूध व डेयरी, स्नैक्स', 'e.g. Dairy, Snacks'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Cancel', 'रद्द करें', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C831F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _categories.add(controller.text.trim()));
                Navigator.pop(context);
              }
            },
            child: Text(t('Add', 'जोड़ें', 'Add')),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Widget _buildZeptoField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0C831F), width: 1.5),
            ),
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
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0C831F).withValues(alpha: 0.1),
              border: Border.all(color: const Color(0xFF0C831F).withValues(alpha: 0.3), width: 2),
            ),
            child: ClipOval(
              child: _isUploading
                  ? const Center(child: ModernLoader(color: Color(0xFF0C831F)))
                  : (widget.shopProvider.shopProfilePic != null && widget.shopProvider.shopProfilePic!.isNotEmpty)
                      ? ProductImageWidget(imageUrl: widget.shopProvider.shopProfilePic, width: 90, height: 90)
                      : const Icon(Icons.storefront_rounded, size: 44, color: Color(0xFF0C831F)),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF0C831F),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
