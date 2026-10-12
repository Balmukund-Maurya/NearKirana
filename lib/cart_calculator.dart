/// Robust cart calculation, pricing, discount, and stock validation engine.
/// Provides deterministic calculations covered by automated tests to prevent regressions.
class CartCalculationItem {
  final String id;
  final String name;
  final double price;
  final double quantity;
  final bool isLoose;
  final double maxStock;

  const CartCalculationItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.isLoose = false,
    this.maxStock = 999.0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'quantity': quantity,
    'is_loose': isLoose,
    'max_stock': maxStock,
  };
}

class Coupon {
  final String code;
  final String type; // 'flat' or 'percent'
  final double value;
  final double minOrder;
  final double? maxDiscount;

  const Coupon({
    required this.code,
    required this.type,
    required this.value,
    this.minOrder = 0.0,
    this.maxDiscount,
  });
}

class StockValidationItemError {
  final String productId;
  final String productName;
  final double requestedQuantity;
  final double availableStock;
  final String message;

  const StockValidationItemError({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.availableStock,
    required this.message,
  });
}

class StockValidationResult {
  final bool isValid;
  final List<StockValidationItemError> errors;
  final List<CartCalculationItem> adjustedItems;

  const StockValidationResult({
    required this.isValid,
    this.errors = const [],
    this.adjustedItems = const [],
  });
}

class OrderValidationResult {
  final bool isValid;
  final String? errorMessage;

  const OrderValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  static const OrderValidationResult valid = OrderValidationResult(isValid: true);
}

class CartCalculator {
  /// Calculate subtotal with standard 2-decimal currency rounding
  static double calculateSubtotal(List<CartCalculationItem> items) {
    if (items.isEmpty) return 0.0;
    double sum = 0.0;
    for (final item in items) {
      if (item.price < 0 || item.quantity < 0) {
        throw ArgumentError('Price and quantity must be non-negative');
      }
      sum += item.price * item.quantity;
    }
    return roundCurrency(sum);
  }

  /// Calculate delivery fee based on store rules and delivery type
  static double calculateDeliveryFee({
    required double subtotal,
    required double minOrder,
    required double freeDeliveryThreshold,
    required double standardFee,
    required bool isDelivery,
  }) {
    if (!isDelivery) return 0.0;
    if (subtotal < minOrder) return standardFee;
    if (subtotal >= freeDeliveryThreshold) return 0.0;
    return roundCurrency(standardFee);
  }

  /// Calculate discount amount from a coupon or manual discount
  static double calculateDiscount(
    double subtotal, {
    Coupon? coupon,
    double manualDiscount = 0.0,
  }) {
    if (subtotal <= 0) return 0.0;

    double discount = 0.0;

    if (coupon != null) {
      if (subtotal >= coupon.minOrder) {
        if (coupon.type == 'percent') {
          double calculated = (subtotal * coupon.value) / 100.0;
          if (coupon.maxDiscount != null && calculated > coupon.maxDiscount!) {
            calculated = coupon.maxDiscount!;
          }
          discount += calculated;
        } else if (coupon.type == 'flat') {
          discount += coupon.value;
        }
      }
    }

    if (manualDiscount > 0) {
      discount += manualDiscount;
    }

    // Safety invariant: Discount can never exceed subtotal!
    if (discount > subtotal) {
      discount = subtotal;
    }

    return roundCurrency(discount);
  }

  /// Calculates final payable total
  static double calculateFinalTotal({
    required double subtotal,
    required double deliveryFee,
    required double discount,
  }) {
    final net = subtotal + deliveryFee - discount;
    if (net < 0) return 0.0;
    return roundCurrency(net);
  }

  /// Round value to 2 decimal places to avoid IEEE 754 precision artifacts
  static double roundCurrency(double value) {
    return (value * 100).roundToDouble() / 100.0;
  }

  /// Validates cart items against live database stock
  static StockValidationResult validateStock({
    required List<CartCalculationItem> items,
    required Map<String, double> liveStock,
  }) {
    if (items.isEmpty) {
      return const StockValidationResult(isValid: true);
    }

    final errors = <StockValidationItemError>[];
    final adjusted = <CartCalculationItem>[];

    for (final item in items) {
      final available = liveStock[item.id] ?? 0.0;

      if (available <= 0) {
        errors.add(StockValidationItemError(
          productId: item.id,
          productName: item.name,
          requestedQuantity: item.quantity,
          availableStock: 0.0,
          message: '${item.name} is out of stock.',
        ));
      } else if (item.quantity > available) {
        errors.add(StockValidationItemError(
          productId: item.id,
          productName: item.name,
          requestedQuantity: item.quantity,
          availableStock: available,
          message: 'Only $available ${item.isLoose ? "kg" : "units"} of ${item.name} available.',
        ));
        adjusted.add(CartCalculationItem(
          id: item.id,
          name: item.name,
          price: item.price,
          quantity: available,
          isLoose: item.isLoose,
          maxStock: available,
        ));
      } else {
        adjusted.add(item);
      }
    }

    return StockValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      adjustedItems: adjusted,
    );
  }

  /// Validates whether an order can be safely placed
  static OrderValidationResult validateOrderPlacement({
    required List<CartCalculationItem> items,
    required double subtotal,
    required double minOrder,
    required bool isDelivery,
    required bool isStoreOpen,
    required bool isWithinDeliveryRange,
  }) {
    if (items.isEmpty) {
      return const OrderValidationResult(
        isValid: false,
        errorMessage: 'Cart is empty. Please add items before checkout.',
      );
    }

    if (!isStoreOpen) {
      return const OrderValidationResult(
        isValid: false,
        errorMessage: 'The store is currently closed. Please order during open hours.',
      );
    }

    if (isDelivery && !isWithinDeliveryRange) {
      return const OrderValidationResult(
        isValid: false,
        errorMessage: 'Your delivery address is outside the store service radius.',
      );
    }

    if (isDelivery && subtotal < minOrder) {
      return OrderValidationResult(
        isValid: false,
        errorMessage: 'Minimum order amount for delivery is ₹${minOrder.toStringAsFixed(0)}. Add items worth ₹${(minOrder - subtotal).toStringAsFixed(0)} more.',
      );
    }

    return OrderValidationResult.valid;
  }
}
