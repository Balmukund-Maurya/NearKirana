import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:near_kirana/firebase_utils.dart';
import 'saved_address_model.dart';

class UserProvider extends ChangeNotifier with WidgetsBindingObserver {
  String _customerName = '';
  String _phoneNumber = '';
  String _email = '';
  String _deliveryAddress = '';
  String _customerHouseNo = '';
  String _customerLandmark = '';
  String _autoLocality = '';
  double? _currentLat;
  double? _currentLng;
  double? _storeLat;
  double? _storeLng;
  double? _deliveryRadiusKm;
  String _addressLabel = 'Home';
  String? _profileImageUrl;
  Map<String, bool> _preferences = {
    'push_notifications': true,
    'offers': true,
    'promo_emails': false,
    'new_products': true,
  };
  List<Map<String, dynamic>> _savedAddresses = [];
  SavedAddress? _activeAddress;

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
  String get email => _email;
  String get deliveryAddress => _deliveryAddress;
  String get customerHouseNo => _customerHouseNo;
  String get customerLandmark => _customerLandmark;
  String get autoLocality => _autoLocality;
  double? get currentLat => _currentLat;
  double? get currentLng => _currentLng;
  double? get storeLat => _storeLat;
  double? get storeLng => _storeLng;
  double? get deliveryRadiusKm => _deliveryRadiusKm;

  void setStoreLocation(double lat, double lng) {
    _storeLat = lat;
    _storeLng = lng;
    notifyListeners();
  }

  void setDeliveryRadius(double radiusKm) {
    _deliveryRadiusKm = radiusKm;
    notifyListeners();
  }
  String get addressLabel => _addressLabel;
  String? get profileImageUrl => _profileImageUrl;
  Map<String, bool> get preferences => _preferences;
  List<Map<String, dynamic>> get savedAddresses => _savedAddresses;

  /// Typed list of customer saved addresses (Home, Office, Other)
  List<SavedAddress> get savedAddressesList =>
      _savedAddresses.map((m) => SavedAddress.fromMap(m)).toList();

  /// The active address currently selected for the customer session/checkout
  SavedAddress? get activeAddress {
    if (_activeAddress != null) return _activeAddress;
    if (_savedAddresses.isEmpty) {
      if (_deliveryAddress.isNotEmpty) {
        return SavedAddress(
          address: _deliveryAddress,
          houseNo: _customerHouseNo,
          landmark: _customerLandmark,
          label: _addressLabel,
          lat: _currentLat,
          lng: _currentLng,
          isDefault: true,
        );
      }
      return null;
    }
    final match = _savedAddresses.firstWhere(
      (m) =>
          m['address'] == _deliveryAddress &&
          m['houseNo'] == _customerHouseNo,
      orElse: () => _savedAddresses.firstWhere(
        (m) => m['isDefault'] == true,
        orElse: () => _savedAddresses.first,
      ),
    );
    return SavedAddress.fromMap(match);
  }

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
    
