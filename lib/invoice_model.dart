import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Individual item in the digital invoice
class InvoiceItem {
  final String id;
  final String name;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String unit;
  final bool isLoose;
  final double taxRate; // in percentage, e.g. 5.0 for 5% GST
  final double taxAmount;

  const InvoiceItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.unit = 'unit',
    this.isLoose = false,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'unit': unit,
      'is_loose': isLoose,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    final qty = (map['quantity'] as num?)?.toDouble() ?? 1.0;
    final price = (map['price'] as num?)?.toDouble() ??
        (map['unit_price'] as num?)?.toDouble() ??
        0.0;
    final total = (map['total_price'] as num?)?.toDouble() ?? (qty * price);
    final rate = (map['tax_rate'] as num?)?.toDouble() ?? 0.0;
    final tax = (map['tax_amount'] as num?)?.toDouble() ??
        (rate > 0 ? (total * rate / (100 + rate)) : 0.0);

    return InvoiceItem(
      id: map['id']?.toString() ?? map['product_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Item',
      quantity: qty,
      unitPrice: price,
      totalPrice: total,
      unit: map['unit']?.toString() ?? (map['is_loose'] == true ? 'kg' : 'pc'),
      isLoose: map['is_loose'] == true || map['isLoose'] == true,
      taxRate: rate,
      taxAmount: tax,
    );
  }
}

/// Kirana store details printed on the invoice
class InvoiceShopDetails {
  final String shopId;
  final String shopName;
  final String address;
  final String phone;
  final String? gstin;
  final String? fssai;
  final String? upiId;

  const InvoiceShopDetails({
    required this.shopId,
    required this.shopName,
    required this.address,
    required this.phone,
    this.gstin,
    this.fssai,
    this.upiId,
  });

  Map<String, dynamic> toMap() {
    return {
      'shop_id': shopId,
      'shop_name': shopName,
      'address': address,
      'phone': phone,
      if (gstin != null) 'gstin': gstin,
      if (fssai != null) 'fssai': fssai,
      if (upiId != null) 'upi_id': upiId,
    };
  }

  factory InvoiceShopDetails.fromMap(Map<String, dynamic> map, {String? shopId}) {
    return InvoiceShopDetails(
      shopId: shopId ?? map['shop_id']?.toString() ?? map['id']?.toString() ?? 'shop_config',
      shopName: map['shop_name']?.toString() ??
          map['name']?.toString() ??
          map['store_name']?.toString() ??
          'NearKirana Store',
      address: map['address']?.toString() ??
          map['locality']?.toString() ??
          'Local Neighborhood, India',
      phone: map['mobile']?.toString() ?? map['phone']?.toString() ?? '9876543210',
      gstin: map['gstin']?.toString() ?? map['gst_number']?.toString(),
      fssai: map['fssai']?.toString() ?? map['fssai_number']?.toString(),
      upiId: map['upi_id']?.toString() ?? map['upi']?.toString(),
    );
  }
}

/// Customer details printed on the invoice
class InvoiceCustomerDetails {
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String? deliveryPin;

  const InvoiceCustomerDetails({
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.deliveryPin,
  });

  Map<String, dynamic> toMap() {
    return {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      if (deliveryPin != null) 'delivery_pin': deliveryPin,
    };
  }

  factory InvoiceCustomerDetails.fromMap(Map<String, dynamic> map) {
    return InvoiceCustomerDetails(
      customerName: map['customer_name']?.toString() ??
          map['name']?.toString() ??
          'Customer',
      customerPhone: map['phone_number']?.toString() ??
          map['customer_phone']?.toString() ??
          map['phone']?.toString() ??
          'N/A',
      deliveryAddress: map['delivery_address']?.toString() ??
          map['address']?.toString() ??
          'Store Pickup',
      deliveryPin: map['delivery_pin']?.toString() ?? map['pin']?.toString(),
    );
  }
}

/// Digital Invoice & Receipt Model (Feature 50)
class InvoiceModel {
  final String invoiceNumber;
  final String orderId;
  final DateTime orderDate;
  final InvoiceShopDetails shop;
  final InvoiceCustomerDetails customer;
  final List<InvoiceItem> items;
  final String deliveryType; // 'Delivery' or 'Pickup'
  final String paymentMethod; // 'Cash on Delivery', 'UPI', 'Card', etc.
  final String paymentStatus; // 'Paid', 'Pending', 'Unpaid'
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final String? couponCode;
  final double taxRate; // in %
  final double taxAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double finalTotal;

  const InvoiceModel({
    required this.invoiceNumber,
    required this.orderId,
    required this.orderDate,
    required this.shop,
    required this.customer,
    required this.items,
    this.deliveryType = 'Delivery',
    this.paymentMethod = 'Cash on Delivery',
    this.paymentStatus = 'Pending',
    required this.subtotal,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    this.couponCode,
    this.taxRate = 5.0, // Default Kirana grocery tax rate bracket
    this.taxAmount = 0.0,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    required this.finalTotal,
  });

