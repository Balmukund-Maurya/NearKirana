import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/app_theme.dart';
import 'modern_loader.dart';
import 'language_provider.dart';
import 'widgets/language_bottom_sheet.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'

  // Analytics Timeframe: 'today', 'week', 'month', 'all'
  String _analyticsTimeframe = 'all';

  // Live Orders Status Filter
  String _ordersFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _t(
    LanguageProvider lang,
    String en,
    String hi,
    String hinglish,
  ) {
    if (lang.isHindi) return hi;
    if (lang.isHinglish) return hinglish;
    return en;
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF5),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // NearKirana Brand Header (Clean White / Mint Theme)
              SliverToBoxAdapter(
                child: _buildNearKiranaHeader(lang),
              ),

              // KPI Metrics Overview Bar
              SliverToBoxAdapter(
                child: _buildMetricsOverview(lang),
              ),

              // Zepto / Blinkit Navigation TabBar
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primaryDark,
                    indicatorWeight: 3.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: AppColors.primaryDark,
                    unselectedLabelColor: const Color(0xFF64748B),
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.storefront_rounded, size: 19),
                        text: _t(lang, 'Stores & KYC', 'दुकानें व सत्यापन', 'Shops & KYC'),
                      ),
                      Tab(
                        icon: const Icon(Icons.analytics_rounded, size: 19),
                        text: _t(lang, 'Analytics & Revenue', 'एनालिटिक्स व कमाई', 'Analytics & GMV'),
                      ),
                      Tab(
                        icon: const Icon(Icons.receipt_long_rounded, size: 19),
                        text: _t(lang, 'Live Orders', 'लाइव ऑर्डर्स', 'Live Orders'),
                      ),
                      Tab(
                        icon: const Icon(Icons.tune_rounded, size: 19),
                        text: _t(lang, 'Governance & Config', 'प्लेटफ़ॉर्म नियंत्रण', 'Governance & Rules'),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildShopsManagementTab(lang),
              _buildPlatformAnalyticsTab(lang),
              _buildLiveOrdersTab(lang),
              _buildGovernanceTab(lang),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SUPER ADMIN TOP BAR
  // ==========================================
  Widget _buildNearKiranaHeader(LanguageProvider lang) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 0.8),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textDark,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _t(lang, 'Super Admin', 'सुपर एडमिन', 'Super Admin'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 8),
              // Live Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryDark.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryDark,
                        shape: BoxShape.circle,
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                          begin: const Offset(0.7, 0.7),
                          end: const Offset(1.3, 1.3),
                          duration: 800.ms,
                        ),
                    const SizedBox(width: 5),
                    Text(
                      _t(lang, 'LIVE', 'लाइव', 'LIVE'),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const LanguageTogglePill(),
        ],
      ),
    );
  }

  // ==========================================
  // METRICS OVERVIEW BAR
  // ==========================================
  Widget _buildMetricsOverview(LanguageProvider lang) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseUtils.firestore.collection('shops').snapshots(),
      builder: (context, shopsSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseUtils.firestore.collection('orders').snapshots(),
          builder: (context, ordersSnap) {
            final shops = shopsSnap.data?.docs ?? [];
            final orders = ordersSnap.data?.docs ?? [];

            final totalStores = shops.length;
            final approvedStores = shops.where((d) {
              final m = d.data() as Map<String, dynamic>;
              return (m['status'] == 'approved') || (m['is_active'] == true && m['status'] != 'rejected');
            }).length;

            final pendingStores = shops.where((d) {
              final m = d.data() as Map<String, dynamic>;
              return m['status'] == 'pending' || (m['is_active'] != true && m['status'] != 'rejected' && m['status'] != 'approved');
            }).length;

            final rejectedStores = shops.where((d) {
              final m = d.data() as Map<String, dynamic>;
              return m['status'] == 'rejected';
            }).length;

            double totalGmv = 0.0;
            for (final o in orders) {
              final data = o.data() as Map<String, dynamic>;
              final amt = data['grand_total'] ?? data['total_amount'] ?? data['total'] ?? 0;
              if (amt is num) {
                totalGmv += amt.toDouble();
              }
            }

            final totalOrders = orders.length;

            return Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMetricCard(
                      icon: Icons.storefront_rounded,
                      iconColor: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                      title: _t(lang, 'Total Stores', 'कुल दुकानें', 'Total Stores'),
                      value: '$totalStores',
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      icon: Icons.verified_rounded,
                      iconColor: AppColors.primaryDark,
                      bgColor: const Color(0xFFF0FDF4),
                      title: _t(lang, 'Active Stores', 'सक्रिय दुकानें', 'Active Stores'),
                      value: '$approvedStores',
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      icon: Icons.hourglass_top_rounded,
                      iconColor: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFFFBEB),
                      title: _t(lang, 'Pending KYC', 'सत्यापन लंबित', 'Pending KYC'),
                      value: '$pendingStores',
                      isAlert: pendingStores > 0,
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      icon: Icons.currency_rupee_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF5F3FF),
                      title: _t(lang, 'Platform GMV', 'कुल बिक्री', 'Total GMV'),
                      value: '₹${NumberFormat.compact().format(totalGmv)}',
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      icon: Icons.shopping_bag_rounded,
                      iconColor: const Color(0xFF0284C7),
                      bgColor: const Color(0xFFF0F9FF),
                      title: _t(lang, 'Total Orders', 'कुल ऑर्डर्स', 'Total Orders'),
                      value: '$totalOrders',
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      icon: Icons.block_rounded,
                      iconColor: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                      title: _t(lang, 'Suspended', 'निलम्बित', 'Suspended'),
                      value: '$rejectedStores',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String value,
    bool isAlert = false,
  }) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert ? const Color(0xFFF59E0B) : iconColor.withValues(alpha: 0.25),
          width: isAlert ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              if (isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ACTION',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMid,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: SHOES & KYC MANAGEMENT
  // ==========================================
  Widget _buildShopsManagementTab(LanguageProvider lang) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseUtils.firestore
          .collection('shops')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: ModernLoader(color: AppColors.primaryDark),
          );
        }

        final docs = snapshot.data!.docs;

        // Apply search and filter
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['shop_name'] ?? '').toString().toLowerCase();
          final owner = (data['owner_name'] ?? '').toString().toLowerCase();
          final mobile = (data['mobile'] ?? '').toString().toLowerCase();
          final gstin = (data['gstin_fssai'] ?? '').toString().toLowerCase();
          final status = (data['status'] ?? 'pending').toString().toLowerCase();
          final isActive = data['is_active'] ?? false;

          // Status filter
          if (_selectedStatusFilter == 'pending') {
            if (status != 'pending' && (isActive == true || status == 'rejected')) {
              return false;
            }
          } else if (_selectedStatusFilter == 'approved') {
            if (status != 'approved' && !isActive) return false;
          } else if (_selectedStatusFilter == 'rejected') {
            if (status != 'rejected') return false;
          }

          // Search query
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            return name.contains(q) ||
                owner.contains(q) ||
                mobile.contains(q) ||
                gstin.contains(q);
          }

          return true;
        }).toList();

        return Column(
          children: [
            // Search & Status Filter Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  // Search TextField
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300, width: 0.8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: GoogleFonts.outfit(fontSize: 13.5, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: _t(
                          lang,
                          'Search by store, owner, phone or GSTIN...',
                          'दुकान, मालिक, फोन या GSTIN से खोजें...',
                          'Store, owner, phone ya GSTIN se search karein...',
                        ),
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: Colors.grey.shade500,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          lang: lang,
                          label: _t(lang, 'All', 'सभी', 'All'),
                          filterKey: 'all',
                          count: docs.length,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          lang: lang,
                          label: _t(lang, 'Pending', 'सत्यापन लंबित', 'Pending'),
                          filterKey: 'pending',
                          count: docs.where((d) {
                            final m = d.data() as Map<String, dynamic>;
                            return m['status'] == 'pending' || (m['is_active'] != true && m['status'] != 'rejected' && m['status'] != 'approved');
                          }).length,
                          highlightColor: const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          lang: lang,
                          label: _t(lang, 'Approved', 'स्वीकृत', 'Approved'),
                          filterKey: 'approved',
                          count: docs.where((d) {
                            final m = d.data() as Map<String, dynamic>;
                            return m['status'] == 'approved' || m['is_active'] == true;
                          }).length,
                          highlightColor: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          lang: lang,
                          label: _t(lang, 'Suspended', 'निलम्बित', 'Suspended'),
                          filterKey: 'rejected',
                          count: docs.where((d) {
                            final m = d.data() as Map<String, dynamic>;
                            return m['status'] == 'rejected';
                          }).length,
                          highlightColor: const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Store Cards List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F5F7),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              size: 32,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _t(
                              lang,
                              'No stores found for this filter',
                              'इस फ़िल्टर के लिए कोई दुकान नहीं मिली',
                              'Koi store nahi mila is filter ke liye',
                            ),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMid,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _NearKiranaStoreCard(
                          docId: doc.id,
                          data: data,
                          lang: lang,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip({
    required LanguageProvider lang,
    required String label,
    required String filterKey,
    required int count,
    Color? highlightColor,
  }) {
    final isSelected = _selectedStatusFilter == filterKey;
    final color = highlightColor ?? AppColors.primaryDark;

    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: ADVANCED ANALYTICS & REVENUE
  // ==========================================
  Widget _buildPlatformAnalyticsTab(LanguageProvider lang) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseUtils.firestore.collection('orders').snapshots(),
      builder: (context, ordersSnap) {
        if (!ordersSnap.hasData) {
          return const Center(
            child: ModernLoader(color: AppColors.primaryDark),
          );
        }

        final allOrders = ordersSnap.data!.docs;

        // Apply Timeframe Filter
        final now = DateTime.now();
        final orders = allOrders.where((doc) {
          if (_analyticsTimeframe == 'all') return true;
          final d = doc.data() as Map<String, dynamic>;
          final dynamic ts = d['created_at'];
          DateTime? orderDate;
          if (ts is Timestamp) {
            orderDate = ts.toDate();
          } else if (ts is String) {
            orderDate = DateTime.tryParse(ts);
          }
          if (orderDate == null) return true;

          if (_analyticsTimeframe == 'today') {
            return orderDate.year == now.year &&
                orderDate.month == now.month &&
                orderDate.day == now.day;
          } else if (_analyticsTimeframe == 'week') {
            return now.difference(orderDate).inDays <= 7;
          } else if (_analyticsTimeframe == 'month') {
            return now.difference(orderDate).inDays <= 30;
          }
          return true;
        }).toList();

        double totalGmv = 0.0;
        int deliveredCount = 0;
        int activeCount = 0;
        int cancelledCount = 0;
        double upiTotal = 0.0;
        int upiCount = 0;
        double codTotal = 0.0;
        int codCount = 0;
        double khataTotal = 0.0;
        int khataCount = 0;

        final Set<String> uniqueCustomers = {};
        final Map<String, int> customerOrderCounts = {};
        final Map<String, int> storeOrdersMap = {};
        final Map<String, double> storeGmvMap = {};

        for (final o in orders) {
          final data = o.data() as Map<String, dynamic>;
          final amt = data['grand_total'] ?? data['total_amount'] ?? data['total'] ?? 0;
          final numVal = (amt is num) ? amt.toDouble() : 0.0;
          totalGmv += numVal;

          final status = (data['status'] ?? '').toString().toLowerCase();
          if (status == 'delivered' || status == 'completed') {
            deliveredCount++;
          } else if (status == 'cancelled' || status == 'rejected') {
            cancelledCount++;
          } else {
            activeCount++;
          }

          // Payment method breakdown
          final pMethod = (data['payment_method'] ?? 'cash on delivery').toString().toLowerCase();
          if (pMethod.contains('upi') || pMethod.contains('online') || pMethod.contains('razorpay')) {
            upiTotal += numVal;
            upiCount++;
          } else if (pMethod.contains('khata') || pMethod.contains('udhaar')) {
            khataTotal += numVal;
            khataCount++;
          } else {
            codTotal += numVal;
            codCount++;
          }

          // Customer Tracking
          final phone = (data['phone_number'] ?? data['customer_phone'] ?? '').toString();
          if (phone.isNotEmpty) {
            uniqueCustomers.add(phone);
            customerOrderCounts[phone] = (customerOrderCounts[phone] ?? 0) + 1;
          }

          // Store Ranking
          final storeId = (data['shop_id'] ?? 'Other').toString();
          storeOrdersMap[storeId] = (storeOrdersMap[storeId] ?? 0) + 1;
          storeGmvMap[storeId] = (storeGmvMap[storeId] ?? 0.0) + numVal;
        }

        final avgOrderVal = orders.isNotEmpty ? (totalGmv / orders.length) : 0.0;
        final repeatCustomers = customerOrderCounts.values.where((c) => c > 1).length;
        final repeatRate = uniqueCustomers.isNotEmpty
            ? ((repeatCustomers / uniqueCustomers.length) * 100).toStringAsFixed(1)
            : '0.0';

        // Platform Commission Estimation (Default 5% of GMV)
        final estPlatformCommission = totalGmv * 0.05;
        final estStorePayouts = max(0.0, totalGmv - estPlatformCommission);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeframe Filter Buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTimeframePill('all', _t(lang, 'All Time', 'कुल समय', 'All Time')),
                    const SizedBox(width: 8),
                    _buildTimeframePill('today', _t(lang, 'Today', 'आज', 'Today')),
                    const SizedBox(width: 8),
                    _buildTimeframePill('week', _t(lang, 'This Week (7D)', 'इस सप्ताह', 'This Week')),
                    const SizedBox(width: 8),
                    _buildTimeframePill('month', _t(lang, 'This Month (30D)', 'इस महीने', 'This Month')),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // High-Impact GMV & Commission Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22511C), AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _t(lang, 'PLATFORM REVENUE (GMV)', 'प्लेटफ़ॉर्म कुल बिक्री (GMV)', 'PLATFORM TOTAL GMV'),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: const Color(0xFFC8E6C9),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt_rounded, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _t(lang, 'Live Analytics', 'लाइव एनालिटिक्स', 'Live Analytics'),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '₹${NumberFormat('#,##,###.##').format(totalGmv)}',
                      style: GoogleFonts.outfit(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withValues(alpha: 0.25), height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(lang, 'Est. Comm. (5%)', 'कमीशन (5%)', 'Est. Comm. (5%)'),
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: const Color(0xFFC8E6C9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${NumberFormat('#,##,###').format(estPlatformCommission)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFDE68A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.25)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(lang, 'Store Payouts', 'दुकानदार भुगतान', 'Store Payouts'),
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: const Color(0xFFC8E6C9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${NumberFormat('#,##,###').format(estStorePayouts)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.25)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(lang, 'Avg Order', 'औसत ऑर्डर', 'Avg Order'),
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: const Color(0xFFC8E6C9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${avgOrderVal.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Order Status Funnel
              Text(
                _t(lang, 'Order Lifecycle Status', 'ऑर्डर स्थिति विश्लेषण', 'Order Lifecycle Funnel'),
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildStatusCard(
                      icon: Icons.check_circle_rounded,
                      color: AppColors.primaryDark,
                      title: _t(lang, 'Delivered', 'डिलीवर हुआ', 'Delivered'),
                      count: deliveredCount,
                      total: orders.length,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatusCard(
                      icon: Icons.delivery_dining_rounded,
                      color: const Color(0xFF0284C7),
                      title: _t(lang, 'Active/Transit', 'प्रक्रिया में', 'Active/Transit'),
                      count: activeCount,
                      total: orders.length,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatusCard(
                      icon: Icons.cancel_rounded,
                      color: const Color(0xFFDC2626),
                      title: _t(lang, 'Cancelled', 'रद्द ऑर्डर्स', 'Cancelled'),
                      count: cancelledCount,
                      total: orders.length,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Payment Method Distribution Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(lang, 'Payment Methods Breakdown', 'भुगतान माध्यम विश्लेषण', 'Payment Methods Split'),
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildPaymentMethodRow(
                      icon: Icons.qr_code_scanner_rounded,
                      name: 'UPI / Online Gateway',
                      amount: upiTotal,
                      count: upiCount,
                      totalGmv: totalGmv,
                      color: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentMethodRow(
                      icon: Icons.payments_rounded,
                      name: 'Cash on Delivery (COD)',
                      amount: codTotal,
                      count: codCount,
                      totalGmv: totalGmv,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentMethodRow(
                      icon: Icons.menu_book_rounded,
                      name: 'Kirana Khata (Udhaar)',
                      amount: khataTotal,
                      count: khataCount,
                      totalGmv: totalGmv,
                      color: const Color(0xFFD97706),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Customer Analytics Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(lang, 'Total Unique Customers', 'कुल ग्राहक संख्या', 'Unique Customers'),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.textMid,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${uniqueCustomers.length}',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(lang, 'Repeat Customer Rate', 'दोहराव ग्राहक दर', 'Repeat Order Rate'),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.textMid,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$repeatRate%',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Top Performing Stores Leaderboard
              Text(
                _t(lang, 'Top Kirana Stores by Orders', 'सर्वश्रेष्ठ किराना स्टोर्स', 'Top Stores by Orders'),
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseUtils.firestore.collection('shops').snapshots(),
                builder: (context, shopsSnap) {
                  final shopDocs = shopsSnap.data?.docs ?? [];
                  final Map<String, String> shopNameMap = {};
                  for (final s in shopDocs) {
                    final d = s.data() as Map<String, dynamic>;
                    shopNameMap[s.id] = (d['shop_name'] ?? s.id).toString();
                  }

                  final sortedStores = storeOrdersMap.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  if (sortedStores.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text(
                          _t(lang, 'No store orders recorded in this timeframe', 'इस अवधि में कोई ऑर्डर नहीं है', 'No store orders in this timeframe'),
                          style: GoogleFonts.outfit(
                            color: AppColors.textMid,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedStores.take(5).length,
                      separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final entry = sortedStores[index];
                        final sName = shopNameMap[entry.key] ?? entry.key;
                        final ordersCount = entry.value;
                        final gmv = storeGmvMap[entry.key] ?? 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFF3F5F7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '#${index + 1}',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: index == 0
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    Text(
                                      '$ordersCount ${_t(lang, 'Orders', 'ऑर्डर्स', 'Orders')}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        color: AppColors.textMid,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${gmv.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeframePill(String key, String label) {
    final isSelected = _analyticsTimeframe == key;
    return InkWell(
      onTap: () => setState(() => _analyticsTimeframe = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodRow({
    required IconData icon,
    required String name,
    required double amount,
    required int count,
    required double totalGmv,
    required Color color,
  }) {
    final pct = totalGmv > 0 ? (amount / totalGmv) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
            ),
            Text(
              '₹${amount.toStringAsFixed(0)} ($count)',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String title,
    required int count,
    required int total,
  }) {
    final pct = total > 0 ? ((count / total) * 100).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMid,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? (count / total) : 0,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$pct%',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: REAL-TIME LIVE ORDERS MONITOR
  // ==========================================
  Widget _buildLiveOrdersTab(LanguageProvider lang) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseUtils.firestore
          .collection('orders')
          .orderBy('created_at', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, ordersSnap) {
        if (!ordersSnap.hasData) {
          return const Center(
            child: ModernLoader(color: AppColors.primaryDark),
          );
        }

        final allOrders = ordersSnap.data!.docs;

        final filteredOrders = allOrders.where((doc) {
          if (_ordersFilter == 'all') return true;
          final d = doc.data() as Map<String, dynamic>;
          final status = (d['status'] ?? 'pending').toString().toLowerCase();
          if (_ordersFilter == 'active') {
            return status != 'delivered' && status != 'cancelled';
          } else if (_ordersFilter == 'delivered') {
            return status == 'delivered' || status == 'completed';
          } else if (_ordersFilter == 'cancelled') {
            return status == 'cancelled';
          }
          return true;
        }).toList();

        return Column(
          children: [
            // Filter Pills Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildOrderFilterPill('all', _t(lang, 'All Orders', 'सभी ऑर्डर्स', 'All Orders'), allOrders.length),
                    const SizedBox(width: 8),
                    _buildOrderFilterPill('active', _t(lang, 'Active/In-Progress', 'चल रहे ऑर्डर्स', 'Active Orders'),
                        allOrders.where((d) => (d.data() as Map<String, dynamic>)['status'] != 'delivered' && (d.data() as Map<String, dynamic>)['status'] != 'cancelled').length),
                    const SizedBox(width: 8),
                    _buildOrderFilterPill('delivered', _t(lang, 'Delivered', 'डिलीवर हुए', 'Delivered'),
                        allOrders.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'delivered').length),
                    const SizedBox(width: 8),
                    _buildOrderFilterPill('cancelled', _t(lang, 'Cancelled', 'रद्द हुए', 'Cancelled'),
                        allOrders.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'cancelled').length),
                  ],
                ),
              ),
            ),

            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Text(
                        _t(lang, 'No orders matching filter', 'कोई ऑर्डर नहीं मिला', 'Koi orders nahi mile'),
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMid),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final doc = filteredOrders[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildLiveOrderCard(doc.id, data, lang);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderFilterPill(String key, String label, int count) {
    final isSelected = _ordersFilter == key;
    return InkWell(
      onTap: () => setState(() => _ordersFilter = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveOrderCard(String orderId, Map<String, dynamic> data, LanguageProvider lang) {
    final cName = (data['customer_name'] ?? 'Customer').toString();
    final cPhone = (data['phone_number'] ?? data['customer_phone'] ?? '').toString();
    final shopId = (data['shop_id'] ?? '').toString();
    final amount = (data['total_amount'] ?? data['grand_total'] ?? 0.0);
    final status = (data['status'] ?? 'pending').toString();
    final pMethod = (data['payment_method'] ?? 'COD').toString();
    final dPin = (data['delivery_pin'] ?? '').toString();
    final items = (data['items'] as List<dynamic>?) ?? [];

    Color statusColor = const Color(0xFFD97706);
    if (status.toLowerCase() == 'delivered') statusColor = AppColors.primaryDark;
    if (status.toLowerCase() == 'cancelled') statusColor = const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${orderId.substring(max(0, orderId.length - 8))}',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 14, color: AppColors.textMid),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$cName ($cPhone)',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${items.length} items • $pMethod${shopId.isNotEmpty ? ' • Store: $shopId' : ''}',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMid),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${amount is num ? amount.toStringAsFixed(0) : amount}',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
              ),
            ],
          ),
          if (dPin.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Delivery PIN: $dPin',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.indigo),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: PLATFORM GOVERNANCE & LIVE CONFIG
  // ==========================================
  Widget _buildGovernanceTab(LanguageProvider lang) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseUtils.firestore.collection('settings').doc('app_config').snapshots(),
      builder: (context, configSnap) {
        final configData = configSnap.data?.data() as Map<String, dynamic>? ?? {};

        final double minOrder = (configData['minimum_order'] as num?)?.toDouble() ?? 50.0;
        final double deliveryFee = (configData['delivery_fee'] as num?)?.toDouble() ?? 20.0;
        final double freeThreshold = (configData['free_delivery_threshold'] as num?)?.toDouble() ?? 500.0;
        final double platformCommission = (configData['platform_commission_percent'] as num?)?.toDouble() ?? 5.0;
        final bool isStoreOpen = configData['is_store_open'] != false;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Global Platform Emergency Controls Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isStoreOpen ? Colors.white : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isStoreOpen ? Colors.grey.shade200 : const Color(0xFFFCA5A5),
                    width: isStoreOpen ? 1 : 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isStoreOpen ? AppColors.primaryDark : const Color(0xFFDC2626)).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isStoreOpen ? Icons.storefront_rounded : Icons.pause_circle_rounded,
                                color: isStoreOpen ? AppColors.primaryDark : const Color(0xFFDC2626),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t(lang, 'Platform Live State', 'प्लेटफ़ॉर्म स्थिति', 'Platform Network Status'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  isStoreOpen
                                      ? _t(lang, 'Platform Active & Accepting Orders', 'प्लेटफ़ॉर्म चालू है', 'Network Online & Accepting Orders')
                                      : _t(lang, 'Emergency Pause Active (Maintenance)', 'प्लेटफ़ॉर्म आपातकालीन रोका गया है', 'Emergency Platform Freeze Active'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: isStoreOpen ? AppColors.primaryDark : const Color(0xFFDC2626),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: isStoreOpen,
                          activeTrackColor: AppColors.primaryDark,
                          onChanged: (val) async {
                            await FirebaseUtils.firestore.collection('settings').doc('app_config').set({
                              'is_store_open': val,
                              'updated_at': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Global Pricing & Commission Manager Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune_rounded, color: Color(0xFF7C3AED), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _t(lang, 'Global Fees & Commission Engine', 'कमीशन व डिलीवरी शुल्क नियंत्रण', 'Fees & Commission Settings'),
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildConfigItemRow(
                      label: _t(lang, 'Default Platform Commission', 'डिफ़ॉल्ट कमीशन %', 'Default Platform Commission'),
                      value: '$platformCommission%',
                      onEdit: () => _editConfigField(
                        title: 'Platform Commission %',
                        currentValue: platformCommission.toString(),
                        field: 'platform_commission_percent',
                        isNumeric: true,
                      ),
                    ),
                    Divider(height: 20, color: Colors.grey.shade100),
                    _buildConfigItemRow(
                      label: _t(lang, 'Standard Delivery Fee', 'मानक डिलीवरी शुल्क', 'Standard Delivery Fee'),
                      value: '₹$deliveryFee',
                      onEdit: () => _editConfigField(
                        title: 'Delivery Fee (₹)',
                        currentValue: deliveryFee.toString(),
                        field: 'delivery_fee',
                        isNumeric: true,
                      ),
                    ),
                    Divider(height: 20, color: Colors.grey.shade100),
                    _buildConfigItemRow(
                      label: _t(lang, 'Free Delivery Threshold', 'निःशुल्क डिलीवरी सीमा', 'Free Delivery Threshold'),
                      value: '₹$freeThreshold',
                      onEdit: () => _editConfigField(
                        title: 'Free Delivery Threshold (₹)',
                        currentValue: freeThreshold.toString(),
                        field: 'free_delivery_threshold',
                        isNumeric: true,
                      ),
                    ),
                    Divider(height: 20, color: Colors.grey.shade100),
                    _buildConfigItemRow(
                      label: _t(lang, 'Minimum Order Value', 'न्यूनतम ऑर्डर मूल्य', 'Minimum Order Value'),
                      value: '₹$minOrder',
                      onEdit: () => _editConfigField(
                        title: 'Minimum Order Value (₹)',
                        currentValue: minOrder.toString(),
                        field: 'minimum_order',
                        isNumeric: true,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Broadcast Notice Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: AppColors.primaryDark,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(lang, 'Platform Broadcast Announcement', 'प्लेटफ़ॉर्म घोषणा अलर्ट', 'Platform Broadcast'),
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                _t(
                                  lang,
                                  'Send instant banner alert to all stores & customers',
                                  'सभी दुकानों और ग्राहकों को तत्काल अलर्ट भेजें',
                                  'Send instant alert to all partner stores',
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.textMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_alert_rounded, size: 18),
                      label: Text(
                        _t(lang, 'Create Broadcast Alert', 'घोषणा अलर्ट बनाएं', 'Create Broadcast Alert'),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _showBroadcastDialog(lang),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Super Admin Security Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: AppColors.primaryDark, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(lang, 'Super Admin Session Active', 'सुपर एडमिन सत्र सक्रिय', 'Super Admin Session Active'),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            'Full Privileges: Stores verification, fees overrides, emergency pause',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfigItemRow({
    required String label,
    required String value,
    required VoidCallback onEdit,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark),
        ),
        InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit_rounded, size: 13, color: AppColors.textMid),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editConfigField({
    required String title,
    required String currentValue,
    required String field,
    bool isNumeric = true,
  }) async {
    final ctrl = TextEditingController(text: currentValue);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (res != null && res.isNotEmpty) {
      final dynamic parsedVal = isNumeric ? (num.tryParse(res) ?? res) : res;
      await FirebaseUtils.firestore.collection('settings').doc('app_config').set({
        field: parsedVal,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Global config updated successfully!'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    }
  }

  void _showBroadcastDialog(LanguageProvider lang) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Text(
              _t(lang, 'Broadcast Alert', 'घोषणा अलर्ट', 'Broadcast Alert'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                hintText: _t(lang, 'Alert Title (e.g. Monsoon Demand)', 'अलर्ट शीर्षक', 'Alert Title'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: messageCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _t(lang, 'Message to all store partners...', 'सभी दुकानों के लिए संदेश...', 'Message to all stores...'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _t(lang, 'Cancel', 'रद्द करें', 'Cancel'),
              style: GoogleFonts.outfit(),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
            onPressed: () async {
              final tText = titleCtrl.text.trim();
              final mText = messageCtrl.text.trim();
              if (mText.isNotEmpty) {
                Navigator.pop(ctx);
                await FirebaseUtils.firestore.collection('platform_announcements').add({
                  'title': tText.isNotEmpty ? tText : 'Super Admin Announcement',
                  'message': mText,
                  'created_at': FieldValue.serverTimestamp(),
                  'is_active': true,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_t(lang, 'Broadcast sent successfully!', 'घोषणा सफलतापूर्वक भेजी गई!', 'Broadcast bhej diya gaya!')),
                      backgroundColor: AppColors.primaryDark,
                    ),
                  );
                }
              }
            },
            child: Text(
              _t(lang, 'Send Broadcast', 'भेजें', 'Send Alert'),
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return true;
  }
}

// ==========================================
// NEARKIRANA BRAND STORE CARD WITH ENHANCED CONTROLS
// ==========================================
class _NearKiranaStoreCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final LanguageProvider lang;

  const _NearKiranaStoreCard({
    required this.docId,
    required this.data,
    required this.lang,
  });

  @override
  State<_NearKiranaStoreCard> createState() => _NearKiranaStoreCardState();
}

class _NearKiranaStoreCardState extends State<_NearKiranaStoreCard> {
  bool _expanded = false;

  String _t(String en, String hi, String hinglish) {
    if (widget.lang.isHindi) return hi;
    if (widget.lang.isHinglish) return hinglish;
    return en;
  }

  Future<void> _approve() async {
    try {
      await FirebaseUtils.firestore.collection('shops').doc(widget.docId).update({
        'is_active': true,
        'status': 'approved',
        'rejection_reason': FieldValue.delete(),
        'approved_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('Store approved and made live!', 'दुकान स्वीकृत और लाइव हो गई!', 'Store approve aur live kar diya gaya!')),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleActive(bool currentActive) async {
    final nextState = !currentActive;
    await FirebaseUtils.firestore.collection('shops').doc(widget.docId).update({
      'is_active': nextState,
      'updated_at': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextState
                ? _t('Store activated and live', 'दुकान सक्रिय की गई', 'Store active kar diya gaya')
                : _t('Store paused / deactivated', 'दुकान निष्क्रिय की गई', 'Store pause kar diya gaya'),
          ),
          backgroundColor: nextState ? AppColors.primaryDark : Colors.orange.shade800,
        ),
      );
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              _t('Reject Store KYC?', 'दुकान अस्वीकार करें?', 'Store Reject karein?'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                'Specify reason for rejection (owner will see this to fix KYC):',
                'अस्वीकृति का कारण लिखें (दुकानदार इसे सुधारने के लिए देखेगा):',
                'Rejection ka reason likhein (owner ko dikhega KYC theek karne ke liye):',
              ),
              style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: GoogleFonts.outfit(fontSize: 13),
              decoration: InputDecoration(
                hintText: _t('e.g. Document blurry or invalid GSTIN', 'जैसे: धुंधला दस्तावेज़ या अमान्य GSTIN', 'e.g. Blurry doc ya GSTIN invalid'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Cancel', 'रद्द करें', 'Cancel'), style: GoogleFonts.outfit()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(
              _t('Confirm Reject', 'अस्वीकार करें', 'Reject'),
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    await FirebaseUtils.firestore.collection('shops').doc(widget.docId).update({
      'is_active': false,
      'status': 'rejected',
      'rejection_reason': reason,
      'rejected_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Store marked as rejected', 'दुकान अस्वीकृत की गई', 'Store reject ho gaya')),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _setStoreCommission() async {
    final currentComm = (widget.data['commission_percent'] as num?)?.toDouble() ?? 5.0;
    final ctrl = TextEditingController(text: currentComm.toString());

    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(_t('Custom Store Commission %', 'दुकान कमीशन % सेट करें', 'Set Store Commission %'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: '%', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (res != null && res.isNotEmpty) {
      final parsed = double.tryParse(res) ?? currentComm;
      await FirebaseUtils.firestore.collection('shops').doc(widget.docId).update({
        'commission_percent': parsed,
        'updated_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Store commission updated to $parsed%'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: cleanPhone));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Phone number copied: $cleanPhone')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: cleanPhone));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Phone number copied: $cleanPhone')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final effectivePhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final uri = Uri.parse('https://wa.me/$effectivePhone');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: cleanPhone));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WhatsApp error. Phone copied: $cleanPhone')),
        );
      }
    }
  }

  Widget _buildDecodedImage(String? base64Str, {required double width, required double height, BoxFit fit = BoxFit.cover}) {
    if (base64Str == null || base64Str.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFF3F5F7),
        child: const Icon(Icons.storefront_rounded, color: Color(0xFF94A3B8), size: 28),
      );
    }
    try {
      final bytes = base64Decode(base64Str);
      return Image.memory(bytes, width: width, height: height, fit: fit);
    } catch (_) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFF3F5F7),
        child: const Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 28),
      );
    }
  }

  void _showFullImageDialog(String? base64Str, String title) {
    if (base64Str == null || base64Str.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.primaryDark,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              child: _buildDecodedImage(base64Str, width: double.infinity, height: 350, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final shopName = (d['shop_name'] ?? 'NearKirana Store').toString();
    final ownerName = (d['owner_name'] ?? 'N/A').toString();
    final mobile = (d['mobile'] ?? '').toString();
    final address = (d['address'] ?? 'N/A').toString();
    final gstin = (d['gstin_fssai'] ?? '').toString();
    final shopImage64 = d['shop_image_base64'] as String?;
    final docImage64 = d['shop_doc_image_base64'] as String?;
    final rejectionReason = d['rejection_reason'] as String?;
    final isActive = d['is_active'] ?? false;
    final status = (d['status'] ?? 'pending').toString().toLowerCase();
    final commissionPercent = (d['commission_percent'] as num?)?.toDouble() ?? 5.0;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (status == 'approved' || (isActive && status != 'rejected')) {
      statusColor = AppColors.primaryDark;
      statusIcon = Icons.verified_rounded;
      statusLabel = _t('Approved & Live', 'स्वीकृत व लाइव', 'Approved & Live');
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFDC2626);
      statusIcon = Icons.cancel_rounded;
      statusLabel = _t('Suspended', 'निलम्बित', 'Suspended');
    } else {
      statusColor = const Color(0xFFD97706);
      statusIcon = Icons.hourglass_top_rounded;
      statusLabel = _t('Pending KYC', 'सत्यापन लंबित', 'Pending Review');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _buildDecodedImage(shopImage64, width: 60, height: 60),
                  ),
                  const SizedBox(width: 12),

                  // Store & Owner Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMid),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                ownerName,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.textMid,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Status Badge Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 13, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Active/Pause Switch & Expand chevron
                  Column(
                    children: [
                      Switch.adaptive(
                        value: isActive,
                        activeTrackColor: AppColors.primaryDark,
                        onChanged: (val) => _toggleActive(isActive),
                      ),
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMid,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Quick Action Bar: Call, WhatsApp, GSTIN, Commission
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                if (mobile.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _callPhone(mobile),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F5F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 13, color: AppColors.primaryDark),
                          const SizedBox(width: 4),
                          Text(
                            mobile,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _openWhatsApp(mobile),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.chat_bubble_rounded, size: 13, color: AppColors.primaryDark),
                          SizedBox(width: 4),
                          Text(
                            'WhatsApp',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Commission Badge Pill
                InkWell(
                  onTap: _setStoreCommission,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.percent_rounded, size: 11, color: Color(0xFFB45309)),
                        const SizedBox(width: 3),
                        Text(
                          '$commissionPercent%',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (gstin.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      'GSTIN',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Expanded Content
          if (_expanded) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMid),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // GSTIN / FSSAI number
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.textMid),
                      const SizedBox(width: 6),
                      Text(
                        'GSTIN/FSSAI: ',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textMid,
                        ),
                      ),
                      Text(
                        gstin.isNotEmpty ? gstin : _t('Not provided', 'नहीं दिया गया', 'Not provided'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: gstin.isNotEmpty ? AppColors.primaryDark : AppColors.textMid,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // KYC Verification Document Preview
                  Text(
                    _t('KYC / Verification Document:', 'केवाईसी / सत्यापन दस्तावेज़:', 'KYC Verification Document:'),
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (docImage64 != null && docImage64.isNotEmpty)
                    InkWell(
                      onTap: () => _showFullImageDialog(docImage64, 'KYC Document'),
                      borderRadius: BorderRadius.circular(14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            _buildDecodedImage(docImage64, width: double.infinity, height: 180, fit: BoxFit.contain),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      _t('Tap to expand', 'बड़ा करके देखें', 'Tap to zoom'),
                                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text(
                          gstin.isNotEmpty
                              ? _t('GSTIN registered — document upload optional', 'GSTIN दर्ज है — दस्तावेज़ वैकल्पिक है', 'GSTIN registered — document upload optional')
                              : _t('No KYC document uploaded', 'कोई दस्तावेज़ अपलोड नहीं किया गया', 'Koi KYC document nahi mila'),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textMid,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Store Live Front Photo Preview
                  Text(
                    _t('Store Live Front Photo:', 'दुकान की लाइव फोटो:', 'Store Live Front Photo:'),
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (shopImage64 != null && shopImage64.isNotEmpty)
                    InkWell(
                      onTap: () => _showFullImageDialog(shopImage64, 'Store Front Photo'),
                      borderRadius: BorderRadius.circular(14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            _buildDecodedImage(shopImage64, width: double.infinity, height: 180, fit: BoxFit.cover),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      _t('Tap to expand', 'बड़ा करके देखें', 'Tap to zoom'),
                                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Rejection reason banner if rejected
                  if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_t('Rejection Reason: ', 'अस्वीकृति कारण: ', 'Reject Reason: ')}$rejectionReason',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Approval, Rejection & Commission Action Buttons
                  Row(
                    children: [
                      // Reject Button
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 18),
                          label: Text(
                            _t('Reject', 'अस्वीकार करें', 'Reject'),
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFDC2626),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: status == 'rejected' ? null : _reject,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Approve Button
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                          label: Text(
                            _t('Approve Store', 'स्वीकृत करें', 'Approve Store'),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: (status == 'approved' && isActive) ? null : _approve,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
