import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'complaint_model.dart';
import 'firebase_utils.dart';

/// Business service managing Returns, Refunds & Complaints (Feature 51)
class ComplaintService {
  final FirebaseFirestore _firestore;

  ComplaintService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseUtils.firestore;

  CollectionReference<Map<String, dynamic>> get _complaintsRef =>
      _firestore.collection('complaints');

  static int _idCounter = 100;

  /// Generate human-readable tracking complaint ID (e.g., CMP-72819-101)
  static String generateComplaintId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final suffix = (now % 90000) + 10000;
    final counter = ++_idCounter;
    return 'CMP-$suffix-$counter';
  }

  /// Create a new complaint lodged by a customer
  Future<ComplaintModel> createComplaint({
    required String orderId,
    required String shopId,
    required String customerPhone,
    required String customerName,
    required ComplaintType type,
    required String description,
    String? imageUrl,
    List<ComplaintItem> affectedItems = const [],
    ResolutionType requestedResolution = ResolutionType.refund,
  }) async {
    final complaintId = generateComplaintId();
    final now = DateTime.now();

    final complaint = ComplaintModel(
      id: complaintId,
      orderId: orderId,
      shopId: shopId,
      customerPhone: customerPhone,
      customerName: customerName,
      type: type,
      status: ComplaintStatus.pending,
      description: description,
      imageUrl: imageUrl,
      affectedItems: affectedItems,
      requestedResolution: requestedResolution,
      createdAt: now,
      updatedAt: now,
    );

    // 1. Save complaint record
    final compDocRef = _complaintsRef.doc(complaintId);
    await compDocRef.set(complaint.toMap());

    // 2. Link complaint to order record for quick customer visibility (if order exists)
    final orderDocRef = _firestore.collection('orders').doc(orderId);
    final orderDoc = await orderDocRef.get();
    if (orderDoc.exists) {
      await orderDocRef.update({
        'has_complaint': true,
        'complaint_id': complaintId,
        'complaint_status': ComplaintStatus.pending.value,
        'complaint_type': type.value,
        'complaint_created_at': Timestamp.fromDate(now),
      });
    }

    return complaint;
  }

  /// Stream complaints for a shopkeeper with optional status filtering
  Stream<List<ComplaintModel>> streamShopComplaints(
    String shopId, {
    ComplaintStatus? statusFilter,
  }) {
    Query<Map<String, dynamic>> query =
        _complaintsRef.where('shop_id', isEqualTo: shopId);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.value);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ComplaintModel.fromFirestore(doc))
          .toList();
      // Sort in-memory: newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream complaints for a customer across their orders
  Stream<List<ComplaintModel>> streamCustomerComplaints(
    String customerPhone,
    String shopId,
  ) {
    return _complaintsRef
        .where('customer_phone', isEqualTo: customerPhone)
        .where('shop_id', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ComplaintModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Fetch active complaint for a specific order (if any)
  Future<ComplaintModel?> getComplaintForOrder(String orderId) async {
    final query = await _complaintsRef
        .where('order_id', isEqualTo: orderId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return ComplaintModel.fromFirestore(query.docs.first);
  }

  /// Move complaint to In Review state by shopkeeper/agent
  Future<void> markInReview(String complaintId, {String? notes}) async {
    final now = DateTime.now();
    await _complaintsRef.doc(complaintId).update({
      'status': ComplaintStatus.inReview.value,
      'updated_at': Timestamp.fromDate(now),
      if (notes != null && notes.isNotEmpty) 'resolution_notes': notes,
    });
  }

  /// Resolve complaint with Refund, Replacement, or Reject
  Future<void> resolveComplaint({
    required String complaintId,
    required ResolutionType resolutionType,
    required String resolutionNotes,
    String? resolvedBy,
    double? refundAmount,
    RefundMethod? refundMethod,
    String? replacementDetails,
  }) async {
    final compDoc = await _complaintsRef.doc(complaintId).get();
    if (!compDoc.exists) {
      throw Exception('Complaint $complaintId not found');
    }

    final complaint = ComplaintModel.fromFirestore(compDoc);
    final now = DateTime.now();

    ComplaintStatus finalStatus;
    if (resolutionType == ResolutionType.refund) {
      finalStatus = ComplaintStatus.resolvedRefund;
    } else if (resolutionType == ResolutionType.replacement) {
      finalStatus = ComplaintStatus.resolvedReplacement;
    } else {
      finalStatus = ComplaintStatus.rejected;
    }

    final batch = _firestore.batch();

    // 1. If refund via Khata credit is chosen, atomically credit the customer's Khata
    if (resolutionType == ResolutionType.refund &&
        refundMethod == RefundMethod.khataCredit &&
        refundAmount != null &&
        refundAmount > 0) {
      await _creditCustomerKhata(
        batch: batch,
        shopId: complaint.shopId,
        customerPhone: complaint.customerPhone,
        customerName: complaint.customerName,
        refundAmount: refundAmount,
        complaintId: complaintId,
        orderId: complaint.orderId,
      );
    }

    final updates = <String, dynamic>{
      'status': finalStatus.value,
      'resolution_type': resolutionType.value,
      'resolution_notes': resolutionNotes,
      'resolved_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
    };
    if (resolvedBy != null) updates['resolved_by'] = resolvedBy;
    if (refundAmount != null) updates['refund_amount'] = refundAmount;
    if (refundMethod != null) updates['refund_method'] = refundMethod.value;
    if (replacementDetails != null) updates['replacement_details'] = replacementDetails;
    batch.update(_complaintsRef.doc(complaintId), updates);

    // 3. Update related order status metadata (if order exists)
    final orderDocRef = _firestore.collection('orders').doc(complaint.orderId);
    final orderDoc = await orderDocRef.get();
    if (orderDoc.exists) {
      final orderUpdates = <String, dynamic>{
        'complaint_status': finalStatus.value,
        'complaint_resolved_at': Timestamp.fromDate(now),
      };
      if (resolutionType == ResolutionType.refund && refundAmount != null) {
        orderUpdates['complaint_refund_amount'] = refundAmount;
      }
      batch.update(orderDocRef, orderUpdates);
    }

    await batch.commit();
  }

  /// Helper to credit Khata ledger atomically
  Future<void> _creditCustomerKhata({
    required WriteBatch batch,
    required String shopId,
    required String customerPhone,
    required String customerName,
    required double refundAmount,
    required String complaintId,
    required String orderId,
  }) async {
    try {
      // Find customer document by phone number
      final customersQuery = await _firestore
          .collection('customers')
          .where('mobile', isEqualTo: customerPhone)
          .limit(1)
          .get();

      DocumentReference custRef;
      if (customersQuery.docs.isNotEmpty) {
        custRef = customersQuery.docs.first.reference;
        batch.update(custRef, {
          'shop_balances.$shopId': FieldValue.increment(-refundAmount),
          'shop_ids': FieldValue.arrayUnion([shopId]),
        });
      } else {
        custRef = _firestore.collection('customers').doc(customerPhone);
        batch.set(custRef, {
          'name': customerName,
          'mobile': customerPhone,
          'shop_balances': {shopId: -refundAmount},
          'shop_ids': [shopId],
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      // Add Khata statement transaction
      final txDocRef = custRef.collection('khata_transactions').doc();
      batch.set(txDocRef, {
        'amount': refundAmount,
        'type': 'credit',
        'shop_id': shopId,
        'description':
            'Complaint Refund #$complaintId (Order #${orderId.length > 5 ? orderId.substring(0, 5) : orderId})',
        'complaint_id': complaintId,
        'order_id': orderId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error crediting Khata for complaint refund: $e');
    }
  }

  /// Customer cancels their own pending complaint
  Future<void> cancelComplaint(String complaintId, String orderId) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    batch.update(_complaintsRef.doc(complaintId), {
      'status': ComplaintStatus.cancelled.value,
      'updated_at': Timestamp.fromDate(now),
      'resolution_notes': 'Cancelled by customer',
    });

    final orderDocRef = _firestore.collection('orders').doc(orderId);
    final orderDoc = await orderDocRef.get();
    if (orderDoc.exists) {
      batch.update(orderDocRef, {
        'complaint_status': ComplaintStatus.cancelled.value,
      });
    }

    await batch.commit();
  }
}
