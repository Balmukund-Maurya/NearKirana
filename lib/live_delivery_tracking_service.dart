import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_utils.dart';
import 'live_delivery_tracking_models.dart';
import 'sound_service.dart';

/// Service responsible for managing real-time GPS broadcasting by delivery partners
/// and secure, battery-efficient live tracking streaming for customers and shopkeepers.
class LiveDeliveryTrackingService {
  final FirebaseFirestore _firestore;

  // Active broadcasting state (Delivery Partner side)
  StreamSubscription<Position>? _positionSubscription;
  String? _activeBroadcastingOrderId;
  DateTime? _lastBroadcastTime;
  Position? _lastBroadcastPosition;
  bool _isBroadcastingPaused = false;

  // Active Phase & Target Coordinates ('to_store' or 'to_customer')
  String _currentPhase = 'to_customer';
  double? _targetLat;
  double? _targetLng;
  double? _currentShopLat;
  double? _currentShopLng;
  double? _currentCustomerLat;
  double? _currentCustomerLng;

  // Configurable thresholds for battery & Firestore optimization
  final int minUpdateIntervalSeconds;
  final double minUpdateDistanceMeters;
  final int maxBreadcrumbsCount;

  LiveDeliveryTrackingService({
    FirebaseFirestore? firestore,
    this.minUpdateIntervalSeconds = 10,
    this.minUpdateDistanceMeters = 15.0,
    this.maxBreadcrumbsCount = 20,
  }) : _firestore = firestore ?? FirebaseUtils.firestore;

  bool get isBroadcasting =>
      _positionSubscription != null && !_isBroadcastingPaused;
  String? get activeBroadcastingOrderId => _activeBroadcastingOrderId;
  bool get isBroadcastingPaused => _isBroadcastingPaused;

  CollectionReference get _trackingRef =>
      _firestore.collection('delivery_tracking');

  // ==========================================
  // DELIVERY PARTNER BROADCASTING METHODS
  // ==========================================

