import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'batch_models.dart';
import 'firebase_utils.dart';

/// Service managing product batches, expiry tracking, stock disposals, and alert notifications.
class BatchService {
  final FirebaseFirestore _firestore;
  static int _idCounter = 100;

  BatchService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseUtils.firestore;

  CollectionReference get _batchesRef => _firestore.collection('product_batches');
  CollectionReference get _disposalsRef => _firestore.collection('batch_disposals');
  CollectionReference get _productsRef => _firestore.collection('products');

  String generateBatchId() {
    _idCounter++;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(900) + 100;
    return 'BATCH-$ts-$r-$_idCounter';
  }

  String generateDisposalId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(900) + 100;
    return 'DISP-$ts-$r';
  }

  /// Create a new product batch with expiry tracking
  Future<BatchModel> createBatch({
    required String shopId,
    required String productId,
    required String productName,
    required String batchNumber,
    required double quantity,
    String unit = 'Pcs',
    required DateTime expiryDate,
    DateTime? mfgDate,
    double costPrice = 0.0,
    double sellingPrice = 0.0,
    String? supplierId,
    String? supplierName,
    String? purchaseOrderId,
    String? notes,
    String? storageLocation,
    bool updateProductExpiry = true,
  }) async {
    final id = generateBatchId();
    final now = DateTime.now();

    // Determine initial status based on expiry
    final today = DateTime(now.year, now.month, now.day);
    final expiryOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final daysRemaining = expiryOnly.difference(today).inDays;

    BatchStatus initialStatus;
    if (quantity <= 0) {
      initialStatus = BatchStatus.depleted;
    } else if (daysRemaining < 0) {
      initialStatus = BatchStatus.expired;
    } else if (daysRemaining <= 15) {
      initialStatus = BatchStatus.nearExpiry;
    } else {
      initialStatus = BatchStatus.active;
    }

    final batch = BatchModel(
      id: id,
      shopId: shopId,
      productId: productId,
      productName: productName,
      batchNumber: batchNumber.trim().toUpperCase(),
      quantity: quantity,
      initialQuantity: quantity,
      unit: unit,
      expiryDate: expiryDate,
      mfgDate: mfgDate,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      supplierId: supplierId,
      supplierName: supplierName,
      purchaseOrderId: purchaseOrderId,
      notes: notes,
      storageLocation: storageLocation,
      status: initialStatus,
      createdAt: now,
      updatedAt: now,
    );

    final writeBatch = _firestore.batch();
    writeBatch.set(_batchesRef.doc(id), batch.toMap());

    // Update product's tracking flags and earliest expiry date if applicable
    if (updateProductExpiry && productId.isNotEmpty) {
      final prodDocRef = _productsRef.doc(productId);
      writeBatch.set(
        prodDocRef,
        {
          'has_batches': true,
          'latest_batch_number': batch.batchNumber,
          'earliest_expiry_date': Timestamp.fromDate(expiryDate),
        },
        SetOptions(merge: true),
      );
    }

    await writeBatch.commit();
    return batch;
  }

  /// Update an existing batch
  Future<void> updateBatch({
    required String batchId,
    String? batchNumber,
    double? quantity,
    DateTime? expiryDate,
    DateTime? mfgDate,
    double? costPrice,
    double? sellingPrice,
    String? notes,
    String? storageLocation,
    BatchStatus? status,
  }) async {
    final doc = await _batchesRef.doc(batchId).get();
    if (!doc.exists) throw Exception('Batch $batchId not found');

    final existing = BatchModel.fromFirestore(doc);
    final newExpiry = expiryDate ?? existing.expiryDate;
    final newQty = quantity ?? existing.quantity;

    // Recalculate status if not explicitly given
    BatchStatus newStatus = status ?? existing.status;
    if (status == null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiryOnly = DateTime(newExpiry.year, newExpiry.month, newExpiry.day);
      final days = expiryOnly.difference(today).inDays;

      if (newQty <= 0) {
        newStatus = BatchStatus.depleted;
      } else if (days < 0) {
        newStatus = BatchStatus.expired;
      } else if (days <= 15) {
        newStatus = BatchStatus.nearExpiry;
      } else {
        newStatus = BatchStatus.active;
      }
    }

    final updates = <String, dynamic>{
      'updated_at': Timestamp.fromDate(DateTime.now()),
      'status': newStatus.key,
      if (batchNumber != null) 'batch_number': batchNumber.trim().toUpperCase(),
      if (quantity != null) 'quantity': quantity,
      if (expiryDate != null) 'expiry_date': Timestamp.fromDate(expiryDate),
      if (mfgDate != null) 'mfg_date': Timestamp.fromDate(mfgDate),
      if (costPrice != null) 'cost_price': costPrice,
      if (sellingPrice != null) 'selling_price': sellingPrice,
      if (notes != null) 'notes': notes,
      if (storageLocation != null) 'storage_location': storageLocation,
    };

    await _batchesRef.doc(batchId).update(updates);
  }

  /// Adjust stock for a batch (e.g. sales, audit counts)
  Future<void> adjustBatchStock(String batchId, double quantityDelta) async {
    final doc = await _batchesRef.doc(batchId).get();
    if (!doc.exists) throw Exception('Batch $batchId not found');

    final batch = BatchModel.fromFirestore(doc);
    final updatedQty = max(0.0, batch.quantity + quantityDelta);

    BatchStatus newStatus = batch.status;
    if (updatedQty <= 0) {
      newStatus = BatchStatus.depleted;
    } else if (batch.isExpired()) {
      newStatus = BatchStatus.expired;
    } else if (batch.isNearExpiry(15)) {
      newStatus = BatchStatus.nearExpiry;
    } else {
      newStatus = BatchStatus.active;
    }

    await _batchesRef.doc(batchId).update({
      'quantity': updatedQty,
      'status': newStatus.key,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Write off / Dispose expired or damaged stock and record loss
  Future<BatchDisposalRecord> disposeBatchStock({
    required String shopId,
    required String batchId,
    required double quantityDisposed,
    required DisposalReason reason,
    double? customLossAmount,
    String? disposedBy,
    String? notes,
    bool syncProductStock = true,
  }) async {
    final doc = await _batchesRef.doc(batchId).get();
    if (!doc.exists) throw Exception('Batch $batchId not found');

    final batch = BatchModel.fromFirestore(doc);
    final effectiveDisposeQty = min(batch.quantity, quantityDisposed);
    final lossAmount = customLossAmount ?? (effectiveDisposeQty * batch.costPrice);
    final remainingQty = max(0.0, batch.quantity - effectiveDisposeQty);

    final disposalId = generateDisposalId();
    final now = DateTime.now();

    final disposalRecord = BatchDisposalRecord(
      id: disposalId,
      shopId: shopId,
      batchId: batchId,
      productId: batch.productId,
      productName: batch.productName,
      batchNumber: batch.batchNumber,
      quantityDisposed: effectiveDisposeQty,
      unit: batch.unit,
      reason: reason,
      lossAmount: lossAmount,
      disposedAt: now,
      disposedBy: disposedBy,
      notes: notes,
    );

    final writeBatch = _firestore.batch();

    // 1. Save disposal record
    writeBatch.set(_disposalsRef.doc(disposalId), disposalRecord.toMap());

    // 2. Update batch remaining quantity and status
    final newStatus = remainingQty <= 0 ? BatchStatus.disposed : batch.status;
    writeBatch.update(_batchesRef.doc(batchId), {
      'quantity': remainingQty,
      'status': newStatus.key,
      'updated_at': Timestamp.fromDate(now),
    });

    // 3. Atomically decrement main inventory product stock if requested
    if (syncProductStock && batch.productId.isNotEmpty) {
      final prodDocRef = _productsRef.doc(batch.productId);
      writeBatch.set(
        prodDocRef,
        {'stock_quantity': FieldValue.increment(-effectiveDisposeQty)},
        SetOptions(merge: true),
      );
    }

    await writeBatch.commit();
    return disposalRecord;
  }

  /// Fetch a single batch by ID
  Future<BatchModel?> getBatch(String batchId) async {
    final doc = await _batchesRef.doc(batchId).get();
    if (!doc.exists) return null;
    return BatchModel.fromFirestore(doc);
  }

  /// Real-time stream of product batches for a shop
  Stream<List<BatchModel>> streamBatches(
    String shopId, {
    String? productId,
    BatchStatus? status,
  }) {
    Query q = _batchesRef.where('shop_id', isEqualTo: shopId);

    if (productId != null && productId.isNotEmpty) {
      q = q.where('product_id', isEqualTo: productId);
    }

    if (status != null) {
      q = q.where('status', isEqualTo: status.key);
    }

    return q.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => BatchModel.fromFirestore(doc)).toList();
      // Sort by expiry date ascending (earliest expiring first)
      list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      return list;
    });
  }

  /// Stream batches that require urgent attention (already expired or expiring in <= thresholdDays)
  Stream<List<BatchModel>> streamExpiringAlerts(
    String shopId, {
    int daysThreshold = 15,
  }) {
    return streamBatches(shopId).map((batches) {
      final now = DateTime.now();
      return batches.where((b) {
        if (b.quantity <= 0) return false;
        final days = b.daysUntilExpiry(now);
        // Include both expired (days < 0) and near expiry (0 <= days <= threshold)
        return days <= daysThreshold;
      }).toList();
    });
  }

  /// Stream disposal history records for the shop
  Stream<List<BatchDisposalRecord>> streamDisposalRecords(String shopId) {
    return _disposalsRef
        .where('shop_id', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => BatchDisposalRecord.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.disposedAt.compareTo(a.disposedAt));
      return list;
    });
  }

  /// Compute KPI metrics for Batch and Expiry management
  Future<BatchAnalyticsSummary> fetchBatchAnalytics(
    String shopId, {
    int nearExpiryDays = 15,
  }) async {
    final now = DateTime.now();

    final batchSnapshots = await _batchesRef
        .where('shop_id', isEqualTo: shopId)
        .get();

    int totalActive = 0;
    int totalNear = 0;
    int totalExpired = 0;
    int totalSafe = 0;
    double atRiskUnits = 0.0;
    double atRiskCost = 0.0;
    double expiredUnits = 0.0;
    double expiredCost = 0.0;

    for (var doc in batchSnapshots.docs) {
      final b = BatchModel.fromFirestore(doc);
      if (b.quantity <= 0) continue;

      totalActive++;
      final days = b.daysUntilExpiry(now);

      if (days < 0) {
        totalExpired++;
        expiredUnits += b.quantity;
        expiredCost += b.inventoryCostValue;
      } else if (days <= nearExpiryDays) {
        totalNear++;
        atRiskUnits += b.quantity;
        atRiskCost += b.inventoryCostValue;
      } else {
        totalSafe++;
      }
    }

    // Historical disposals
    final disposalSnapshots = await _disposalsRef
        .where('shop_id', isEqualTo: shopId)
        .get();

    double disposedUnits = 0.0;
    double disposedLoss = 0.0;

    for (var doc in disposalSnapshots.docs) {
      final r = BatchDisposalRecord.fromFirestore(doc);
      disposedUnits += r.quantityDisposed;
      disposedLoss += r.lossAmount;
    }

    return BatchAnalyticsSummary(
      totalActiveBatches: totalActive,
      totalNearExpiryBatches: totalNear,
      totalExpiredBatches: totalExpired,
      safeBatchesCount: totalSafe,
      totalAtRiskUnits: atRiskUnits,
      totalAtRiskCostValue: atRiskCost,
      totalExpiredUnits: expiredUnits,
      totalExpiredCostValue: expiredCost,
      totalDisposedUnits: disposedUnits,
      totalDisposedLossValue: disposedLoss,
    );
  }
}
