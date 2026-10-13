import 'package:cloud_firestore/cloud_firestore.dart';

/// Available time periods for analyzing sales & profit
enum AnalyticsTimePeriod {
  today,
  thisWeek,
  thisMonth,
  last30Days,
  allTime,
  custom,
}

extension AnalyticsTimePeriodExtension on AnalyticsTimePeriod {
  String get displayName {
    switch (this) {
      case AnalyticsTimePeriod.today:
        return 'Today';
      case AnalyticsTimePeriod.thisWeek:
        return 'Last 7 Days';
      case AnalyticsTimePeriod.thisMonth:
        return 'This Month';
      case AnalyticsTimePeriod.last30Days:
        return 'Last 30 Days';
      case AnalyticsTimePeriod.allTime:
        return 'All Time';
      case AnalyticsTimePeriod.custom:
        return 'Custom';
    }
  }

  DateTime getStartDate() {
    final now = DateTime.now();
    switch (this) {
      case AnalyticsTimePeriod.today:
        return DateTime(now.year, now.month, now.day);
      case AnalyticsTimePeriod.thisWeek:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      case AnalyticsTimePeriod.thisMonth:
        return DateTime(now.year, now.month, 1);
      case AnalyticsTimePeriod.last30Days:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      case AnalyticsTimePeriod.allTime:
        return DateTime(2020, 1, 1);
      case AnalyticsTimePeriod.custom:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    }
  }

  DateTime getEndDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }
}

/// Operating / Store Expense Model (Rent, Utilities, Salaries, Packaging, etc.)
class ShopExpense {
  final String id;
  final String shopId;
  final String title;
  final double amount;
  final String category; // 'Rent', 'Utilities', 'Salaries', 'Packaging', 'Transport', 'Other'
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  const ShopExpense({
    required this.id,
    required this.shopId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  factory ShopExpense.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ShopExpense(
      id: id,
      shopId: map['shop_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Store Expense',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category']?.toString() ?? 'Other',
      date: parseDate(map['date']),
      notes: map['notes']?.toString(),
      createdAt: parseDate(map['created_at']),
    );
  }

  factory ShopExpense.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ShopExpense.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap({bool forCache = false}) {
    return {
      'shop_id': shopId,
      'title': title,
      'amount': amount,
      'category': category,
      'date': forCache ? date.toIso8601String() : Timestamp.fromDate(date),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'created_at': forCache ? createdAt.toIso8601String() : Timestamp.fromDate(createdAt),
    };
  }

  ShopExpense copyWith({
    String? id,
    String? shopId,
    String? title,
    double? amount,
    String? category,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
  }) {
    return ShopExpense(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Metrics for an individual product sold
class ProductMarginMetric {
  final String productId;
  final String productName;
  final String category;
  final double unitsSold;
  final double totalRevenue;
  final double unitSellingPrice;
  final double unitPurchaseCost;
  final double totalCOGS; // Cost of Goods Sold = unitsSold * unitPurchaseCost
  final double grossProfit; // totalRevenue - totalCOGS
  final double marginPercent; // (grossProfit / totalRevenue) * 100
  final bool isPurchaseCostEstimated; // true if estimated fallback was used

  const ProductMarginMetric({
    required this.productId,
    required this.productName,
    required this.category,
    required this.unitsSold,
    required this.totalRevenue,
    required this.unitSellingPrice,
    required this.unitPurchaseCost,
    required this.totalCOGS,
    required this.grossProfit,
    required this.marginPercent,
    this.isPurchaseCostEstimated = false,
  });

  bool get isLowMargin => marginPercent < 8.0;
  bool get isHighMargin => marginPercent >= 20.0;
  bool get isLossMaking => grossProfit < 0;
}

/// Metrics aggregated per product category (e.g., Dairy, Staples, Snacks)
class CategoryMarginMetric {
  final String categoryName;
  final double totalRevenue;
  final double totalCOGS;
  final double grossProfit;
  final double marginPercent;
  final double itemsSoldCount;

  const CategoryMarginMetric({
    required this.categoryName,
    required this.totalRevenue,
    required this.totalCOGS,
    required this.grossProfit,
    required this.marginPercent,
    required this.itemsSoldCount,
  });

  bool get isLowMargin => marginPercent < 8.0;
}

/// Daily timeline point for sales & profit trend
class DailySalesPoint {
  final DateTime date;
  final String label; // e.g. "12 Oct"
  final double revenue;
  final double cogs;
  final double grossProfit;
  final int orderCount;

  const DailySalesPoint({
    required this.date,
    required this.label,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.orderCount,
  });

  double get marginPercent => revenue > 0 ? (grossProfit / revenue) * 100 : 0.0;
}

/// Comprehensive summary of sales, margins, and profit metrics
class AdvancedAnalyticsSummary {
  final AnalyticsTimePeriod timePeriod;
  final DateTime startDate;
  final DateTime endDate;

  // Financials
  final double totalRevenue;
  final double totalCOGS; // Total Cost of Goods Sold (Purchase costs)
  final double grossProfit; // totalRevenue - totalCOGS
  final double grossMarginPercent; // (grossProfit / totalRevenue) * 100
  final double totalExpenses; // Operating / Store expenses
  final double netProfit; // grossProfit - totalExpenses
  final double netMarginPercent; // (netProfit / totalRevenue) * 100

  // Orders
  final int totalOrders;
  final int deliveredOrders;
  final int processingOrders;
  final int cancelledOrders;
  final int returnedOrders;
  final double averageOrderValue;
  final double totalDiscounts;

  // Breakdowns
  final List<DailySalesPoint> dailyTrends;
  final List<ProductMarginMetric> topProducts;
  final List<ProductMarginMetric> lowMarginProducts;
  final List<CategoryMarginMetric> categoryMetrics;
  final List<ShopExpense> expenses;

  // Data Quality
  final int productsMissingPurchasePrice;

  const AdvancedAnalyticsSummary({
    required this.timePeriod,
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.totalCOGS,
    required this.grossProfit,
    required this.grossMarginPercent,
    required this.totalExpenses,
    required this.netProfit,
    required this.netMarginPercent,
    required this.totalOrders,
    required this.deliveredOrders,
    required this.processingOrders,
    required this.cancelledOrders,
    required this.returnedOrders,
    required this.averageOrderValue,
    required this.totalDiscounts,
    required this.dailyTrends,
    required this.topProducts,
    required this.lowMarginProducts,
    required this.categoryMetrics,
    required this.expenses,
    this.productsMissingPurchasePrice = 0,
  });

  bool get hasPurchasePriceGaps => productsMissingPurchasePrice > 0;

  static AdvancedAnalyticsSummary empty({AnalyticsTimePeriod period = AnalyticsTimePeriod.last30Days}) {
    return AdvancedAnalyticsSummary(
      timePeriod: period,
      startDate: period.getStartDate(),
      endDate: period.getEndDate(),
      totalRevenue: 0.0,
      totalCOGS: 0.0,
      grossProfit: 0.0,
      grossMarginPercent: 0.0,
      totalExpenses: 0.0,
      netProfit: 0.0,
      netMarginPercent: 0.0,
      totalOrders: 0,
      deliveredOrders: 0,
      processingOrders: 0,
      cancelledOrders: 0,
      returnedOrders: 0,
      averageOrderValue: 0.0,
      totalDiscounts: 0.0,
      dailyTrends: [],
      topProducts: [],
      lowMarginProducts: [],
      categoryMetrics: [],
      expenses: [],
      productsMissingPurchasePrice: 0,
    );
  }
}
