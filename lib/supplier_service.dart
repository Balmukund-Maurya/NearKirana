import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'supplier_models.dart';
import 'firebase_utils.dart';

/// Business Service managing Wholesalers, Purchase Orders, Inventory Receiving,
/// and Supplier Payment Ledgers (Feature 54: Supplier & Purchase Management).
class SupplierService {
  final FirebaseFirestore _firestore;
  static int _idCounter = 100;

  SupplierService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseUtils.firestore;

  CollectionReference<Map<String, dynamic>> get _suppliersRef =>
      _firestore.collection('suppliers');

  CollectionReference<Map<String, dynamic>> get _purchasesRef =>
      _firestore.collection('purchase_orders');

  CollectionReference<Map<String, dynamic>> get _paymentsRef =>
      _firestore.collection('supplier_payments');

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('products');

  // --- ID GENERATORS ---
  static String generateSupplierId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final suffix = (now % 90000) + 10000;
    final counter = ++_idCounter;
    return 'SUP-$suffix-$counter';
  }

  static String generatePurchaseOrderId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final suffix = (now % 90000) + 10000;
    final counter = ++_idCounter;
    return 'PO-$suffix-$counter';
  }

  static String generatePaymentId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final suffix = (now % 90000) + 10000;
    final counter = ++_idCounter;
    return 'SPAY-$suffix-$counter';
  }

  // =========================================================================
  // SUPPLIER CRUD OPERATIONS
  // =========================================================================

  /// Register a new wholesaler/supplier
  Future<SupplierModel> createSupplier({
    required String shopId,
    required String name,
    String? contactPerson,
    required String phone,
    String? email,
    String? gstin,
    String? address,
    String category = 'General',
    double openingBalanceDue = 0.0,
    String? notes,
  }) async {
    final id = generateSupplierId();
    final now = DateTime.now();

    final supplier = SupplierModel(
      id: id,
      shopId: shopId,
      name: name.trim(),
      contactPerson: contactPerson?.trim(),
      phone: phone.trim(),
      email: email?.trim(),
      gstin: gstin?.trim().toUpperCase(),
      address: address?.trim(),
      category: category,
      balanceDue: openingBalanceDue,
      totalPurchased: openingBalanceDue > 0 ? openingBalanceDue : 0.0,
      totalPaid: 0.0,
      notes: notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _suppliersRef.doc(id).set(supplier.toMap());
    return supplier;
  }

  /// Update existing supplier details
  Future<void> updateSupplier({
    required String supplierId,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? gstin,
    String? address,
    String? category,
    String? notes,
  }) async {
    final doc = await _suppliersRef.doc(supplierId).get();
    if (!doc.exists) throw Exception('Supplier $supplierId not found');

    final Map<String, dynamic> updates = {
      'updated_at': Timestamp.fromDate(DateTime.now()),
    };
    if (name != null) updates['name'] = name.trim();
    if (contactPerson != null) updates['contact_person'] = contactPerson.trim();
    if (phone != null) updates['phone'] = phone.trim();
    if (email != null) updates['email'] = email.trim();
    if (gstin != null) updates['gstin'] = gstin.trim().toUpperCase();
    if (address != null) updates['address'] = address.trim();
    if (category != null) updates['category'] = category;
    if (notes != null) updates['notes'] = notes.trim();

    await _suppliersRef.doc(supplierId).update(updates);
  }

  /// Delete a supplier if there are no pending dues
  Future<void> deleteSupplier(String supplierId) async {
    final doc = await _suppliersRef.doc(supplierId).get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final balance = (data['balance_due'] as num?)?.toDouble() ?? 0.0;
    if (balance > 0.01) {
      throw Exception(
        'Cannot delete supplier with pending dues of ₹${balance.toStringAsFixed(2)}. Please clear the balance first.',
      );
    }
    await _suppliersRef.doc(supplierId).delete();
  }

  /// Fetch single supplier
  Future<SupplierModel?> getSupplier(String supplierId) async {
    final doc = await _suppliersRef.doc(supplierId).get();
    if (!doc.exists) return null;
    return SupplierModel.fromFirestore(doc);
  }

  /// Realtime stream of suppliers for a shop
  Stream<List<SupplierModel>> streamSuppliers(String shopId) {
    return _suppliersRef
        .where('shop_id', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SupplierModel.fromFirestore(doc))
          .toList();
      // Sort in-memory: Suppliers with outstanding dues first, then alphabetically
      list.sort((a, b) {
        if (b.balanceDue > 0 && a.balanceDue <= 0) return 1;
        if (a.balanceDue > 0 && b.balanceDue <= 0) return -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  // =========================================================================
  // PURCHASE ORDER OPERATIONS
  // =========================================================================

  /// Create a purchase invoice / stock in entry
  Future<PurchaseOrderModel> createPurchaseOrder({
    required String shopId,
    required String supplierId,
    required String supplierName,
    required String supplierPhone,
    required String invoiceNumber,
    required DateTime purchaseDate,
    PurchaseOrderStatus status = PurchaseOrderStatus.received,
    required List<PurchaseItemModel> items,
    double discount = 0.0,
    double taxes = 0.0,
    double transportCharges = 0.0,
    double paidAmount = 0.0,
    PurchasePaymentMethod paymentMethod = PurchasePaymentMethod.credit,
    String? notes,
    bool updateStock = true,
  }) async {
    final id = generatePurchaseOrderId();
    final now = DateTime.now();

    // 1. Calculate financials
    final subtotal = items.fold(0.0, (total, it) => total + it.subtotal);
    final totalAmount = max(0.0, subtotal - discount + taxes + transportCharges);
    final effectivePaid = min(paidAmount, totalAmount);
    final balanceDue = max(0.0, totalAmount - effectivePaid);

    PaymentStatus paymentStatus;
    if (balanceDue <= 0.01) {
      paymentStatus = PaymentStatus.paid;
    } else if (effectivePaid > 0.01) {
      paymentStatus = PaymentStatus.partial;
    } else {
      paymentStatus = PaymentStatus.unpaid;
    }

    // 2. Mark line items stock updated if receiving now
    final shouldApplyStock = status == PurchaseOrderStatus.received && updateStock;
    final processedItems = items.map((it) {
      return it.copyWith(isStockUpdated: shouldApplyStock);
    }).toList();

    final order = PurchaseOrderModel(
      id: id,
      shopId: shopId,
      supplierId: supplierId,
      supplierName: supplierName,
      supplierPhone: supplierPhone,
      invoiceNumber: invoiceNumber.trim(),
      purchaseDate: purchaseDate,
      status: status,
      items: processedItems,
      subtotal: subtotal,
      discount: discount,
      taxes: taxes,
      transportCharges: transportCharges,
      totalAmount: totalAmount,
      paidAmount: effectivePaid,
      balanceDue: balanceDue,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      notes: notes?.trim(),
      stockUpdated: shouldApplyStock,
      createdAt: now,
      updatedAt: now,
    );

    // 3. Write Purchase Order to Firestore
    await _purchasesRef.doc(id).set(order.toMap());

    // 4. Update Product Inventory & Cost Prices if receiving now
    if (shouldApplyStock) {
      await _applyStockUpdates(shopId, items);
    }

    // 5. Update Supplier Ledger (Total Purchases, Paid, Balance Due)
    await _updateSupplierBalances(
      supplierId: supplierId,
      purchaseDelta: totalAmount,
      paidDelta: effectivePaid,
      dueDelta: balanceDue,
    );

    // 6. Record Initial Payment entry if paid upfront
    if (effectivePaid > 0.01) {
      final paymentId = generatePaymentId();
      final payment = SupplierPaymentModel(
        id: paymentId,
        shopId: shopId,
        supplierId: supplierId,
        supplierName: supplierName,
        purchaseOrderId: id,
        amount: effectivePaid,
        paymentDate: purchaseDate,
        paymentMethod: paymentMethod,
        notes: 'Initial payment for bill #$invoiceNumber',
        createdAt: now,
      );
      await _paymentsRef.doc(paymentId).set(payment.toMap());
    }

    return order;
  }

  /// Mark an ordered/draft purchase as received and update store inventory
  Future<void> receivePurchaseOrder(String purchaseId) async {
    final doc = await _purchasesRef.doc(purchaseId).get();
    if (!doc.exists) throw Exception('Purchase order $purchaseId not found');

    final order = PurchaseOrderModel.fromFirestore(doc);
    if (order.status == PurchaseOrderStatus.received && order.stockUpdated) {
      return; // Already received and stock applied
    }

    final updatedItems = order.items.map((it) => it.copyWith(isStockUpdated: true)).toList();

    await _applyStockUpdates(order.shopId, order.items);

    await _purchasesRef.doc(purchaseId).update({
      'status': PurchaseOrderStatus.received.value,
      'stock_updated': true,
      'items': updatedItems.map((i) => i.toMap()).toList(),
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Cancel a purchase order and reverse supplier ledger dues
  Future<void> cancelPurchaseOrder(String purchaseId) async {
    final doc = await _purchasesRef.doc(purchaseId).get();
    if (!doc.exists) throw Exception('Purchase order $purchaseId not found');

    final order = PurchaseOrderModel.fromFirestore(doc);
    if (order.status == PurchaseOrderStatus.cancelled) return;

    // Revert supplier balance
    await _updateSupplierBalances(
      supplierId: order.supplierId,
      purchaseDelta: -order.totalAmount,
      paidDelta: -order.paidAmount,
      dueDelta: -order.balanceDue,
    );

    // If stock was already credited, roll back stock increment
    if (order.stockUpdated) {
      final rollbackItems = order.items.map((it) {
        return it.copyWith(receivedQuantity: -it.receivedQuantity);
      }).toList();
      await _applyStockUpdates(order.shopId, rollbackItems, updateCostPrice: false);
    }

    await _purchasesRef.doc(purchaseId).update({
      'status': PurchaseOrderStatus.cancelled.value,
      'stock_updated': false,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Helper: Atomically update product inventory stock quantities and cost prices
  Future<void> _applyStockUpdates(
    String shopId,
    List<PurchaseItemModel> items, {
    bool updateCostPrice = true,
  }) async {
    for (final item in items) {
      if (item.productId.isEmpty || item.receivedQuantity == 0) continue;

      final prodDocRef = _productsRef.doc(item.productId);
      final prodDoc = await prodDocRef.get();

      if (prodDoc.exists) {
        final Map<String, dynamic> updateData = {
          'stock_quantity': FieldValue.increment(item.receivedQuantity),
          'updated_at': Timestamp.fromDate(DateTime.now()),
        };

        if (updateCostPrice && item.costPrice > 0) {
          updateData['cost_price'] = item.costPrice;
          updateData['purchase_price'] = item.costPrice;
        }

        await prodDocRef.update(updateData);
      }
    }
  }

  /// Helper: Update supplier balance, total purchases, and total paid
  Future<void> _updateSupplierBalances({
    required String supplierId,
    required double purchaseDelta,
    required double paidDelta,
    required double dueDelta,
  }) async {
    final supRef = _suppliersRef.doc(supplierId);
    final supDoc = await supRef.get();
    if (!supDoc.exists) return;

    final currentData = supDoc.data() ?? {};
    final currentPurchased = (currentData['total_purchased'] as num?)?.toDouble() ?? 0.0;
    final currentPaid = (currentData['total_paid'] as num?)?.toDouble() ?? 0.0;
    final currentDue = (currentData['balance_due'] as num?)?.toDouble() ?? 0.0;

    final newPurchased = max(0.0, currentPurchased + purchaseDelta);
    final newPaid = max(0.0, currentPaid + paidDelta);
    final newDue = max(0.0, currentDue + dueDelta);

    await supRef.update({
      'total_purchased': newPurchased,
      'total_paid': newPaid,
      'balance_due': newDue,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  // =========================================================================
  // SUPPLIER PAYMENT OPERATIONS
  // =========================================================================

  /// Record payment made to a supplier (clearing udhaar / dues)
  Future<SupplierPaymentModel> recordSupplierPayment({
    required String shopId,
    required String supplierId,
    required String supplierName,
    String? purchaseOrderId,
    required double amount,
    required DateTime paymentDate,
    PurchasePaymentMethod paymentMethod = PurchasePaymentMethod.cash,
    String? referenceNumber,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw Exception('Payment amount must be greater than zero');
    }

    final id = generatePaymentId();
    final now = DateTime.now();

    final payment = SupplierPaymentModel(
      id: id,
      shopId: shopId,
      supplierId: supplierId,
      supplierName: supplierName,
      purchaseOrderId: purchaseOrderId,
      amount: amount,
      paymentDate: paymentDate,
      paymentMethod: paymentMethod,
      referenceNumber: referenceNumber?.trim(),
      notes: notes?.trim(),
      createdAt: now,
    );

    // 1. Write payment record
    await _paymentsRef.doc(id).set(payment.toMap());

    // 2. Decrement supplier balance due & increment total paid
    await _updateSupplierBalances(
      supplierId: supplierId,
      purchaseDelta: 0.0,
      paidDelta: amount,
      dueDelta: -amount,
    );

    // 3. If tied to a specific purchase order, update invoice paid amount and payment status
    if (purchaseOrderId != null && purchaseOrderId.isNotEmpty) {
      final poDoc = await _purchasesRef.doc(purchaseOrderId).get();
      if (poDoc.exists) {
        final po = PurchaseOrderModel.fromFirestore(poDoc);
        final newPaid = po.paidAmount + amount;
        final newBalance = max(0.0, po.totalAmount - newPaid);

        PaymentStatus newStatus;
        if (newBalance <= 0.01) {
          newStatus = PaymentStatus.paid;
        } else {
          newStatus = PaymentStatus.partial;
        }

        await _purchasesRef.doc(purchaseOrderId).update({
          'paid_amount': newPaid,
          'balance_due': newBalance,
          'payment_status': newStatus.value,
          'updated_at': Timestamp.fromDate(now),
        });
      }
    }

    return payment;
  }

  // =========================================================================
  // STREAMS & ANALYTICS
  // =========================================================================

  /// Realtime stream of purchase orders
  Stream<List<PurchaseOrderModel>> streamPurchaseOrders(
    String shopId, {
    PurchaseOrderStatus? status,
    String? supplierId,
  }) {
    Query<Map<String, dynamic>> q = _purchasesRef.where('shop_id', isEqualTo: shopId);

    if (status != null) {
      q = q.where('status', isEqualTo: status.value);
    }
    if (supplierId != null && supplierId.isNotEmpty) {
      q = q.where('supplier_id', isEqualTo: supplierId);
    }

    return q.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PurchaseOrderModel.fromFirestore(doc))
          .toList();
      // Sort newest purchase date first
      list.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
      return list;
    });
  }

  /// Realtime stream of payments made to suppliers
  Stream<List<SupplierPaymentModel>> streamSupplierPayments(
    String shopId, {
    String? supplierId,
  }) {
    Query<Map<String, dynamic>> q = _paymentsRef.where('shop_id', isEqualTo: shopId);

    if (supplierId != null && supplierId.isNotEmpty) {
      q = q.where('supplier_id', isEqualTo: supplierId);
    }

    return q.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SupplierPaymentModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      return list;
    });
  }

  /// Aggregate KPI summary for the supplier management dashboard
  Future<SupplierAnalyticsSummary> fetchSupplierAnalytics(String shopId) async {
    final suppliersSnapshot =
        await _suppliersRef.where('shop_id', isEqualTo: shopId).get();
    final purchasesSnapshot =
        await _purchasesRef.where('shop_id', isEqualTo: shopId).get();

    double totalOutstandingDues = 0.0;
    int suppliersWithDuesCount = 0;

    for (final doc in suppliersSnapshot.docs) {
      final data = doc.data();
      final due = (data['balance_due'] as num?)?.toDouble() ?? 0.0;
      if (due > 0.01) {
        totalOutstandingDues += due;
        suppliersWithDuesCount++;
      }
    }

    double totalPurchases = 0.0;
    double totalPaid = 0.0;
    int pendingOrders = 0;
    int totalItems = 0;

    for (final doc in purchasesSnapshot.docs) {
      final data = doc.data();
      final status = data['status']?.toString();
      if (status != PurchaseOrderStatus.cancelled.value) {
        totalPurchases += (data['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalPaid += (data['paid_amount'] as num?)?.toDouble() ?? 0.0;

        if (status == PurchaseOrderStatus.ordered.value ||
            status == PurchaseOrderStatus.draft.value) {
          pendingOrders++;
        }

        final items = data['items'] as List<dynamic>? ?? [];
        for (final it in items) {
          if (it is Map) {
            totalItems += ((it['received_quantity'] as num?)?.toInt() ?? 0);
          }
        }
      }
    }

    return SupplierAnalyticsSummary(
      totalPurchasesAmount: totalPurchases,
      totalPaidAmount: totalPaid,
      totalOutstandingDues: totalOutstandingDues,
      totalSuppliersCount: suppliersSnapshot.docs.length,
      suppliersWithDuesCount: suppliersWithDuesCount,
      totalPurchaseOrdersCount: purchasesSnapshot.docs.length,
      pendingOrdersCount: pendingOrders,
      totalItemsReceived: totalItems,
    );
  }

  /// Quick product search from store inventory for purchase order line items
  Future<List<Map<String, dynamic>>> searchProducts(String shopId, String query) async {
    final trimmed = query.trim().toLowerCase();
    final snapshot = await _productsRef
        .where('shop_id', isEqualTo: shopId)
        .limit(60)
        .get();

    final results = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final barcode = (data['barcode'] ?? doc.id).toString().toLowerCase();

      if (trimmed.isEmpty || name.contains(trimmed) || barcode.contains(trimmed)) {
        results.add({
          'id': doc.id,
          'barcode': data['barcode'] ?? doc.id,
          'name': data['name'] ?? 'Product',
          'cost_price': (data['cost_price'] ?? data['purchase_price'] as num?)?.toDouble() ?? 0.0,
          'selling_price': (data['price'] as num?)?.toDouble() ?? 0.0,
          'stock_quantity': (data['stock_quantity'] as num?)?.toDouble() ?? 0.0,
          'unit': data['unit'] ?? (data['is_loose'] == true ? 'Kg' : 'Pcs'),
        });
      }
    }
    return results;
  }
}
