import 'package:flutter_test/flutter_test.dart';
import 'package:near_kirana/cart_calculator.dart';

void main() {
  group('Order Placement Validation Rules', () {
    final validItem = const CartCalculationItem(
      id: 'item_1',
      name: 'Basmati Rice 1kg',
      price: 120.0,
      quantity: 2.0,
    );

    test('Empty cart is rejected', () {
      final result = CartCalculator.validateOrderPlacement(
        items: [],
        subtotal: 0.0,
        minOrder: 100.0,
        isDelivery: true,
        isStoreOpen: true,
        isWithinDeliveryRange: true,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Cart is empty'));
    });

    test('Order is rejected if store is currently closed', () {
      final result = CartCalculator.validateOrderPlacement(
        items: [validItem],
        subtotal: 240.0,
        minOrder: 100.0,
        isDelivery: true,
        isStoreOpen: false, // Closed!
        isWithinDeliveryRange: true,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('store is currently closed'));
    });

    test('Delivery order outside serviceable radius is rejected', () {
      final result = CartCalculator.validateOrderPlacement(
        items: [validItem],
        subtotal: 240.0,
        minOrder: 100.0,
        isDelivery: true,
        isStoreOpen: true,
        isWithinDeliveryRange: false, // Out of range!
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('outside the store service radius'));
    });

    test('Self-pickup order bypasses delivery service radius constraint', () {
      final result = CartCalculator.validateOrderPlacement(
        items: [validItem],
        subtotal: 240.0,
        minOrder: 100.0,
        isDelivery: false, // Self-pickup
        isStoreOpen: true,
        isWithinDeliveryRange: false, // Out of delivery range, but customer will pick up!
      );

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('Delivery order below minimum order threshold is rejected with actionable deficit amount', () {
      final cheapItem = const CartCalculationItem(
        id: 'biscuit',
        name: 'Biscuit',
        price: 30.0,
        quantity: 1.0,
      );

      final result = CartCalculator.validateOrderPlacement(
        items: [cheapItem],
        subtotal: 30.0,
        minOrder: 100.0,
        isDelivery: true,
        isStoreOpen: true,
        isWithinDeliveryRange: true,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Minimum order amount'));
      expect(result.errorMessage, contains('₹70')); // Needs ₹70 more
    });

    test('Self-pickup order bypasses delivery minimum order threshold', () {
      final cheapItem = const CartCalculationItem(
        id: 'biscuit',
        name: 'Biscuit',
        price: 30.0,
        quantity: 1.0,
      );

      final result = CartCalculator.validateOrderPlacement(
        items: [cheapItem],
        subtotal: 30.0,
        minOrder: 100.0,
        isDelivery: false, // Self pickup
        isStoreOpen: true,
        isWithinDeliveryRange: true,
      );

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('Valid delivery order meeting all constraints is approved', () {
      final result = CartCalculator.validateOrderPlacement(
        items: [validItem],
        subtotal: 240.0,
        minOrder: 100.0,
        isDelivery: true,
        isStoreOpen: true,
        isWithinDeliveryRange: true,
      );

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });
  });
}
