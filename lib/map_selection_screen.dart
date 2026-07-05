import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_provider.dart';
import 'language_provider.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapSelectionScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final bool isPickingOnly;

  const MapSelectionScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.isPickingOnly = false,
  });

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  late final MapController _mapController;
  late LatLng _currentCenter;
  bool _isSatellite = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<dynamic> _suggestions = [];
  bool _isSearching = false;
  double? _storeLat;
  double? _storeLng;
  double? _deliveryRadiusKm;
  String? _storeName;

  bool get _isOutOfDeliveryZone {
    if (_storeLat == null || _storeLng == null || _deliveryRadiusKm == null) return false;
    // Don't show out of delivery message for admin who is just picking a location for store setup
    if (widget.isPickingOnly) return false; 
    if (_deliveryRadiusKm! <= 0) return false; // 0 means unlimited delivery radius
    
    final distance = Geolocator.distanceBetween(
      _currentCenter.latitude,
      _currentCenter.longitude,
      _storeLat!,
      _storeLng!,
    );
    return distance > (_deliveryRadiusKm! * 1000);
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLat != 0.0 || widget.initialLng != 0.0) {
      _currentCenter = LatLng(widget.initialLat, widget.initialLng);
    } else {
      // Default fallback while loading
      _currentCenter = const LatLng(28.6139, 77.2090); // New Delhi as fallback
    }
    
    _fetchStoreArea();
  }

  Future<void> _fetchStoreArea() async {
    try {
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final shopId = shopProvider.currentShopId;
      final doc = shopId != null && shopId.isNotEmpty 
          ? await FirebaseFirestore.instance.collection('shops').doc(shopId).get()
          : await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
          
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _storeLat = (data['store_latitude'] as num?)?.toDouble();
          _storeLng = (data['store_longitude'] as num?)?.toDouble();
          _deliveryRadiusKm = (data['delivery_radius_km'] as num?)?.toDouble();
          _storeName = (data['shop_name'] ?? shopProvider.shopName ?? 'Store').toString();
        });

        // Center on store if no initial location was passed
        if (widget.initialLat == 0.0 && widget.initialLng == 0.0 && _storeLat != null && _storeLng != null) {
          setState(() {
            _currentCenter = LatLng(_storeLat!, _storeLng!);
          });
          _mapController.move(_currentCenter, 16.0);
        } else if (widget.initialLat == 0.0 && widget.initialLng == 0.0) {
          _locateUser();
        }
      } else if (widget.initialLat == 0.0 && widget.initialLng == 0.0) {
        _locateUser();
      }
    } catch (_) {
      if (widget.initialLat == 0.0 && widget.initialLng == 0.0) {
        _locateUser();
      }
    }
  }

  void _searchAddress(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }
    
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      try {
        // Adding lat & lon gives location bias for better local places results
        final uri = Uri.parse('https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&lat=${_currentCenter.latitude}&lon=${_currentCenter.longitude}&limit=8');
        final response = await http.get(
          uri, 
          headers: {'User-Agent': 'AdityaKirana/1.0 (Contact: local@kirana.com)'},
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) {
            setState(() {
              _suggestions = data['features'] ?? [];
              _isSearching = false;
            });
          }
        } else {
          if (mounted) {
            setState(() => _isSearching = false);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  Future<void> _locateUser() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text('Please enable GPS/Location services on your device to find your location.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Geolocator.openLocationSettings();
                },
                child: const Text('Open Settings'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permission Denied'),
            content: const Text('Location permissions are permanently denied. Please enable them in your device app settings.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Geolocator.openAppSettings();
                },
                child: const Text('Open App Settings'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _currentCenter = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_currentCenter, 16.0);
      }
    } catch (e) {
      debugPrint('Could not locate user: $e');
    }
  }

  void _showAddressDetailsSheet() async {
    if (widget.isPickingOnly) {
      Navigator.pop(context, _currentCenter);
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: ModernLoader()),
    );

    final addressData = await userProvider.updateCustomLocation(
      _currentCenter.latitude,
      _currentCenter.longitude,
    );

    if (!mounted) return;
    Navigator.pop(context); // close loader

    if (!userProvider.isServiceable) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(langProvider.translate('out_of_delivery_area')),
          content: Text(
            userProvider.serviceabilityError ?? langProvider.translate('error_cant_deliver'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(langProvider.translate('ok_btn')),
            ),
          ],
        ),
      );
      return;
    }

    String selectedLabel = userProvider.addressLabel;
    if (selectedLabel.isEmpty) selectedLabel = 'Home';
    final houseController = TextEditingController(
      text: addressData['house'] ?? userProvider.customerHouseNo,
    );
    final landmarkController = TextEditingController(
      text: addressData['landmark'] ?? userProvider.customerLandmark,
    );
    final localityController = TextEditingController(
      text: addressData['locality'] ?? userProvider.autoLocality,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    langProvider.translate('enter_complete_address'),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: localityController,
                    decoration: InputDecoration(
                      labelText: langProvider.translate('locality_area'),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: houseController,
                    decoration: InputDecoration(
                      labelText: langProvider.translate('house_flat_no'),
                      prefixIcon: const Icon(Icons.home_outlined),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: landmarkController,
                    decoration: InputDecoration(
                      labelText: langProvider.translate('landmark_optional'),
                      prefixIcon: const Icon(Icons.park_outlined),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    langProvider.translate('save_address_as'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildLabelChip(
                        'Home',
                        Icons.home,
                        selectedLabel,
                        (val) => setState(() => selectedLabel = val),
                      ),
                      const SizedBox(width: 8),
                      _buildLabelChip(
                        'Work',
                        Icons.work,
                        selectedLabel,
                        (val) => setState(() => selectedLabel = val),
                      ),
                      const SizedBox(width: 8),
                      _buildLabelChip(
                        'Other',
                        Icons.location_on,
                        selectedLabel,
                        (val) => setState(() => selectedLabel = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (houseController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(behavior: SnackBarBehavior.floating, content: Text(langProvider.translate('enter_house_no')),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        await userProvider.setDeliveryAddress(
                          localityController.text.trim(),
                          houseController.text.trim(),
                          landmarkController.text.trim(),
                          label: selectedLabel,
                        );

                        if (context.mounted) {
                          Navigator.pop(context); // close bottom sheet
                          Navigator.pop(
                            context,
                            _currentCenter,
                          ); // pop map screen and return LatLng
                        }
                      },
                      child: Text(
                        langProvider.translate('save_address_btn'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }

  Widget _buildLabelChip(
    String label,
    IconData icon,
    String selectedLabel,
    Function(String) onSelect,
  ) {
    bool isSelected = selectedLabel == label;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4CAF50).withOpacity(0.1)
              : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPickingOnly ? 'Shop Location' : 'Delivery Location'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 16.0,
              onPositionChanged: (MapCamera position, bool hasGesture) {
                setState(() {
                  _currentCenter = position.center;
                });
              },
              onTap: (tapPosition, point) {
                _mapController.move(point, _mapController.camera.zoom);
                setState(() {
                  _currentCenter = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                    : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.adityakirana.aditya_kirana',
              ),
              if (_storeLat != null && _storeLng != null && _deliveryRadiusKm != null && _deliveryRadiusKm! > 0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(_storeLat!, _storeLng!),
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderColor: Colors.blue.withValues(alpha: 0.5),
                      borderStrokeWidth: 2,
                      radius: _deliveryRadiusKm! * 1000,
                      useRadiusInMeter: true,
                    ),
                  ],
                ),
              if (_storeLat != null && _storeLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_storeLat!, _storeLng!),
                      width: 150,
                      height: 100,
                      alignment: Alignment.center,
                      child: FractionalTranslation(
                        translation: const Offset(0.0, -0.5),
                        child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: Text(
                              _storeName ?? 'Store Location',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.blue, size: 16),
                          const Icon(Icons.location_on, size: 50, color: Colors.blue),
                        ],
                      ),
                    ),
                  ),
                  ],
                ),
            ],
          ),
          // Fixed center pin overlay
          Center(
            child: FractionalTranslation(
              translation: const Offset(0.0, -0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Text(
                      langProvider.translate('move_map_adjust'),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.black87, size: 16),
                  const Icon(Icons.location_on, size: 50, color: Colors.red),
                ],
              ),
            ),
          ),
          // Search overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: langProvider.translate('search_area_hint'),
                      hintStyle: GoogleFonts.poppins(fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _searchAddress('');
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (val) {
                      setState(() {});
                      _searchAddress(val);
                    },
                  ),
                ),
                if (_isSearching)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final feature = _suggestions[i];
                        final props = feature['properties'];
                        final coords = feature['geometry']['coordinates'];
                        
                        String title = props['name'] ?? '';
                        String subtitle = [
                          props['street'], 
                          props['locality'], 
                          props['city'], 
                          props['state']
                        ].where((e) => e != null).join(', ');

                        if (title.isEmpty && subtitle.isNotEmpty) {
                          title = subtitle;
                          subtitle = '';
                        }

                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.grey),
                          title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
                          subtitle: subtitle.isNotEmpty 
                            ? Text(subtitle, style: GoogleFonts.poppins(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis) 
                            : null,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            final lat = coords[1];
                            final lng = coords[0];
                            final newCenter = LatLng(lat, lng);
                            setState(() {
                              _currentCenter = newCenter;
                              _suggestions = [];
                              _searchController.text = title;
                            });
                            _mapController.move(newCenter, 16.0);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 80, // Placed below search bar
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'map_locate_user',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _locateUser,
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'map_layer_toggle',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _isSatellite = !_isSatellite;
                    });
                  },
                  child: Icon(
                    _isSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SafeArea(
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: () {
              if (_isOutOfDeliveryZone) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(langProvider.translate('selected_loc_outside')),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                _showAddressDetailsSheet();
              }
            },
            backgroundColor: _isOutOfDeliveryZone ? Colors.red : const Color(0xFF4CAF50),
            icon: Icon(
              _isOutOfDeliveryZone ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            label: Text(
              _isOutOfDeliveryZone
                  ? langProvider.translate('out_of_delivery_area')
                  : widget.isPickingOnly
                      ? langProvider.translate('confirm_location')
                      : langProvider.translate('confirm_delivery_loc'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