  /// Formatted date string (e.g. 13 Oct 2026, 07:30 PM)
  String get formattedDate => DateFormat('dd MMM yyyy, hh:mm a').format(orderDate);

  /// Formatted date only (e.g. 13 Oct 2026)
  String get formattedDateOnly => DateFormat('dd MMM yyyy').format(orderDate);

  /// Formatted total (e.g. ₹520.00)
  String get formattedTotal => '₹${finalTotal.toStringAsFixed(2)}';

  /// Serializes invoice to Map
  Map<String, dynamic> toMap() {
    return {
      'invoice_number': invoiceNumber,
      'order_id': orderId,
      'order_date': Timestamp.fromDate(orderDate),
      'shop': shop.toMap(),
      'customer': customer.toMap(),
      'items': items.map((e) => e.toMap()).toList(),
      'delivery_type': deliveryType,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'discount': discount,
      if (couponCode != null) 'coupon_code': couponCode,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'cgst_amount': cgstAmount,
      'sgst_amount': sgstAmount,
      'final_total': finalTotal,
    };
  }

  /// Construct deterministic, consistent InvoiceModel from live Firestore Order document
  factory InvoiceModel.fromOrder(
    Map<String, dynamic> orderData, {
    String? orderId,
    Map<String, dynamic>? shopData,
  }) {
    final effectiveOrderId = orderId ?? orderData['order_id']?.toString() ?? orderData['id']?.toString() ?? 'ORD';

    // Parse Order Placement Date
    DateTime orderDate = DateTime.now();
    final rawDate = orderData['created_at'] ?? orderData['order_date'] ?? orderData['timestamp'];
    if (rawDate is Timestamp) {
      orderDate = rawDate.toDate();
    } else if (rawDate is String) {
      orderDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    // Generate deterministic invoice number from date and order ID
    // e.g. INV-20261013-ABCD
    final datePrefix = DateFormat('yyyyMMdd').format(orderDate);
    final idSuffix = effectiveOrderId.length > 6
        ? effectiveOrderId.substring(effectiveOrderId.length - 6).toUpperCase()
        : effectiveOrderId.toUpperCase();
    final generatedInvoiceNo = orderData['invoice_number']?.toString() ?? 'INV-$datePrefix-$idSuffix';

    // Parse Items
    final rawItems = orderData['items'];
    final List<InvoiceItem> items = [];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          items.add(InvoiceItem.fromMap(it));
        } else if (it is Map) {
          items.add(InvoiceItem.fromMap(Map<String, dynamic>.from(it)));
        }
      }
    }

    // Parse Shop details
    final effectiveShopData = shopData ?? (orderData['shop'] is Map ? Map<String, dynamic>.from(orderData['shop']) : null);
    final shop = InvoiceShopDetails.fromMap(
      effectiveShopData ?? {},
      shopId: orderData['shop_id']?.toString(),
    );

    // Parse Customer details
    final customer = InvoiceCustomerDetails.fromMap(orderData);

    // Parse Financials
    final double subtotal = (orderData['subtotal'] as num?)?.toDouble() ??
        items.fold<double>(0.0, (acc, item) => acc + item.totalPrice);
    final double deliveryFee = (orderData['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    final double discount = (orderData['discount'] as num?)?.toDouble() ?? 0.0;
    final String? couponCode = orderData['coupon_code']?.toString();

    // Final total is strictly consistent with the recorded order total
    final double recordedTotal = (orderData['total_amount'] as num?)?.toDouble() ??
        (orderData['total'] as num?)?.toDouble() ??
        ((subtotal - discount).clamp(0.0, double.infinity) + deliveryFee);

    // Calculate tax breakdown (Standard 5% retail GST component for packaged goods)
    final double taxRate = (orderData['tax_rate'] as num?)?.toDouble() ?? 5.0;
    // In retail, subtotal is inclusive of GST: Tax = Subtotal - (Subtotal / (1 + Rate%))
    final double taxableBase = subtotal > 0 ? (subtotal / (1 + (taxRate / 100))) : 0.0;
    final double calculatedTax = subtotal > 0 ? (subtotal - taxableBase) : 0.0;
    final double halfTax = calculatedTax / 2.0;

    return InvoiceModel(
      invoiceNumber: generatedInvoiceNo,
      orderId: effectiveOrderId,
      orderDate: orderDate,
      shop: shop,
      customer: customer,
      items: items,
      deliveryType: orderData['delivery_type']?.toString() ?? 'Delivery',
      paymentMethod: orderData['payment_method']?.toString() ?? 'Cash on Delivery',
      paymentStatus: orderData['payment_status']?.toString() ?? 'Pending',
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      discount: discount,
      couponCode: couponCode,
      taxRate: taxRate,
      taxAmount: calculatedTax,
      cgstAmount: halfTax,
      sgstAmount: halfTax,
      finalTotal: recordedTotal,
    );
  }
}
