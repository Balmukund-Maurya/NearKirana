import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopProvider with ChangeNotifier {
  StreamSubscription<DocumentSnapshot>? _shopSubscription;
  String? _currentShopId;
  String? _shopName;
  String? _shopAddress;
  String? _shopMobile;
  String? _shopSupportPhone;
  String? _shopBannerUrl;
  String? _shopWhatsAppTemplate;
  String? _shopUpiId;
  String? _shopProfilePic;
  bool _isActive = true;

  String? get currentShopId => _currentShopId;
  String? get shopName => _shopName;
  String? get shopAddress => _shopAddress;
  String? get shopMobile => _shopMobile;
  String? get shopSupportPhone => _shopSupportPhone;
  String? get shopBannerUrl => _shopBannerUrl;
  String? get shopWhatsAppTemplate => _shopWhatsAppTemplate;
  String? get shopUpiId => _shopUpiId;
  String? get shopProfilePic => _shopProfilePic;
  bool get isActive => _isActive;

  Future<void> loadCurrentShop() async {
    final prefs = await SharedPreferences.getInstance();
    _currentShopId = prefs.getString('current_shop_id');
    _shopName = prefs.getString('current_shop_name');
    _shopAddress = prefs.getString('current_shop_address');
    _shopMobile = prefs.getString('current_shop_mobile');
    _shopSupportPhone = prefs.getString('current_shop_support_phone');
    _shopBannerUrl = prefs.getString('current_shop_banner_url');
    _shopWhatsAppTemplate = prefs.getString('current_shop_whatsapp_template');
    _shopUpiId = prefs.getString('current_shop_upi_id');
    _shopProfilePic = prefs.getString('current_shop_profile_pic');
    _isActive = prefs.getBool('current_shop_is_active') ?? true;

    if (_currentShopId != null && _currentShopId!.isNotEmpty) {
      _listenToShop(_currentShopId!);
    } else {
      notifyListeners();
    }
  }

  void _listenToShop(String shopId) {
    _shopSubscription?.cancel();
    _shopSubscription = FirebaseUtils.firestore
        .collection('shops')
        .doc(shopId)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists) {
        notifyListeners();
        return;
      }

      final data = doc.data() ?? {};
      _shopName = data['shop_name']?.toString() ?? _shopName;
      _shopAddress = data['address']?.toString() ?? _shopAddress;
      _shopMobile = data['mobile']?.toString() ?? _shopMobile;
      _shopSupportPhone = data['support_phone']?.toString() ?? data['mobile']?.toString() ?? _shopSupportPhone;
      _shopBannerUrl = data['banner_image_url']?.toString() ?? data['shop_image_url']?.toString() ?? _shopBannerUrl;
      _shopWhatsAppTemplate = data['whatsapp_message_template']?.toString() ?? _shopWhatsAppTemplate;
      _shopUpiId = data['upi_id']?.toString() ?? data['vpa']?.toString() ?? _shopUpiId;
      _shopProfilePic = data['profile_image_url']?.toString() ?? _shopProfilePic;
      _isActive = data['is_active'] ?? true;

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_shop_id', shopId);
        await prefs.setString('current_shop_name', _shopName ?? '');
        if ((_shopAddress ?? '').isNotEmpty) {
          await prefs.setString('current_shop_address', _shopAddress!);
        }
        if ((_shopMobile ?? '').isNotEmpty) {
          await prefs.setString('current_shop_mobile', _shopMobile!);
        }
        if ((_shopSupportPhone ?? '').isNotEmpty) {
          await prefs.setString('current_shop_support_phone', _shopSupportPhone!);
        }
        if ((_shopBannerUrl ?? '').isNotEmpty) {
          await prefs.setString('current_shop_banner_url', _shopBannerUrl!);
        }
        if ((_shopWhatsAppTemplate ?? '').isNotEmpty) {
          await prefs.setString('current_shop_whatsapp_template', _shopWhatsAppTemplate!);
        }
        if ((_shopUpiId ?? '').isNotEmpty) {
          await prefs.setString('current_shop_upi_id', _shopUpiId!);
        }
        if ((_shopProfilePic ?? '').isNotEmpty) {
          await prefs.setString('current_shop_profile_pic', _shopProfilePic!);
        }
        await prefs.setBool('current_shop_is_active', _isActive);
      } catch (_) {}

      notifyListeners();
    });
  }

  Future<void> setShop(
    String shopId,
    String name, {
    String? address,
    String? mobile,
    String? supportPhone,
    String? bannerUrl,
    String? whatsappTemplate,
    String? upiId,
  }) async {
    _currentShopId = shopId;
    _shopName = name;
    _shopAddress = address;
    _shopMobile = mobile;
    _shopSupportPhone = supportPhone ?? mobile;
    _shopBannerUrl = bannerUrl;
    _shopWhatsAppTemplate = whatsappTemplate;
    _shopUpiId = upiId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_shop_id', shopId);
    await prefs.setString('current_shop_name', name);
    if ((address ?? '').isNotEmpty) {
      await prefs.setString('current_shop_address', address!);
    } else {
      await prefs.remove('current_shop_address');
    }
    if ((mobile ?? '').isNotEmpty) {
      await prefs.setString('current_shop_mobile', mobile!);
    } else {
      await prefs.remove('current_shop_mobile');
    }
    if ((supportPhone ?? mobile ?? '').isNotEmpty) {
      await prefs.setString('current_shop_support_phone', supportPhone ?? mobile!);
    } else {
      await prefs.remove('current_shop_support_phone');
    }
    if ((bannerUrl ?? '').isNotEmpty) {
      await prefs.setString('current_shop_banner_url', bannerUrl!);
    } else {
      await prefs.remove('current_shop_banner_url');
    }
    if ((whatsappTemplate ?? '').isNotEmpty) {
      await prefs.setString('current_shop_whatsapp_template', whatsappTemplate!);
    } else {
      await prefs.remove('current_shop_whatsapp_template');
    }
    if ((upiId ?? '').isNotEmpty) {
      await prefs.setString('current_shop_upi_id', upiId!);
    } else {
      await prefs.remove('current_shop_upi_id');
    }

    _listenToShop(shopId);

    notifyListeners();
  }

  Future<void> clearShop() async {
    _shopSubscription?.cancel();
    _shopSubscription = null;
    _currentShopId = null;
    _shopName = null;
    _shopAddress = null;
    _shopMobile = null;
    _shopSupportPhone = null;
    _shopBannerUrl = null;
    _shopWhatsAppTemplate = null;
    _shopUpiId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_shop_id');
    await prefs.remove('current_shop_name');
    await prefs.remove('current_shop_address');
    await prefs.remove('current_shop_mobile');
    await prefs.remove('current_shop_support_phone');
    await prefs.remove('current_shop_banner_url');
    await prefs.remove('current_shop_whatsapp_template');
    await prefs.remove('current_shop_upi_id');
    await prefs.remove('current_shop_profile_pic');
    await prefs.remove('current_shop_is_active');

    notifyListeners();
  }

  Future<void> updateShopProfilePic(String base64Image) async {
    if (_currentShopId == null) return;
    _shopProfilePic = base64Image;
    await FirebaseUtils.firestore.collection('shops').doc(_currentShopId).update({
      'profile_image_url': base64Image,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_shop_profile_pic', base64Image);
    notifyListeners();
  }

  @override
  void dispose() {
    _shopSubscription?.cancel();
    super.dispose();
  }
}