    // Auto-add or update in saved addresses
    final existingIndex = _savedAddresses.indexWhere((a) => a['address'] == address && a['houseNo'] == houseNo);
    if (existingIndex == -1) {
      final isFirst = _savedAddresses.isEmpty;
      _savedAddresses.add({
        'id': 'addr_${DateTime.now().millisecondsSinceEpoch}',
        'address': address,
        'houseNo': houseNo,
        'landmark': landmark,
        'label': label,
        'lat': _currentLat,
        'lng': _currentLng,
        'isDefault': isFirst,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await prefs.setString('savedAddresses', jsonEncode(_savedAddresses));
      _syncAddressesToFirebase();
    }
    
    notifyListeners();
  }

  /// Add or update a SavedAddress model, managing defaults and syncing
  Future<void> saveAddressModel(SavedAddress address, {bool makeDefault = false}) async {
    final shouldBeDefault = makeDefault || address.isDefault || _savedAddresses.isEmpty;
    final map = address.copyWith(isDefault: shouldBeDefault).toMap();

    if (shouldBeDefault) {
      for (var a in _savedAddresses) {
        a['isDefault'] = false;
      }
    }

    final existingIndex = _savedAddresses.indexWhere(
      (a) => a['id'] == address.id || (a['address'] == address.address && a['houseNo'] == address.houseNo),
    );

    if (existingIndex >= 0) {
      _savedAddresses[existingIndex] = map;
    } else {
      _savedAddresses.add(map);
    }

    if (shouldBeDefault || _deliveryAddress.isEmpty || _deliveryAddress == address.address) {
      _deliveryAddress = address.address;
      _customerHouseNo = address.houseNo;
      _customerLandmark = address.landmark;
      _addressLabel = address.label;
      if (address.lat != null) _currentLat = address.lat;
      if (address.lng != null) _currentLng = address.lng;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customerAddress', _deliveryAddress);
      await prefs.setString('customerHouseNo', _customerHouseNo);
      await prefs.setString('customerLandmark', _customerLandmark);
      await prefs.setString('addressLabel', _addressLabel);
      if (_currentLat != null) await prefs.setDouble('customerLat', _currentLat!);
      if (_currentLng != null) await prefs.setDouble('customerLng', _currentLng!);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedAddresses', jsonEncode(_savedAddresses));
    _syncAddressesToFirebase();
    if (_storeLat == null || _storeLng == null) {
      await checkServiceability();
    } else if (shouldBeDefault || _deliveryAddress.isEmpty || _deliveryAddress == address.address) {
      final serv = evaluateAddressServiceability(address);
      _isServiceable = serv.isServiceable;
      _serviceabilityError = serv.errorMessage;
    }
    notifyListeners();
  }

  /// Select a saved address as the active delivery address for checkout
  Future<void> selectAddressForCheckout(SavedAddress address) async {
    _activeAddress = address;
    _deliveryAddress = address.address;
    _customerHouseNo = address.houseNo;
    _customerLandmark = address.landmark;
    _addressLabel = address.label;
    if (address.lat != null) _currentLat = address.lat;
    if (address.lng != null) _currentLng = address.lng;

    final serv = evaluateAddressServiceability(address);
    _isServiceable = serv.isServiceable;
    _serviceabilityError = serv.errorMessage;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customerAddress', _deliveryAddress);
      await prefs.setString('customerHouseNo', _customerHouseNo);
      await prefs.setString('customerLandmark', _customerLandmark);
      await prefs.setString('addressLabel', _addressLabel);
      if (_currentLat != null) await prefs.setDouble('customerLat', _currentLat!);
      if (_currentLng != null) await prefs.setDouble('customerLng', _currentLng!);
    } catch (e) {
      debugPrint('Error persisting checkout address: $e');
    }

    if (_storeLat == null || _storeLng == null) {
      await checkServiceability();
    }
  }

  /// Sets an address as default, unsetting default on others
  Future<void> setDefaultAddress(String addressId) async {
    int targetIdx = -1;
    for (int i = 0; i < _savedAddresses.length; i++) {
      if (_savedAddresses[i]['id'] == addressId) {
        _savedAddresses[i]['isDefault'] = true;
        targetIdx = i;
      } else {
        _savedAddresses[i]['isDefault'] = false;
      }
    }

    if (targetIdx != -1) {
      final target = SavedAddress.fromMap(_savedAddresses[targetIdx]);
      await selectAddressForCheckout(target);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedAddresses', jsonEncode(_savedAddresses));
      _syncAddressesToFirebase();
    }
    notifyListeners();
  }

  /// Delete saved address by its unique ID
  Future<void> deleteAddressById(String addressId) async {
    final idx = _savedAddresses.indexWhere((a) => a['id'] == addressId);
    if (idx != -1) {
      final wasDefault = _savedAddresses[idx]['isDefault'] == true;
      final wasActive = _savedAddresses[idx]['address'] == _deliveryAddress &&
          _savedAddresses[idx]['houseNo'] == _customerHouseNo;
      _savedAddresses.removeAt(idx);
      if (wasDefault && _savedAddresses.isNotEmpty) {
        _savedAddresses.first['isDefault'] = true;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedAddresses', jsonEncode(_savedAddresses));

      if ((wasActive || wasDefault) && _savedAddresses.isNotEmpty) {
        final next = SavedAddress.fromMap(_savedAddresses.first);
        await selectAddressForCheckout(next);
      } else if (_savedAddresses.isEmpty) {
        _deliveryAddress = '';
        _customerHouseNo = '';
        _customerLandmark = '';
        _addressLabel = 'Home';
        _currentLat = null;
        _currentLng = null;
        await prefs.remove('customerAddress');
        await prefs.remove('customerHouseNo');
        await prefs.remove('customerLandmark');
        await prefs.remove('customerLat');
        await prefs.remove('customerLng');
      }

      _syncAddressesToFirebase();
      if (_storeLat == null || _storeLng == null) {
        await checkServiceability();
      }
      notifyListeners();
    }
  }

  /// Evaluates delivery serviceability for any given SavedAddress against current store location
  AddressServiceabilityResult evaluateAddressServiceability(
    SavedAddress address, {
    double? storeLat,
    double? storeLng,
    double? maxRadiusKm,
  }) {
    final sLat = storeLat ?? _storeLat;
    final sLng = storeLng ?? _storeLng;
    final radius = maxRadiusKm ?? _deliveryRadiusKm ?? 5.0; // fallback default 5km

    if (address.lat == null || address.lng == null || sLat == null || sLng == null) {
      return AddressServiceabilityResult(
        isServiceable: true,
        distanceKm: 0.0,
        maxRadiusKm: radius,
      );
    }

    final distanceMeters = Geolocator.distanceBetween(
      sLat,
      sLng,
      address.lat!,
      address.lng!,
    );
    final distanceKm = distanceMeters / 1000;
    final isServiceable = radius <= 0 || distanceKm <= radius;

    return AddressServiceabilityResult(
      isServiceable: isServiceable,
      distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      maxRadiusKm: radius,
      errorMessage: isServiceable
          ? null
          : 'Outside delivery radius: Dukaan sirf ${radius.toStringAsFixed(1)} km tak deliver karti hai. Yeh address ${distanceKm.toStringAsFixed(1)} km door hai.',
    );
  }

  Future<void> _syncAddressesToFirebase() async {
    final phoneStr = _phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (phoneStr.isNotEmpty) {
      try {
        final qs = await FirebaseUtils.firestore.collection('customers').where('mobile', isEqualTo: phoneStr).get();
        if (qs.docs.isNotEmpty) {
          await FirebaseUtils.firestore.collection('customers').doc(qs.docs.first.id).update({
            'saved_addresses': _savedAddresses,
          });
        }
      } catch (e) {
        debugPrint('Error syncing addresses to Firebase: $e');
      }
    }
  }

  Future<void> addSavedAddress(Map<String, dynamic> addressData) async {
    if (!addressData.containsKey('id')) {
      addressData['id'] = 'addr_${DateTime.now().millisecondsSinceEpoch}';
    }
    _savedAddresses.add(addressData);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedAddresses', jsonEncode(_savedAddresses));
    _syncAddressesToFirebase();
    notifyListeners();
  }

  Future<void> deleteSavedAddress(int index) async {
    if (index >= 0 && index < _savedAddresses.length) {
      _savedAddresses.removeAt(index);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedAddresses', jsonEncode(_savedAddresses));
      _syncAddressesToFirebase();
      notifyListeners();
    }
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
    await prefs.remove('customerProfilePic');
    await prefs.remove('preferences');
    await prefs.remove('savedAddresses');
    _savedAddresses.clear();
    // FIX-4: Clear cart on logout so next user doesn't see previous user's cart
    await prefs.remove('cart_items');
    await prefs.remove('last_order_time');
    await prefs.remove('global_phone');
    await prefs.remove('app_role');
    await prefs.remove('customerEmail');
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final phoneStr = _phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (phoneStr.isNotEmpty) {
      try {
        final qs = await FirebaseUtils.firestore.collection('customers').where('mobile', isEqualTo: phoneStr).get();
        for (var doc in qs.docs) {
          await FirebaseUtils.firestore.collection('customers').doc(doc.id).delete();
        }
      } catch (e) {
        debugPrint('Error deleting account from Firestore: $e');
      }
    }
    await logout();
  }

  Future<void> checkServiceability() async {
    try {
      if (isLoggedIn) {
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('customerPhone') ?? _phoneNumber;
        if (phone.isNotEmpty) {
          final customerDocs = await FirebaseUtils.firestore
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
        doc = await FirebaseUtils.firestore.collection('shops').doc(currentShopId).get();
      } else {
        doc = await FirebaseUtils.firestore.collection('settings').doc('app_config').get();
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

      _currentLat = prefs.getDouble('customerLat');
      _currentLng = prefs.getDouble('customerLng');

      if (_currentLat == null || _currentLng == null) {
        _isServiceable = true; // Let them browse, they will have to set address at checkout
        _serviceabilityError = null;
        _autoLocality = 'Please select delivery address';
      } else {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            _currentLat!,
            _currentLng!,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            _autoLocality = '${place.subLocality ?? ''} ${place.locality ?? ''}'.trim();
            if (_autoLocality.isEmpty) {
              _autoLocality = place.name ?? 'Unknown Location';
            }
          }
        } catch (e) {
          debugPrint('Geocoding error: $e');
          _autoLocality = 'Saved Location';
        }
      }

      if (radiusKm == null || _storeLat == null || _storeLng == null) {
        _isServiceable = true;
        _serviceabilityError = null;
        notifyListeners();
        return;
      }

      if (data['is_store_open'] == false) {
        _isServiceable = false;
        _serviceabilityError = 'Store is currently closed. We are not accepting new orders right now.';
        notifyListeners();
        return;
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

  Future<void> updateProfileImage(String base64Image) async {
    _profileImageUrl = base64Image;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customerProfilePic', base64Image);
    
    final phoneStr = _phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (phoneStr.isNotEmpty) {
      final qs = await FirebaseUtils.firestore.collection('customers').where('mobile', isEqualTo: phoneStr).get();
      if (qs.docs.isNotEmpty) {
        await FirebaseUtils.firestore.collection('customers').doc(qs.docs.first.id).update({
          'profile_image': base64Image,
        });
      }
    }
    notifyListeners();
  }

  Future<void> updateEmail(String newEmail) async {
    _email = newEmail;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customerEmail', newEmail);
    
    final phoneStr = _phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (phoneStr.isNotEmpty) {
      final qs = await FirebaseUtils.firestore.collection('customers').where('mobile', isEqualTo: phoneStr).get();
      if (qs.docs.isNotEmpty) {
        await FirebaseUtils.firestore.collection('customers').doc(qs.docs.first.id).update({
          'email': newEmail,
        });
      }
    }
    notifyListeners();
  }

  Future<void> updatePreference(String key, bool value) async {
    _preferences[key] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferences', jsonEncode(_preferences));
    
    final phoneStr = _phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (phoneStr.isNotEmpty) {
      final qs = await FirebaseUtils.firestore.collection('customers').where('mobile', isEqualTo: phoneStr).get();
      if (qs.docs.isNotEmpty) {
        await FirebaseUtils.firestore.collection('customers').doc(qs.docs.first.id).update({
          'preferences': _preferences,
        });
      }
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
      doc = await FirebaseUtils.firestore.collection('shops').doc(currentShopId).get();
    } else {
      doc = await FirebaseUtils.firestore.collection('settings').doc('app_config').get();
    }
    if (!doc.exists) {
      return {'autoLocality': 'Location selected', 'fullAddress': ''};
    }
    final data = doc.data() as Map<String, dynamic>;
    final double maxDeliveryRadiusKm =
        (data['delivery_radius_km'] as num?)?.toDouble() ?? 5.0;
    final double storeLat = (data['store_latitude'] as num?)?.toDouble() ?? (data['lat'] as num?)?.toDouble() ?? 0.0;
    final double storeLng =
        (data['store_longitude'] as num?)?.toDouble() ?? (data['lng'] as num?)?.toDouble() ?? 0.0;

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
    _email = prefs.getString('customerEmail') ?? '';
    _deliveryAddress = prefs.getString('customerAddress') ?? '';
    _customerHouseNo = prefs.getString('customerHouseNo') ?? '';
    _customerLandmark = prefs.getString('customerLandmark') ?? '';
    _currentLat = prefs.getDouble('customerLat');
    _currentLng = prefs.getDouble('customerLng');
    _addressLabel = prefs.getString('addressLabel') ?? 'Home';
    _profileImageUrl = prefs.getString('customerProfilePic');
    
    final prefsStr = prefs.getString('preferences');
    if (prefsStr != null) {
      try {
        final decoded = jsonDecode(prefsStr) as Map<String, dynamic>;
        _preferences = decoded.map((key, value) => MapEntry(key, value as bool));
      } catch (e) {
        debugPrint('Error decoding preferences: $e');
      }
    }
    
    final savedAddrStr = prefs.getString('savedAddresses');
    if (savedAddrStr != null) {
      try {
        final decodedList = jsonDecode(savedAddrStr) as List;
        _savedAddresses = decodedList.map((e) => e as Map<String, dynamic>).toList();
      } catch (e) {
        debugPrint('Error decoding saved addresses: $e');
      }
    }
    
    notifyListeners();
  }
}
