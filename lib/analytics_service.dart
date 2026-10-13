import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'firebase_utils.dart';
import 'analytics_models.dart';

/// Business service managing sales analytics, purchase costs, margins, and store expenses
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseUtils.firestore;

  /// Default margin estimate percentage (15%) when a product has no recorded purchase price yet.
  static const double defaultEstimatedMarginRatio = 0.85;

  /// Fetch comprehensive sales, profit, margin and expenses summary for a shop
  Future<AdvancedAnalyticsSummary> fetchAnalyticsSummary({
    required String shopId,
    required AnalyticsTimePeriod period,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    if (shopId.isEmpty) {
      return AdvancedAnalyticsSummary.empty(period: period);
    }

    try {
      final DateTime startDate = customStart ?? period.getStartDate();
      final DateTime endDate = customEnd ?? period.getEndDate();

      // 1. Fetch products for catalog lookup (to resolve purchase_price and category)
      final productCatalog = await _fetchProductCatalog(shopId);

      // 2. Fetch orders in the timeframe
      final ordersSnap = await _firestore
          .collection('orders')
          .where('shop_id', isEqualTo: shopId)
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      // 3. Fetch expenses in the timeframe
      final expensesSnap = await _firestore
          .collection('expenses')
          .where('shop_id', isEqualTo: shopId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final List<ShopExpense> expensesList = [];
      double totalExpenses = 0.0;
      for (var doc in expensesSnap.docs) {
        final exp = ShopExpense.fromFirestore(doc);
        if (exp.date.isBefore(endDate) || exp.date.isAtSameMomentAs(endDate)) {
          expensesList.add(exp);
          totalExpenses += exp.amount;
        }
      }

      // 4. Process Orders and Items
      int totalOrders = 0;
      int deliveredOrders = 0;
      int processingOrders = 0;
      int cancelledOrders = 0;
      int returnedOrders = 0;
      double totalRevenue = 0.0;
      double totalCOGS = 0.0;
      double totalDiscounts = 0.0;

      // Aggregators
      final Map<String, _ProductAccumulator> productMap = {};
      final Map<String, _CategoryAccumulator> categoryMap = {};
      final Map<String, _DayAccumulator> dayMap = {};
      final Set<String> productsMissingPurchase = {};

      // Initialize day slots for clean charts
      final int numDays = endDate.difference(startDate).inDays + 1;
      final int safeDays = numDays > 60 ? 30 : (numDays <= 0 ? 1 : numDays);
      for (int i = 0; i < safeDays; i++) {
        final d = startDate.add(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(d);
        final label = DateFormat('d MMM').format(d);
        dayMap[key] = _DayAccumulator(date: d, label: label);
      }

      for (var doc in ordersSnap.docs) {
        final data = doc.data();
        final createdAtTs = data['created_at'] as Timestamp?;
        final orderDate = createdAtTs?.toDate() ?? DateTime.now();

        if (orderDate.isAfter(endDate)) continue;

        totalOrders++;
        final status = (data['status']?.toString() ?? 'Pending').trim();

        if (status == 'Delivered' || status == 'Completed') {
          deliveredOrders++;
        } else if (status == 'Cancelled') {
          cancelledOrders++;
          continue; // Cancelled orders do not contribute to revenue or COGS
        } else if (status == 'Returned') {
          returnedOrders++;
          continue; // Returned orders do not contribute to net sales
        } else {
          processingOrders++;
        }

        // Active revenue-earning orders
        final bool isRevenueStatus = [
          'Delivered',
          'Completed',
          'Packed',
          'Ready',
          'Out for Delivery',
          'Confirmed',
          'Pending',
        ].contains(status);

        if (!isRevenueStatus) continue;

        final double orderAmount = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
        final double discount = (data['discount_amount'] as num?)?.toDouble() ?? 0.0;
        totalDiscounts += discount;

        // Daily bucket
        final dayKey = DateFormat('yyyy-MM-dd').format(orderDate);
        final dayBucket = dayMap[dayKey] ?? _DayAccumulator(
          date: orderDate,
          label: DateFormat('d MMM').format(orderDate),
        );
        dayBucket.orderCount++;
        dayBucket.revenue += orderAmount;
        dayMap[dayKey] = dayBucket;

        // Process line items
        final rawItems = data['items'];
        double orderCOGS = 0.0;

        if (rawItems is List) {
          for (var rawItem in rawItems) {
            if (rawItem is! Map) continue;
            final itemMap = Map<String, dynamic>.from(rawItem);

            final String pId = (itemMap['id'] ?? itemMap['productId'] ?? '').toString();
            final String pName = (itemMap['name'] ?? 'Item').toString();
            final double qty = (itemMap['quantity'] as num?)?.toDouble() ?? 1.0;
            final double sellPrice = (itemMap['price'] as num?)?.toDouble() ?? 0.0;
            final double lineRevenue = qty * sellPrice;

            // Lookup product details
            final catalogInfo = productCatalog[pId] ?? productCatalog[pName.toLowerCase()];
            final String category = (itemMap['category'] ?? catalogInfo?['category'] ?? 'General').toString();

            double purchaseCost = 0.0;
            bool isEstimated = false;

            // Check if purchase cost is recorded in item or catalog
            final dynamic rawCost = itemMap['purchase_price'] ??
                itemMap['cost_price'] ??
                catalogInfo?['purchase_price'] ??
                catalogInfo?['cost_price'];

            if (rawCost != null && (rawCost as num) > 0) {
              purchaseCost = (rawCost as num).toDouble();
            } else {
              // Intelligent Kirana fallback estimate (85% cost = 15% margin)
              purchaseCost = sellPrice * defaultEstimatedMarginRatio;
              isEstimated = true;
              productsMissingPurchase.add(pId.isNotEmpty ? pId : pName);
            }

            final double lineCOGS = qty * purchaseCost;
            orderCOGS += lineCOGS;

            // Product aggregation
            final String prodKey = pId.isNotEmpty ? pId : pName;
            final prodAcc = productMap[prodKey] ?? _ProductAccumulator(
              productId: prodKey,
              productName: pName,
              category: category,
              unitSellingPrice: sellPrice,
              unitPurchaseCost: purchaseCost,
              isPurchaseCostEstimated: isEstimated,
            );
            prodAcc.unitsSold += qty;
            prodAcc.totalRevenue += lineRevenue;
            prodAcc.totalCOGS += lineCOGS;
            productMap[prodKey] = prodAcc;

            // Category aggregation
            final catAcc = categoryMap[category] ?? _CategoryAccumulator(categoryName: category);
            catAcc.totalRevenue += lineRevenue;
            catAcc.totalCOGS += lineCOGS;
            catAcc.itemsSoldCount += qty;
            categoryMap[category] = catAcc;
          }
        }

        totalRevenue += orderAmount;
        totalCOGS += orderCOGS;
        dayBucket.cogs += orderCOGS;
        dayBucket.grossProfit += (orderAmount - orderCOGS);
      }

      // Compute core profit metrics
      final double grossProfit = totalRevenue - totalCOGS;
      final double grossMarginPercent = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0.0;
      final double netProfit = grossProfit - totalExpenses;
      final double netMarginPercent = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;
      final double aov = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

      // Transform products
      final List<ProductMarginMetric> productMetrics = productMap.values.map((p) {
        final double gp = p.totalRevenue - p.totalCOGS;
        final double mp = p.totalRevenue > 0 ? (gp / p.totalRevenue) * 100 : 0.0;
        return ProductMarginMetric(
          productId: p.productId,
          productName: p.productName,
          category: p.category,
          unitsSold: p.unitsSold,
          totalRevenue: p.totalRevenue,
          unitSellingPrice: p.unitSellingPrice,
          unitPurchaseCost: p.unitPurchaseCost,
          totalCOGS: p.totalCOGS,
          grossProfit: gp,
          marginPercent: mp,
          isPurchaseCostEstimated: p.isPurchaseCostEstimated,
        );
      }).toList();

      // Sort by units sold (descending)
      productMetrics.sort((a, b) => b.unitsSold.compareTo(a.unitsSold));
      final topProducts = productMetrics.take(10).toList();

      // Low margin products (high volume or dairy items with margin < 8%)
      final lowMarginProducts = productMetrics.where((p) => p.isLowMargin).toList();
      lowMarginProducts.sort((a, b) => a.marginPercent.compareTo(b.marginPercent));

      // Category metrics
      final List<CategoryMarginMetric> catMetrics = categoryMap.values.map((c) {
        final double gp = c.totalRevenue - c.totalCOGS;
        final double mp = c.totalRevenue > 0 ? (gp / c.totalRevenue) * 100 : 0.0;
        return CategoryMarginMetric(
          categoryName: c.categoryName,
          totalRevenue: c.totalRevenue,
          totalCOGS: c.totalCOGS,
          grossProfit: gp,
          marginPercent: mp,
          itemsSoldCount: c.itemsSoldCount,
        );
      }).toList();
      catMetrics.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

      // Daily trends
      final dailyTrends = dayMap.values.map((d) {
        return DailySalesPoint(
          date: d.date,
          label: d.label,
          revenue: d.revenue,
          cogs: d.cogs,
          grossProfit: d.grossProfit,
          orderCount: d.orderCount,
        );
      }).toList();
      dailyTrends.sort((a, b) => a.date.compareTo(b.date));

      return AdvancedAnalyticsSummary(
        timePeriod: period,
        startDate: startDate,
        endDate: endDate,
        totalRevenue: totalRevenue,
        totalCOGS: totalCOGS,
        grossProfit: grossProfit,
        grossMarginPercent: grossMarginPercent,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        netMarginPercent: netMarginPercent,
        totalOrders: totalOrders,
        deliveredOrders: deliveredOrders,
        processingOrders: processingOrders,
        cancelledOrders: cancelledOrders,
        returnedOrders: returnedOrders,
        averageOrderValue: aov,
        totalDiscounts: totalDiscounts,
        dailyTrends: dailyTrends,
        topProducts: topProducts,
        lowMarginProducts: lowMarginProducts,
        categoryMetrics: catMetrics,
        expenses: expensesList,
        productsMissingPurchasePrice: productsMissingPurchase.length,
      );
    } catch (e, stack) {
      debugPrint('Error in fetchAnalyticsSummary: $e\n$stack');
      return AdvancedAnalyticsSummary.empty(period: period);
    }
  }

  /// Helper to fetch product catalog map for cost lookup
  Future<Map<String, Map<String, dynamic>>> _fetchProductCatalog(String shopId) async {
    final Map<String, Map<String, dynamic>> catalog = {};
    try {
      final snap = await _firestore
          .collection('products')
          .where('shop_id', isEqualTo: shopId)
          .get();

      for (var doc in snap.docs) {
        final data = doc.data();
        catalog[doc.id] = data;
        final name = (data['name'] ?? '').toString().toLowerCase().trim();
        if (name.isNotEmpty) {
          catalog[name] = data;
        }
      }
    } catch (e) {
      debugPrint('Error fetching product catalog for analytics: $e');
    }
    return catalog;
  }

  /// Add a new operating / store expense
  Future<String> addExpense({
    required String shopId,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? notes,
  }) async {
    final docRef = _firestore.collection('expenses').doc();
    final expense = ShopExpense(
      id: docRef.id,
      shopId: shopId,
      title: title.trim(),
      amount: amount,
      category: category.trim(),
      date: date,
      notes: notes?.trim(),
      createdAt: DateTime.now(),
    );

    await docRef.set(expense.toMap());
    return docRef.id;
  }

  /// Delete a store expense
  Future<void> deleteExpense(String expenseId) async {
    await _firestore.collection('expenses').doc(expenseId).delete();
  }

  /// Stream expenses for a shop
  Stream<List<ShopExpense>> streamExpenses(String shopId) {
    return _firestore
        .collection('expenses')
        .where('shop_id', isEqualTo: shopId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ShopExpense.fromFirestore(d)).toList());
  }

  /// Update a product's purchase price to ensure accurate profit margins
  Future<void> updateProductPurchasePrice({
    required String productId,
    required double purchasePrice,
  }) async {
    await _firestore.collection('products').doc(productId).update({
      'purchase_price': purchasePrice,
      'cost_price': purchasePrice,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}

class _ProductAccumulator {
  final String productId;
  final String productName;
  final String category;
  double unitsSold = 0.0;
  double totalRevenue = 0.0;
  double totalCOGS = 0.0;
  double unitSellingPrice;
  double unitPurchaseCost;
  bool isPurchaseCostEstimated;

  _ProductAccumulator({
    required this.productId,
    required this.productName,
    required this.category,
    required this.unitSellingPrice,
    required this.unitPurchaseCost,
    required this.isPurchaseCostEstimated,
  });
}

class _CategoryAccumulator {
  final String categoryName;
  double totalRevenue = 0.0;
  double totalCOGS = 0.0;
  double itemsSoldCount = 0.0;

  _CategoryAccumulator({required this.categoryName});
}

class _DayAccumulator {
  final DateTime date;
  final String label;
  double revenue = 0.0;
  double cogs = 0.0;
  double grossProfit = 0.0;
  int orderCount = 0;

  _DayAccumulator({required this.date, required this.label});
}