  /// Initiates live location broadcasting for a specific out-for-delivery order.
  /// Bounded strictly to the active delivery window for privacy.
  Future<bool> startBroadcasting({
    required String orderId,
    required String partnerId,
    required String partnerName,
    required String partnerPhone,
    String? partnerVehicle,
    required String shopId,
    String? shopName,
    double? shopLat,
    double? shopLng,
    required String customerPhone,
    required String customerName,
    required String customerAddress,
    double? customerLat,
    double? customerLng,
    String phase = 'to_customer', // 'to_store' or 'to_customer'
    Stream<Position>? customPositionStreamForTesting,
  }) async {
    // If already broadcasting for another order, terminate previous session first
    if (_activeBroadcastingOrderId != null &&
        _activeBroadcastingOrderId != orderId) {
      await stopBroadcasting(_activeBroadcastingOrderId!, isDelivered: false);
    }

    _activeBroadcastingOrderId = orderId;
    _isBroadcastingPaused = false;
    _lastBroadcastTime = null;
    _lastBroadcastPosition = null;

    _currentPhase = phase;
    _currentShopLat = shopLat;
    _currentShopLng = shopLng;
    _currentCustomerLat = customerLat;
    _currentCustomerLng = customerLng;

    if (phase == 'to_store') {
      _targetLat = shopLat;
      _targetLng = shopLng;
    } else {
      _targetLat = customerLat;
      _targetLng = customerLng;
    }

    final now = DateTime.now();
    final docRef = _trackingRef.doc(orderId);

    final initialStatus = phase == 'to_store'
        ? LiveTrackingStatus.headingToStore
        : LiveTrackingStatus.transit;

    // Initial session document
    final initialSession = LiveTrackingSession(
      orderId: orderId,
      partnerId: partnerId,
      partnerName: partnerName,
      partnerPhone: partnerPhone,
      partnerVehicle: partnerVehicle,
      shopId: shopId,
      shopName: shopName,
      shopLat: shopLat,
      shopLng: shopLng,
      customerPhone: customerPhone,
      customerName: customerName,
      customerAddress: customerAddress,
      customerLat: customerLat,
      customerLng: customerLng,
      currentPhase: phase,
      targetLabel: phase == 'to_store' ? (shopName ?? 'Kirana Store') : customerName,
      isActive: true,
      status: initialStatus,
      sessionStartedAt: now,
      lastUpdatedAt: now,
    );

    await docRef.set(initialSession.toMap(), SetOptions(merge: true));

    // Handle position streaming
    if (customPositionStreamForTesting != null) {
      _positionSubscription = customPositionStreamForTesting.listen(
        (pos) => _handleNewPosition(
          pos,
          orderId,
          customerLat: customerLat,
          customerLng: customerLng,
        ),
        onError: (e) => debugPrint('[Tracking] Custom stream error: $e'),
      );
      return true;
    }

    try {
      final permission = await _checkAndRequestLocationPermission();
      if (!permission) {
        debugPrint('[Tracking] Location permission not granted');
        return false;
      }

      // Configure battery-friendly GPS stream (15m distance filter)
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (pos) => _handleNewPosition(
          pos,
          orderId,
          customerLat: customerLat,
          customerLng: customerLng,
        ),
        onError: (e) => debugPrint('[Tracking] GPS stream error: $e'),
      );

      // Attempt immediate current position fetch
      try {
        final currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        await _handleNewPosition(
          currentPos,
          orderId,
          customerLat: customerLat,
          customerLng: customerLng,
          forceUpdate: true,
        );
      } catch (_) {
        // Fallback to waiting for stream
      }

      return true;
    } catch (e) {
      debugPrint('[Tracking] Error starting location stream: $e');
      return false;
    }
  }

  /// Processes raw GPS update from hardware, applies throttling, ETA calculation,
  /// proximity check, and syncs to Firestore.
  Future<void> _handleNewPosition(
    Position pos,
    String orderId, {
    double? customerLat,
    double? customerLng,
    bool forceUpdate = false,
  }) async {
    if (_isBroadcastingPaused) return;

    final now = DateTime.now();

    // Throttling logic to save battery and Firestore write costs
    if (!forceUpdate && _lastBroadcastTime != null && _lastBroadcastPosition != null) {
      final elapsed = now.difference(_lastBroadcastTime!).inSeconds;
      final distMoved = Geolocator.distanceBetween(
        _lastBroadcastPosition!.latitude,
        _lastBroadcastPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );

      // If updated very recently (< 10s) and moved less than 15m, skip write
      if (elapsed < minUpdateIntervalSeconds &&
          distMoved < minUpdateDistanceMeters) {
        return;
      }
    }

    _lastBroadcastTime = now;
    _lastBroadcastPosition = pos;

    // Calculate distance remaining to target (Store or Customer)
    double? distanceRemaining;
    int? etaMinutes;
    final isHeadingToStore = _currentPhase == 'to_store';
    LiveTrackingStatus computedStatus = isHeadingToStore
        ? LiveTrackingStatus.headingToStore
        : LiveTrackingStatus.transit;

    final double? targetLat = isHeadingToStore
        ? (_targetLat ?? _currentShopLat)
        : (_targetLat ?? _currentCustomerLat ?? customerLat);
    final double? targetLng = isHeadingToStore
        ? (_targetLng ?? _currentShopLng)
        : (_targetLng ?? _currentCustomerLng ?? customerLng);

    if (targetLat != null &&
        targetLng != null &&
        targetLat != 0.0 &&
        targetLng != 0.0) {
      distanceRemaining = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        targetLat,
        targetLng,
      );

      if (isHeadingToStore) {
        // Proximity detection for store arrival: within 80 meters
        if (distanceRemaining <= 80.0) {
          computedStatus = LiveTrackingStatus.arrivedAtStore;
          try {
            SoundService().orderDispatched();
          } catch (_) {}
        }
      } else {
        // Proximity detection for customer: within 180 meters
        if (distanceRemaining <= 180.0) {
          computedStatus = LiveTrackingStatus.nearby;
          try {
            SoundService().orderDispatched();
          } catch (_) {}
        }
      }

      // Calculate approximate ETA in minutes (assumes 20 km/h average speed in city)
      // 20 km/h = ~5.55 meters per second
      final speed = pos.speed > 2.0 ? pos.speed : 5.5;
      final secondsRemaining = distanceRemaining / speed;
      etaMinutes = (secondsRemaining / 60).ceil();
      if (etaMinutes < 1) etaMinutes = 1;
    }

    final newPoint = DeliveryLocationPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      heading: pos.heading >= 0 ? pos.heading : null,
      speedMps: pos.speed >= 0 ? pos.speed : null,
      accuracyMeters: pos.accuracy,
      timestamp: now,
    );

    try {
      final docRef = _trackingRef.doc(orderId);
      final updateData = <String, dynamic>{
        'current_location': newPoint.toMap(),
        'last_updated_at': Timestamp.fromDate(now),
        'status': computedStatus.key,
        'current_phase': _currentPhase,
        'distance_remaining_meters': distanceRemaining,
        'estimated_minutes_remaining': etaMinutes,
        'breadcrumbs': FieldValue.arrayUnion([newPoint.toMap()]),
      };

      await docRef.set(updateData, SetOptions(merge: true));

      // Also sync light location info into the main order document
      await _firestore.collection('orders').doc(orderId).set({
        'delivery_location': {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'heading': pos.heading,
          'updated_at': Timestamp.fromDate(now),
          'status': computedStatus.key,
          'phase': _currentPhase,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Tracking] Failed to sync position to Firestore: $e');
    }
  }

  /// Manually inject a position (useful for testing or manual ping)
  Future<void> updateManualPosition({
    required String orderId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speedMps,
    double? customerLat,
    double? customerLng,
  }) async {
    final fakePos = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: heading ?? 0.0,
      headingAccuracy: 0.0,
      speed: speedMps ?? 0.0,
      speedAccuracy: 0.0,
    );

    await _handleNewPosition(
      fakePos,
      orderId,
      customerLat: customerLat,
      customerLng: customerLng,
      forceUpdate: true,
    );
  }

  /// Pauses location transmission without tearing down the order session
  void pauseBroadcasting() {
    _isBroadcastingPaused = true;
  }

  /// Resumes location transmission
  void resumeBroadcasting() {
    _isBroadcastingPaused = false;
  }

  /// Completely stops location broadcasting when order is delivered or cancelled.
  /// Bounded strictly to active delivery window to protect partner privacy.
  Future<void> stopBroadcasting(
    String orderId, {
    bool isDelivered = true,
  }) async {
    try {
      await _positionSubscription?.cancel();
    } catch (_) {}
    _positionSubscription = null;
    _isBroadcastingPaused = false;
    _activeBroadcastingOrderId = null;
    _lastBroadcastTime = null;
    _lastBroadcastPosition = null;

    try {
      final now = DateTime.now();
      await _trackingRef.doc(orderId).set({
        'is_active': false,
        'status': isDelivered
            ? LiveTrackingStatus.delivered.key
            : LiveTrackingStatus.ended.key,
        'session_ended_at': Timestamp.fromDate(now),
        'last_updated_at': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Tracking] Error ending tracking session: $e');
    }
  }

  // ==========================================
  // CUSTOMER & SHOP CONSUMPTION METHODS
  // ==========================================

  /// Real-time stream of the live tracking session for an order.
  Stream<LiveTrackingSession?> streamTrackingSession(String orderId) {
    return _trackingRef.doc(orderId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return LiveTrackingSession.fromMap(
        snapshot.data() as Map<String, dynamic>,
        snapshot.id,
      );
    });
  }

  /// Fetches current tracking session once
  Future<LiveTrackingSession?> getTrackingSession(String orderId) async {
    try {
      final doc = await _trackingRef.doc(orderId).get();
      if (!doc.exists || doc.data() == null) return null;
      return LiveTrackingSession.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    } catch (e) {
      debugPrint('[Tracking] Error fetching tracking session: $e');
      return null;
    }
  }

  /// Verifies if GPS permissions are available and enabled
  Future<bool> _checkAndRequestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[Tracking] Permission check error/unsupported: $e');
      return false;
    }
  }
}
