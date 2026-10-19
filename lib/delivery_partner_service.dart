import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_utils.dart';
import 'order_state_machine.dart';
import 'notification_service.dart';
import 'delivery_partner_models.dart';

/// Service managing Delivery Partner registrations, status toggles,
/// order dispatching, pickup confirmation, and delivery completions.
class DeliveryPartnerService {
  final FirebaseFirestore _firestore;

  DeliveryPartnerService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseUtils.firestore;

  FirebaseFirestore get firestore => _firestore;

  CollectionReference get _partnersRef =>
      _firestore.collection('delivery_partners');

  CollectionReference get _ordersRef =>
      _firestore.collection('orders');

  /// Creates or updates a delivery partner profile in Firestore
  Future<DeliveryPartner> registerOrUpdatePartner(DeliveryPartner partner) async {
    final docRef = partner.id.isNotEmpty
        ? _partnersRef.doc(partner.id)
        : _partnersRef.doc();

    final toSave = partner.id.isEmpty
        ? partner.copyWith(id: docRef.id)
        : partner;

    await docRef.set(toSave.toMap(), SetOptions(merge: true));

    // Cache recently used partner for convenience
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_delivery_partner_id', toSave.id);
      await prefs.setString('last_delivery_partner_name', toSave.name);
      await prefs.setString('last_delivery_partner_phone', toSave.phone);
    } catch (_) {}

