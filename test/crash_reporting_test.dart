import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/crash_reporting_service.dart';

void main() {
  late CrashReportingService crashService;

  setUp(() {
    crashService = CrashReportingService();
    crashService.reset();
    crashService.init();
  });

  group('CrashReportingService & Actionable Logging', () {
    test('Breadcrumb ring buffer records events in sequence', () {
      crashService.addBreadcrumb(
        'Customer added Parle-G to cart',
        category: 'cart',
      );
      crashService.addBreadcrumb(
        'Customer applied coupon SAVE50',
        category: 'coupon',
      );

      final breadcrumbs = crashService.getBreadcrumbs();
      expect(breadcrumbs.length, equals(3)); // 1 from init + 2 added
      expect(breadcrumbs[1].message, equals('Customer added Parle-G to cart'));
      expect(breadcrumbs[1].category, equals('cart'));
      expect(breadcrumbs[2].message, equals('Customer applied coupon SAVE50'));
      expect(breadcrumbs[2].category, equals('coupon'));
    });

    test('recordAction convenience alias logs user actions correctly', () {
      crashService.recordAction(
        'User opened CartScreen',
        category: 'navigation',
        data: {'tab': 'cart'},
      );
      final breadcrumbs = crashService.getBreadcrumbs();
      expect(breadcrumbs.last.message, equals('User opened CartScreen'));
      expect(breadcrumbs.last.category, equals('navigation'));
      expect(breadcrumbs.last.data?['tab'], equals('cart'));
    });

    test(
      'Breadcrumb ring buffer enforces max 50 items and evicts oldest FIFO',
      () {
        // Add 60 breadcrumbs
        for (int i = 1; i <= 60; i++) {
          crashService.addBreadcrumb('Action $i', category: 'test');
        }

        final breadcrumbs = crashService.getBreadcrumbs();
        expect(
          breadcrumbs.length,
          equals(CrashReportingService.maxBreadcrumbs),
        ); // Exactly 50

        // Oldest actions (Action 1 to 11) should have been evicted
        expect(breadcrumbs.first.message, equals('Action 11'));
        expect(breadcrumbs.last.message, equals('Action 60'));
      },
    );

    test('User context is captured and attached to error reports', () {
      crashService.setUser(
        uid: 'user_test_99',
        role: 'shop_owner',
        phone: '9876543210',
        shopId: 'SHOP_TEST_01',
      );

      final report = crashService.recordError(
        Exception('Network timeout while syncing stock'),
        StackTrace.current,
        reason: 'Sync Failure',
      );

      expect(report.userContext['uid'], equals('user_test_99'));
      expect(report.userContext['role'], equals('shop_owner'));
      expect(report.userContext['phone'], equals('9876543210'));
      expect(report.userContext['shop_id'], equals('SHOP_TEST_01'));
      expect(report.reason, equals('Sync Failure'));
      expect(report.fatal, isFalse);
    });

    test('clearUser removes sensitive user data on logout', () {
      crashService.setUser(uid: 'temp_user', role: 'customer');
      crashService.clearUser();

      final report = crashService.recordError('Uncaught test error', null);

      expect(report.userContext.containsKey('uid'), isFalse);
      expect(report.userContext.containsKey('role'), isFalse);
    });

    test('Custom telemetry keys and ad-hoc context data are captured', () {
      crashService.setCustomKey('app_version', '2.4.0');
      crashService.setCustomKey('active_screen', 'CheckoutScreen');

      final report = crashService.recordError(
        'Payment gateway error',
        null,
        contextData: {'order_id': 'ORD_123', 'amount': 450.0},
      );

      expect(report.customKeys['app_version'], equals('2.4.0'));
      expect(report.customKeys['active_screen'], equals('CheckoutScreen'));
      expect(report.customKeys['order_id'], equals('ORD_123'));
      expect(report.customKeys['amount'], equals(450.0));
    });

    test('Remote sink hook onReportRecorded receives error reports', () async {
      ErrorReport? capturedReport;

      crashService.onReportRecorded = (report) async {
        capturedReport = report;
      };

      crashService.addBreadcrumb('Navigated to PaymentScreen');
      crashService.recordError(
        'UPI intent launch failed',
        null,
        reason: 'App not installed',
        fatal: true,
      );

      expect(capturedReport, isNotNull);
      expect(capturedReport!.error, contains('UPI intent launch failed'));
      expect(capturedReport!.reason, equals('App not installed'));
      expect(capturedReport!.fatal, isTrue);
      expect(
        capturedReport!.breadcrumbs.any(
          (b) => b.message == 'Navigated to PaymentScreen',
        ),
        isTrue,
      );
    });

    test(
      'Flutter UI error details are converted to actionable ErrorReport',
      () {
        final flutterDetails = FlutterErrorDetails(
          exception: StateError('RenderFlex overflowed by 24 pixels'),
          stack: StackTrace.current,
          library: 'widgets library',
          context: ErrorDescription('building CartItemWidget'),
        );

        crashService.recordFlutterError(flutterDetails);

        final reports = crashService.getStoredReports();
        expect(reports.isNotEmpty, isTrue);
        final lastReport = reports.last;
        expect(
          lastReport.error,
          contains('RenderFlex overflowed by 24 pixels'),
        );
        expect(lastReport.reason, contains('building CartItemWidget'));
        expect(lastReport.toString(), contains('ACTIONABLE CRASH REPORT'));
      },
    );

    test(
      'reportCrashToFirestore writes structured error report into Firestore collection',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final report = ErrorReport(
          error: 'Database timeout',
          reason: 'Firestore unreachable',
          fatal: true,
          userContext: {'uid': 'user_abc', 'role': 'customer'},
          customKeys: {'screen': 'OrderReviewScreen'},
          breadcrumbs: [Breadcrumb(message: 'Tapped Place Order')],
        );

        final docId = await CrashReportingService.reportCrashToFirestore(
          report,
          firestore: fakeFirestore,
        );
        expect(docId, isNotNull);

        final doc = await fakeFirestore
            .collection('crash_reports')
            .doc(docId!)
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['error'], equals('Database timeout'));
        expect(doc.data()?['reason'], equals('Firestore unreachable'));
        expect(doc.data()?['fatal'], isTrue);
      },
    );

    test(
      'fetchRecentCrashReports retrieves reports sorted by timestamp',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final now = DateTime.now();

        await fakeFirestore.collection('crash_reports').add({
          'error': 'Error 1',
          'timestamp': now
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
        });
        await fakeFirestore.collection('crash_reports').add({
          'error': 'Error 2',
          'timestamp': now.toIso8601String(),
        });

        final reports = await CrashReportingService.fetchRecentCrashReports(
          limit: 10,
          firestore: fakeFirestore,
        );
        expect(reports.length, equals(2));
        expect(reports.first['error'], equals('Error 2'));
      },
    );

    test(
      'Automatic Firestore sink persists unhandled errors when enabled in init',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final service = CrashReportingService();
        service.reset();
        service.init(enableFirestoreSink: true, firestore: fakeFirestore);

        service.recordError(
          'Simulated crash in background job',
          null,
          reason: 'Out of memory',
        );

        final reports = await fakeFirestore.collection('crash_reports').get();
        expect(reports.docs.length, equals(1));
        expect(
          reports.docs.first.data()['error'],
          contains('Simulated crash in background job'),
        );
      },
    );

    test(
      'ErrorReport and Breadcrumb map serialization and deserialization round-trip',
      () {
        final original = ErrorReport(
          error: 'Serialization test',
          reason: 'Testing JSON converter',
          fatal: false,
          userContext: {'phone': '9999999999'},
          customKeys: {'device': 'Android 14'},
          breadcrumbs: [Breadcrumb(message: 'Step 1', category: 'action')],
        );

        final map = original.toMap();
        final reconstructed = ErrorReport.fromMap(map);

        expect(reconstructed.error, equals(original.error));
        expect(reconstructed.reason, equals(original.reason));
        expect(reconstructed.fatal, equals(original.fatal));
        expect(reconstructed.userContext['phone'], equals('9999999999'));
        expect(reconstructed.customKeys['device'], equals('Android 14'));
        expect(reconstructed.breadcrumbs.first.message, equals('Step 1'));
      },
    );
  });
}
