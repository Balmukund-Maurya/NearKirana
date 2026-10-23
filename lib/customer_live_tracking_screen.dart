import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'firebase_utils.dart';
import 'language_provider.dart';
import 'order_state_machine.dart';
import 'app_theme.dart';
import 'live_delivery_tracking_models.dart';
import 'live_delivery_tracking_service.dart';
import 'road_routing_service.dart';

/// Screen displayed to customers, store owners, and delivery partners to view real-time GPS location
/// and dynamic ETA/route during active order delivery.
class CustomerLiveTrackingScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic>? initialOrderData;
  final LiveDeliveryTrackingService? service;
  final bool enableTiles;
  final bool enableAnimations;
  final String viewerRole; // 'customer', 'shop_owner', 'rider'

  const CustomerLiveTrackingScreen({
    super.key,
    required this.orderId,
    this.initialOrderData,
    this.service,
    this.enableTiles = true,
    this.enableAnimations = true,
    this.viewerRole = 'customer',
  });

  /// Convenient helper to open the tracking screen
  static void open(
    BuildContext context, {
    required String orderId,
    Map<String, dynamic>? orderData,
    String viewerRole = 'customer',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerLiveTrackingScreen(
          orderId: orderId,
          initialOrderData: orderData,
          viewerRole: viewerRole,
        ),
      ),
    );
  }

  @override
  State<CustomerLiveTrackingScreen> createState() =>
      _CustomerLiveTrackingScreenState();
}

