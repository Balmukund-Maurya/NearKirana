import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/order_state_machine.dart';

void main() {
  group('OrderStatus Helpers & Classification', () {
    test('isTerminal correctly classifies terminal vs active states', () {
      expect(OrderStatus.isTerminal(OrderStatus.delivered), isTrue);
      expect(OrderStatus.isTerminal(OrderStatus.cancelled), isTrue);
      expect(OrderStatus.isTerminal(OrderStatus.rejected), isTrue);

      expect(OrderStatus.isTerminal(OrderStatus.pending), isFalse);
      expect(OrderStatus.isTerminal(OrderStatus.accepted), isFalse);
      expect(OrderStatus.isTerminal(OrderStatus.packing), isFalse);
      expect(OrderStatus.isTerminal(OrderStatus.packed), isFalse);
      expect(OrderStatus.isTerminal(OrderStatus.ready), isFalse);
      expect(OrderStatus.isTerminal(OrderStatus.outForDelivery), isFalse);
      expect(OrderStatus.isTerminal(OrderStatus.deliveryFailed), isFalse);
      expect(OrderStatus.isTerminal(null), isFalse);
      expect(OrderStatus.isTerminal('invalid_status'), isFalse);
    });

    test('isActive correctly identifies ongoing orders', () {
      expect(OrderStatus.isActive(OrderStatus.pending), isTrue);
      expect(OrderStatus.isActive(OrderStatus.accepted), isTrue);
      expect(OrderStatus.isActive(OrderStatus.packing), isTrue);
      expect(OrderStatus.isActive(OrderStatus.packed), isTrue);
      expect(OrderStatus.isActive(OrderStatus.ready), isTrue);
      expect(OrderStatus.isActive(OrderStatus.outForDelivery), isTrue);
      expect(OrderStatus.isActive(OrderStatus.deliveryFailed), isTrue);

      expect(OrderStatus.isActive(OrderStatus.delivered), isFalse);
      expect(OrderStatus.isActive(OrderStatus.cancelled), isFalse);
      expect(OrderStatus.isActive(OrderStatus.rejected), isFalse);
      expect(OrderStatus.isActive(null), isFalse);
    });

    test(
      'getProgressPercentage returns accurate numeric progress from 0.0 to 1.0',
      () {
        expect(
          OrderStatus.getProgressPercentage(OrderStatus.pending),
          closeTo(0.10, 0.001),
        );
        expect(
          OrderStatus.getProgressPercentage(OrderStatus.accepted),
          closeTo(0.25, 0.001),
        );
        expect(
          OrderStatus.getProgressPercentage(OrderStatus.packing),
          closeTo(0.50, 0.001),
        );
        expect(
          OrderStatus.getProgressPercentage(OrderStatus.packed),
          closeTo(0.50, 0.001),
        );
        expect(
          OrderStatus.getProgressPercentage(OrderStatus.ready),
          closeTo(0.70, 0.001),
        );
        expect(
          OrderStatus.getProgressPercentage(OrderStatus.outForDelivery),
          closeTo(0.85, 0.001),
        );
        expect(
          OrderStatus.getProgressPercentage(OrderStatus.delivered),
          closeTo(1.00, 0.001),
        );
        expect(
          OrderStatus.getProgressPercentage(OrderStatus.cancelled),
          closeTo(0.00, 0.001),
        );
        expect(
          OrderStatus.getProgressPercentage(OrderStatus.rejected),
          closeTo(0.00, 0.001),
        );
        expect(
          OrderStatus.getProgressPercentage(OrderStatus.deliveryFailed),
          closeTo(0.00, 0.001),
        );
        expect(OrderStatus.getProgressPercentage(null), closeTo(0.00, 0.001));
      },
    );

    test(
      'getDescription provides informative and user-friendly status text',
      () {
        expect(
          OrderStatus.getDescription(OrderStatus.pending),
          contains('Awaiting'),
        );
        expect(
          OrderStatus.getDescription(OrderStatus.accepted),
          contains('accepted'),
        );
        expect(
          OrderStatus.getDescription(OrderStatus.packing),
          contains('packed'),
        );
        expect(
          OrderStatus.getDescription(OrderStatus.ready),
          contains('ready'),
        );
        expect(
          OrderStatus.getDescription(OrderStatus.outForDelivery),
          contains('way'),
        );
        expect(
          OrderStatus.getDescription(OrderStatus.delivered),
          contains('delivered'),
        );
        expect(
          OrderStatus.getDescription(OrderStatus.rejected),
          contains('rejected'),
        );
        expect(
          OrderStatus.getDescription(OrderStatus.cancelled),
          contains('cancelled'),
        );
        expect(
          OrderStatus.getDescription(OrderStatus.deliveryFailed),
          contains('Delivery'),
        );
        expect(
          OrderStatus.getDescription('CustomStatus'),
          contains('CustomStatus'),
        );
      },
    );
  });

  group('OrderStateMachine - Standard Progression Transitions', () {
    test(
      'Delivery flow progresses correctly: Pending -> Accepted -> Packing -> Ready -> Out -> Delivered',
      () {
        expect(
          OrderStateMachine.getNextProgressiveStatus(
            OrderStatus.pending,
            deliveryType: 'Delivery',
          ),
          equals(OrderStatus.accepted),
        );
        expect(
          OrderStateMachine.getNextProgressiveStatus(
            OrderStatus.accepted,
            deliveryType: 'Delivery',
          ),
          equals(OrderStatus.packing),
        );
        expect(
          OrderStateMachine.getNextProgressiveStatus(
            OrderStatus.packing,
            deliveryType: 'Delivery',
          ),
          equals(OrderStatus.ready),
        );
        expect(
          OrderStateMachine.getNextProgressiveStatus(
            OrderStatus.ready,
            deliveryType: 'Delivery',
          ),
          equals(OrderStatus.outForDelivery),
        );
        expect(
          OrderStateMachine.getNextProgressiveStatus(
            OrderStatus.outForDelivery,
            deliveryType: 'Delivery',
          ),
          equals(OrderStatus.delivered),
        );
        expect(
          OrderStateMachine.getNextProgressiveStatus(
            OrderStatus.delivered,
            deliveryType: 'Delivery',
          ),
          isNull,
        );
      },
    );

    test(
      'Pickup flow progresses correctly: Ready transitions directly to Delivered (pickup verified)',
      () {
        expect(
          OrderStateMachine.getNextProgressiveStatus(
            OrderStatus.ready,
            deliveryType: 'Pickup',
          ),
          equals(OrderStatus.delivered),
        );
      },
    );

    test(
      'All forward progressive steps are valid transitions in state machine',
      () {
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.pending,
            OrderStatus.accepted,
          ),
          isTrue,
        );
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.accepted,
            OrderStatus.packing,
          ),
          isTrue,
        );
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.packing,
            OrderStatus.ready,
          ),
          isTrue,
        );
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.ready,
            OrderStatus.outForDelivery,
          ),
          isTrue,
        );
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.outForDelivery,
            OrderStatus.delivered,
          ),
          isTrue,
        );
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.ready,
            OrderStatus.delivered,
          ),
          isTrue,
        ); // Pickup
      },
    );

    test('Idempotent self transitions are permitted', () {
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.pending,
          OrderStatus.pending,
        ),
        isTrue,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.packing,
          OrderStatus.packing,
        ),
        isTrue,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.delivered,
          OrderStatus.delivered,
        ),
        isTrue,
      );
    });
  });

  group('OrderStateMachine - Failure & Exception Transitions', () {
    test('Rejection is valid from Pending', () {
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.pending,
          OrderStatus.rejected,
        ),
        isTrue,
      );
    });

    test('Cancellation is valid from active non-terminal states', () {
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.pending,
          OrderStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.accepted,
          OrderStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.packing,
          OrderStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.ready,
          OrderStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.outForDelivery,
          OrderStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.deliveryFailed,
          OrderStatus.cancelled,
        ),
        isTrue,
      );
    });

    test(
      'Failed delivery transitions: Out for Delivery -> Delivery_Failed -> Out for Delivery or Cancelled',
      () {
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.outForDelivery,
            OrderStatus.deliveryFailed,
          ),
          isTrue,
        );
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.deliveryFailed,
            OrderStatus.outForDelivery,
          ),
          isTrue,
        );
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.deliveryFailed,
            OrderStatus.cancelled,
          ),
          isTrue,
        );
      },
    );
  });

  group('OrderStateMachine - Terminal State Protection & Security Invariance', () {
    test(
      'Delivered order CANNOT be moved back to Pending or Packing by standard merchant/customer',
      () {
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.delivered,
            OrderStatus.pending,
          ),
          isFalse,
        );
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.delivered,
            OrderStatus.packing,
          ),
          isFalse,
        );

        expect(
          () => OrderStateMachine.assertValidTransition(
            OrderStatus.delivered,
            OrderStatus.packing,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Delivered orders cannot be changed back to "Packing" without an authorized correction process',
              ),
            ),
          ),
        );
      },
    );

    test('Delivered order CANNOT be cancelled or moved to active states', () {
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.delivered,
          OrderStatus.cancelled,
        ),
        isFalse,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.delivered,
          OrderStatus.accepted,
        ),
        isFalse,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.delivered,
          OrderStatus.outForDelivery,
        ),
        isFalse,
      );

      expect(
        () => OrderStateMachine.assertValidTransition(
          OrderStatus.delivered,
          OrderStatus.cancelled,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Cancelled and Rejected orders are strictly terminal', () {
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.cancelled,
          OrderStatus.pending,
        ),
        isFalse,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.cancelled,
          OrderStatus.delivered,
        ),
        isFalse,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.rejected,
          OrderStatus.pending,
        ),
        isFalse,
      );
      expect(
        OrderStateMachine.isValidTransition(
          OrderStatus.rejected,
          OrderStatus.accepted,
        ),
        isFalse,
      );

      expect(
        () => OrderStateMachine.assertValidTransition(
          OrderStatus.cancelled,
          OrderStatus.pending,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(
              'Terminal order in state "Cancelled" cannot be transitioned to "Pending"',
            ),
          ),
        ),
      );

      expect(
        () => OrderStateMachine.assertValidTransition(
          OrderStatus.rejected,
          OrderStatus.delivered,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'Super admin CAN authorize corrections for Delivered and terminal orders',
      () {
        expect(
          OrderStateMachine.isValidTransition(
            OrderStatus.delivered,
            OrderStatus.packing,
            isSuperAdmin: true,
          ),
          isTrue,
        );

        expect(
          () => OrderStateMachine.assertValidTransition(
            OrderStatus.delivered,
            OrderStatus.packing,
            isSuperAdmin: true,
          ),
          returnsNormally,
        );
      },
    );
  });

  group('OrderStateMachine - getAllowedTransitions', () {
    test('Returns exact legal transitions for normal operators', () {
      final fromPending = OrderStateMachine.getAllowedTransitions(
        OrderStatus.pending,
      );
      expect(
        fromPending,
        containsAll([
          OrderStatus.accepted,
          OrderStatus.packing,
          OrderStatus.ready,
          OrderStatus.rejected,
          OrderStatus.cancelled,
        ]),
      );

      final fromDelivered = OrderStateMachine.getAllowedTransitions(
        OrderStatus.delivered,
      );
      expect(fromDelivered, isEmpty);

      final fromCancelled = OrderStateMachine.getAllowedTransitions(
        OrderStatus.cancelled,
      );
      expect(fromCancelled, isEmpty);

      final fromRejected = OrderStateMachine.getAllowedTransitions(
        OrderStatus.rejected,
      );
      expect(fromRejected, isEmpty);

      final fromDeliveryFailed = OrderStateMachine.getAllowedTransitions(
        OrderStatus.deliveryFailed,
      );
      expect(
        fromDeliveryFailed,
        containsAll([OrderStatus.outForDelivery, OrderStatus.cancelled]),
      );
    });

    test('Super admin receives all alternative states except current', () {
      final allowedForAdmin = OrderStateMachine.getAllowedTransitions(
        OrderStatus.delivered,
        isSuperAdmin: true,
      );
      expect(allowedForAdmin.contains(OrderStatus.delivered), isFalse);
      expect(allowedForAdmin.contains(OrderStatus.packing), isTrue);
      expect(allowedForAdmin.contains(OrderStatus.pending), isTrue);
    });
  });

  group('OrderStateMachine - Authorized Correction Workflow', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test('Non-super admin cannot execute authorized correction', () async {
      await fakeFirestore.collection('orders').doc('ORD-101').set({
        'status': OrderStatus.delivered,
      });

      expect(
        () => OrderStateMachine.applyAuthorizedCorrection(
          orderId: 'ORD-101',
          targetStatus: OrderStatus.packing,
          authorizedBy: 'merchant_user',
          correctionReason: 'Customer called saying packet not received',
          isSuperAdmin: false,
          firestore: fakeFirestore,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('requires authorized super admin permissions'),
          ),
        ),
      );
    });

    test('Rejects invalid status name during correction', () async {
      await fakeFirestore.collection('orders').doc('ORD-102').set({
        'status': OrderStatus.delivered,
      });

      expect(
        () => OrderStateMachine.applyAuthorizedCorrection(
          orderId: 'ORD-102',
          targetStatus: 'random_invalid_status',
          authorizedBy: 'super_admin_1',
          correctionReason: 'Testing validation',
          isSuperAdmin: true,
          firestore: fakeFirestore,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'Super admin successfully corrects Delivered order to Packing with audit trail',
      () async {
        final orderRef = fakeFirestore.collection('orders').doc('ORD-103');
        await orderRef.set({
          'status': OrderStatus.delivered,
          'customer_name': 'Ramesh Kumar',
        });

        final result = await OrderStateMachine.applyAuthorizedCorrection(
          orderId: 'ORD-103',
          targetStatus: OrderStatus.packing,
          authorizedBy: 'admin_balmukund',
          correctionReason:
              'Operator accidentally hit deliver instead of packing',
          isSuperAdmin: true,
          firestore: fakeFirestore,
        );

        expect(result.success, isTrue);
        expect(result.previousStatus, equals(OrderStatus.delivered));
        expect(result.newStatus, equals(OrderStatus.packing));
        expect(result.authorizedBy, equals('admin_balmukund'));
        expect(result.reason, contains('accidentally hit deliver'));

        // Verify Firestore document update
        final updatedSnap = await orderRef.get();
        expect(updatedSnap.data()?['status'], equals(OrderStatus.packing));

        final lastCorrection =
            updatedSnap.data()?['last_correction'] as Map<String, dynamic>;
        expect(lastCorrection['from_status'], equals(OrderStatus.delivered));
        expect(lastCorrection['to_status'], equals(OrderStatus.packing));
        expect(lastCorrection['authorized_by'], equals('admin_balmukund'));
        expect(lastCorrection['is_correction'], isTrue);

        final auditLog = (updatedSnap.data()?['status_audit_log'] as List)
            .cast<Map<String, dynamic>>();
        expect(auditLog.length, equals(1));
        expect(auditLog.first['reason'], contains('accidentally hit deliver'));

        // Verify subcollection entry
        final subHistory = await orderRef.collection('status_history').get();
        expect(subHistory.docs.length, equals(1));
        expect(
          subHistory.docs.first.data()['to_status'],
          equals(OrderStatus.packing),
        );

        // Verify OrderStateCorrectionResult toMap() serialization
        final resultMap = result.toMap();
        expect(resultMap['order_id'], equals('ORD-103'));
        expect(resultMap['new_status'], equals(OrderStatus.packing));
      },
    );
  });

  group('OrderStateMachine - transitionOrder Automated Workflow', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test('Throws StateError on illegal status transition', () async {
      final orderRef = fakeFirestore.collection('orders').doc('ORD-201');
      await orderRef.set({'status': OrderStatus.delivered});

      expect(
        () => OrderStateMachine.transitionOrder(
          orderId: 'ORD-201',
          targetStatus: OrderStatus.packing,
          updatedBy: 'delivery_boy_1',
          firestore: fakeFirestore,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Throws Exception if order document does not exist', () async {
      expect(
        () => OrderStateMachine.transitionOrder(
          orderId: 'NON_EXISTENT_ORDER',
          targetStatus: OrderStatus.accepted,
          updatedBy: 'merchant',
          firestore: fakeFirestore,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'Transitions Pending to Accepted and records accepted_at timestamp and audit logs',
      () async {
        final orderRef = fakeFirestore.collection('orders').doc('ORD-202');
        await orderRef.set({'status': OrderStatus.pending});

        final success = await OrderStateMachine.transitionOrder(
          orderId: 'ORD-202',
          targetStatus: OrderStatus.accepted,
          updatedBy: 'store_manager',
          note: 'Order confirmed by store manager',
          firestore: fakeFirestore,
        );

        expect(success, isTrue);

        final snap = await orderRef.get();
        expect(snap.data()?['status'], equals(OrderStatus.accepted));
        expect(snap.data()?['accepted_at'], isNotNull);

        final auditLog = (snap.data()?['status_audit_log'] as List)
            .cast<Map<String, dynamic>>();
        expect(auditLog.length, equals(1));
        expect(auditLog.first['from_status'], equals(OrderStatus.pending));
        expect(auditLog.first['to_status'], equals(OrderStatus.accepted));
        expect(
          auditLog.first['note'],
          equals('Order confirmed by store manager'),
        );

        final subHistory = await orderRef.collection('status_history').get();
        expect(subHistory.docs.length, equals(1));
        expect(
          subHistory.docs.first.data()['to_status'],
          equals(OrderStatus.accepted),
        );
      },
    );

    test(
      'Transitions through full lifecycle setting appropriate timestamps',
      () async {
        final orderRef = fakeFirestore.collection('orders').doc('ORD-203');
        await orderRef.set({'status': OrderStatus.accepted});

        // Accepted -> Packing
        await OrderStateMachine.transitionOrder(
          orderId: 'ORD-203',
          targetStatus: OrderStatus.packing,
          updatedBy: 'packer_1',
          firestore: fakeFirestore,
        );
        var snap = await orderRef.get();
        expect(snap.data()?['status'], equals(OrderStatus.packing));
        expect(snap.data()?['packing_started_at'], isNotNull);

        // Packing -> Ready
        await OrderStateMachine.transitionOrder(
          orderId: 'ORD-203',
          targetStatus: OrderStatus.ready,
          updatedBy: 'packer_1',
          firestore: fakeFirestore,
        );
        snap = await orderRef.get();
        expect(snap.data()?['status'], equals(OrderStatus.ready));
        expect(snap.data()?['ready_at'], isNotNull);

        // Ready -> Out for Delivery
        await OrderStateMachine.transitionOrder(
          orderId: 'ORD-203',
          targetStatus: OrderStatus.outForDelivery,
          updatedBy: 'driver_1',
          firestore: fakeFirestore,
        );
        snap = await orderRef.get();
        expect(snap.data()?['status'], equals(OrderStatus.outForDelivery));
        expect(snap.data()?['dispatched_at'], isNotNull);

        // Out for Delivery -> Delivered
        await OrderStateMachine.transitionOrder(
          orderId: 'ORD-203',
          targetStatus: OrderStatus.delivered,
          updatedBy: 'driver_1',
          firestore: fakeFirestore,
        );
        snap = await orderRef.get();
        expect(snap.data()?['status'], equals(OrderStatus.delivered));
        expect(snap.data()?['delivered_at'], isNotNull);
      },
    );
  });

  group('OrderStateMachine - UI Helpers & Timeline Indices', () {
    test('Timeline step index maps correctly from 0 to 5', () {
      expect(
        OrderStateMachine.getTimelineStepIndex(OrderStatus.pending),
        equals(0),
      );
      expect(
        OrderStateMachine.getTimelineStepIndex(OrderStatus.accepted),
        equals(1),
      );
      expect(
        OrderStateMachine.getTimelineStepIndex(OrderStatus.packing),
        equals(2),
      );
      expect(
        OrderStateMachine.getTimelineStepIndex(OrderStatus.packed),
        equals(2),
      );
      expect(
        OrderStateMachine.getTimelineStepIndex(OrderStatus.ready),
        equals(3),
      );
      expect(
        OrderStateMachine.getTimelineStepIndex(OrderStatus.outForDelivery),
        equals(4),
      );
      expect(
        OrderStateMachine.getTimelineStepIndex(OrderStatus.delivered),
        equals(5),
      );
      expect(
        OrderStateMachine.getTimelineStepIndex('UnknownStatus'),
        equals(0),
      );
    });

    test('Button labels and icons adapt to status and delivery type', () {
      expect(
        OrderStateMachine.getProgressiveButtonLabel(OrderStatus.pending),
        equals('Accept Order'),
      );
      expect(
        OrderStateMachine.getProgressiveButtonLabel(OrderStatus.accepted),
        equals('Start Packing'),
      );
      expect(
        OrderStateMachine.getProgressiveButtonLabel(OrderStatus.packing),
        equals('Mark as Ready'),
      );
      expect(
        OrderStateMachine.getProgressiveButtonLabel(
          OrderStatus.ready,
          deliveryType: 'Delivery',
        ),
        equals('Dispatch Order'),
      );
      expect(
        OrderStateMachine.getProgressiveButtonLabel(
          OrderStatus.ready,
          deliveryType: 'Pickup',
        ),
        equals('Deliver to Customer'),
      );
      expect(
        OrderStateMachine.getProgressiveButtonLabel(OrderStatus.outForDelivery),
        equals('Verify Delivery'),
      );
      expect(
        OrderStateMachine.getProgressiveButtonLabel(OrderStatus.deliveryFailed),
        equals('Re-dispatch Order'),
      );

      expect(
        OrderStateMachine.getProgressiveButtonIcon(OrderStatus.pending),
        equals(Icons.check_circle_outline_rounded),
      );
      expect(
        OrderStateMachine.getProgressiveButtonIcon(OrderStatus.deliveryFailed),
        equals(Icons.replay_rounded),
      );
    });

    test('Status badge colors return valid Colors for all statuses', () {
      for (var status in OrderStatus.allStatuses) {
        final color = OrderStateMachine.getStatusColor(status);
        expect(color, isA<Color>());
      }
    });
  });
}
