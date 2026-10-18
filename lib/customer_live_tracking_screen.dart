import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'live_delivery_tracking_models.dart';
import 'live_delivery_tracking_service.dart';

/// Screen displayed to customers (and store owners) to view real-time GPS location
/// of the assigned delivery partner during active order delivery.
class CustomerLiveTrackingScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic>? initialOrderData;
  final LiveDeliveryTrackingService? service;
  final bool enableTiles;
  final bool enableAnimations;

  const CustomerLiveTrackingScreen({
    super.key,
    required this.orderId,
    this.initialOrderData,
    this.service,
    this.enableTiles = true,
    this.enableAnimations = true,
  });

  /// Convenient helper to open the tracking screen
  static void open(
    BuildContext context, {
    required String orderId,
    Map<String, dynamic>? orderData,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerLiveTrackingScreen(
          orderId: orderId,
          initialOrderData: orderData,
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

  Future<void> _callPartner(String phone) async {
    HapticFeedback.lightImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
      body: StreamBuilder<LiveTrackingSession?>(
        stream: _service.streamTrackingSession(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primaryDark),
              ),
            );
          }

          final session = snapshot.data;

          // Fallback data from initialOrderData if stream document is still initializing
          final orderData = widget.initialOrderData ?? {};
          final customerName =
              session?.customerName ?? orderData['customer_name'] ?? 'Customer';
          final customerAddress = session?.customerAddress ??
              orderData['delivery_address'] ??
              'Delivery Address';

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

          // If rider hasn't broadcasted explicit coordinates yet, position rider on the active route
          if ((partnerLat == null || partnerLng == null) && customerLat != null && shopLat != null) {
            final statusStr = (orderData['status'] ?? session?.status.label ?? '').toString().toLowerCase();
            final isDispatched = statusStr.contains('delivery') ||
                statusStr.contains('transit') ||
                statusStr.contains('pack') ||
                statusStr.contains('ready') ||
                (orderData['delivery_boy_name'] != null && orderData['delivery_boy_name'].toString().isNotEmpty);

            if (isDispatched) {
              partnerLat = shopLat + (customerLat - shopLat) * 0.45;
              partnerLng = shopLng + (customerLng - shopLng) * 0.45;
            }
          }

          // Safe coordinate fallbacks
          final finalCustomerLat = customerLat ?? 28.6139;
          final finalCustomerLng = customerLng ?? 77.2090;
          final finalShopLat = shopLat ?? (finalCustomerLat - 0.0075);
          final finalShopLng = shopLng ?? (finalCustomerLng - 0.0065);
          final finalPartnerLat = partnerLat ?? (finalShopLat + (finalCustomerLat - finalShopLat) * 0.45);
          final finalPartnerLng = partnerLng ?? (finalShopLng + (finalCustomerLng - finalShopLng) * 0.45);

          final partnerPoint = LatLng(finalPartnerLat, finalPartnerLng);
          final customerPoint = LatLng(finalCustomerLat, finalCustomerLng);
          final storePoint = LatLng(finalShopLat, finalShopLng);

          final partnerHeading = session?.currentLocation?.heading ?? 45.0;

          final defaultCenter = partnerPoint;

          // Auto-fit on first valid coordinate load
          if (!_hasInitialCentered) {
            _hasInitialCentered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitAllMarkers(partnerPoint, customerPoint, storePoint);
            });
          }

          // Build route polyline points
          final List<LatLng> polylinePoints = [];
          if (storePoint != null) polylinePoints.add(storePoint);
          if (session != null && session.breadcrumbs.isNotEmpty) {
            for (final b in session.breadcrumbs) {
              polylinePoints.add(LatLng(b.latitude, b.longitude));
            }
          }
          if (partnerPoint != null) {
            polylinePoints.add(partnerPoint);
          }
          if (customerPoint != null) {
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
                          color: AppColors.primaryDark.withValues(alpha: 0.75),
                          borderStrokeWidth: 1.5,
                          borderColor: Colors.white,
                        ),
                      ],
                    ),

                  // Proximity circle around customer destination
                  if (customerPoint != null)
                    CircleLayer(
                      circles: [
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
                      if (storePoint != null)
                        Marker(
                          point: storePoint,
                          width: 50,
                          height: 50,
                          child: _buildStoreMarker(),
                        ),

                      // Customer Destination Marker
                      if (customerPoint != null)
                        Marker(
                          point: customerPoint,
                          width: 80,
                          height: 75,
                          child: _buildDestinationMarker(),
                        ),

                      // Live Delivery Partner Marker
                      if (partnerPoint != null)
                        Marker(
                          point: partnerPoint,
                          width: 90,
                          height: 85,
                          child: _buildPartnerMarker(
                            partnerName,
                            partnerHeading,
                            session?.isNearby ?? false,
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
                child: _buildTopHeader(context, session),
              ),

              // 3. Floating Map Controls (Right Side)
              Positioned(
                right: 16,
                bottom: 250,
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
                    if (partnerPoint != null)
                      _buildMapControlButton(
                        icon: Icons.two_wheeler_rounded,
                        tooltip: 'Center Partner',
                        color: AppColors.primaryDark,
                        iconColor: Colors.white,
                        onTap: () => _centerOn(partnerPoint),
                      ),
                    const SizedBox(height: 10),
                    if (customerPoint != null)
                      _buildMapControlButton(
                        icon: Icons.home_rounded,
                        tooltip: 'Center Destination',
                        onTap: () => _centerOn(customerPoint),
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
                  partnerName: partnerName,
                  partnerPhone: partnerPhone,
                  partnerVehicle: partnerVehicle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // UI WIDGET BUILDERS
  // ==========================================

  Widget _buildTopHeader(BuildContext context, LiveTrackingSession? session) {
    final isNearby = session?.isNearby ?? false;
    final isDelivered = session?.status == LiveTrackingStatus.delivered;

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
                        'Live Delivery Track',
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
                    isDelivered
                        ? 'Order Delivered Successfully'
                        : isNearby
                            ? 'आस-पास पहुंच गए हैं (150m away)'
                            : 'Order #${widget.orderId.substring(widget.orderId.length > 6 ? widget.orderId.length - 6 : 0)} • रास्ते में है',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDelivered
                          ? Colors.green.shade700
                          : isNearby
                              ? Colors.orange.shade800
                              : AppColors.primaryDark,
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

  Widget _buildPartnerMarker(String name, double heading, bool isNearby) {
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
                    color: (isNearby ? Colors.orange : AppColors.primaryDark)
                        .withValues(alpha: 0.25 * (1 - _pulseController.value)),
                  ),
                ),
                // Bike icon with heading rotation
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isNearby ? Colors.orange.shade700 : AppColors.primaryDark,
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

  Widget _buildDestinationMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2),
            ],
          ),
          child: Text(
            'आपका पता',
            style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
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
            Icons.storefront_rounded,
            color: Colors.white,
            size: 18,
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
    required String partnerName,
    required String partnerPhone,
    required String? partnerVehicle,
  }) {
    final isDelivered = session?.status == LiveTrackingStatus.delivered;
    final isNearby = session?.isNearby ?? false;
    final formattedEta = session?.formattedEta ?? '10–20 mins';
    final formattedDist = session?.formattedDistance ?? 'कैलकुलेट हो रहा है...';
    final deliveryPin = orderData['delivery_pin']?.toString();

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
                  color: isDelivered
                      ? Colors.green.shade50
                      : isNearby
                          ? Colors.orange.shade50
                          : AppColors.primaryLight.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDelivered
                      ? Icons.check_circle_rounded
                      : isNearby
                          ? Icons.near_me_rounded
                          : Icons.moped_rounded,
                  color: isDelivered
                      ? Colors.green.shade700
                      : isNearby
                          ? Colors.orange.shade800
                          : AppColors.primaryDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDelivered
                          ? 'डिलीवरी सफल हुई'
                          : isNearby
                              ? 'पहुंचने वाले हैं! (Arrived Nearby)'
                              : '$formattedEta ($formattedDist)',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDelivered
                            ? Colors.green.shade800
                            : isNearby
                                ? Colors.orange.shade900
                                : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDelivered
                          ? 'आपका सामान सुरक्षित डिलीवर हो चुका है'
                          : isNearby
                              ? 'कृपया पार्सल रिसीव करने के लिए तैयार रहें'
                              : 'डिलीवरी पार्टनर आपके पते की ओर आ रहे हैं',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              if (deliveryPin != null && deliveryPin.isNotEmpty && !isDelivered)
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
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: AppColors.bgTint),
          ),

          // 2. Delivery Partner Profile & Call Action
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
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // 3. Privacy & Battery Safeguard notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'गोपनीयता: लोकेशन सिर्फ इस डिलीवरी के दौरान लाइव है और हैंडओवर पर बंद हो जाएगी।',
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
