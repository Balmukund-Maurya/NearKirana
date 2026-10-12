import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_kirana/order_state_machine.dart';

void main() {
  group('OrderStateMachine - Standard Progression Transitions', () {
    test('Delivery flow progresses correctly: Pending -> Accepted -> Packing -> Ready -> Out -> Delivered', () {
      expect(OrderStateMachine.getNextProgressiveStatus(OrderStatus.pending, deliveryType: 'Delivery'), equals(OrderStatus.accepted));
      expect(OrderStateMachine.getNextProgressiveStatus(OrderStatus.accepted, deliveryType: 'Delivery'), equals(OrderStatus.packing));
      expect(OrderStateMachine.getNextProgressiveStatus(OrderStatus.packing, deliveryType: 'Delivery'), equals(OrderStatus.ready));
      expect(OrderStateMachine.getNextProgressiveStatus(OrderStatus.ready, deliveryType: 'Delivery'), equals(OrderStatus.outForDelivery));
      expect(OrderStateMachine.getNextProgressiveStatus(OrderStatus.outForDelivery, deliveryType: 'Delivery'), equals(OrderStatus.delivered));
      expect(OrderStateMachine.getNextProgressiveStatus(OrderStatus.delivered, deliveryType: 'Delivery'), isNull);
    });

    test('Pickup flow progresses correctly: Ready transitions directly to Delivered (pickup verified)', () {
      expect(OrderStateMachine.getNextProgressiveStatus(OrderStatus.ready, deliveryType: 'Pickup'), equals(OrderStatus.delivered));
    });

    test('All forward progressive steps are valid transitions in state machine', () {
      expect(OrderStateMachine.isValidTransition(OrderStatus.pending, OrderStatus.accepted), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.accepted, OrderStatus.packing), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.packing, OrderStatus.ready), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.ready, OrderStatus.outForDelivery), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.outForDelivery, OrderStatus.delivered), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.ready, OrderStatus.delivered), isTrue); // Pickup
    });
  });

  group('OrderStateMachine - Failure & Exception Transitions', () {
    test('Rejection is valid from Pending', () {
      expect(OrderStateMachine.isValidTransition(OrderStatus.pending, OrderStatus.rejected), isTrue);
    });

    test('Cancellation is valid from active non-terminal states', () {
      expect(OrderStateMachine.isValidTransition(OrderStatus.pending, OrderStatus.cancelled), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.accepted, OrderStatus.cancelled), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.packing, OrderStatus.cancelled), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.ready, OrderStatus.cancelled), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.outForDelivery, OrderStatus.cancelled), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.deliveryFailed, OrderStatus.cancelled), isTrue);
    });

    test('Failed delivery transitions: Out for Delivery -> Delivery_Failed -> Out for Delivery or Cancelled', () {
      expect(OrderStateMachine.isValidTransition(OrderStatus.outForDelivery, OrderStatus.deliveryFailed), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.deliveryFailed, OrderStatus.outForDelivery), isTrue);
      expect(OrderStateMachine.isValidTransition(OrderStatus.deliveryFailed, OrderStatus.cancelled), isTrue);
    });
  });

  group('OrderStateMachine - Terminal State Protection & Security Invariance', () {
    test('Delivered order CANNOT be moved back to Pending by standard merchant/customer', () {
      expect(OrderStateMachine.isValidTransition(OrderStatus.delivered, OrderStatus.pending), isFalse);

      expect(
        () => OrderStateMachine.assertValidTransition(OrderStatus.delivered, OrderStatus.pending),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Delivered orders cannot be changed back to "Pending" without an authorized correction process'),
          ),
        ),
      );
    });

    test('Delivered order CANNOT be cancelled or moved to active states', () {
      expect(OrderStateMachine.isValidTransition(OrderStatus.delivered, OrderStatus.cancelled), isFalse);
      expect(OrderStateMachine.isValidTransition(OrderStatus.delivered, OrderStatus.accepted), isFalse);
      expect(OrderStateMachine.isValidTransition(OrderStatus.delivered, OrderStatus.outForDelivery), isFalse);

      expect(
        () => OrderStateMachine.assertValidTransition(OrderStatus.delivered, OrderStatus.cancelled),
        throwsA(isA<StateError>()),
      );
    });

    test('Cancelled and Rejected orders are strictly terminal', () {
      expect(OrderStateMachine.isValidTransition(OrderStatus.cancelled, OrderStatus.pending), isFalse);
      expect(OrderStateMachine.isValidTransition(OrderStatus.cancelled, OrderStatus.delivered), isFalse);
      expect(OrderStateMachine.isValidTransition(OrderStatus.rejected, OrderStatus.pending), isFalse);
      expect(OrderStateMachine.isValidTransition(OrderStatus.rejected, OrderStatus.accepted), isFalse);

      expect(
        () => OrderStateMachine.assertValidTransition(OrderStatus.cancelled, OrderStatus.pending),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Terminal order in state "Cancelled" cannot be transitioned to "Pending"'),
          ),
        ),
      );

      expect(
        () => OrderStateMachine.assertValidTransition(OrderStatus.rejected, OrderStatus.delivered),
        throwsA(isA<StateError>()),
      );
    });

    test('Super admin CAN authorize corrections for Delivered orders', () {
      expect(
        OrderStateMachine.isValidTransition(OrderStatus.delivered, OrderStatus.pending, isSuperAdmin: true),
        isTrue,
      );

      expect(
        () => OrderStateMachine.assertValidTransition(OrderStatus.delivered, OrderStatus.pending, isSuperAdmin: true),
        returnsNormally,
      );
    });
  });

  group('OrderStateMachine - UI Helpers & Timeline Indices', () {
    test('Timeline step index maps correctly from 0 to 5', () {
      expect(OrderStateMachine.getTimelineStepIndex(OrderStatus.pending), equals(0));
      expect(OrderStateMachine.getTimelineStepIndex(OrderStatus.accepted), equals(1));
      expect(OrderStateMachine.getTimelineStepIndex(OrderStatus.packing), equals(2));
      expect(OrderStateMachine.getTimelineStepIndex(OrderStatus.packed), equals(2));
      expect(OrderStateMachine.getTimelineStepIndex(OrderStatus.ready), equals(3));
      expect(OrderStateMachine.getTimelineStepIndex(OrderStatus.outForDelivery), equals(4));
      expect(OrderStateMachine.getTimelineStepIndex(OrderStatus.delivered), equals(5));
      expect(OrderStateMachine.getTimelineStepIndex('UnknownStatus'), equals(0));
    });

    test('Button labels and icons adapt to status and delivery type', () {
      expect(OrderStateMachine.getProgressiveButtonLabel(OrderStatus.pending), equals('Accept Order'));
      expect(OrderStateMachine.getProgressiveButtonLabel(OrderStatus.accepted), equals('Start Packing'));
      expect(OrderStateMachine.getProgressiveButtonLabel(OrderStatus.packing), equals('Mark as Ready'));
      expect(OrderStateMachine.getProgressiveButtonLabel(OrderStatus.ready, deliveryType: 'Delivery'), equals('Dispatch Order'));
      expect(OrderStateMachine.getProgressiveButtonLabel(OrderStatus.ready, deliveryType: 'Pickup'), equals('Deliver to Customer'));
      expect(OrderStateMachine.getProgressiveButtonLabel(OrderStatus.outForDelivery), equals('Verify Delivery'));
      expect(OrderStateMachine.getProgressiveButtonLabel(OrderStatus.deliveryFailed), equals('Re-dispatch Order'));

      expect(OrderStateMachine.getProgressiveButtonIcon(OrderStatus.pending), equals(Icons.check_circle_outline_rounded));
      expect(OrderStateMachine.getProgressiveButtonIcon(OrderStatus.deliveryFailed), equals(Icons.replay_rounded));
    });

    test('Status badge colors return valid Colors for all statuses', () {
      for (var status in OrderStatus.allStatuses) {
        final color = OrderStateMachine.getStatusColor(status);
        expect(color, isA<Color>());
      }
    });
  });
}