class _CustomerLiveTrackingScreenState extends State<CustomerLiveTrackingScreen>
    with TickerProviderStateMixin {
  late final LiveDeliveryTrackingService _service;
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final AnimationController _riderMoveController;

  LatLng? _previousRiderPoint;
  LatLng? _targetRiderPoint;
  double _previousHeading = 0.0;
  double _targetHeading = 0.0;

  bool _isSatellite = false;
  bool _hasInitialCentered = false;

  final RoadRoutingService _roadRoutingService = RoadRoutingService();
  List<LatLng> _roadRoutePoints = [];
  double _roadDistanceMeters = 0.0;
  double _roadDurationSeconds = 0.0;
  String _selectedTransportMode = 'bike'; // 'bike', 'car', 'walk'
  bool _isBottomCardMinimized = false;
  LatLng? _lastRouteStart;
  LatLng? _lastRouteEnd;
  bool _isFetchingRoute = false;

  void _fetchRoadRouteIfNeeded(LatLng start, LatLng end) {
    if (_lastRouteStart != null && _lastRouteEnd != null) {
      final double distStart = Geolocator.distanceBetween(
        _lastRouteStart!.latitude,
        _lastRouteStart!.longitude,
        start.latitude,
        start.longitude,
      );
      final double distEnd = Geolocator.distanceBetween(
        _lastRouteEnd!.latitude,
        _lastRouteEnd!.longitude,
        end.latitude,
        end.longitude,
      );
      if (distStart < 15.0 && distEnd < 15.0 && _roadRoutePoints.isNotEmpty) {
        return;
      }
    }
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;
    _lastRouteStart = start;
    _lastRouteEnd = end;

    _roadRoutingService.fetchRoadRoute(start: start, end: end).then((res) {
      if (mounted) {
        setState(() {
          _isFetchingRoute = false;
          if (res != null && res.points.isNotEmpty) {
            _roadRoutePoints = res.points;
            _roadDistanceMeters = res.distanceMeters;
            _roadDurationSeconds = res.durationSeconds;
          }
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() => _isFetchingRoute = false);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LiveDeliveryTrackingService();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _riderMoveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.enableAnimations) {
      _pulseController.repeat(reverse: true);
    }

    // If viewed by rider, start phone GPS broadcasting immediately
    if (widget.viewerRole == 'rider' && widget.initialOrderData != null) {
      _service.ensureBroadcastingForRider(
        orderId: widget.orderId,
        orderData: widget.initialOrderData!,
      );
    }
  }

  @override
  void dispose() {
    _riderMoveController.dispose();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _updateRiderTarget(LatLng newPoint, double newHeading) {
    if (_targetRiderPoint == null) {
      _previousRiderPoint = newPoint;
      _targetRiderPoint = newPoint;
      _previousHeading = newHeading;
      _targetHeading = newHeading;
      return;
    }

    final double dist = Geolocator.distanceBetween(
      _targetRiderPoint!.latitude,
      _targetRiderPoint!.longitude,
      newPoint.latitude,
      newPoint.longitude,
    );

    final double headingDiff = (newHeading - _targetHeading).abs();

    if (dist > 1.2 || headingDiff > 3.0) {
      _previousRiderPoint = _getCurrentAnimatedRiderPoint();
      _targetRiderPoint = newPoint;
      _previousHeading = _getCurrentAnimatedHeading();
      _targetHeading = newHeading;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _riderMoveController.forward(from: 0.0);
        }
      });
    }
  }

  LatLng _getCurrentAnimatedRiderPoint() {
    if (_previousRiderPoint == null) {
      return _targetRiderPoint ?? const LatLng(28.6139, 77.2090);
    }
    if (_targetRiderPoint == null) return _previousRiderPoint!;
    final t = Curves.easeInOut.transform(_riderMoveController.value);
    final lat = _previousRiderPoint!.latitude +
        (_targetRiderPoint!.latitude - _previousRiderPoint!.latitude) * t;
    final lng = _previousRiderPoint!.longitude +
        (_targetRiderPoint!.longitude - _previousRiderPoint!.longitude) * t;
    return LatLng(lat, lng);
  }

  double _getCurrentAnimatedHeading() {
    if (_previousRiderPoint == null) return _targetHeading;
    final t = Curves.easeInOut.transform(_riderMoveController.value);
    double diff = (_targetHeading - _previousHeading) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (_previousHeading + diff * t) % 360;
  }

  Future<void> _callNumber(String phone) async {
    HapticFeedback.lightImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchGoogleMaps(double lat, double lng) async {
    HapticFeedback.lightImpact();
    if (lat != 0.0 && lng != 0.0) {
      final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      final webNavUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=two_wheeler',
      );
      try {
        if (await canLaunchUrl(navUri)) {
          await launchUrl(navUri);
          return;
        } else if (await canLaunchUrl(webNavUri)) {
          await launchUrl(webNavUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }
  }

  void _showRiderPinDialog(
    BuildContext context,
    Map<String, dynamic> orderData,
    LanguageProvider lang,
  ) {
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    final expectedPin = (orderData['delivery_pin'] ?? '').toString().trim();
    final pinCtrl = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C831F).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF0C831F),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('Delivery PIN Verification', 'डिलीवरी PIN सत्यापन', 'Delivery PIN Verification'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(
                  'Ask customer for the 4-digit delivery PIN and enter below:',
                  'ग्राहक से 4-अंकों का डिलीवरी PIN पूछकर यहाँ दर्ज करें:',
                  'Customer se 4-digit delivery PIN poochkar yahan enter karein:',
                ),
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  errorText: errorText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text(
                t('Cancel', 'रद्द करें', 'Cancel'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final entered = pinCtrl.text.trim();
                if (expectedPin.isNotEmpty && entered != expectedPin) {
                  setDlgState(() {
                    errorText = t(
                      'Incorrect PIN! Please ask customer for correct PIN.',
                      'गलत PIN! कृपया ग्राहक से सही PIN लें।',
                      'Galat PIN! Please customer se correct PIN lein.',
                    );
                  });
                  return;
                }
                Navigator.pop(dlgCtx);
                await FirebaseUtils.firestore.collection('orders').doc(widget.orderId).update({
                  'status': OrderStatus.delivered,
                  'delivered_at': FieldValue.serverTimestamp(),
                  'delivery_status': 'delivered',
                });
                await _service.stopBroadcasting(widget.orderId, isDelivered: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t(
                          'Order delivered successfully!',
                          'ऑर्डर सफलतापूर्वक डिलीवर हुआ!',
                          'Order successfully deliver ho gaya!',
                        ),
                      ),
                      backgroundColor: const Color(0xFF0C831F),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C831F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                t('Verify & Complete', 'वेरिफाई व पूरा करें', 'Verify & Complete'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _centerOn(LatLng point, {double zoom = 16.5}) {
    HapticFeedback.selectionClick();
    _mapController.move(point, zoom);
  }

  void _fitAllMarkers(LatLng? p1, LatLng? p2, LatLng? p3) {
    HapticFeedback.selectionClick();
    final points = [p1, p2, p3].whereType<LatLng>().toList();
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 16.0);
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(
          top: 80,
          bottom: 240,
          left: 40,
          right: 40,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseUtils.firestore.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, orderSnapshot) {
          final liveOrderData = orderSnapshot.data?.data() ?? widget.initialOrderData ?? {};

          return StreamBuilder<LiveTrackingSession?>(
            stream: _service.streamTrackingSession(widget.orderId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && widget.initialOrderData == null && !orderSnapshot.hasData) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: AppColors.primaryDark),
                  ),
                );
              }

              final session = snapshot.data;
              final orderData = liveOrderData;

              // Fallback data from orderData if stream document is still initializing
              final customerName =
                  session?.customerName ?? orderData['customer_name'] ?? 'Customer';
              final customerAddress = session?.customerAddress ??
                  orderData['delivery_address'] ??
                  'Delivery Address';
              final customerPhone = session?.customerPhone ??
                  orderData['customer_phone'] ??
                  orderData['user_phone'] ??
                  orderData['phone'] ??
                  '';
              final shopName = session?.shopName ??
                  orderData['shop_name'] ??
                  orderData['store_name'] ??
                  'Kirana Store';
              final shopAddress = orderData['shop_address'] ??
                  orderData['store_address'] ??
                  'Store Location';

              // 1. Resolve Customer coordinates
              final customerLat = session?.customerLat ??
                  (orderData['customer_lat'] as num?)?.toDouble() ??
                  (orderData['selected_address']?['latitude'] as num?)?.toDouble() ??
                  (orderData['selected_address']?['lat'] as num?)?.toDouble() ??
                  (orderData['delivery_location']?['latitude'] as num?)?.toDouble() ??
                  (orderData['delivery_location']?['lat'] as num?)?.toDouble() ??
                  (orderData['address_lat'] as num?)?.toDouble();
              final customerLng = session?.customerLng ??
                  (orderData['customer_lng'] as num?)?.toDouble() ??
                  (orderData['selected_address']?['longitude'] as num?)?.toDouble() ??
                  (orderData['selected_address']?['lng'] as num?)?.toDouble() ??
                  (orderData['delivery_location']?['longitude'] as num?)?.toDouble() ??
                  (orderData['delivery_location']?['lng'] as num?)?.toDouble() ??
                  (orderData['address_lng'] as num?)?.toDouble();

              final partnerName = session?.partnerName ??
                  orderData['delivery_boy_name'] ??
                  'Rider';
              final partnerPhone = session?.partnerPhone ??
                  orderData['delivery_boy_phone'] ??
                  '';
              final partnerVehicle = session?.partnerVehicle ??
                  orderData['delivery_partner_vehicle'];

              // 2. Resolve Store coordinates
              double? shopLat = session?.shopLat ??
                  (orderData['shop_lat'] as num?)?.toDouble() ??
                  (orderData['store_lat'] as num?)?.toDouble() ??
                  (orderData['shop_latitude'] as num?)?.toDouble();
              double? shopLng = session?.shopLng ??
                  (orderData['shop_lng'] as num?)?.toDouble() ??
                  (orderData['store_lng'] as num?)?.toDouble() ??
                  (orderData['shop_longitude'] as num?)?.toDouble();

              if (shopLat == null && customerLat != null) {
                shopLat = customerLat - 0.0075;
              }
              if (shopLng == null && customerLng != null) {
                shopLng = customerLng - 0.0065;
              }

              // 3. Resolve Rider / Partner coordinates
              double? partnerLat = session?.currentLocation?.latitude ??
                  (orderData['rider_lat'] as num?)?.toDouble() ??
                  (orderData['rider_latitude'] as num?)?.toDouble() ??
                  (orderData['delivery_boy_lat'] as num?)?.toDouble() ??
                  (orderData['partner_lat'] as num?)?.toDouble() ??
                  (orderData['driver_lat'] as num?)?.toDouble();
              double? partnerLng = session?.currentLocation?.longitude ??
                  (orderData['rider_lng'] as num?)?.toDouble() ??
                  (orderData['rider_longitude'] as num?)?.toDouble() ??
                  (orderData['delivery_boy_lng'] as num?)?.toDouble() ??
                  (orderData['partner_lng'] as num?)?.toDouble() ??
                  (orderData['driver_lng'] as num?)?.toDouble();

              // Safe coordinate fallbacks
              final double finalCustomerLat = customerLat ?? 28.6139;
              final double finalCustomerLng = customerLng ?? 77.2090;
              final double finalShopLat = shopLat ?? (finalCustomerLat - 0.0075);
              final double finalShopLng = shopLng ?? (finalCustomerLng - 0.0065);

              // If rider hasn't broadcasted explicit coordinates yet, position rider on the active route
              if (partnerLat == null || partnerLng == null) {
                final statusStr = (orderData['status'] ?? session?.status.label ?? '').toString().toLowerCase();
                final isDispatched = statusStr.contains('delivery') ||
                    statusStr.contains('transit') ||
                    statusStr.contains('pack') ||
                    statusStr.contains('ready') ||
                    (orderData['delivery_boy_name'] != null && orderData['delivery_boy_name'].toString().isNotEmpty);

                if (isDispatched) {
                  partnerLat = finalShopLat + (finalCustomerLat - finalShopLat) * 0.45;
                  partnerLng = finalShopLng + (finalCustomerLng - finalShopLng) * 0.45;
                }
              }

              final double finalPartnerLat = partnerLat ?? (finalShopLat + (finalCustomerLat - finalShopLat) * 0.45);
              final double finalPartnerLng = partnerLng ?? (finalShopLng + (finalCustomerLng - finalShopLng) * 0.45);

              final LatLng partnerPoint = LatLng(finalPartnerLat, finalPartnerLng);
              final LatLng customerPoint = LatLng(finalCustomerLat, finalCustomerLng);
              final LatLng storePoint = LatLng(finalShopLat, finalShopLng);

              final partnerHeading = session?.currentLocation?.heading ?? 45.0;
              final defaultCenter = partnerPoint;

              // Update target point for smooth Zepto/Blinkit glide animation
              _updateRiderTarget(partnerPoint, partnerHeading);

              // Auto-start broadcasting if viewer is rider and service is not yet broadcasting
              if (widget.viewerRole == 'rider' && !_service.isBroadcasting) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_service.isBroadcasting) {
                    _service.ensureBroadcastingForRider(
                      orderId: widget.orderId,
                      orderData: orderData,
                    );
                  }
                });
              }

              final lang = Provider.of<LanguageProvider>(context);
              String t(String en, String hi, String hinglish) {
                if (lang.isHindi) return hi;
                if (lang.isHinglish) return hinglish;
                return en;
              }

              final bool isHeadingToStore = session?.isHeadingToStore ?? false;
              final bool isArrivedAtStore = session?.isArrivedAtStore ?? false;
              final bool isDelivered = (orderData['status']?.toString().toLowerCase() == OrderStatus.delivered.toLowerCase()) ||
                  (session?.status == LiveTrackingStatus.delivered);

              // Auto-fit on first valid coordinate load
              if (!_hasInitialCentered) {
                _hasInitialCentered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (isHeadingToStore || isArrivedAtStore) {
                    _fitAllMarkers(partnerPoint, storePoint, null);
                  } else {
                    _fitAllMarkers(partnerPoint, customerPoint, storePoint);
                  }
                });
              }

              // Dynamic distance & ETA calculation based on real GPS coordinates
              final double targetLat = (isHeadingToStore || isArrivedAtStore) ? finalShopLat : finalCustomerLat;
              final double targetLng = (isHeadingToStore || isArrivedAtStore) ? finalShopLng : finalCustomerLng;

              final double calculatedDist = Geolocator.distanceBetween(
                finalPartnerLat,
                finalPartnerLng,
                targetLat,
                targetLng,
              );

              final double realDistMeters = (session?.distanceRemainingMeters != null && session!.distanceRemainingMeters! > 0)
                  ? session.distanceRemainingMeters!
                  : calculatedDist;

              // Speed approximation: ~20-22 km/h in city traffic = ~350 meters per minute
              final int calculatedEta = ((realDistMeters / 350).ceil()).clamp(1, 90);
              final int realEtaMins = (session?.estimatedMinutesRemaining != null && session!.estimatedMinutesRemaining! > 0)
                  ? session.estimatedMinutesRemaining!
                  : calculatedEta;

              final bool realIsNearby = (session?.isNearby ?? false) || realDistMeters <= 200.0;

              final String dynamicDistStr = realDistMeters < 1000
                  ? '${realDistMeters.round()} m'
                  : '${(realDistMeters / 1000).toStringAsFixed(1)} km';

              final String dynamicEtaStr = isDelivered
                  ? t('Delivered', 'डिलीवर हो गया', 'Delivered')
                  : isArrivedAtStore
                      ? t('At Store', 'दुकान पर पहुंचे', 'Store par pahuche')
                      : realIsNearby
                          ? t('1–2 mins', '1–2 मिनट', '1–2 mins')
                          : realEtaMins <= 2
                              ? t('1–2 mins', '1–2 मिनट', '1–2 mins')
                              : t('$realEtaMins mins', '$realEtaMins मिनट', '$realEtaMins mins');

              final String distAwayStr = t(
                '$dynamicDistStr away',
                '$dynamicDistStr दूर',
                '$dynamicDistStr door',
              );

              return AnimatedBuilder(
                animation: _riderMoveController,
                builder: (context, _) {
                  final animatedRiderPoint = _getCurrentAnimatedRiderPoint();
                  final animatedRiderHeading = _getCurrentAnimatedHeading();

                  // Determine active navigation start & target
                  final LatLng navStart = animatedRiderPoint;
                  final LatLng navTarget = (isHeadingToStore || isArrivedAtStore) ? storePoint : customerPoint;

                  // Request turn-by-turn road route along real streets (OSRM / OpenStreetMap)
                  _fetchRoadRouteIfNeeded(navStart, navTarget);

                  // Compose display route along actual streets
                  final List<LatLng> displayRoutePoints = [];
                  if (_roadRoutePoints.isNotEmpty) {
                    displayRoutePoints.addAll(_roadRoutePoints);
                    final double distToFirst = Geolocator.distanceBetween(
                      animatedRiderPoint.latitude,
                      animatedRiderPoint.longitude,
                      displayRoutePoints.first.latitude,
                      displayRoutePoints.first.longitude,
                    );
                    if (distToFirst > 4.0) {
                      displayRoutePoints.insert(0, animatedRiderPoint);
                    }
                  } else {
                    if (isHeadingToStore || isArrivedAtStore) {
                      displayRoutePoints.add(animatedRiderPoint);
                      displayRoutePoints.add(storePoint);
                    } else {
                      displayRoutePoints.add(storePoint);
                      displayRoutePoints.add(animatedRiderPoint);
                      displayRoutePoints.add(customerPoint);
                    }
                  }

                  // Active road distance & travel speeds:
                  // Bike (~21 km/h): 350 m/min (or OSRM calculated road duration)
                  // Car (~18 km/h): 300 m/min
                  // Walk (~4.8 km/h): 80 m/min
                  final double activeDistanceMeters = _roadDistanceMeters > 0 ? _roadDistanceMeters : realDistMeters;
                  final int bikeEtaMins = _roadDurationSeconds > 0
                      ? (_roadDurationSeconds / 60).ceil().clamp(1, 120)
                      : ((activeDistanceMeters / 350).ceil()).clamp(1, 120);
                  final int carEtaMins = _roadDurationSeconds > 0
                      ? ((_roadDurationSeconds * 1.15) / 60).ceil().clamp(1, 120)
                      : ((activeDistanceMeters / 300).ceil()).clamp(1, 120);
                  final int walkEtaMins = ((activeDistanceMeters / 80).ceil()).clamp(1, 180);

                  final int selectedEtaMins = _selectedTransportMode == 'car'
                      ? carEtaMins
                      : _selectedTransportMode == 'walk'
                          ? walkEtaMins
                          : bikeEtaMins;

                  final String selectedDistStr = activeDistanceMeters < 1000
                      ? '${activeDistanceMeters.round()} m'
                      : '${(activeDistanceMeters / 1000).toStringAsFixed(1)} km';

                  // Floating Road ETA Badge (midpoint along road route)
                  LatLng? roadBadgePoint;
                  if (displayRoutePoints.length >= 2) {
                    final midIdx = displayRoutePoints.length ~/ 2;
                    roadBadgePoint = displayRoutePoints[midIdx];
                  }

                  // Top header labels
                  final String originLabel = widget.viewerRole == 'customer'
                      ? (partnerName.isNotEmpty ? '$partnerName (Live)' : t('Rider Live Location', 'राइडर की लोकेशन', 'Rider Live Location'))
                      : widget.viewerRole == 'rider'
                          ? t('Your Location', 'आपकी लोकेशन', 'Your Location')
                          : t('Delivery Partner', 'डिलीवरी पार्टनर', 'Delivery Partner');

                  final String destinationLabel = isHeadingToStore || isArrivedAtStore
                      ? (shopAddress.isNotEmpty ? shopAddress : shopName)
                      : (customerAddress.isNotEmpty ? customerAddress : customerName);

                  return Stack(
                    children: [
                      // 1. Full Screen Interactive Map
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: defaultCenter,
                          initialZoom: 15.5,
                        ),
                        children: [
                          if (widget.enableTiles)
                            TileLayer(
                              urlTemplate: _isSatellite
                                  ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                                  : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                              userAgentPackageName: 'com.adityakirana.aditya_kirana',
                            ),

                          // Google Maps 2-Layer Road Polyline (exact match to screenshot)
                          if (displayRoutePoints.length >= 2)
                            PolylineLayer(
                              polylines: [
                                // Layer 1: Dark navy road border (Color 0xFF1E3A8A)
                                Polyline(
                                  points: displayRoutePoints,
                                  strokeWidth: 8.5,
                                  color: const Color(0xFF1E3A8A),
                                ),
                                // Layer 2: Vibrant electric blue road core (Color 0xFF2563EB)
                                Polyline(
                                  points: displayRoutePoints,
                                  strokeWidth: 5.5,
                                  color: const Color(0xFF2563EB),
                                ),
                              ],
                            ),

                          // Proximity circle around active destination (Store or Customer)
                          CircleLayer(
                            circles: [
                              if (isHeadingToStore || isArrivedAtStore)
                                CircleMarker(
                                  point: storePoint,
                                  radius: 80,
                                  useRadiusInMeter: true,
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                                  borderColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                  borderStrokeWidth: 1.5,
                                )
                              else
                                CircleMarker(
                                  point: customerPoint,
                                  radius: 120,
                                  useRadiusInMeter: true,
                                  color: Colors.blue.withValues(alpha: 0.08),
                                  borderColor: Colors.blue.withValues(alpha: 0.35),
                                  borderStrokeWidth: 1.5,
                                ),
                            ],
                          ),

                          // Markers Layer
                          MarkerLayer(
                            markers: [
                              // Floating Road ETA Badge (Like [ 1 min ] badge in screenshot)
                              if (roadBadgePoint != null && !isDelivered)
                                Marker(
                                  point: roadBadgePoint,
                                  width: 76,
                                  height: 32,
                                  alignment: Alignment.center,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1D4ED8),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white, width: 1.8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$selectedEtaMins min',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Store Marker
                              Marker(
                                point: storePoint,
                                width: 85,
                                height: 65,
                                child: _buildStoreMarker(
                                  isTarget: isHeadingToStore || isArrivedAtStore,
                                  storeName: shopName,
                                  lang: lang,
                                ),
                              ),

                              // Destination Marker (Google Maps Red Pin with White Dot)
                              Marker(
                                point: customerPoint,
                                width: 90,
                                height: 75,
                                alignment: Alignment.topCenter,
                                child: _buildGoogleMapsDestinationPin(
                                  label: widget.viewerRole == 'customer'
                                      ? t('Your Location', 'आपका पता', 'Aapka Address')
                                      : '${t('Customer', 'ग्राहक', 'Customer')}: $customerName',
                                ),
                              ),

                              // Live Delivery Partner Marker (Google Maps Live Location Blue Dot)
                              Marker(
                                point: animatedRiderPoint,
                                width: 85,
                                height: 85,
                                alignment: Alignment.center,
                                child: _buildGoogleMapsLiveLocationMarker(
                                  partnerName,
                                  animatedRiderHeading,
                                  realIsNearby,
                                  isHeadingToStore: isHeadingToStore || isArrivedAtStore,
                                  lang: lang,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // 2. Top Navigation & Status Bar (Google Maps Header Card)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildTopHeader(
                          context,
                          session,
                          isDelivered,
                          lang,
                          originLabel: originLabel,
                          destinationLabel: destinationLabel,
                          onFitAll: () => _fitAllMarkers(
                            animatedRiderPoint,
                            customerPoint,
                            storePoint,
                          ),
                        ),
                      ),

                      // 3. Floating Map Controls (Right Side)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        right: 16,
                        bottom: _isBottomCardMinimized
                            ? 96
                            : (widget.viewerRole == 'rider' ? 345 : 310),
                        child: Column(
                          children: [
                            _buildMapControlButton(
                              icon: _isSatellite
                                  ? Icons.map_outlined
                                  : Icons.satellite_alt_rounded,
                              tooltip: t('Toggle Satellite', 'सैटेलाइट व्यू बदलें', 'Toggle Satellite'),
                              onTap: () {
                                setState(() => _isSatellite = !_isSatellite);
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildMapControlButton(
                              icon: Icons.two_wheeler_rounded,
                              tooltip: t('Center Rider', 'राइडर पर केंद्रित करें', 'Center Rider'),
                              color: AppColors.primaryDark,
                              iconColor: Colors.white,
                              onTap: () => _centerOn(animatedRiderPoint),
                            ),
                            const SizedBox(height: 10),
                            _buildMapControlButton(
                              icon: (isHeadingToStore || isArrivedAtStore)
                                  ? Icons.storefront_rounded
                                  : Icons.home_rounded,
                              tooltip: (isHeadingToStore || isArrivedAtStore)
                                  ? t('Center Store', 'दुकान पर केंद्रित करें', 'Center Store')
                                  : t('Center Destination', 'गंतव्य पर केंद्रित करें', 'Center Destination'),
                              onTap: () => _centerOn(
                                (isHeadingToStore || isArrivedAtStore)
                                    ? storePoint
                                    : customerPoint,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildMapControlButton(
                              icon: Icons.zoom_out_map_rounded,
                              tooltip: t('Fit All', 'सभी देखें', 'Fit All'),
                              onTap: () => _fitAllMarkers(
                                animatedRiderPoint,
                                customerPoint,
                                storePoint,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 4. Floating Bottom Navigation Card (Matches Screenshot Google Maps Sheet)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: _buildBottomCard(
                          context: context,
                          session: session,
                          orderData: orderData,
                          customerName: customerName,
                          customerAddress: customerAddress,
                          customerPhone: customerPhone,
                          shopName: shopName,
                          shopAddress: shopAddress,
                          partnerName: partnerName,
                          partnerPhone: partnerPhone,
                          partnerVehicle: partnerVehicle,
                          targetLat: targetLat,
                          targetLng: targetLng,
                          realDistMeters: realDistMeters,
                          dynamicDistStr: dynamicDistStr,
                          dynamicEtaStr: dynamicEtaStr,
                          distAwayStr: distAwayStr,
                          isDelivered: isDelivered,
                          realIsNearby: realIsNearby,
                          lang: lang,
                          selectedEtaMins: selectedEtaMins,
                          selectedDistStr: selectedDistStr,
                          bikeEtaMins: bikeEtaMins,
                          carEtaMins: carEtaMins,
                          walkEtaMins: walkEtaMins,
                          onStartNavigation: () => _centerOn(animatedRiderPoint, zoom: 17.5),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ==========================================
  // UI WIDGET BUILDERS
  // ==========================================

  Widget _buildTopHeader(
    BuildContext context,
    LiveTrackingSession? session,
    bool isDelivered,
    LanguageProvider lang, {
    required String originLabel,
    required String destinationLabel,
    VoidCallback? onFitAll,
  }) {
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Origin row (Google Maps blue origin dot)
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A73E8), // Google Maps origin blue dot
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          originLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // 3 vertical connector dots
                  Padding(
                    padding: const EdgeInsets.only(left: 3.5, top: 2, bottom: 2),
                    child: Column(
                      children: [
                        Container(width: 3, height: 3, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                        const SizedBox(height: 2),
                        Container(width: 3, height: 3, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                      ],
                    ),
                  ),
                  // Destination row (Google Maps red pin)
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 13,
                        color: Color(0xFFEA4335), // Google Maps red pin
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          destinationLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Live badge and Route Action
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLivePulseIndicator(isDelivered, lang),
                if (onFitAll != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.swap_vert_rounded, size: 20, color: Color(0xFF475569)),
                    tooltip: t('Fit Route', 'रूट देखें', 'Fit Route'),
                    onPressed: onFitAll,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePulseIndicator(bool isEnded, LanguageProvider lang) {
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    if (isEnded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          t('ENDED', 'समाप्त', 'ENDED'),
          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15 + (_pulseController.value * 0.1)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.4 + (_pulseController.value * 0.4)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'LIVE',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color iconColor = AppColors.textDark,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleMapsLiveLocationMarker(
    String name,
    double heading,
    bool isNearby, {
    bool isHeadingToStore = false,
    required LanguageProvider lang,
  }) {
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4),
                ],
              ),
              child: Text(
                name.isNotEmpty ? name : t('Rider', 'राइडर', 'Rider'),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulsing halo (Google Maps live location aura)
                Container(
                  width: 38 + (_pulseController.value * 14),
                  height: 38 + (_pulseController.value * 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A73E8).withValues(
                      alpha: 0.24 * (1 - _pulseController.value),
                    ),
                  ),
                ),
                // Heading rotation with outer white ring and intense blue dot
                Transform.rotate(
                  angle: heading * (math.pi / 180),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A73E8).withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // White border ring
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        // Solid blue center
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1A73E8), // Google Maps live dot blue
                          ),
                        ),
                        // Mini rider bike
                        const Icon(
                          Icons.two_wheeler_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildGoogleMapsDestinationPin({required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 40,
              color: Color(0xFFEA4335), // Google Maps red
            ),
            Positioned(
              top: 9,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStoreMarker({
    bool isTarget = false,
    String storeName = 'Store',
    required LanguageProvider lang,
  }) {
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isTarget ? const Color(0xFF6366F1) : Colors.blue.shade700,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: (isTarget ? const Color(0xFF6366F1) : Colors.black).withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2),
            ],
          ),
          child: Text(
            storeName.isNotEmpty ? storeName : t('Store', 'दुकान', 'Store'),
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: isTarget ? const Color(0xFF4338CA) : AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTransportModeTab({
    required String mode,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTransportMode = mode);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE0F2FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: const Color(0xFF0284C7), width: 1.5) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCard({
    required BuildContext context,
    required LiveTrackingSession? session,
    required Map<String, dynamic> orderData,
    required String customerName,
    required String customerAddress,
    required String customerPhone,
    required String shopName,
    required String shopAddress,
    required String partnerName,
    required String partnerPhone,
    required String? partnerVehicle,
    required double targetLat,
    required double targetLng,
    required double realDistMeters,
    required String dynamicDistStr,
    required String dynamicEtaStr,
    required String distAwayStr,
    required bool isDelivered,
    required bool realIsNearby,
    required LanguageProvider lang,
    required int selectedEtaMins,
    required String selectedDistStr,
    required int bikeEtaMins,
    required int carEtaMins,
    required int walkEtaMins,
    required VoidCallback onStartNavigation,
  }) {
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    final isHeadingToStore = session?.isHeadingToStore ?? false;
    final isArrivedAtStore = session?.isArrivedAtStore ?? false;
    final deliveryPin = (orderData['delivery_pin'] ?? '').toString().trim();

    final IconData selectedModeIcon;
    switch (_selectedTransportMode) {
      case 'car':
        selectedModeIcon = Icons.directions_car_rounded;
        break;
      case 'walk':
        selectedModeIcon = Icons.directions_walk_rounded;
        break;
      case 'bike':
      default:
        selectedModeIcon = Icons.two_wheeler_rounded;
        break;
    }

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 150 && !_isBottomCardMinimized) {
            HapticFeedback.selectionClick();
            setState(() => _isBottomCardMinimized = true);
          } else if (details.primaryVelocity! < -150 && _isBottomCardMinimized) {
            HapticFeedback.selectionClick();
            setState(() => _isBottomCardMinimized = false);
          }
        }
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(16, 10, 16, _isBottomCardMinimized ? 12 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Pull Handle (Tap to toggle minimize/expand)
              Center(
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isBottomCardMinimized = !_isBottomCardMinimized);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),

              if (_isBottomCardMinimized) ...[
                // Minimized Compact Bar - Leaves entire map unobstructed
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isBottomCardMinimized = false);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        // Transport Mode Icon
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            selectedModeIcon,
                            size: 22,
                            color: const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // ETA & Distance
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isDelivered
                                        ? t('Delivered', 'डिलीवर हुआ', 'Delivered')
                                        : '$selectedEtaMins min',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF15803D),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '($selectedDistStr)',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                isHeadingToStore || isArrivedAtStore
                                    ? shopName
                                    : (customerAddress.isNotEmpty ? customerAddress : customerName),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quick Start Nav Button
                        ElevatedButton.icon(
                          onPressed: onStartNavigation,
                          icon: const Icon(Icons.navigation_rounded, size: 15),
                          label: Text(
                            t('Start', 'शुरू', 'Start'),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007A87),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            minimumSize: Size.zero,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Expand Up-Chevron Button
                        Material(
                          color: Colors.grey.shade100,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _isBottomCardMinimized = false);
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 20,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Expanded Mode - Full Google Maps Sheet
                Row(
                  children: [
                    Text(
                      t('Drive', 'ड्राइव', 'Drive'),
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    // Minimize Down Chevron button
                    Material(
                      color: Colors.grey.shade100,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isBottomCardMinimized = true);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tune/Satellite button
                    Material(
                      color: Colors.grey.shade100,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isSatellite = !_isSatellite);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _isSatellite ? Icons.map_outlined : Icons.tune_rounded,
                            size: 18,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Share button
                    Material(
                      color: Colors.grey.shade100,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(ClipboardData(text: 'Tracking Order #${widget.orderId}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t('Tracking link copied', 'ट्रैकिंग लिंक कॉपी हुआ', 'Tracking link copied')),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.share_rounded,
                            size: 18,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close button
                    Material(
                      color: Colors.grey.shade100,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 3. Transport Modes Selector Tabs (Bike, Car, Walk)
                Row(
                  children: [
                    _buildTransportModeTab(
                      mode: 'bike',
                      icon: Icons.two_wheeler_rounded,
                      label: '$bikeEtaMins min',
                      isSelected: _selectedTransportMode == 'bike',
                    ),
                    const SizedBox(width: 8),
                    _buildTransportModeTab(
                      mode: 'car',
                      icon: Icons.directions_car_rounded,
                      label: '$carEtaMins min',
                      isSelected: _selectedTransportMode == 'car',
                    ),
                    const SizedBox(width: 8),
                    _buildTransportModeTab(
                      mode: 'walk',
                      icon: Icons.directions_walk_rounded,
                      label: '$walkEtaMins min',
                      isSelected: _selectedTransportMode == 'walk',
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 4. Large Green Bold ETA Text
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      isDelivered
                          ? t('Delivered', 'डिलीवर हुआ', 'Delivered')
                          : '$selectedEtaMins min',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF15803D), // Google Maps Green
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '($selectedDistStr)',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isDelivered
                      ? t('Delivery completed successfully', 'ऑर्डर सफलतापूर्वक डिलीवर हो चुका है', 'Order successfully deliver ho gaya')
                      : t('Fastest route, the usual traffic', 'सबसे तेज़ रास्ता, सामान्य ट्रैफ़िक', 'Fastest route, normal traffic'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 12),

                // 5. Action Buttons (Start, Call, PIN)
                Row(
                  children: [
                    // Primary Start / Center Button (Teal pill)
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        onPressed: onStartNavigation,
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: Text(
                          t('Start', 'शुरू करें', 'Start'),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007A87), // Google Maps Teal Navigation
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick Call Button
                    if ((widget.viewerRole == 'customer' && partnerPhone.isNotEmpty) ||
                        (widget.viewerRole == 'rider' && customerPhone.isNotEmpty) ||
                        (widget.viewerRole == 'shop_owner' && partnerPhone.isNotEmpty))
                      Expanded(
                        flex: 4,
                        child: OutlinedButton.icon(
                          onPressed: () => _callNumber(
                            widget.viewerRole == 'rider' ? customerPhone : partnerPhone,
                          ),
                          icon: const Icon(Icons.call_rounded, size: 16),
                          label: Text(
                            widget.viewerRole == 'rider'
                                ? t('Call Customer', 'कॉल ग्राहक', 'Call Customer')
                                : t('Call Rider', 'कॉल राइडर', 'Call Rider'),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Delivery PIN pill
                    if (deliveryPin.isNotEmpty && !isDelivered)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.vpn_key_rounded, size: 13, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Text(
                              'PIN: $deliveryPin',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // 6. Active Destination / Target Address Info Pill
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHeadingToStore || isArrivedAtStore
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isHeadingToStore || isArrivedAtStore
                          ? const Color(0xFFC7D2FE)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isHeadingToStore || isArrivedAtStore
                            ? Icons.storefront_rounded
                            : Icons.location_on_rounded,
                        size: 16,
                        color: isHeadingToStore || isArrivedAtStore
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFFEA4335),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHeadingToStore || isArrivedAtStore
                                  ? '${t('Pickup Store', 'पिकअप दुकान', 'Pickup Store')}: $shopName'
                                  : '${t('Destination', 'गंतव्य', 'Destination')}: $customerName',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isHeadingToStore || isArrivedAtStore
                                  ? shopAddress
                                  : (customerAddress.isNotEmpty ? customerAddress : t('Customer Address', 'ग्राहक का पता', 'Customer Address')),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.textMid,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 7. Rider actions if viewer is Rider
                if (widget.viewerRole == 'rider' && !isDelivered) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchGoogleMaps(targetLat, targetLng),
                          icon: const Icon(Icons.navigation_rounded, size: 15),
                          label: Text(
                            t('Google Maps', 'गूगल मैप्स', 'Google Maps'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFFBAE6FD)),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRiderPinDialog(context, orderData, lang),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                          label: Text(
                            t('Verify PIN', 'PIN दर्ज करें', 'Verify PIN'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C831F),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

