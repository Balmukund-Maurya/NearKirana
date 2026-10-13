import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:near_kirana/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({});
  });

  group('Reliable Push Notifications & Token Management (Feature 41)', () {
    test(
      '1. NotificationItem serialization & deserialization handles Timestamps and Strings',
      () {
        final now = DateTime.now();
        final item = NotificationItem(
          id: 'notif_100',
          title: 'Order Dispatched',
          body: 'Your groceries are on the way',
          orderId: 'ORD-987654',
          type: 'order_status',
          recipientPhone: '9876543210',
          recipientUid: 'user_cust_1',
          shopId: 'shop_gupta',
          createdAt: now,
          isRead: false,
          data: {'tracking_url': 'https://nearkirana.app/track/ORD-987654'},
        );

        final map = item.toMap();
        expect(map['title'], 'Order Dispatched');
        expect(map['body'], 'Your groceries are on the way');
        expect(map['order_id'], 'ORD-987654');
        expect(map['recipient_phone'], '9876543210');
        expect(map['recipient_uid'], 'user_cust_1');
        expect(map['shop_id'], 'shop_gupta');
        expect(map['is_read'], false);
        expect(
          map['data']['tracking_url'],
          'https://nearkirana.app/track/ORD-987654',
        );

        // Test fromMap with Timestamp
        final reconstituted = NotificationItem.fromMap('notif_100', map);
        expect(reconstituted.id, 'notif_100');
        expect(reconstituted.title, 'Order Dispatched');
        expect(reconstituted.orderId, 'ORD-987654');
        expect(reconstituted.recipientPhone, '9876543210');
        expect(reconstituted.recipientUid, 'user_cust_1');

        // Test fromMap with String date
        final mapWithString = Map<String, dynamic>.from(map);
        mapWithString['created_at'] = '2026-10-13T10:00:00.000Z';
        final reconstitutedFromString = NotificationItem.fromMap(
          'notif_101',
          mapWithString,
        );
        expect(reconstitutedFromString.createdAt.year, 2026);
      },
    );

    test(
      '2. Device token registration syncs to global registry and user profile subcollection',
      () async {
        const token =
            'fcm_test_device_token_abc123xyz789_unique_sample_string_long';
        const uid = 'customer_uid_42';
        const phone = '9876500042';

        await NotificationService.syncDeviceToken(
          uid: uid,
          token: token,
          phone: phone,
          role: 'customer',
          shopId: 'shop_gupta',
          firestore: fakeFirestore,
        );

        // Verify global device_tokens collection
        final globalTokens = await fakeFirestore
            .collection('device_tokens')
            .get();
        expect(globalTokens.docs.isNotEmpty, isTrue);
        final globalDoc = globalTokens.docs.first.data();
        expect(globalDoc['token'], token);
        expect(globalDoc['uid'], uid);
        expect(globalDoc['phone'], phone);
        expect(globalDoc['role'], 'customer');
        expect(globalDoc['shop_id'], 'shop_gupta');
        expect(globalDoc['is_active'], isTrue);

        // Verify user subcollection users/{uid}/fcm_tokens
        final userTokens = await fakeFirestore
            .collection('users')
            .doc(uid)
            .collection('fcm_tokens')
            .get();
        expect(userTokens.docs.isNotEmpty, isTrue);
        final userDoc = userTokens.docs.first.data();
        expect(userDoc['token'], token);
        expect(userDoc['is_active'], isTrue);
      },
    );

    test(
      '3. Token removal deactivates token in both collections upon logout',
      () async {
        const token =
            'fcm_test_logout_token_555_secure_string_sample_value_1234';
        const uid = 'customer_uid_logout';

        await NotificationService.syncDeviceToken(
          uid: uid,
          token: token,
          phone: '9988776655',
          role: 'customer',
          firestore: fakeFirestore,
        );

        // Now logout and remove device token
        await NotificationService.removeDeviceToken(
          uid: uid,
          token: token,
          firestore: fakeFirestore,
        );

        final globalTokens = await fakeFirestore
            .collection('device_tokens')
            .get();
        expect(globalTokens.docs.first.data()['is_active'], isFalse);

        final userTokens = await fakeFirestore
            .collection('users')
            .doc(uid)
            .collection('fcm_tokens')
            .get();
        expect(userTokens.docs.first.data()['is_active'], isFalse);
      },
    );

    test(
      '4. Token rotation/refresh updates SharedPreferences and refreshes Firestore registrations',
      () async {
        SharedPreferences.setMockInitialValues({
          'current_user_uid': 'user_refresh_123',
          'customerPhone': '9812345678',
          'selectedRole': 'shopkeeper',
          'current_shop_id': 'shop_refresh_99',
        });

        const rotatedToken =
            'newly_rotated_fcm_token_super_random_hex_string_value';

        await NotificationService.handleTokenRefresh(
          rotatedToken,
          firestore: fakeFirestore,
        );

        // Verify SharedPreferences updated
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('fcm_device_token'), rotatedToken);

        // Verify Firestore refreshed records
        final userTokens = await fakeFirestore
            .collection('users')
            .doc('user_refresh_123')
            .collection('fcm_tokens')
            .get();
        expect(userTokens.docs.isNotEmpty, isTrue);
        expect(userTokens.docs.first.data()['token'], rotatedToken);
        expect(userTokens.docs.first.data()['role'], 'shopkeeper');
        expect(userTokens.docs.first.data()['shop_id'], 'shop_refresh_99');
      },
    );

    test(
      '5. Example Scenario: Order Packed -> Out for Delivery triggers notification to customer and enqueues backend job',
      () async {
        const orderId = 'ORD_OUT_123456';
        const customerPhone = '9876543210';
        const customerUid = 'cust_out_delivery';
        const shopId = 'shop_kirana_central';

        final result =
            await NotificationService.dispatchOrderStatusNotification(
              orderId: orderId,
              newStatus: 'Out for Delivery',
              customerPhone: customerPhone,
              customerUid: customerUid,
              shopId: shopId,
              orderTotal: 450.0,
              deliveryBoyName: 'Ramesh Kumar',
              firestore: fakeFirestore,
            );

        expect(result['status'], 'queued');
        expect(result['title'], contains('Out for Delivery'));
        expect(result['body'], contains('Ramesh Kumar'));

        // Check customer in-app notifications collection
        final notifQuery = await fakeFirestore
            .collection('notifications')
            .where('order_id', isEqualTo: orderId)
            .get();
        expect(notifQuery.docs.length, 1);
        final notifDoc = notifQuery.docs.first.data();
        expect(notifDoc['title'], contains('Out for Delivery'));
        expect(notifDoc['body'], contains('Ramesh Kumar'));
        expect(notifDoc['recipient_phone'], customerPhone);
        expect(notifDoc['recipient_uid'], customerUid);
        expect(notifDoc['is_read'], isFalse);

        // Check reliable notification_queue for backend FCM worker
        final queueQuery = await fakeFirestore
            .collection('notification_queue')
            .where('order_id', isEqualTo: orderId)
            .get();
        expect(queueQuery.docs.length, 1);
        final queueDoc = queueQuery.docs.first.data();
        expect(queueDoc['status'], 'queued');
        expect(queueDoc['target_topic'], 'order_$orderId');
        expect(queueDoc['target_phone'], customerPhone);
        expect(queueDoc['retry_count'], 0);
        expect(queueDoc['max_retries'], 3);
        expect(queueDoc['priority'], 'high');
        expect(queueDoc['payload']['delivery_boy'], 'Ramesh Kumar');
      },
    );

    test(
      '6. Order status transitions generate appropriate localized titles and bodies',
      () async {
        final statuses = [
          'Pending',
          'Accepted',
          'Packing',
          'Ready',
          'Delivered',
          'Delivery_Failed',
          'Cancelled',
        ];

        for (var status in statuses) {
          final res = await NotificationService.dispatchOrderStatusNotification(
            orderId: 'ORD_STATUS_$status',
            newStatus: status,
            customerPhone: '9000000000',
            shopId: 'shop_all',
            orderTotal: 250.0,
            failureReason: status == 'Delivery_Failed'
                ? 'Customer unreachable'
                : null,
            firestore: fakeFirestore,
          );

          expect(res['title'], isNotEmpty);
          expect(res['body'], isNotEmpty);

          if (status == 'Delivery_Failed') {
            expect(res['body'], contains('Customer unreachable'));
          }
        }

        final allNotifs = await fakeFirestore.collection('notifications').get();
        expect(allNotifs.docs.length, statuses.length);
      },
    );

    test(
      '7. Failed notification retry mechanism re-attempts failed jobs and isolates dead letters',
      () async {
        // 1. Seed two failed queue items:
        // Item A: retry_count = 1 (can retry)
        await fakeFirestore
            .collection('notification_queue')
            .doc('queue_fail_1')
            .set({
              'order_id': 'ORD_RETRY_1',
              'status': 'failed',
              'retry_count': 1,
              'max_retries': 3,
              'title': 'Test Retry 1',
              'body': 'Content 1',
            });

        // Item B: retry_count = 3 (reached max retries -> must be dead_letter)
        await fakeFirestore
            .collection('notification_queue')
            .doc('queue_fail_2')
            .set({
              'order_id': 'ORD_DEAD_2',
              'status': 'failed',
              'retry_count': 3,
              'max_retries': 3,
              'title': 'Test Dead Letter',
              'body': 'Content 2',
            });

        // 2. Trigger retry processor
        final retriedCount = await NotificationService.retryFailedNotifications(
          firestore: fakeFirestore,
        );

        expect(retriedCount, 1);

        // Verify Item A was re-queued with incremented retry count
        final doc1 = await fakeFirestore
            .collection('notification_queue')
            .doc('queue_fail_1')
            .get();
        expect(doc1.data()!['status'], 'queued');
        expect(doc1.data()!['retry_count'], 2);

        // Verify Item B was moved to dead_letter
        final doc2 = await fakeFirestore
            .collection('notification_queue')
            .doc('queue_fail_2')
            .get();
        expect(doc2.data()!['status'], 'dead_letter');
      },
    );
  });
}
