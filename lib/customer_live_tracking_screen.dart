import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_utils.dart';
import 'order_state_machine.dart';
import 'app_theme.dart';
import 'live_delivery_tracking_models.dart';
import 'live_delivery_tracking_service.dart';

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
    with SingleTickerProviderStateMixin {
  late final LiveDeliveryTrackingService _service;
  late final MapController _mapController;
  late final AnimationController _pulseController;

  bool _isSatellite = false;
  bool _hasInitialCentered = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LiveDeliveryTrackingService();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.enableAnimations) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
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

  Future<void> _callPartner(String phone) async {
    await _callNumber(phone);
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

  void _showRiderPinDialog(BuildContext context, Map<String, dynamic> orderData) {
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
                child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0C831F), size: 24),
              ),
              const SizedBox(width: 10),
              const Text('डिलीवरी PIN सत्यापन', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ग्राहक से 4-अंकों का डिलीवरी PIN पूछकर यहाँ दर्ज करें:',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
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
              child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final entered = pinCtrl.text.trim();
                if (expectedPin.isNotEmpty && entered != expectedPin) {
                  setDlgState(() {
                    errorText = 'गलत PIN! कृपया ग्राहक से सही PIN लें।';
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
                    const SnackBar(
                      content: Text('ऑर्डर सफलतापूर्वक डिलीवर हुआ!'),
                      backgroundColor: Color(0xFF0C831F),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C831F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('वेरिफाई व पूरा करें'),
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
                  ? 'Delivered'
                  : isArrivedAtStore
                      ? 'दुकान पर पहुंचे'
                      : realIsNearby
                          ? '1–2 mins'
                          : realEtaMins <= 2
                              ? '1–2 mins'
                              : '$realEtaMins mins';

              // Build route polyline points based on current delivery phase
              final List<LatLng> polylinePoints = [];
              if (isHeadingToStore || isArrivedAtStore) {
                polylinePoints.add(partnerPoint);
                if (session != null && session.breadcrumbs.isNotEmpty) {
                  for (final b in session.breadcrumbs) {
                    polylinePoints.add(LatLng(b.latitude, b.longitude));
                  }
                }
                polylinePoints.add(storePoint);
              } else {
                polylinePoints.add(storePoint);
                if (session != null && session.breadcrumbs.isNotEmpty) {
                  for (final b in session.breadcrumbs) {
                    polylinePoints.add(LatLng(b.latitude, b.longitude));
                  }
                }
                polylinePoints.add(partnerPoint);
                polylinePoints.add(customerPoint);
              }

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

                      // Route polyline
                      if (polylinePoints.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: polylinePoints,
                              strokeWidth: 4.5,
                              color: (isHeadingToStore || isArrivedAtStore)
                                  ? const Color(0xFF4F46E5).withValues(alpha: 0.85)
                                  : AppColors.primaryDark.withValues(alpha: 0.75),
                              borderStrokeWidth: 1.5,
                              borderColor: Colors.white,
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
                          // Store Marker
                          Marker(
                            point: storePoint,
                            width: 75,
                            height: 60,
                            child: _buildStoreMarker(
                              isTarget: isHeadingToStore || isArrivedAtStore,
                              storeName: shopName,
                            ),
                          ),

                          // Customer Destination Marker
                          Marker(
                            point: customerPoint,
                            width: 90,
                            height: 75,
                            child: _buildDestinationMarker(
                              label: widget.viewerRole == 'customer'
                                  ? 'आपका पता'
                                  : 'ग्राहक: $customerName',
                            ),
                          ),

                          // Live Delivery Partner Marker
                          Marker(
                            point: partnerPoint,
                            width: 90,
                            height: 85,
                            child: _buildPartnerMarker(
                              partnerName,
                              partnerHeading,
                              realIsNearby,
                              isHeadingToStore: isHeadingToStore || isArrivedAtStore,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 2. Top Navigation & Status Bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopHeader(context, session, isDelivered),
                  ),

                  // 3. Floating Map Controls (Right Side)
                  Positioned(
                    right: 16,
                    bottom: widget.viewerRole == 'rider' ? 295 : 260,
                    child: Column(
                      children: [
                        _buildMapControlButton(
                          icon: _isSatellite
                              ? Icons.map_outlined
                              : Icons.satellite_alt_rounded,
                          tooltip: 'Toggle Satellite',
                          onTap: () {
                            setState(() => _isSatellite = !_isSatellite);
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildMapControlButton(
                          icon: Icons.two_wheeler_rounded,
                          tooltip: 'Center Partner',
                          color: AppColors.primaryDark,
                          iconColor: Colors.white,
                          onTap: () => _centerOn(partnerPoint),
                        ),
                        const SizedBox(height: 10),
                        _buildMapControlButton(
                          icon: (isHeadingToStore || isArrivedAtStore)
                              ? Icons.storefront_rounded
                              : Icons.home_rounded,
                          tooltip: (isHeadingToStore || isArrivedAtStore)
                              ? 'Center Store'
                              : 'Center Destination',
                          onTap: () => _centerOn(
                            (isHeadingToStore || isArrivedAtStore)
                                ? storePoint
                                : customerPoint,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildMapControlButton(
                          icon: Icons.zoom_out_map_rounded,
                          tooltip: 'Fit All',
                          onTap: () => _fitAllMarkers(
                            partnerPoint,
                            customerPoint,
                            storePoint,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Floating Bottom Info Card
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
                      isDelivered: isDelivered,
                      realIsNearby: realIsNearby,
                    ),
                  ),
                ],
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

  Widget _buildTopHeader(BuildContext context, LiveTrackingSession? session, bool isDelivered) {
    final isHeadingToStore = session?.isHeadingToStore ?? false;
    final isArrivedAtStore = session?.isArrivedAtStore ?? false;
    final isNearby = session?.isNearby ?? false;

    String titleText = 'Live Delivery Track';
    if (widget.viewerRole == 'shop_owner') {
      titleText = 'Store Live Tracking';
    } else if (widget.viewerRole == 'rider') {
      titleText = 'Delivery Navigation';
    }

    String subtitleText;
    Color subtitleColor;

    final shortOrderId = widget.orderId.length > 6
        ? widget.orderId.substring(widget.orderId.length - 6)
        : widget.orderId;

    if (isDelivered) {
      subtitleText = 'Order #$shortOrderId • डिलीवर हो चुका है';
      subtitleColor = Colors.green.shade700;
    } else if (isArrivedAtStore) {
      subtitleText = 'Order #$shortOrderId • दुकान पहुंच गए हैं (पिकअप)';
      subtitleColor = Colors.purple.shade700;
    } else if (isHeadingToStore) {
      subtitleText = 'Order #$shortOrderId • दुकान की ओर आ रहे हैं';
      subtitleColor = const Color(0xFF4F46E5);
    } else if (isNearby) {
      subtitleText = 'Order #$shortOrderId • आस-पास पहुंच गए हैं';
      subtitleColor = Colors.orange.shade800;
    } else {
      subtitleText = 'Order #$shortOrderId • रास्ते में है';
      subtitleColor = AppColors.primaryDark;
    }

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        titleText,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildLivePulseIndicator(isDelivered),
                    ],
                  ),
                  Text(
                    subtitleText,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor,
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
    );
  }

  Widget _buildLivePulseIndicator(bool isEnded) {
    if (isEnded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'ENDED',
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

  Widget _buildPartnerMarker(
    String name,
    double heading,
    bool isNearby, {
    bool isHeadingToStore = false,
  }) {
    final markerColor = isNearby
        ? Colors.orange.shade700
        : isHeadingToStore
            ? const Color(0xFF4F46E5)
            : AppColors.primaryDark;

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
                name.isNotEmpty ? name : 'Rider',
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
                // Pulsing ring
                Container(
                  width: 44 + (_pulseController.value * 16),
                  height: 44 + (_pulseController.value * 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isNearby
                            ? Colors.orange
                            : isHeadingToStore
                                ? const Color(0xFF6366F1)
                                : AppColors.primaryDark)
                        .withValues(alpha: 0.25 * (1 - _pulseController.value)),
                  ),
                ),
                // Bike icon with heading rotation
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Transform.rotate(
                    angle: heading * (math.pi / 180),
                    child: const Icon(
                      Icons.two_wheeler_rounded,
                      color: Colors.white,
                      size: 20,
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

  Widget _buildDestinationMarker({String label = 'आपका पता'}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.home_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStoreMarker({bool isTarget = false, String storeName = 'दुकान'}) {
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
            storeName.isNotEmpty ? storeName : 'दुकान',
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
    required bool isDelivered,
    required bool realIsNearby,
  }) {
    final isHeadingToStore = session?.isHeadingToStore ?? false;
    final isArrivedAtStore = session?.isArrivedAtStore ?? false;
    final deliveryPin = (orderData['delivery_pin'] ?? '').toString().trim();

    final IconData statusIcon = isDelivered
        ? Icons.check_circle_rounded
        : isArrivedAtStore
            ? Icons.storefront_rounded
            : isHeadingToStore
                ? Icons.store_mall_directory_rounded
                : realIsNearby
                    ? Icons.near_me_rounded
                    : Icons.moped_rounded;

    final Color statusBg = isDelivered
        ? Colors.green.shade50
        : isArrivedAtStore
            ? Colors.purple.shade50
            : isHeadingToStore
                ? const Color(0xFFEEF2FF)
                : realIsNearby
                    ? Colors.orange.shade50
                    : AppColors.primaryLight.withValues(alpha: 0.15);

    final Color statusIconColor = isDelivered
        ? Colors.green.shade700
        : isArrivedAtStore
            ? Colors.purple.shade700
            : isHeadingToStore
                ? const Color(0xFF4F46E5)
                : realIsNearby
                    ? Colors.orange.shade800
                    : AppColors.primaryDark;

    // Dynamic Time & Location Calculation
    final String heroTitle = isDelivered
        ? 'डिलीवरी सफल हुई'
        : isArrivedAtStore
            ? 'दुकान पर पहुंच गए हैं'
            : isHeadingToStore
                ? 'दुकान पिकअप: $dynamicEtaStr ($dynamicDistStr)'
                : realIsNearby
                    ? 'पहुंचने वाले हैं! ($dynamicDistStr)'
                    : '$dynamicEtaStr ($dynamicDistStr दूर)';

    final Color heroTitleColor = isDelivered
        ? Colors.green.shade800
        : isArrivedAtStore
            ? Colors.purple.shade900
            : realIsNearby
                ? Colors.orange.shade900
                : AppColors.textDark;

    final String heroSubtitle = isDelivered
        ? 'सामान सुरक्षित डिलीवर हो चुका है'
        : isArrivedAtStore
            ? 'राइडर दुकान से सामान पिक कर रहे हैं'
            : isHeadingToStore
                ? 'राइडर दुकान की ओर आ रहे हैं'
                : realIsNearby
                    ? 'कृपया पार्सल रिसीव करने के लिए तैयार रहें'
                    : widget.viewerRole == 'rider'
                        ? 'ग्राहक के पते की ओर नेविगेट करें'
                        : widget.viewerRole == 'shop_owner'
                            ? 'राइडर ग्राहक के पते की ओर जा रहा है'
                            : 'डिलीवरी पार्टनर आपके पते की ओर आ रहे हैं';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ETA & Status Hero Banner
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: statusIconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heroTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: heroTitleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      heroSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              if (deliveryPin.isNotEmpty && !isDelivered) ...[
                if (widget.viewerRole == 'rider')
                  InkWell(
                    onTap: () => _showRiderPinDialog(context, orderData),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C831F).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF0C831F).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF0C831F)),
                          const SizedBox(width: 4),
                          Text(
                            'PIN दर्ज करें',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0C831F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentPink.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accentPink.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'PIN',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentPink,
                          ),
                        ),
                        Text(
                          deliveryPin,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentPink,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),

          // 2. Active Destination / Target Info Pill
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isHeadingToStore || isArrivedAtStore
                  ? const Color(0xFFEEF2FF)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHeadingToStore || isArrivedAtStore
                    ? const Color(0xFFC7D2FE)
                    : const Color(0xFFBBF7D0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isHeadingToStore || isArrivedAtStore
                      ? Icons.storefront_rounded
                      : Icons.location_on_rounded,
                  size: 18,
                  color: isHeadingToStore || isArrivedAtStore
                      ? const Color(0xFF4F46E5)
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHeadingToStore || isArrivedAtStore
                            ? 'पिकअप दुकान: $shopName'
                            : 'डिलीवरी गंतव्य: $customerName',
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
                            : (customerAddress.isNotEmpty ? customerAddress : 'ग्राहक का पता'),
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

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: AppColors.bgTint),
          ),

          // 3. Role-Specific Profile & Action Area
          if (widget.viewerRole == 'customer') ...[
            // Customer view: Rider profile + Call Rider
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryDark,
                  child: Text(
                    partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'D',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partnerName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (partnerVehicle != null && partnerVehicle.isNotEmpty)
                        Text(
                          'वाहन: $partnerVehicle',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMid,
                          ),
                        ),
                    ],
                  ),
                ),
                if (partnerPhone.isNotEmpty && !isDelivered)
                  ElevatedButton.icon(
                    onPressed: () => _callPartner(partnerPhone),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('कॉल करें'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ] else if (widget.viewerRole == 'shop_owner') ...[
            // Shop Owner view: Rider + Customer Quick Call Actions
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF1E3A8A),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'राइडर: $partnerName',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ग्राहक: $customerName',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMid,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (partnerPhone.isNotEmpty && !isDelivered) ...[
                  ElevatedButton.icon(
                    onPressed: () => _callNumber(partnerPhone),
                    icon: const Icon(Icons.call_rounded, size: 14),
                    label: const Text('राइडर', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C831F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (customerPhone.isNotEmpty && !isDelivered)
                  OutlinedButton.icon(
                    onPressed: () => _callNumber(customerPhone),
                    icon: const Icon(Icons.call_rounded, size: 14),
                    label: const Text('ग्राहक', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ] else if (widget.viewerRole == 'rider') ...[
            // Rider view: Call Customer, Google Maps Navigation, and Verify PIN Complete button
            Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF0C831F),
                      child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            customerAddress.isNotEmpty ? customerAddress : 'ग्राहक का पता',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textMid,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (customerPhone.isNotEmpty && !isDelivered)
                      ElevatedButton.icon(
                        onPressed: () => _callNumber(customerPhone),
                        icon: const Icon(Icons.call_rounded, size: 15),
                        label: const Text('कॉल ग्राहक', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C831F),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                  ],
                ),
                if (!isDelivered) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchGoogleMaps(targetLat, targetLng),
                          icon: const Icon(Icons.navigation_rounded, size: 16),
                          label: const Text(
                            'गूगल मैप्स',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFFBAE6FD)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRiderPinDialog(context, orderData),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: const Text(
                            'PIN दर्ज कर पूरा करें',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C831F),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: 10),

          // 4. Role-Aware Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  widget.viewerRole == 'rider'
                      ? Icons.navigation_rounded
                      : widget.viewerRole == 'shop_owner'
                          ? Icons.shield_rounded
                          : Icons.lock_outline_rounded,
                  size: 13,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.viewerRole == 'rider'
                        ? 'नेविगेशन मोड: लोकेशन ग्राहक और दुकान को लाइव शेयर हो रही है।'
                        : widget.viewerRole == 'shop_owner'
                            ? 'लाइव ट्रैकिंग: दुकान और ग्राहक दोनों के लिए रियल-टाइम डिलीवरी मॉनिटरिंग।'
                            : 'गोपनीयता: लोकेशन सिर्फ इस डिलीवरी के दौरान लाइव है और हैंडओवर पर बंद हो जाएगी।',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
