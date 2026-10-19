import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_utils.dart';
import 'substitution_model.dart';
import 'notification_service.dart';

/// Service managing product substitution workflows for out-of-stock items:
/// - Merchant proposes an alternative product with price, quantity, and reason.
/// - Customer accepts or rejects the proposed substitution.
/// - Atomically updates order items, recalculates subtotal and total_amount,
///   and records audit events in the order's timeline.
class ProductSubstitutionService {
  final FirebaseFirestore _firestore;

  ProductSubstitutionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseUtils.firestore;

  static final ProductSubstitutionService instance = ProductSubstitutionService();

  /// Proposes a product substitution for an active order item.
  Future<ProductSubstitutionProposal> proposeSubstitution({
    required String orderId,
    required String originalProductId,
    required String originalProductName,
    required double originalPrice,
    required double originalQuantity,
    String? originalUnit,
    String? originalImageUrl,
    String? substituteProductId,
    required String substituteProductName,
    required double substitutePrice,
    required double substituteQuantity,
    String? substituteUnit,
    String? substituteImageUrl,
    String? reason,
    String proposedBy = 'merchant',
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final proposalId = 'sub_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final now = DateTime.now();

    final proposal = ProductSubstitutionProposal(
      id: proposalId,
      orderId: orderId,
      originalProductId: originalProductId,
      originalProductName: originalProductName,
      originalPrice: originalPrice,
      originalQuantity: originalQuantity,
      originalUnit: originalUnit,
      originalImageUrl: originalImageUrl,
      substituteProductId: substituteProductId,
      substituteProductName: substituteProductName,
      substitutePrice: substitutePrice,
      substituteQuantity: substituteQuantity,
      substituteUnit: substituteUnit,
      substituteImageUrl: substituteImageUrl,
      status: SubstitutionStatus.pending,
      reason: reason,
      proposedBy: proposedBy,
      proposedAt: now,
    );

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) {
        throw StateError('Order $orderId does not exist');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString();

      // Only allow substitutions on active preparation stages
      final terminalStatuses = ['Delivered', 'Cancelled', 'Rejected'];
      if (terminalStatuses.contains(status)) {
        throw StateError('Cannot propose substitution for terminal order ($status)');
      }

      // Verify the item exists in the order
      final items = (data['items'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final hasItem = items.any((i) =>
          (i['id']?.toString() == originalProductId) ||
          (i['name']?.toString().toLowerCase() == originalProductName.toLowerCase()));

      if (!hasItem) {
        throw StateError('Original product "$originalProductName" was not found in this order');
      }

      // Check if a pending substitution already exists for this product
      final rawProposals = (data['substitution_proposals'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final hasExistingPending = rawProposals.any((p) =>
          (p['original_product_id'] == originalProductId ||
              p['original_product_name'] == originalProductName) &&
          p['status'] == SubstitutionStatus.pending);

      if (hasExistingPending) {
        throw StateError('A substitution proposal for "$originalProductName" is already awaiting customer approval');
      }

      rawProposals.add(proposal.toMap());

      // Append audit timeline entry
      final timeline = (data['timeline'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      timeline.add({
        'action': 'substitution_proposed',
        'proposal_id': proposalId,
        'title': 'Alternative Item Proposed',
        'description': 'Proposed "$substituteProductName" (₹${substitutePrice.toStringAsFixed(0)} × ${substituteQuantity.toStringAsFixed(0)}) for "$originalProductName" (${proposal.formattedDifference})',
        'timestamp': Timestamp.fromDate(now),
        'actor': proposedBy,
      });

      transaction.update(orderRef, {
        'substitution_proposals': rawProposals,
        'has_pending_substitution': true,
        'timeline': timeline,
        'last_substitution_proposed_at': Timestamp.fromDate(now),
      });
    });

    // Dispatch background notification
    try {
      final doc = await orderRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final phone = data['phone_number']?.toString();
        final uid = data['customer_uid']?.toString();
        final shopId = data['shop_id']?.toString() ?? '';

        await NotificationService.dispatchSubstitutionNotification(
          orderId: orderId,
          type: 'proposed',
          message: 'Alternative item proposed for your order: $substituteProductName (${proposal.formattedDifference}). Please review and approve.',
          customerPhone: phone,
          customerUid: uid,
          shopId: shopId,
          firestore: _firestore,
        );
      }
    } catch (_) {}

    return proposal;
  }

  /// Customer responds to a proposed substitution (accept or reject).
  /// Atomically updates items, recalculates totals, and records customer choice.
  Future<Map<String, dynamic>> respondToSubstitution({
    required String orderId,
    required String proposalId,
    required bool isAccepted,
    String rejectionAction = SubstitutionRejectionAction.removeItem,
    String? customerNote,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final now = DateTime.now();

    return await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) {
        throw StateError('Order $orderId does not exist');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final rawProposals = (data['substitution_proposals'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final proposalIndex = rawProposals.indexWhere((p) => p['id'] == proposalId);
      if (proposalIndex == -1) {
        throw StateError('Substitution proposal $proposalId not found');
      }

      final targetProposalMap = Map<String, dynamic>.from(rawProposals[proposalIndex]);
      final proposal = ProductSubstitutionProposal.fromMap(targetProposalMap);

      if (proposal.status != SubstitutionStatus.pending) {
        throw StateError('Proposal is already processed with status: ${proposal.status}');
      }

      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final deliveryFee = (data['delivery_fee'] as num?)?.toDouble() ?? 0.0;
      final discount = (data['discount'] as num?)?.toDouble() ?? 0.0;

      final timeline = (data['timeline'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (isAccepted) {
        // Find and replace original item in items array
        final itemIndex = items.indexWhere((i) =>
            i['id']?.toString() == proposal.originalProductId ||
            i['name']?.toString().toLowerCase() == proposal.originalProductName.toLowerCase());

        if (itemIndex != -1) {
          final oldItem = items[itemIndex];
          items[itemIndex] = {
            ...oldItem,
            'id': proposal.substituteProductId ?? proposal.originalProductId,
            'name': proposal.substituteProductName,
            'price': proposal.substitutePrice,
            'quantity': proposal.substituteQuantity,
            if (proposal.substituteUnit != null) 'unit': proposal.substituteUnit,
            if (proposal.substituteImageUrl != null && proposal.substituteImageUrl!.isNotEmpty)
              'image_url': proposal.substituteImageUrl,
            'is_substituted': true,
            'substituted_from': proposal.originalProductName,
            'original_price': proposal.originalPrice,
            'original_quantity': proposal.originalQuantity,
          };
        } else {
          // If original item was somehow missing, append substitute item
          items.add({
            'id': proposal.substituteProductId ?? proposal.originalProductId,
            'name': proposal.substituteProductName,
            'price': proposal.substitutePrice,
            'quantity': proposal.substituteQuantity,
            if (proposal.substituteUnit != null) 'unit': proposal.substituteUnit,
            'is_substituted': true,
            'substituted_from': proposal.originalProductName,
          });
        }

        targetProposalMap['status'] = SubstitutionStatus.accepted;
        targetProposalMap['responded_at'] = Timestamp.fromDate(now);
        if (customerNote != null) targetProposalMap['customer_note'] = customerNote;
      } else {
        // Customer rejected
        targetProposalMap['status'] = SubstitutionStatus.rejected;
        targetProposalMap['responded_at'] = Timestamp.fromDate(now);
        targetProposalMap['rejection_action'] = rejectionAction;
        if (customerNote != null) targetProposalMap['customer_note'] = customerNote;

        if (rejectionAction == SubstitutionRejectionAction.removeItem) {
          // Remove the out-of-stock item from the order
          items.removeWhere((i) =>
              i['id']?.toString() == proposal.originalProductId ||
              i['name']?.toString().toLowerCase() == proposal.originalProductName.toLowerCase());
        }
      }

      rawProposals[proposalIndex] = targetProposalMap;

      // Recalculate subtotal from scratch
      double revisedSubtotal = 0.0;
      for (final item in items) {
        final p = (item['price'] as num?)?.toDouble() ?? 0.0;
        final q = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        revisedSubtotal += (p * q);
      }

      // Recalculate total amount
      final revisedTotal = max(0.0, revisedSubtotal + deliveryFee - discount);

      // Check if any proposals remain pending
      final hasPending = rawProposals.any((p) => p['status'] == SubstitutionStatus.pending);

      // Add timeline event
      if (isAccepted) {
        timeline.add({
          'action': 'substitution_accepted',
          'proposal_id': proposalId,
          'title': 'Alternative Item Approved by Customer',
          'description': 'Customer approved "${proposal.substituteProductName}". Order revised to ₹${revisedTotal.toStringAsFixed(0)}',
          'timestamp': Timestamp.fromDate(now),
          'actor': 'customer',
        });
      } else {
        final removalNote = rejectionAction == SubstitutionRejectionAction.removeItem
            ? 'Item "${proposal.originalProductName}" removed from order.'
            : 'Original item retained as pending.';
        timeline.add({
          'action': 'substitution_rejected',
          'proposal_id': proposalId,
          'title': 'Alternative Item Declined by Customer',
          'description': 'Customer declined "${proposal.substituteProductName}". $removalNote Order revised to ₹${revisedTotal.toStringAsFixed(0)}',
          'timestamp': Timestamp.fromDate(now),
          'actor': 'customer',
        });
      }

      final updatePayload = {
        'items': items,
        'subtotal': revisedSubtotal,
        'total_amount': revisedTotal,
        'substitution_proposals': rawProposals,
        'has_pending_substitution': hasPending,
        'timeline': timeline,
        'last_substitution_resolved_at': Timestamp.fromDate(now),
      };

      transaction.update(orderRef, updatePayload);

      return {
        'orderId': orderId,
        'proposalId': proposalId,
        'isAccepted': isAccepted,
        'revisedSubtotal': revisedSubtotal,
        'revisedTotal': revisedTotal,
        'hasPending': hasPending,
        'itemCount': items.length,
      };
    });
  }

  /// Cancels a pending substitution proposal (e.g. merchant found the original stock).
  Future<void> cancelSubstitutionProposal({
    required String orderId,
    required String proposalId,
    String? reason,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final now = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) throw StateError('Order $orderId does not exist');

      final data = snapshot.data() as Map<String, dynamic>;
      final rawProposals = (data['substitution_proposals'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final index = rawProposals.indexWhere((p) => p['id'] == proposalId);
      if (index == -1) throw StateError('Proposal not found');

      final prop = rawProposals[index];
      if (prop['status'] != SubstitutionStatus.pending) {
        throw StateError('Cannot cancel non-pending proposal');
      }

      prop['status'] = SubstitutionStatus.cancelled;
      prop['responded_at'] = Timestamp.fromDate(now);
      if (reason != null) prop['reason'] = reason;
      rawProposals[index] = prop;

      final hasPending = rawProposals.any((p) => p['status'] == SubstitutionStatus.pending);

      transaction.update(orderRef, {
        'substitution_proposals': rawProposals,
        'has_pending_substitution': hasPending,
      });
    });
  }

  /// Extracts pending proposals from an order data Map.
  static List<ProductSubstitutionProposal> getPendingProposals(Map<String, dynamic>? data) {
    if (data == null) return [];
    final list = data['substitution_proposals'] as List<dynamic>? ?? [];
    return list
        .map((e) => ProductSubstitutionProposal.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((p) => p.isPending)
        .toList();
  }

  /// Extracts all proposals from an order data Map.
  static List<ProductSubstitutionProposal> getAllProposals(Map<String, dynamic>? data) {
    if (data == null) return [];
    final list = data['substitution_proposals'] as List<dynamic>? ?? [];
    return list
        .map((e) => ProductSubstitutionProposal.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
