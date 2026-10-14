import 'package:cloud_firestore/cloud_firestore.dart';

/// Purchase Order status lifecycle
enum PurchaseOrderStatus {
  draft('draft', 'Draft', 0xFF9E9E9E),
  ordered('ordered', 'Ordered (आर्डर दिया)', 0xFF2196F3),
  received('received', 'Received (स्टॉक प्राप्त)', 0xFF2E7D32),
  cancelled('cancelled', 'Cancelled', 0xFFD32F2F);

  final String value;
  final String displayName;
  final int colorValue;

  const PurchaseOrderStatus(this.value, this.displayName, this.colorValue);

  static PurchaseOrderStatus fromString(String? val) {
    switch (val) {
      case 'ordered':
        return PurchaseOrderStatus.ordered;
      case 'received':
        return PurchaseOrderStatus.received;
      case 'cancelled':
        return PurchaseOrderStatus.cancelled;
      case 'draft':
      default:
        return PurchaseOrderStatus.draft;
    }
  }
}

/// Payment Status of a Purchase Invoice
enum PaymentStatus {
  unpaid('unpaid', 'Unpaid (उधारी)', 0xFFD32F2F),
  partial('partial', 'Partial (आंशिक)', 0xFFF57C00),
  paid('paid', 'Paid (चुकाया गया)', 0xFF2E7D32);

  final String value;
  final String displayName;
  final int colorValue;

  const PaymentStatus(this.value, this.displayName, this.colorValue);

  static PaymentStatus fromString(String? val) {
    switch (val) {
      case 'paid':
        return PaymentStatus.paid;
      case 'partial':
        return PaymentStatus.partial;
      case 'unpaid':
      default:
        return PaymentStatus.unpaid;
    }
  }
}

/// Payment Method for Supplier Transactions
enum PurchasePaymentMethod {
  cash('cash', 'Cash (नकद)'),
  upi('upi', 'UPI / QR'),
  bankTransfer('bank_transfer', 'Bank Transfer / NEFT'),
  credit('credit', 'Credit / Udhaar (उधारी)'),
  cheque('cheque', 'Cheque');

  final String value;
  final String displayName;

  const PurchasePaymentMethod(this.value, this.displayName);

  static PurchasePaymentMethod fromString(String? val) {
    switch (val) {
      case 'upi':
        return PurchasePaymentMethod.upi;
      case 'bank_transfer':
        return PurchasePaymentMethod.bankTransfer;
      case 'credit':
        return PurchasePaymentMethod.credit;
      case 'cheque':
        return PurchasePaymentMethod.cheque;
      case 'cash':
      default:
        return PurchasePaymentMethod.cash;
    }
  }
}