    return toSave;
  }

  /// Retrieves a partner by document ID
  Future<DeliveryPartner?> getPartner(String partnerId) async {
    if (partnerId.isEmpty) return null;
    try {
      final doc = await _partnersRef.doc(partnerId).get();
      if (!doc.exists || doc.data() == null) return null;
      return DeliveryPartner.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (_) {
      return null;
    }
  }

  /// Looks up a delivery partner by their phone number
  Future<DeliveryPartner?> getPartnerByPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleanPhone.isEmpty) return null;

    try {
      final query = await _partnersRef
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return DeliveryPartner.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (_) {}

    return null;
  }

  /// Real-time stream of all delivery partners registered for a shop (or all if shopId empty)
  Stream<List<DeliveryPartner>> streamShopPartners(String shopId) {
    Query query = _partnersRef;
    if (shopId.isNotEmpty) {
      query = query.where('shop_id', isEqualTo: shopId);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => DeliveryPartner.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// One-time fetch of delivery partners
  Future<List<DeliveryPartner>> getShopPartners(String shopId) async {
    try {
      Query query = _partnersRef;
      if (shopId.isNotEmpty) {
        query = query.where('shop_id', isEqualTo: shopId);
      }
      final snapshot = await query.get();
      final list = snapshot.docs
          .map((doc) => DeliveryPartner.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Toggles partner availability status (available, onDelivery, offline)
  Future<void> updatePartnerStatus(
    String partnerId,
    DeliveryPartnerStatus status,
  ) async {
    if (partnerId.isEmpty) return;
    await _partnersRef.doc(partnerId).update({
      'status': status.key,
      'last_active_at': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a delivery partner record
  Future<void> deletePartner(String partnerId) async {
    if (partnerId.isEmpty) return;
    await _partnersRef.doc(partnerId).delete();
  }

  /// Step 1: Shopkeeper assigns an order to a delivery partner
  Future<void> assignOrderToPartner({
    required String shopId,
    required String orderId,
    required DeliveryPartner partner,
    String? notes,
  }) async {
    if (orderId.isEmpty || partner.id.isEmpty) return;

    final batch = _firestore.batch();

    // 1. Update Order document
    final orderDoc = _ordersRef.doc(orderId);
    batch.set(orderDoc, {
      'delivery_boy_id': partner.id,
      'delivery_boy_name': partner.name,
      'delivery_boy_phone': partner.phone,
      'delivery_vehicle': partner.vehicleNumber,
      'delivery_status': DeliveryTaskStatus.assigned.key,
      'delivery_assigned_at': FieldValue.serverTimestamp(),
      if (notes != null && notes.isNotEmpty) 'delivery_notes': notes,
    }, SetOptions(merge: true));

    // 2. Increment active orders count on Delivery Partner
    final partnerDoc = _partnersRef.doc(partner.id);
    batch.update(partnerDoc, {
      'active_orders_count': FieldValue.increment(1),
      'last_active_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Cache assigned partner details in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_delivery_boy_name', partner.name);
      await prefs.setString('last_delivery_boy_phone', partner.phone);
    } catch (_) {}
  }

  /// Step 2: Delivery Partner accepts the assigned task
  Future<void> acceptDeliveryTask({
    required String orderId,
    required String partnerId,
  }) async {
    if (orderId.isEmpty) return;
    await _ordersRef.doc(orderId).set({
      'delivery_status': DeliveryTaskStatus.accepted.key,
      'delivery_accepted_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Step 3: Partner arrives at shop and confirms pickup of packed parcel
  /// Transitions order status to 'Out for Delivery'
  Future<void> confirmStorePickup({
    required String orderId,
    required String partnerId,
    required String shopId,
    String? customerPhone,
    String? customerUid,
    double? orderTotal,
    String? partnerName,
  }) async {
    if (orderId.isEmpty) return;

    final batch = _firestore.batch();

    final orderDoc = _ordersRef.doc(orderId);
    batch.set(orderDoc, {
      'status': OrderStatus.outForDelivery,
      'delivery_status': DeliveryTaskStatus.pickedUp.key,
      'delivery_picked_up_at': FieldValue.serverTimestamp(),
      'dispatched_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (partnerId.isNotEmpty) {
      final partnerDoc = _partnersRef.doc(partnerId);
      batch.update(partnerDoc, {
        'status': DeliveryPartnerStatus.onDelivery.key,
        'last_active_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // Trigger Out for Delivery Notification to customer
    if (customerPhone != null && customerPhone.isNotEmpty) {
      try {
        await NotificationService.dispatchOrderStatusNotification(
          orderId: orderId,
          newStatus: OrderStatus.outForDelivery,
          customerPhone: customerPhone,
          customerUid: customerUid,
          shopId: shopId,
          orderTotal: orderTotal,
          deliveryBoyName: partnerName,
          firestore: _firestore,
        );
      } catch (_) {}
    }
  }

  /// Step 4: Partner delivers parcel to customer and marks completed
  /// Transitions order status to 'Delivered'
  Future<void> completeDelivery({
    required String orderId,
    required String partnerId,
    required String shopId,
    bool codCollected = false,
    double codAmount = 0.0,
    String? completionNotes,
    String? customerPhone,
    String? customerUid,
    double? orderTotal,
    String? partnerName,
  }) async {
    if (orderId.isEmpty) return;

    final batch = _firestore.batch();

    final orderDoc = _ordersRef.doc(orderId);
    final orderUpdates = <String, dynamic>{
      'status': OrderStatus.delivered,
      'delivery_status': DeliveryTaskStatus.delivered.key,
      'delivery_completed_at': FieldValue.serverTimestamp(),
      'delivered_at': FieldValue.serverTimestamp(),
    };

    if (codCollected) {
      orderUpdates['payment_status'] = 'Paid';
      orderUpdates['cod_collected_by_partner'] = true;
      orderUpdates['cod_amount_collected'] = codAmount;
      orderUpdates['cod_collected_at'] = FieldValue.serverTimestamp();
    }

    if (completionNotes != null && completionNotes.isNotEmpty) {
      orderUpdates['delivery_completion_notes'] = completionNotes;
    }

    batch.set(orderDoc, orderUpdates, SetOptions(merge: true));

    if (partnerId.isNotEmpty) {
      final partnerDoc = _partnersRef.doc(partnerId);
      final partnerUpdates = <String, dynamic>{
        'active_orders_count': FieldValue.increment(-1),
        'total_delivered_count': FieldValue.increment(1),
        'last_active_at': FieldValue.serverTimestamp(),
      };
      if (codCollected && codAmount > 0) {
        partnerUpdates['cash_collected'] = FieldValue.increment(codAmount);
      }
      batch.update(partnerDoc, partnerUpdates);
    }

    await batch.commit();

    // Check if partner has any remaining active deliveries, if not revert status to available
    if (partnerId.isNotEmpty) {
      try {
        final partnerSnap = await _partnersRef.doc(partnerId).get();
        if (partnerSnap.exists && partnerSnap.data() != null) {
          final count = (partnerSnap.data() as Map<String, dynamic>)['active_orders_count'] as num? ?? 0;
          if (count <= 0) {
            await _partnersRef.doc(partnerId).update({
              'status': DeliveryPartnerStatus.available.key,
              'active_orders_count': 0,
            });
          }
        }
      } catch (_) {}
    }

    // Trigger Delivered notification to customer
    if (customerPhone != null && customerPhone.isNotEmpty) {
      try {
        await NotificationService.dispatchOrderStatusNotification(
          orderId: orderId,
          newStatus: OrderStatus.delivered,
          customerPhone: customerPhone,
          customerUid: customerUid,
          shopId: shopId,
          orderTotal: orderTotal,
          deliveryBoyName: partnerName,
          firestore: _firestore,
        );
      } catch (_) {}
    }
  }

  /// Live stream of active orders assigned to this delivery partner
  Stream<List<DeliveryOrderTask>> streamPartnerActiveTasks(String partnerId) {
    if (partnerId.isEmpty) return Stream.value([]);

    return _ordersRef
        .where('delivery_boy_id', isEqualTo: partnerId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DeliveryOrderTask.fromFirestoreDoc(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .where((task) =>
              task.orderStatus != OrderStatus.delivered &&
              task.orderStatus != OrderStatus.cancelled &&
              task.orderStatus != OrderStatus.rejected &&
              task.deliveryTaskStatus != DeliveryTaskStatus.delivered &&
              task.deliveryTaskStatus != DeliveryTaskStatus.cancelled)
          .toList()
        ..sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
    });
  }

  /// Live stream of completed deliveries for this partner
  Stream<List<DeliveryOrderTask>> streamPartnerCompletedTasks(String partnerId) {
    if (partnerId.isEmpty) return Stream.value([]);

    return _ordersRef
        .where('delivery_boy_id', isEqualTo: partnerId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DeliveryOrderTask.fromFirestoreDoc(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .where((task) =>
              task.orderStatus == OrderStatus.delivered ||
              task.deliveryTaskStatus == DeliveryTaskStatus.delivered)
          .toList()
        ..sort((a, b) {
          final timeA = a.deliveredAt ?? a.assignedAt;
          final timeB = b.deliveredAt ?? b.assignedAt;
          return timeB.compareTo(timeA);
        });
    });
  }
}
