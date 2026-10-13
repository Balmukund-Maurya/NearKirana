import 'package:flutter_test/flutter_test.dart';
import 'package:near_kirana/cart_calculator.dart';

void main() {
  group('Cart Subtotal Calculations', () {
    test('Empty cart subtotal returns 0.0', () {
      final subtotal = CartCalculator.calculateSubtotal([]);
      expect(subtotal, equals(0.0));
    });

    test('Standard discrete packaged items calculate correctly', () {
      final items = [
        const CartCalculationItem(
          id: 'item_1',
          name: 'Parle-G 100g',
          price: 10.0,
          quantity: 5.0,
        ),
        const CartCalculationItem(
          id: 'item_2',
          name: 'Tata Salt 1kg',
          price: 28.0,
          quantity: 2.0,
        ),
        const CartCalculationItem(
          id: 'item_3',
          name: 'Maggi Noodles 4-pack',
          price: 56.0,
          quantity: 1.0,
        ),
      ];

      // 10*5 (50) + 28*2 (56) + 56*1 (56) = 162.0
      final subtotal = CartCalculator.calculateSubtotal(items);
      expect(subtotal, equals(162.0));
    });

    test(
      'User Specification: 2 x ₹50 and 1 x ₹30 produces expected subtotal of ₹130.0',
      () {
        final items = [
          const CartCalculationItem(
            id: 'item_a',
            name: 'Oil Packet (₹50)',
            price: 50.0,
            quantity: 2.0,
          ),
          const CartCalculationItem(
            id: 'item_b',
            name: 'Sugar 500g (₹30)',
            price: 30.0,
            quantity: 1.0,
          ),
        ];

        // 2 * 50 + 1 * 30 = 130.0
        final subtotal = CartCalculator.calculateSubtotal(items);
        expect(subtotal, equals(130.0));
        // Verify that incorrect calculation would fail the assertion
        expect(subtotal == 100.0, isFalse);
      },
    );

    test(
      'Loose items with fractional quantities (kg/gm) avoid floating point imprecision',
      () {
        final items = [
          const CartCalculationItem(
            id: 'sugar',
            name: 'Sugar (Loose)',
            price: 44.0,
            quantity: 1.75, // 1.75 kg @ 44/kg = 77.0
            isLoose: true,
          ),
          const CartCalculationItem(
            id: 'mustard_oil',
            name: 'Mustard Oil (Loose)',
            price: 135.50,
            quantity: 0.5, // 0.5 L @ 135.50 = 67.75
            isLoose: true,
          ),
          const CartCalculationItem(
            id: 'chana_dal',
            name: 'Chana Dal',
            price: 93.33,
            quantity: 0.333, // 31.07889 -> rounded to 31.08
            isLoose: true,
          ),
        ];

        final subtotal = CartCalculator.calculateSubtotal(items);
        // 77.0 + 67.75 + 31.08 = 175.83
        expect(subtotal, equals(175.83));
      },
    );

    test('Negative price or quantity throws ArgumentError', () {
      expect(
        () => CartCalculator.calculateSubtotal([
          const CartCalculationItem(
            id: 'invalid',
            name: 'Bad Item',
            price: -10.0,
            quantity: 1.0,
          ),
        ]),
        throwsArgumentError,
      );

      expect(
        () => CartCalculator.calculateSubtotal([
          const CartCalculationItem(
            id: 'invalid',
            name: 'Bad Item',
            price: 50.0,
            quantity: -2.0,
          ),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('Delivery Fee Calculations', () {
    test('Self-pickup orders always have 0.0 delivery fee', () {
      final fee = CartCalculator.calculateDeliveryFee(
        subtotal: 150.0,
        minOrder: 200.0,
        freeDeliveryThreshold: 500.0,
        standardFee: 30.0,
        isDelivery: false,
      );
      expect(fee, equals(0.0));
    });

    test(
      'Delivery orders above freeDeliveryThreshold have 0.0 delivery fee',
      () {
        final fee = CartCalculator.calculateDeliveryFee(
          subtotal: 550.0,
          minOrder: 100.0,
          freeDeliveryThreshold: 500.0,
          standardFee: 40.0,
          isDelivery: true,
        );
        expect(fee, equals(0.0));
      },
    );

    test('Delivery orders below freeDeliveryThreshold incur standard fee', () {
      final fee = CartCalculator.calculateDeliveryFee(
        subtotal: 350.0,
        minOrder: 100.0,
        freeDeliveryThreshold: 500.0,
        standardFee: 40.0,
        isDelivery: true,
      );
      expect(fee, equals(40.0));
    });

    test('Orders below minOrder incur standard fee', () {
      final fee = CartCalculator.calculateDeliveryFee(
        subtotal: 80.0,
        minOrder: 100.0,
        freeDeliveryThreshold: 500.0,
        standardFee: 40.0,
        isDelivery: true,
      );
      expect(fee, equals(40.0));
    });
  });

  group('Discounts & Coupon Rules', () {
    test('Flat discount coupon applies exact value', () {
      const coupon = Coupon(
        code: 'SAVE50',
        type: 'flat',
        value: 50.0,
        minOrder: 200.0,
      );

      final discount = CartCalculator.calculateDiscount(350.0, coupon: coupon);
      expect(discount, equals(50.0));
    });

    test('Coupon is rejected if subtotal is below minOrder condition', () {
      const coupon = Coupon(
        code: 'SAVE50',
        type: 'flat',
        value: 50.0,
        minOrder: 200.0,
      );

      final discount = CartCalculator.calculateDiscount(150.0, coupon: coupon);
      expect(discount, equals(0.0));
    });

    test('Percentage coupon applies correct percent discount', () {
      const coupon = Coupon(
        code: 'KIRANA10',
        type: 'percent',
        value: 10.0, // 10%
        minOrder: 100.0,
      );

      final discount = CartCalculator.calculateDiscount(450.0, coupon: coupon);
      expect(discount, equals(45.0)); // 10% of 450 = 45.0
    });

    test('Percentage coupon respects maxDiscount cap', () {
      const coupon = Coupon(
        code: 'MEGA20',
        type: 'percent',
        value: 20.0, // 20%
        minOrder: 200.0,
        maxDiscount: 60.0, // Capped at ₹60
      );

      // 20% of 1000 is 200, but cap is 60
      final discount = CartCalculator.calculateDiscount(1000.0, coupon: coupon);
      expect(discount, equals(60.0));
    });

    test('Safety Invariant: Discount can never exceed subtotal', () {
      const coupon = Coupon(
        code: 'SUPER100',
        type: 'flat',
        value: 200.0,
        minOrder: 50.0,
      );

      // Subtotal is 80, but coupon is 200 -> discount MUST be capped to 80
      final discount = CartCalculator.calculateDiscount(80.0, coupon: coupon);
      expect(discount, equals(80.0));
    });

    test('Zero or negative subtotal returns 0.0 discount', () {
      const coupon = Coupon(code: 'FREEBIE', type: 'flat', value: 50.0);

      expect(
        CartCalculator.calculateDiscount(0.0, coupon: coupon),
        equals(0.0),
      );
      expect(
        CartCalculator.calculateDiscount(-20.0, coupon: coupon),
        equals(0.0),
      );
    });
  });

  group('Final Payable Total Calculations', () {
    test('Standard total: subtotal + deliveryFee - discount', () {
      final total = CartCalculator.calculateFinalTotal(
        subtotal: 500.0,
        deliveryFee: 30.0,
        discount: 50.0,
      );
      expect(total, equals(480.0));
    });

    test('Total cannot be negative under any edge conditions', () {
      final total = CartCalculator.calculateFinalTotal(
        subtotal: 100.0,
        deliveryFee: 0.0,
        discount: 200.0,
      );
      expect(total, equals(0.0));
    });

    test('Decimal cents rounding consistency', () {
      final total = CartCalculator.calculateFinalTotal(
        subtotal: 149.99,
        deliveryFee: 25.50,
        discount: 10.33,
      );
      // 149.99 + 25.50 - 10.33 = 165.16
      expect(total, equals(165.16));
    });
  });

  group('Stock Validation Engine', () {
    test('All items fully available in live stock passes validation', () {
      final items = [
        const CartCalculationItem(
          id: 'atta',
          name: 'Aashirvaad Atta 5kg',
          price: 240,
          quantity: 2,
        ),
        const CartCalculationItem(
          id: 'ghee',
          name: 'Amul Ghee 1L',
          price: 620,
          quantity: 1,
        ),
      ];
      final liveStock = {'atta': 10.0, 'ghee': 5.0};

      final result = CartCalculator.validateStock(
        items: items,
        liveStock: liveStock,
      );
      expect(result.isValid, isTrue);
      expect(result.errors.isEmpty, isTrue);
      expect(result.adjustedItems.length, equals(2));
      expect(result.adjustedItems[0].quantity, equals(2.0));
    });

    test(
      'Item out of stock is detected and flagged with actionable message',
      () {
        final items = [
          const CartCalculationItem(
            id: 'maggi',
            name: 'Maggi Noodles',
            price: 14,
            quantity: 3,
          ),
        ];
        final liveStock = {'maggi': 0.0};

        final result = CartCalculator.validateStock(
          items: items,
          liveStock: liveStock,
        );
        expect(result.isValid, isFalse);
        expect(result.errors.length, equals(1));
        expect(result.errors.first.productId, equals('maggi'));
        expect(result.errors.first.message, contains('out of stock'));
        expect(result.adjustedItems.isEmpty, isTrue);
      },
    );

    test('Item missing completely from stock map treated as out of stock', () {
      final items = [
        const CartCalculationItem(
          id: 'new_item',
          name: 'Biscuits',
          price: 20,
          quantity: 1,
        ),
      ];

      final result = CartCalculator.validateStock(items: items, liveStock: {});
      expect(result.isValid, isFalse);
      expect(result.errors.first.availableStock, equals(0.0));
    });

    test('Partial stock: requested quantity is clamped to available stock', () {
      final items = [
        const CartCalculationItem(
          id: 'sugar_loose',
          name: 'Sugar (Loose)',
          price: 42.0,
          quantity: 5.0, // Requested 5kg
          isLoose: true,
        ),
      ];
      final liveStock = {
        'sugar_loose': 2.5, // Only 2.5kg available
      };

      final result = CartCalculator.validateStock(
        items: items,
        liveStock: liveStock,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.length, equals(1));
      expect(result.errors.first.availableStock, equals(2.5));
      expect(result.errors.first.message, contains('Only 2.5 kg'));

      // Adjusted items contains the clamped quantity
      expect(result.adjustedItems.length, equals(1));
      expect(result.adjustedItems.first.quantity, equals(2.5));
    });

    test(
      'Mixed cart: one item available, one partially available, one out of stock',
      () {
        final items = [
          const CartCalculationItem(
            id: 'p1',
            name: 'Milk',
            price: 30,
            quantity: 2,
          ),
          const CartCalculationItem(
            id: 'p2',
            name: 'Rice',
            price: 80,
            quantity: 4,
          ),
          const CartCalculationItem(
            id: 'p3',
            name: 'Paneer',
            price: 90,
            quantity: 1,
          ),
        ];
        final liveStock = {
          'p1': 5.0, // Sufficient
          'p2': 2.0, // Partial (4 -> 2)
          'p3': 0.0, // Out of stock
        };

        final result = CartCalculator.validateStock(
          items: items,
          liveStock: liveStock,
        );
        expect(result.isValid, isFalse);
        expect(result.errors.length, equals(2)); // p2 and p3 had errors
        expect(result.adjustedItems.length, equals(2)); // p1 and adjusted p2
        expect(
          result.adjustedItems.map((e) => e.id),
          containsAll(['p1', 'p2']),
        );
      },
    );
  });
}