/// Wholesaler / Distributor Model
class SupplierModel {
  final String id;
  final String shopId;
  final String name;
  final String? contactPerson;
  final String phone;
  final String? email;
  final String? gstin;
  final String? address;
  final String category; // e.g., 'FMCG', 'Grains & Pulses', 'Dairy', 'General'
  final double balanceDue; // Pending payment owed to supplier
  final double totalPurchased; // Cumulative purchase amount
  final double totalPaid; // Cumulative payment made
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplierModel({
    required this.id,
    required this.shopId,
    required this.name,
    this.contactPerson,
    required this.phone,
    this.email,
    this.gstin,
    this.address,
    this.category = 'General',
    this.balanceDue = 0.0,
    this.totalPurchased = 0.0,
    this.totalPaid = 0.0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasOutstandingDue => balanceDue > 0.01;

  factory SupplierModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return SupplierModel.fromMap(doc.id, data);
  }

  factory SupplierModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return SupplierModel(
      id: id,
      shopId: data['shop_id']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Unnamed Supplier',
      contactPerson: data['contact_person']?.toString(),
      phone: data['phone']?.toString() ?? '',
      email: data['email']?.toString(),
      gstin: data['gstin']?.toString(),
      address: data['address']?.toString(),
      category: data['category']?.toString() ?? 'General',
      balanceDue: (data['balance_due'] as num?)?.toDouble() ?? 0.0,
      totalPurchased: (data['total_purchased'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (data['total_paid'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes']?.toString(),
      createdAt: parseDate(data['created_at']),
      updatedAt: parseDate(data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shop_id': shopId,
      'name': name,
      if (contactPerson != null) 'contact_person': contactPerson,
      'phone': phone,
      if (email != null) 'email': email,
      if (gstin != null) 'gstin': gstin,
      if (address != null) 'address': address,
      'category': category,
      'balance_due': balanceDue,
      'total_purchased': totalPurchased,
      'total_paid': totalPaid,
      if (notes != null) 'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  SupplierModel copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? gstin,
    String? address,
    String? category,
    double? balanceDue,
    double? totalPurchased,
    double? totalPaid,
    String? notes,
    DateTime? updatedAt,
  }) {
    return SupplierModel(
      id: id,
      shopId: shopId,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      address: address ?? this.address,
      category: category ?? this.category,
      balanceDue: balanceDue ?? this.balanceDue,
      totalPurchased: totalPurchased ?? this.totalPurchased,
      totalPaid: totalPaid ?? this.totalPaid,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// Line Item in a Purchase Order
class PurchaseItemModel {
  final String productId; // Barcode or Product Doc ID
  final String productName;
  final double orderedQuantity;
  final double receivedQuantity;
  final String unit; // 'Packets', 'Pcs', 'Kg', 'Litre', 'Boxes'
  final double costPrice; // Rate at which bought (₹)
  final double sellingPrice; // Store retail selling price (₹)
  final bool isStockUpdated;

  const PurchaseItemModel({
    required this.productId,
    required this.productName,
    required this.orderedQuantity,
    required this.receivedQuantity,
    this.unit = 'Pcs',
    required this.costPrice,
    this.sellingPrice = 0.0,
    this.isStockUpdated = false,
  });

  double get subtotal => receivedQuantity * costPrice;

  /// Estimated gross profit margin if sold at sellingPrice
  double get estimatedMarginPercent {
    if (sellingPrice <= 0 || sellingPrice <= costPrice) return 0.0;
    return ((sellingPrice - costPrice) / sellingPrice) * 100;
  }

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseItemModel(
      productId: map['product_id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? 'Item',
      orderedQuantity: (map['ordered_quantity'] as num?)?.toDouble() ?? 1.0,
      receivedQuantity: (map['received_quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit']?.toString() ?? 'Pcs',
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
      isStockUpdated: map['is_stock_updated'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'ordered_quantity': orderedQuantity,
      'received_quantity': receivedQuantity,
      'unit': unit,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'subtotal': subtotal,
      'is_stock_updated': isStockUpdated,
    };
  }

  PurchaseItemModel copyWith({
    String? productId,
    String? productName,
    double? orderedQuantity,
    double? receivedQuantity,
    String? unit,
    double? costPrice,
    double? sellingPrice,
    bool? isStockUpdated,
  }) {
    return PurchaseItemModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      orderedQuantity: orderedQuantity ?? this.orderedQuantity,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      isStockUpdated: isStockUpdated ?? this.isStockUpdated,
    );
  }
}

/// Purchase Invoice / Order Document
class PurchaseOrderModel {
  final String id;
  final String shopId;
  final String supplierId;
  final String supplierName;
  final String supplierPhone;
  final String invoiceNumber;
  final DateTime purchaseDate;
  final PurchaseOrderStatus status;
  final List<PurchaseItemModel> items;
  final double subtotal;
  final double discount;
  final double taxes;
  final double transportCharges;
  final double totalAmount;
  final double paidAmount;
  final double balanceDue;
  final PaymentStatus paymentStatus;
  final PurchasePaymentMethod paymentMethod;
  final String? notes;
  final bool stockUpdated;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PurchaseOrderModel({
    required this.id,
    required this.shopId,
    required this.supplierId,
    required this.supplierName,
    required this.supplierPhone,
    required this.invoiceNumber,
    required this.purchaseDate,
    this.status = PurchaseOrderStatus.received,
    this.items = const [],
    required this.subtotal,
    this.discount = 0.0,
    this.taxes = 0.0,
    this.transportCharges = 0.0,
    required this.totalAmount,
    this.paidAmount = 0.0,
    required this.balanceDue,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentMethod = PurchasePaymentMethod.credit,
    this.notes,
    this.stockUpdated = false,
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalItemUnits => items.fold(0, (total, item) => total + item.receivedQuantity.toInt());

  factory PurchaseOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return PurchaseOrderModel.fromMap(doc.id, data);
  }

  factory PurchaseOrderModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final rawItems = data['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((it) => PurchaseItemModel.fromMap(Map<String, dynamic>.from(it as Map)))
        .toList();

    return PurchaseOrderModel(
      id: id,
      shopId: data['shop_id']?.toString() ?? '',
      supplierId: data['supplier_id']?.toString() ?? '',
      supplierName: data['supplier_name']?.toString() ?? 'Supplier',
      supplierPhone: data['supplier_phone']?.toString() ?? '',
      invoiceNumber: data['invoice_number']?.toString() ?? '',
      purchaseDate: parseDate(data['purchase_date']),
      status: PurchaseOrderStatus.fromString(data['status']?.toString()),
      items: itemsList,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
      taxes: (data['taxes'] as num?)?.toDouble() ?? 0.0,
      transportCharges: (data['transport_charges'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (data['total_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (data['paid_amount'] as num?)?.toDouble() ?? 0.0,
      balanceDue: (data['balance_due'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: PaymentStatus.fromString(data['payment_status']?.toString()),
      paymentMethod: PurchasePaymentMethod.fromString(data['payment_method']?.toString()),
      notes: data['notes']?.toString(),
      stockUpdated: data['stock_updated'] == true,
      createdAt: parseDate(data['created_at']),
      updatedAt: parseDate(data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shop_id': shopId,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'supplier_phone': supplierPhone,
      'invoice_number': invoiceNumber,
      'purchase_date': Timestamp.fromDate(purchaseDate),
      'status': status.value,
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'taxes': taxes,
      'transport_charges': transportCharges,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'balance_due': balanceDue,
      'payment_status': paymentStatus.value,
      'payment_method': paymentMethod.value,
      if (notes != null) 'notes': notes,
      'stock_updated': stockUpdated,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  PurchaseOrderModel copyWith({
    PurchaseOrderStatus? status,
    List<PurchaseItemModel>? items,
    double? paidAmount,
    double? balanceDue,
    PaymentStatus? paymentStatus,
    PurchasePaymentMethod? paymentMethod,
    bool? stockUpdated,
    String? notes,
    DateTime? updatedAt,
  }) {
    return PurchaseOrderModel(
      id: id,
      shopId: shopId,
      supplierId: supplierId,
      supplierName: supplierName,
      supplierPhone: supplierPhone,
      invoiceNumber: invoiceNumber,
      purchaseDate: purchaseDate,
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal,
      discount: discount,
      taxes: taxes,
      transportCharges: transportCharges,
      totalAmount: totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceDue: balanceDue ?? this.balanceDue,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      stockUpdated: stockUpdated ?? this.stockUpdated,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// Record of payment made to a wholesaler/supplier
class SupplierPaymentModel {
  final String id;
  final String shopId;
  final String supplierId;
  final String supplierName;
  final String? purchaseOrderId;
  final double amount;
  final DateTime paymentDate;
  final PurchasePaymentMethod paymentMethod;
  final String? referenceNumber;
  final String? notes;
  final DateTime createdAt;

  const SupplierPaymentModel({
    required this.id,
    required this.shopId,
    required this.supplierId,
    required this.supplierName,
    this.purchaseOrderId,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = PurchasePaymentMethod.cash,
    this.referenceNumber,
    this.notes,
    required this.createdAt,
  });

  factory SupplierPaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return SupplierPaymentModel.fromMap(doc.id, data);
  }

  factory SupplierPaymentModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return SupplierPaymentModel(
      id: id,
      shopId: data['shop_id']?.toString() ?? '',
      supplierId: data['supplier_id']?.toString() ?? '',
      supplierName: data['supplier_name']?.toString() ?? 'Supplier',
      purchaseOrderId: data['purchase_order_id']?.toString(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: parseDate(data['payment_date']),
      paymentMethod: PurchasePaymentMethod.fromString(data['payment_method']?.toString()),
      referenceNumber: data['reference_number']?.toString(),
      notes: data['notes']?.toString(),
      createdAt: parseDate(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shop_id': shopId,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      if (purchaseOrderId != null) 'purchase_order_id': purchaseOrderId,
      'amount': amount,
      'payment_date': Timestamp.fromDate(paymentDate),
      'payment_method': paymentMethod.value,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (notes != null) 'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}

/// KPI summary for Supplier & Purchase management
class SupplierAnalyticsSummary {
  final double totalPurchasesAmount;
  final double totalPaidAmount;
  final double totalOutstandingDues;
  final int totalSuppliersCount;
  final int suppliersWithDuesCount;
  final int totalPurchaseOrdersCount;
  final int pendingOrdersCount;
  final int totalItemsReceived;

  const SupplierAnalyticsSummary({
    required this.totalPurchasesAmount,
    required this.totalPaidAmount,
    required this.totalOutstandingDues,
    required this.totalSuppliersCount,
    required this.suppliersWithDuesCount,
    required this.totalPurchaseOrdersCount,
    required this.pendingOrdersCount,
    required this.totalItemsReceived,
  });

  factory SupplierAnalyticsSummary.empty() {
    return const SupplierAnalyticsSummary(
      totalPurchasesAmount: 0.0,
      totalPaidAmount: 0.0,
      totalOutstandingDues: 0.0,
      totalSuppliersCount: 0,
      suppliersWithDuesCount: 0,
      totalPurchaseOrdersCount: 0,
      pendingOrdersCount: 0,
      totalItemsReceived: 0,
    );
  }
}
