import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'modern_loader.dart';

class MapSelectionScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const MapSelectionScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  late final MapController _mapController;
  late LatLng _currentCenter;
  bool _isSatellite = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = LatLng(widget.initialLat, widget.initialLng);

    if (widget.initialLat == 0.0 && widget.initialLng == 0.0) {
      _locateUser();
    }
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
    final userProvider = Provider.of<UserProvider>(context, listen: false);

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
          title: const Text('Out of Delivery Area'),
          content: Text(
            userProvider.serviceabilityError ?? 'We do not deliver here yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
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
            return Padding(
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
                    'Enter Complete Address',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: localityController,
                    decoration: const InputDecoration(
                      labelText: 'Locality / Area',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: houseController,
                    decoration: const InputDecoration(
                      labelText: 'House / Flat / Block No.',
                      prefixIcon: Icon(Icons.home_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: landmarkController,
                    decoration: const InputDecoration(
                      labelText: 'Landmark (Optional)',
                      prefixIcon: Icon(Icons.park_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Save address as',
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
                            const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Please enter House/Flat No.'),
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
                        'Save Address',
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
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Adjust Location',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
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
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.adityakirana.aditya_kirana',
              ),
            ],
          ),
          // Fixed center pin overlay
          const Center(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: 40.0,
              ), // Shift up to align pin tip with center
              child: Icon(Icons.location_on, size: 50, color: Colors.red),
            ),
          ),
          // Floating overlay text
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Drag the map to pinpoint your exact delivery location.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
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
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: _showAddressDetailsSheet,
            backgroundColor: const Color(0xFF4CAF50),
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: Text(
              'Confirm Delivery Location',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
