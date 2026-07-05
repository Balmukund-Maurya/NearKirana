import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserProvider extends ChangeNotifier with WidgetsBindingObserver {
  String _customerName = '';
  String _phoneNumber = '';
  String _deliveryAddress = '';
  String _customerHouseNo = '';
  String _customerLandmark = '';
  String _autoLocality = '';
  double? _currentLat;
  double? _currentLng;
  double? _storeLat;
  double? _storeLng;
  String _addressLabel = 'Home';

  UserProvider() {
    WidgetsBinding.instance.addObserver(this);
    loadUserFromPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isLoggedIn) {
        checkServiceability();
      }
    }
  }

  String get customerName => _customerName;
  String get phoneNumber => _phoneNumber;
  String get deliveryAddress => _deliveryAddress;
  String get customerHouseNo => _customerHouseNo;
  String get customerLandmark => _customerLandmark;
  String get autoLocality => _autoLocality;
  double? get currentLat => _currentLat;
  double? get currentLng => _currentLng;
  double? get storeLat => _storeLat;
  double? get storeLng => _storeLng;
  String get addressLabel => _addressLabel;

  bool get isLoggedIn => _phoneNumber.isNotEmpty;

  bool _isServiceable = true;
  String? _serviceabilityError;
  // FIX-3: Separate pickup serviceability
  bool _isPickupAllowed = true;
  String? _pickupError;

  bool get isServiceable => _isServiceable;
  String? get serviceabilityError => _serviceabilityError;
  bool get isPickupAllowed => _isPickupAllowed;
  String? get pickupError => _pickupError;

  void setUser(
    String name,
    String phone, {
    String? address,
    String? houseNo,
    String? landmark,
  }) {
    _customerName = name;
    _phoneNumber = phone;
    if (address != null) _deliveryAddress = address;
    if (houseNo != null) _customerHouseNo = houseNo;
    if (landmark != null) _customerLandmark = landmark;
    notifyListeners();
  }

  Future<void> setDeliveryAddress(
    String address,
    String houseNo,
    String landmark, {
    String label = 'Home',
  }) async {
    _deliveryAddress = address;
    _customerHouseNo = houseNo;
    _customerLandmark = landmark;
    _addressLabel = label;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customerAddress', address);
    await prefs.setString('customerHouseNo', houseNo);
    await prefs.setString('customerLandmark', landmark);
    await prefs.setString('addressLabel', label);
    notifyListeners();
  }

  Future<void> logout() async {
    _customerName = '';
    _phoneNumber = '';
    _deliveryAddress = '';
    _currentLat = null;
    _currentLng = null;
    _isServiceable = true;
    _serviceabilityError = null;
    _isPickupAllowed = true;
    _pickupError = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customerName');
    await prefs.remove('customerPhone');
    await prefs.remove('customerAddress');
    await prefs.remove('customerHouseNo');
    await prefs.remove('customerLandmark');
    await prefs.remove('customerLat');
    await prefs.remove('customerLng');
    await prefs.remove('addressLabel');
    // FIX-4: Clear cart on logout so next user doesn't see previous user's cart
    await prefs.remove('cart_items');
    await prefs.remove('last_order_time');
    notifyListeners();
  }

  Future<void> checkServiceability() async {
    try {
      if (isLoggedIn) {
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('customerPhone') ?? _phoneNumber;
        if (phone.isNotEmpty) {
          final customerDocs = await FirebaseFirestore.instance
              .collection('customers')
              .where('mobile', isEqualTo: phone)
              .limit(1)
              .get();
          if (customerDocs.docs.isNotEmpty) {
            final customerData = customerDocs.docs.first.data();
            if (customerData['is_banned'] == true) {
              _isServiceable = false;
              _serviceabilityError =
                  'Your account has been restricted from placing orders.';
              // FIX-28: Disable pickup as well if user is banned
              _isPickupAllowed = false;
              _pickupError = 'Your account has been restricted from placing orders.';
              notifyListeners();
              return;
            }
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final currentShopId = prefs.getString('current_shop_id');
      
      DocumentSnapshot doc;
      if (currentShopId != null && currentShopId.isNotEmpty) {
        doc = await FirebaseFirestore.instance.collection('shops').doc(currentShopId).get();
      } else {
        doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
      }
      if (!doc.exists) {
        _isServiceable = true;
        _serviceabilityError = null;
        notifyListeners();
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final double? radiusKm = (data['delivery_radius_km'] as num?)?.toDouble();
      _storeLat = (data['store_latitude'] as num?)?.toDouble();
      _storeLng = (data['store_longitude'] as num?)?.toDouble();

      if (radiusKm == null || _storeLat == null || _storeLng == null) {
        _isServiceable = true;
        _serviceabilityError = null;
        notifyListeners();
        return;
      }
      _currentLat = prefs.getDouble('customerLat');
      _currentLng = prefs.getDouble('customerLng');

      if (data['is_store_open'] == false) {
        _isServiceable = false;
        _serviceabilityError = 'Store is currently closed. We are not accepting new orders right now.';
        notifyListeners();
        return;
      }

      if (_currentLat == null || _currentLng == null) {
        _isServiceable =
            true; // Let them browse, they will have to set address at checkout
        _serviceabilityError = null;
        _autoLocality = 'Please select delivery address';
        notifyListeners();
        return;
      } else {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            _currentLat!,
            _currentLng!,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            _autoLocality = '${place.subLocality ?? ''} ${place.locality ?? ''}'
                .trim();
            if (_autoLocality.isEmpty) {
              _autoLocality = place.name ?? 'Unknown Location';
            }
          }
        } catch (e) {
          debugPrint('Geocoding error: $e');
          _autoLocality = 'Saved Location';
        }
      }

      if (_currentLat != null && _currentLng != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          _storeLat!,
          _storeLng!,
          _currentLat!,
          _currentLng!,
        );

        // Delivery radius check
        if (distanceInMeters > radiusKm * 1000) {
          _isServiceable = false;
          _serviceabilityError =
              'Maaf kijiye, abhi hamari service sirf dukaan ke $radiusKm km ke daayre mein uplabdh hai.';
        } else if (data['is_store_open'] == false) {
          _isServiceable = false;
          _serviceabilityError = 'Store is currently closed. We are not accepting new orders right now.';
        } else {
          _isServiceable = true;
          _serviceabilityError = null;
        }

        // FIX-3: Pickup radius check (separate, larger radius)
        final double pickupRadiusKm =
            (data['pickup_radius_km'] as num?)?.toDouble() ?? 25.0;
        if (data['is_store_open'] == false) {
          _isPickupAllowed = false;
          _pickupError = 'Store is currently closed.';
        } else if (distanceInMeters > pickupRadiusKm * 1000) {
          _isPickupAllowed = false;
          _pickupError =
              'You are ${(distanceInMeters / 1000).toStringAsFixed(0)}km away. Pickup is available within ${pickupRadiusKm.toStringAsFixed(0)}km.';
        } else {
          _isPickupAllowed = true;
          _pickupError = null;
        }
      } else {
        // No location set — allow pickup (store will verify in person)
        // FIX-3: If no location, check only store open status for pickup
        if (data['is_store_open'] == false) {
          _isPickupAllowed = false;
          _pickupError = 'Store is currently closed.';
        } else {
          _isPickupAllowed = true;
          _pickupError = null;
        }
      }
    } catch (e) {
      _isServiceable = false;
      _serviceabilityError = 'Could not verify location: $e';
      // On error, allow pickup (conservative approach)
      _isPickupAllowed = true;
      _pickupError = null;
    }
    notifyListeners();
  }

  Future<Map<String, String>> updateCustomLocation(
    double lat,
    double lng,
  ) async {
    _currentLat = lat;
    _currentLng = lng;

    final prefs = await SharedPreferences.getInstance();
    final currentShopId = prefs.getString('current_shop_id');
    
    DocumentSnapshot doc;
    if (currentShopId != null && currentShopId.isNotEmpty) {
      doc = await FirebaseFirestore.instance.collection('shops').doc(currentShopId).get();
    } else {
      doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
    }
    if (!doc.exists) {
      return {'autoLocality': 'Location selected', 'fullAddress': ''};
    }
    final data = doc.data() as Map<String, dynamic>;
    final double maxDeliveryRadiusKm =
        (data['delivery_radius_km'] as num?)?.toDouble() ?? 5.0;
    final double storeLat = (data['store_latitude'] as num?)?.toDouble() ?? 0.0;
    final double storeLng =
        (data['store_longitude'] as num?)?.toDouble() ?? 0.0;

    _storeLat = storeLat;
    _storeLng = storeLng;

    String house = '';
    String landmark = '';

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'AdityaKiranaApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final road =
            address['road'] ?? address['pedestrian'] ?? address['path'] ?? '';
        final suburb =
            address['suburb'] ??
            address['neighbourhood'] ??
            address['residential'] ??
            '';
        final city =
            address['city'] ?? address['town'] ?? address['village'] ?? '';

        _autoLocality = [
          suburb,
          city,
        ].where((e) => e.toString().isNotEmpty).join(', ');
        if (_autoLocality.isEmpty) {
          _autoLocality = data['name'] ?? 'Location selected from Map';
        }

        house =
            address['house_number'] ??
            address['house_name'] ??
            address['building'] ??
            '';
        landmark = road;
      } else {
        throw Exception('Nominatim failed');
      }
    } catch (e) {
      debugPrint('Nominatim error: $e. Falling back to native geocoding.');
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          _autoLocality = '${place.subLocality ?? ''} ${place.locality ?? ''}'
              .trim();
          if (_autoLocality.isEmpty) {
            _autoLocality = place.name ?? 'Location selected from Map';
          }
          if (place.name != null &&
              place.name!.isNotEmpty &&
              place.name != place.subLocality) {
            house = place.name!;
          }
          if (place.street != null &&
              place.street!.isNotEmpty &&
              place.street != house) {
            landmark = place.street!;
          } else if (place.thoroughfare != null &&
              place.thoroughfare!.isNotEmpty) {
            landmark = place.thoroughfare!;
          }
        }
      } catch (nativeE) {
        debugPrint('Native geocoding error: $nativeE');
        _autoLocality = 'Location selected from Map';
      }
    }

    double distanceInMeters = Geolocator.distanceBetween(
      storeLat,
      storeLng,
      lat,
      lng,
    );

    _isServiceable = distanceInMeters <= (maxDeliveryRadiusKm * 1000);
    if (!_isServiceable) {
      _serviceabilityError =
          'Map pin is ${(distanceInMeters / 1000).toStringAsFixed(1)}km away. Max delivery radius is ${maxDeliveryRadiusKm}km.';
    } else {
      _serviceabilityError = null;
    }

    if (_isServiceable) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('customerLat', lat);
      await prefs.setDouble('customerLng', lng);
    }

    notifyListeners();
    return {'house': house, 'landmark': landmark};
  }

  Future<void> loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _customerName = prefs.getString('customerName') ?? '';
    _phoneNumber = prefs.getString('customerPhone') ?? '';
    _deliveryAddress = prefs.getString('customerAddress') ?? '';
    _customerHouseNo = prefs.getString('customerHouseNo') ?? '';
    _customerLandmark = prefs.getString('customerLandmark') ?? '';
    _currentLat = prefs.getDouble('customerLat');
    _currentLng = prefs.getDouble('customerLng');
    _addressLabel = prefs.getString('addressLabel') ?? 'Home';
    notifyListeners();
  }
}
