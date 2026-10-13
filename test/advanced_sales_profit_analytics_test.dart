import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:near_kirana/analytics_models.dart';
import 'package:near_kirana/analytics_service.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/widgets/add_expense_dialog.dart';
import 'package:near_kirana/admin_analytics_screen.dart';
import 'package:near_kirana/firebase_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'admin_shop_id': 'SHOP_TEST_101',
      'shop_id': 'SHOP_TEST_101',
      'ownerName': 'Ramesh Kirana',
    });
  });

  group('Feature 53: Domain Models - Analytics Models & Profit Margins', () {
    test('AnalyticsTimePeriod date range calculation', () {
      final now = DateTime.now();

      final todayStart = AnalyticsTimePeriod.today.getStartDate();
      expect(todayStart.year, now.year);
      expect(todayStart.month, now.month);
      expect(todayStart.day, now.day);

      final thisMonthStart = AnalyticsTimePeriod.thisMonth.getStartDate();
      expect(thisMonthStart.day, 1);
      expect(thisMonthStart.month, now.month);

      final last30DaysStart = AnalyticsTimePeriod.last30Days.getStartDate();
      expect(now.difference(last30DaysStart).inDays, greaterThanOrEqualTo(28));

      final end = AnalyticsTimePeriod.thisMonth.getEndDate();
      expect(end.hour, 23);
      expect(end.minute, 59);
    });

    test('ShopExpense serialization, deserialization and copyWith', () {
      final now = DateTime(2026, 10, 14, 10, 30);
      final expense = ShopExpense(
        id: 'exp_01',
        shopId: 'SHOP_TEST_101',
        title: 'Electricity Bill Oct',
        amount: 3450.0,
        category: 'Utilities',
        date: now,
        notes: 'Paid via electricity board portal',
        createdAt: now,
      );

      final map = expense.toMap();
      expect(map['shop_id'], 'SHOP_TEST_101');
      expect(map['title'], 'Electricity Bill Oct');
      expect(map['amount'], 3450.0);
      expect(map['category'], 'Utilities');
      expect(map['notes'], 'Paid via electricity board portal');

      final restored = ShopExpense.fromMap(map, 'exp_01');
      expect(restored.id, 'exp_01');
      expect(restored.title, 'Electricity Bill Oct');
      expect(restored.amount, 3450.0);
      expect(restored.category, 'Utilities');

      final updated = restored.copyWith(amount: 3600.0, notes: 'Adjusted with surcharge');
      expect(updated.amount, 3600.0);
      expect(updated.notes, 'Adjusted with surcharge');
      expect(updated.title, 'Electricity Bill Oct');
    });

    test('ProductMarginMetric calculates gross profit, margin percentage, and alert flags', () {
      // 1. High margin item (e.g. Loose Spices: sell 100, cost 70 -> margin 30%)
      const spice = ProductMarginMetric(
        productId: 'prod_spice',
        productName: 'Garam Masala 100g',
        category: 'Spices',
        unitsSold: 10,
        totalRevenue: 1000.0,
        unitSellingPrice: 100.0,
        unitPurchaseCost: 70.0,
        totalCOGS: 700.0,
        grossProfit: 300.0,
        marginPercent: 30.0,
      );

      expect(spice.grossProfit, 300.0);
      expect(spice.marginPercent, 30.0);
      expect(spice.isHighMargin, isTrue);
      expect(spice.isLowMargin, isFalse);
      expect(spice.isLossMaking, isFalse);

      // 2. Low margin dairy item (user example: Amul Milk: sell 60, cost 57 -> profit 3, margin 5%)
      const dairy = ProductMarginMetric(
        productId: 'prod_milk',
        productName: 'Amul Taaza Milk 1L',
        category: 'Dairy',
        unitsSold: 50,
        totalRevenue: 3000.0,
        unitSellingPrice: 60.0,
        unitPurchaseCost: 57.0,
        totalCOGS: 2850.0,
        grossProfit: 150.0,
        marginPercent: 5.0, // < 8%
      );

      expect(dairy.grossProfit, 150.0);
      expect(dairy.marginPercent, 5.0);
      expect(dairy.isLowMargin, isTrue);
      expect(dairy.isHighMargin, isFalse);
      expect(dairy.isLossMaking, isFalse);

      // 3. Loss making clearance item
      const lossItem = ProductMarginMetric(
        productId: 'prod_loss',
        productName: 'Old Stock Biscuit',
        category: 'Snacks',
        unitsSold: 5,
        totalRevenue: 50.0,
        unitSellingPrice: 10.0,
        unitPurchaseCost: 12.0,
        totalCOGS: 60.0,
        grossProfit: -10.0,
        marginPercent: -20.0,
      );

      expect(lossItem.isLossMaking, isTrue);
      expect(lossItem.isLowMargin, isTrue);
    });

    test('CategoryMarginMetric and DailySalesPoint margin calculations', () {
      const cat = CategoryMarginMetric(
        categoryName: 'Dairy',
        totalRevenue: 10000.0,
        totalCOGS: 9400.0,
        grossProfit: 600.0,
        marginPercent: 6.0,
        itemsSoldCount: 150.0,
      );

      expect(cat.isLowMargin, isTrue);
      expect(cat.grossProfit, 600.0);

      final day = DailySalesPoint(
        date: DateTime.now(),
        label: '14 Oct',
        revenue: 5000.0,
        cogs: 4000.0,
        grossProfit: 1000.0,
        orderCount: 12,
      );

      expect(day.marginPercent, 20.0);
      expect(day.orderCount, 12);
    });

    test('AdvancedAnalyticsSummary empty factory and net profit logic', () {
      final summary = AdvancedAnalyticsSummary.empty();
      expect(summary.totalRevenue, 0.0);
      expect(summary.totalCOGS, 0.0);
      expect(summary.grossProfit, 0.0);
      expect(summary.totalExpenses, 0.0);
      expect(summary.netProfit, 0.0);
      expect(summary.hasPurchasePriceGaps, isFalse);

      final populated = AdvancedAnalyticsSummary(
        timePeriod: AnalyticsTimePeriod.thisMonth,
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
        totalRevenue: 100000.0,
        totalCOGS: 75000.0,
        grossProfit: 25000.0, // 25% gross margin
        grossMarginPercent: 25.0,
        totalExpenses: 8000.0, // Operating expenses (rent, electricity)
        netProfit: 17000.0, // 25000 - 8000 = 17000 (17% net margin)
        netMarginPercent: 17.0,
        totalOrders: 100,
        deliveredOrders: 90,
        processingOrders: 5,
        cancelledOrders: 3,
        returnedOrders: 2,
        averageOrderValue: 1000.0,
        totalDiscounts: 2500.0,
        dailyTrends: const [],
        topProducts: const [],
        lowMarginProducts: const [],
        categoryMetrics: const [],
        expenses: const [],
        productsMissingPurchasePrice: 2,
      );

      expect(populated.grossProfit, 25000.0);
      expect(populated.netProfit, 17000.0);
      expect(populated.hasPurchasePriceGaps, isTrue);
    });
  });

  group('Feature 53: AnalyticsService Backend Calculation & Expenses Ledger', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AnalyticsService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = AnalyticsService(firestore: fakeFirestore);
    });

    test('addExpense, updateExpense, streamExpenses, and deleteExpense', () async {
      final now = DateTime.now();

      final expId = await service.addExpense(
        shopId: 'SHOP_TEST_101',
        title: 'Shop Rent Oct',
        amount: 15000.0,
        category: 'Rent',
        date: now,
        notes: 'Bank transfer to landlord',
      );

      expect(expId, isNotEmpty);

      final doc = await fakeFirestore.collection('expenses').doc(expId).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['amount'], 15000.0);
      expect(doc.data()!['category'], 'Rent');

      // Update expense
      final expense = ShopExpense.fromFirestore(doc);
      final updated = expense.copyWith(amount: 16000.0, notes: 'Rent with maintenance');
      await service.updateExpense(updated);

      final updatedDoc = await fakeFirestore.collection('expenses').doc(expId).get();
      expect(updatedDoc.data()!['amount'], 16000.0);
      expect(updatedDoc.data()!['notes'], 'Rent with maintenance');

      // Delete expense
      await service.deleteExpense(expId);
      final deletedDoc = await fakeFirestore.collection('expenses').doc(expId).get();
      expect(deletedDoc.exists, isFalse);
    });

    test('updateProductPurchasePrice saves purchase_price and cost_price', () async {
      await fakeFirestore.collection('products').doc('p_atta').set({
        'name': 'Aashirvaad Atta 5kg',
        'price': 260.0,
        'stock_quantity': 20,
      });

      await service.updateProductPurchasePrice(
        productId: 'p_atta',
        purchasePrice: 220.0,
      );

      final doc = await fakeFirestore.collection('products').doc('p_atta').get();
      expect(doc.data()!['purchase_price'], 220.0);
      expect(doc.data()!['cost_price'], 220.0);
    });

    test('fetchAnalyticsSummary computes exact COGS, identifies low margins & flags missing costs', () async {
      const shopId = 'SHOP_TEST_101';
      final now = DateTime.now();

      // 1. Seed products catalog
      // - Dairy milk: sell 60, cost 57 (Low margin: 5%)
      await fakeFirestore.collection('products').doc('prod_milk').set({
        'name': 'Amul Taaza Milk 1L',
        'price': 60.0,
        'purchase_price': 57.0,
        'category': 'Dairy',
      });

      // - Atta: sell 260, cost 210 (Healthy margin: ~19.2%)
      await fakeFirestore.collection('products').doc('prod_atta').set({
        'name': 'Aashirvaad Atta 5kg',
        'price': 260.0,
        'purchase_price': 210.0,
        'category': 'Staples',
      });

      // - Biscuit: sell 30, no purchase cost recorded (fallback 85% = 25.5 cost)
      await fakeFirestore.collection('products').doc('prod_biscuit').set({
        'name': 'Parle-G Gold 1kg',
        'price': 30.0,
        'category': 'Snacks',
      });

      final orderTime = DateTime(now.year, now.month, now.day, 12, 0, 0);

      // 2. Seed delivered order
      await fakeFirestore.collection('orders').doc('ORD-001').set({
        'shop_id': shopId,
        'status': 'Delivered',
        'total_amount': 760.0, // (60*5 = 300) + (260*1 = 260) + (30*6 = 180) + 20 delivery = 760
        'discount_amount': 20.0,
        'created_at': Timestamp.fromDate(orderTime),
        'items': [
          {
            'id': 'prod_milk',
            'name': 'Amul Taaza Milk 1L',
            'price': 60.0,
            'quantity': 5.0,
            'purchase_price': 57.0,
            'category': 'Dairy',
          },
          {
            'id': 'prod_atta',
            'name': 'Aashirvaad Atta 5kg',
            'price': 260.0,
            'quantity': 1.0,
            'purchase_price': 210.0,
            'category': 'Staples',
          },
          {
            'id': 'prod_biscuit',
            'name': 'Parle-G Gold 1kg',
            'price': 30.0,
            'quantity': 6.0,
            // Notice: no purchase_price -> will trigger fallback estimate
            'category': 'Snacks',
          },
        ],
      });

      // 3. Seed cancelled order (must be excluded from revenue and COGS)
      await fakeFirestore.collection('orders').doc('ORD-002').set({
        'shop_id': shopId,
        'status': 'Cancelled',
        'total_amount': 500.0,
        'created_at': Timestamp.fromDate(orderTime.add(const Duration(minutes: 10))),
        'items': [
          {'id': 'prod_milk', 'name': 'Amul Taaza Milk 1L', 'price': 60.0, 'quantity': 5.0},
        ],
      });

      // 4. Seed store expense (Rent / electricity)
      await fakeFirestore.collection('expenses').doc('EXP-001').set({
        'shop_id': shopId,
        'title': 'Delivery Boy Petrol',
        'amount': 150.0,
        'category': 'Transport / Fuel',
        'date': Timestamp.fromDate(orderTime.add(const Duration(minutes: 20))),
        'created_at': Timestamp.fromDate(orderTime.add(const Duration(minutes: 20))),
      });

      // Execute calculation
      final summary = await service.fetchAnalyticsSummary(
        shopId: shopId,
        period: AnalyticsTimePeriod.today,
      );

      // Verify orders & revenue
      expect(summary.totalOrders, 2);
      expect(summary.deliveredOrders, 1);
      expect(summary.cancelledOrders, 1);
      expect(summary.totalRevenue, 760.0);
      expect(summary.totalExpenses, 150.0);

      // Milk: 5 units * 57 cost = 285 COGS, revenue = 300, profit = 15 (margin = 5.0% < 8%)
      // Atta: 1 unit * 210 cost = 210 COGS, revenue = 260, profit = 50 (margin = 19.23%)
      // Biscuit: 6 units * (30 * 0.85 = 25.5) = 153 COGS, revenue = 180, profit = 27 (margin = 15%)
      // Total COGS = 285 + 210 + 153 = 648.0
      expect(summary.totalCOGS, closeTo(648.0, 0.1));

      // Gross profit = 760.0 - 648.0 = 112.0
      expect(summary.grossProfit, closeTo(112.0, 0.1));

      // Net profit = 112.0 - 150.0 (expense) = -38.0
      expect(summary.netProfit, closeTo(-38.0, 0.1));

      // Low margin products watchlist should contain Milk
      expect(summary.lowMarginProducts.any((p) => p.productName.contains('Milk')), isTrue);
      final milkMetric = summary.lowMarginProducts.firstWhere((p) => p.productName.contains('Milk'));
      expect(milkMetric.isLowMargin, isTrue);
      expect(milkMetric.marginPercent, closeTo(5.0, 0.1));

      // Biscuit has missing purchase price -> flagged
      expect(summary.productsMissingPurchasePrice, 1);
    });
  });

  group('Feature 53: Widget Tests - AddExpenseDialog & AdminAnalyticsScreen', () {
    late FakeFirebaseFirestore fakeFirestore;

    late ShopProvider shopProvider;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
      shopProvider = ShopProvider();
      await shopProvider.setShop('SHOP_TEST_101', 'Ramesh Kirana Store');
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: shopProvider),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('AddExpenseDialog renders inputs and handles validation', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          const Scaffold(
            body: AddExpenseDialog(shopId: 'SHOP_TEST_101'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Store Expense'), findsOneWidget);
      expect(find.text('Expense Title / Description *'), findsOneWidget);
      expect(find.text('Amount (₹) *'), findsOneWidget);
      expect(find.text('Category *'), findsOneWidget);

      // Attempt to submit empty form
      final submitButton = find.text('Record Expense');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Form validation error appears
      expect(find.text('Please enter an expense title'), findsOneWidget);

      // Fill valid details
      await tester.enterText(find.byType(TextFormField).first, 'Carry Bags 500 pcs');
      await tester.enterText(find.byType(TextFormField).at(1), '450.00');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify Firestore has the new expense
      final snap = await fakeFirestore.collection('expenses').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['title'], 'Carry Bags 500 pcs');
      expect(snap.docs.first.data()['amount'], 450.0);
    });

    testWidgets('AdminAnalyticsScreen renders KPI cards, timeframe chips, and tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          const AdminAnalyticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Executive KPI Cards & Header
      expect(find.text('Sales & Profit Analytics'), findsOneWidget);
      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('Gross Profit'), findsWidgets);
      expect(find.text('Store Expenses'), findsOneWidget);
      expect(find.text('Net Profit'), findsOneWidget);
      expect(find.text('Avg Order Value'), findsOneWidget);

      // Timeframe chips
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Last 7 Days'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Last 30 Days'), findsOneWidget);

      // Tabs
      expect(find.text('Overview & Trends'), findsOneWidget);
      expect(find.text('Profit & Margins'), findsOneWidget);

      // Switch to Profit & Margins tab
      await tester.tap(find.text('Profit & Margins'));
      await tester.pumpAndSettle();

      expect(find.text('Category Margin Performance'), findsOneWidget);
    });
  });
}
