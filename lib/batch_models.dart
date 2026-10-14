import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a product batch in inventory
enum BatchStatus {
  active('active', 'Active (सक्रिय)', 0xFF2E7D32),
  nearExpiry('near_expiry', 'Near Expiry (जल्द एक्सपायर)', 0xFFE65100),
  expired('expired', 'Expired (एक्सपायर हो चुका)', 0xFFC62828),
  depleted('depleted', 'Depleted (स्टॉक खत्म)', 0xFF757575),
  disposed('disposed', 'Disposed / Written Off', 0xFF455A64);

  final String key;
  final String displayName;
  final int colorValue;

  const BatchStatus(this.key, this.displayName, this.colorValue);

  static BatchStatus fromString(String? val) {
    return BatchStatus.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => BatchStatus.active,
    );
  }
}

/// Urgency level based on days remaining before expiry
enum ExpiryUrgency {
  expired('Expired', 'एक्सपायर हो चुका है', 0xFFD32F2F),
  critical('Critical (<=7 Days)', 'अति गंभीर (7 दिन के अंदर)', 0xFFC2185B),
  warning('Warning (8-15 Days)', 'चेतावनी (15 दिन के अंदर)', 0xFFE65100),
  attention('Attention (16-30 Days)', 'सावधानी (30 दिन के अंदर)', 0xFFF57C00),
  safe('Fresh / Safe (>30 Days)', 'सुरक्षित (>30 दिन)', 0xFF2E7D32);

  final String label;
  final String hindiLabel;
  final int colorValue;

  const ExpiryUrgency(this.label, this.hindiLabel, this.colorValue);
}

/// Domain Model representing a batch of products with expiry date tracking
class BatchModel {
  final String id;
  final String shopId;
  final String productId; // Barcode or Product Doc ID
  final String productName;
  final String batchNumber; // e.g. 'B-2026-10A', 'L9021'
  final double quantity; // Current remaining stock
  final double initialQuantity; // Original received quantity
  final String unit; // 'Packets', 'Pcs', 'Kg', 'Litre', 'Boxes'
  final DateTime expiryDate; // When the batch expires
  final DateTime? mfgDate; // Manufacturing date
  final double costPrice; // Rate at which bought (₹)
  final double sellingPrice; // Store retail selling price (₹)
  final String? supplierId;
  final String? supplierName;
  final String? purchaseOrderId;
  final String? notes; // Storage instructions e.g. 'Keep refrigerated'
  final String? storageLocation; // Rack / shelf location e.g. 'Rack B-3'
  final BatchStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BatchModel({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.quantity,
    required this.initialQuantity,
    this.unit = 'Pcs',
    required this.expiryDate,
    this.mfgDate,
    this.costPrice = 0.0,
    this.sellingPrice = 0.0,
    this.supplierId,
    this.supplierName,
    this.purchaseOrderId,
    this.notes,
    this.storageLocation,
    this.status = BatchStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Days remaining until expiry date from a given reference time (defaults to now)
  int daysUntilExpiry([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  /// Whether the batch has already expired
  bool isExpired([DateTime? referenceDate]) {
    return daysUntilExpiry(referenceDate) < 0;
  }

  /// Whether the batch will expire within given threshold days
  bool isNearExpiry(int thresholdDays, [DateTime? referenceDate]) {
    final days = daysUntilExpiry(referenceDate);
    return days >= 0 && days <= thresholdDays;
  }

  /// Current urgency classification
  ExpiryUrgency urgency([DateTime? referenceDate]) {
    final days = daysUntilExpiry(referenceDate);
    if (days < 0) return ExpiryUrgency.expired;
    if (days <= 7) return ExpiryUrgency.critical;
    if (days <= 15) return ExpiryUrgency.warning;
    if (days <= 30) return ExpiryUrgency.attention;
    return ExpiryUrgency.safe;
  }

  /// Total inventory cost locked in this batch (₹)
  double get inventoryCostValue => quantity * costPrice;

  /// Total retail potential value in this batch (₹)
  double get inventoryRetailValue => quantity * sellingPrice;

  /// Estimated gross profit margin percentage
  double get grossMarginPercent {
    if (sellingPrice <= 0 || sellingPrice <= costPrice) return 0.0;
    return ((sellingPrice - costPrice) / sellingPrice) * 100;
  }

  /// Evaluates the dynamic status based on quantity and remaining days
  BatchStatus computedStatus([DateTime? referenceDate]) {
    if (quantity <= 0) return BatchStatus.depleted;
    if (isExpired(referenceDate)) return BatchStatus.expired;
    if (isNearExpiry(15, referenceDate)) return BatchStatus.nearExpiry;
    return BatchStatus.active;
  }

  factory BatchModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return BatchModel.fromMap(doc.id, data);
  }

  factory BatchModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return BatchModel(
      id: id,
      shopId: data['shop_id']?.toString() ?? '',
      productId: data['product_id']?.toString() ?? '',
      productName: data['product_name']?.toString() ?? 'Unnamed Product',
      batchNumber: data['batch_number']?.toString() ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      initialQuantity: (data['initial_quantity'] as num?)?.toDouble() ??
          (data['quantity'] as num?)?.toDouble() ??
          0.0,
      unit: data['unit']?.toString() ?? 'Pcs',
      expiryDate: parseDate(data['expiry_date']),
      mfgDate: data['mfg_date'] != null ? parseDate(data['mfg_date']) : null,
      costPrice: (data['cost_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (data['selling_price'] as num?)?.toDouble() ?? 0.0,
      supplierId: data['supplier_id']?.toString(),
      supplierName: data['supplier_name']?.toString(),
      purchaseOrderId: data['purchase_order_id']?.toString(),
      notes: data['notes']?.toString(),
      storageLocation: data['storage_location']?.toString(),
      status: BatchStatus.fromString(data['status']?.toString()),
      createdAt: parseDate(data['created_at']),
      updatedAt: parseDate(data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shop_id': shopId,
      'product_id': productId,
      'product_name': productName,
      'batch_number': batchNumber,
      'quantity': quantity,
      'initial_quantity': initialQuantity,
      'unit': unit,
      'expiry_date': Timestamp.fromDate(expiryDate),
      if (mfgDate != null) 'mfg_date': Timestamp.fromDate(mfgDate!),
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      if (supplierId != null) 'supplier_id': supplierId,
      if (supplierName != null) 'supplier_name': supplierName,
      if (purchaseOrderId != null) 'purchase_order_id': purchaseOrderId,
      if (notes != null) 'notes': notes,
      if (storageLocation != null) 'storage_location': storageLocation,
      'status': status.key,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  BatchModel copyWith({
    String? productId,
    String? productName,
    String? batchNumber,
    double? quantity,
    double? initialQuantity,
    String? unit,
    DateTime? expiryDate,
    DateTime? mfgDate,
    double? costPrice,
    double? sellingPrice,
    String? supplierId,
    String? supplierName,
    String? purchaseOrderId,
    String? notes,
    String? storageLocation,
    BatchStatus? status,
    DateTime? updatedAt,
  }) {
    return BatchModel(
      id: id,
      shopId: shopId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      batchNumber: batchNumber ?? this.batchNumber,
      quantity: quantity ?? this.quantity,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      mfgDate: mfgDate ?? this.mfgDate,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      notes: notes ?? this.notes,
      storageLocation: storageLocation ?? this.storageLocation,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// Reason for discarding or discounting batch stock
enum DisposalReason {
  expired('expired', 'Expired (एक्सपायर हो गया)'),
  damaged('damaged', 'Damaged / Spoiled (खराब / टूटा हुआ)'),
  leakage('leakage', 'Packaging Leakage (पैकेट खुला / लीक)'),
  customerReturn('customer_return', 'Customer Returned (वापस आया)'),
  clearanceSale('clearance_sale', 'Clearance Markdown (सस्ता बेच दिया)'),
  other('other', 'Other Reason (अन्य)');

  final String key;
  final String displayName;

  const DisposalReason(this.key, this.displayName);

  static DisposalReason fromString(String? val) {
    return DisposalReason.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => DisposalReason.expired,
    );
  }
}

/// Record of written-off or discarded batch stock
class BatchDisposalRecord {
  final String id;
  final String shopId;
  final String batchId;
  final String productId;
  final String productName;
  final String batchNumber;
  final double quantityDisposed;
  final String unit;
  final DisposalReason reason;
  final double lossAmount; // Financial cost of disposal
  final DateTime disposedAt;
  final String? disposedBy;
  final String? notes;

  const BatchDisposalRecord({
    required this.id,
    required this.shopId,
    required this.batchId,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.quantityDisposed,
    this.unit = 'Pcs',
    required this.reason,
    required this.lossAmount,
    required this.disposedAt,
    this.disposedBy,
    this.notes,
  });

  factory BatchDisposalRecord.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return BatchDisposalRecord.fromMap(doc.id, data);
  }

  factory BatchDisposalRecord.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return BatchDisposalRecord(
      id: id,
      shopId: data['shop_id']?.toString() ?? '',
      batchId: data['batch_id']?.toString() ?? '',
      productId: data['product_id']?.toString() ?? '',
      productName: data['product_name']?.toString() ?? 'Item',
      batchNumber: data['batch_number']?.toString() ?? '',
      quantityDisposed: (data['quantity_disposed'] as num?)?.toDouble() ?? 0.0,
      unit: data['unit']?.toString() ?? 'Pcs',
      reason: DisposalReason.fromString(data['reason']?.toString()),
      lossAmount: (data['loss_amount'] as num?)?.toDouble() ?? 0.0,
      disposedAt: parseDate(data['disposed_at']),
      disposedBy: data['disposed_by']?.toString(),
      notes: data['notes']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shop_id': shopId,
      'batch_id': batchId,
      'product_id': productId,
      'product_name': productName,
      'batch_number': batchNumber,
      'quantity_disposed': quantityDisposed,
      'unit': unit,
      'reason': reason.key,
      'loss_amount': lossAmount,
      'disposed_at': Timestamp.fromDate(disposedAt),
      if (disposedBy != null) 'disposed_by': disposedBy,
      if (notes != null) 'notes': notes,
    };
  }
}

/// KPI Analytics Summary for Batches & Expiry Management
class BatchAnalyticsSummary {
  final int totalActiveBatches;
  final int totalNearExpiryBatches;
  final int totalExpiredBatches;
  final int safeBatchesCount;
  final double totalAtRiskUnits; // Stock in near-expiry batches
  final double totalAtRiskCostValue; // ₹ in near-expiry batches
  final double totalExpiredUnits; // Stock already expired
  final double totalExpiredCostValue; // ₹ in already expired batches
  final double totalDisposedUnits; // Historical discarded units
  final double totalDisposedLossValue; // Historical financial loss (₹)

  const BatchAnalyticsSummary({
    this.totalActiveBatches = 0,
    this.totalNearExpiryBatches = 0,
    this.totalExpiredBatches = 0,
    this.safeBatchesCount = 0,
    this.totalAtRiskUnits = 0.0,
    this.totalAtRiskCostValue = 0.0,
    this.totalExpiredUnits = 0.0,
    this.totalExpiredCostValue = 0.0,
    this.totalDisposedUnits = 0.0,
    this.totalDisposedLossValue = 0.0,
  });

  /// Total units requiring urgent attention (expired + near expiry)
  double get totalUrgentUnits => totalAtRiskUnits + totalExpiredUnits;

  /// Total capital at risk or lost (₹)
  double get totalCapitalAtRisk => totalAtRiskCostValue + totalExpiredCostValue;
}
