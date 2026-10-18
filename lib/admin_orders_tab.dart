import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'notification_service.dart';
import 'admin_order_card.dart';
import 'app_theme.dart';
import 'modern_loader.dart';
import 'animation_helpers.dart';
import 'shop_provider.dart';
import 'language_provider.dart';
import 'package:near_kirana/firebase_utils.dart';

class AdminOrdersTab extends StatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFF0C831F),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('Customer Orders', 'ग्राहकों के ऑर्डर्स', 'Customer Orders'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  t('Live order fulfillment', 'लाइव ऑर्डर प्रोसेसिंग', 'Live order fulfillment'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF0C831F),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0C831F).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(3),
              tabs: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseUtils.firestore
                      .collection('orders')
                      .where('shop_id', isEqualTo: shopId)
                      .where(
                        'status',
                        whereIn: const [
                          'Pending',
                          'Accepted',
                          'Packing',
                          'Packed',
                          'Ready',
                          'Out for Delivery',
                          'Delivery_Failed',
                        ],
                      )
                      .snapshots(),
                  builder: (context, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    return Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t('Active Orders', 'चालू ऑर्डर्स', 'Active Orders')),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                Tab(text: t('History', 'इतिहास', 'History')),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LiveOrdersTab(t: t),
          _OrderHistoryTab(t: t),
        ],
      ),
    );
  }

}

class _LiveOrdersTab extends StatefulWidget {
  final String Function(String, String, String) t;
  const _LiveOrdersTab({required this.t});

  @override
  State<_LiveOrdersTab> createState() => _LiveOrdersTabState();
}

class _LiveOrdersTabState extends State<_LiveOrdersTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _activeSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _activeSearchQuery = '';
  int _selectedActiveFilter = 0; // 0: All, 1: Ready/Packed, 2: Out for Delivery, 3: Pickup
  int _previousPendingCount = 0;

  Stream<QuerySnapshot>? _ordersStream;
  String? _cachedShopId;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    if (_cachedShopId != shopId) {
      _cachedShopId = shopId;
      _ordersStream = FirebaseUtils.firestore
          .collection('orders')
          .where('shop_id', isEqualTo: shopId)
          .where(
            'status',
            whereIn: const [
              'Pending',
              'Accepted',
              'Packing',
              'Packed',
              'Ready',
              'Out for Delivery',
              'Delivery_Failed',
            ],
          )
          .snapshots();
    }
  }

  @override
  void dispose() {
    _activeSearchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = widget.t;

    if (_ordersStream == null) {
      return const Center(child: ModernLoader(color: Color(0xFF0C831F)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${t('Error loading orders', 'ऑर्डर्स लोड करने में त्रुटि', 'Orders load karne me error')}: ${snapshot.error}',
              style: AppTextStyles.bodyMedium(color: AppColors.error),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: ModernLoader(color: Color(0xFF0C831F)),
          );
        }

        final allOrders = snapshot.data?.docs.toList() ?? [];

        // Sort orders manually descending by created_at
        allOrders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['created_at'] as Timestamp?;
          final bTime = bData['created_at'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // Descending
        });

        final currentCount = allOrders.length;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && currentCount > _previousPendingCount) {
            NotificationService.showOrderNotification(
              t('New Order Received!', 'नया ऑर्डर आया है!', 'Naya Order Aaya Hai!'),
              t('Total $currentCount pending orders. Check immediately.', 'कुल $currentCount ऑर्डर्स पेंडिंग हैं। तुरंत चेक करें।', 'Total $currentCount pending orders hai. Jaldi check karein.'),
              titleEn: 'New Order Received!',
              titleHi: 'नया ऑर्डर आया है!',
              titleHinglish: 'Naya Order Aaya Hai!',
              bodyEn: 'Total $currentCount pending orders. Check immediately.',
              bodyHi: 'कुल $currentCount ऑर्डर्स पेंडिंग हैं। तुरंत चेक करें।',
              bodyHinglish: 'Total $currentCount pending orders hai. Jaldi check karein.',
            );
          }
          _previousPendingCount = currentCount;
        });

        // Compute metric counts
        final totalActiveCount = allOrders.length;
        final readyPackedCount = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();
          return status == 'Ready' || status == 'Packed' || status == 'Packing';
        }).length;
        final outForDeliveryCount = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['status'] ?? '').toString() == 'Out for Delivery';
        }).length;
        final storePickupCount = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = (data['delivery_type'] ?? data['type'] ?? '').toString().toLowerCase();
          return type.contains('pickup');
        }).length;

        // Apply filter pill
        List<DocumentSnapshot> filteredOrders = allOrders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();
          final type = (data['delivery_type'] ?? data['type'] ?? '').toString().toLowerCase();

          if (_selectedActiveFilter == 1) {
            return status == 'Ready' || status == 'Packed' || status == 'Packing';
          } else if (_selectedActiveFilter == 2) {
            return status == 'Out for Delivery';
          } else if (_selectedActiveFilter == 3) {
            return type.contains('pickup');
          }
          return true; // 0 = All
        }).toList();

        // Apply search query
        if (_activeSearchQuery.trim().isNotEmpty) {
          final q = _activeSearchQuery.trim().toLowerCase();
          filteredOrders = filteredOrders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final customerName = (data['customer_name'] ?? '').toString().toLowerCase();
            final phone = (data['phone_number'] ?? data['customer_phone'] ?? '').toString().toLowerCase();
            final docId = doc.id.toLowerCase();
            final orderId = (data['order_id'] ?? '').toString().toLowerCase();
            final address = (data['delivery_address'] ?? '').toString().toLowerCase();

            return customerName.contains(q) ||
                phone.contains(q) ||
                docId.contains(q) ||
                orderId.contains(q) ||
                address.contains(q);
          }).toList();
        }

        return Column(
          children: [
            // Top Controls: Search Bar & Metric Filter Cards
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _activeSearchController,
                      focusNode: _searchFocusNode,
                      onChanged: (val) {
                        setState(() => _activeSearchQuery = val);
                      },
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: t(
                          'Search customer, mobile, order ID or address...',
                          'ग्राहक का नाम, मोबाइल, ऑर्डर ID या पता खोजें...',
                          'Customer, mobile, order ID ya address se search karein...',
                        ),
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF0C831F),
                          size: 20,
                        ),
                        suffixIcon: _activeSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                                onPressed: () {
                                  _activeSearchController.clear();
                                  setState(() => _activeSearchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 4 Filter Metric Cards (Inventory & Khata style)
                  Row(
                    children: [
                      _buildMetricFilterCard(
                        title: t('All Active', 'सभी चालू', 'All Active'),
                        count: totalActiveCount,
                        color: const Color(0xFF0C831F),
                        isSelected: _selectedActiveFilter == 0,
                        onTap: () => setState(() => _selectedActiveFilter = 0),
                      ),
                      _buildMetricFilterCard(
                        title: t('Ready / Pack', 'तैयार / पैक', 'Ready / Pack'),
                        count: readyPackedCount,
                        color: const Color(0xFFD97706),
                        isSelected: _selectedActiveFilter == 1,
                        onTap: () => setState(() => _selectedActiveFilter = 1),
                      ),
                      _buildMetricFilterCard(
                        title: t('Out for Delivery', 'डिलीवरी चालू', 'On the Way'),
                        count: outForDeliveryCount,
                        color: const Color(0xFF2563EB),
                        isSelected: _selectedActiveFilter == 2,
                        onTap: () => setState(() => _selectedActiveFilter = 2),
                      ),
                      _buildMetricFilterCard(
                        title: t('Store Pickup', 'दुकान पिकअप', 'Store Pickup'),
                        count: storePickupCount,
                        color: const Color(0xFF7C3AED),
                        isSelected: _selectedActiveFilter == 3,
                        onTap: () => setState(() => _selectedActiveFilter = 3),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Order List or Empty State
            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C831F).withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 48,
                              color: Color(0xFF0C831F),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _activeSearchQuery.isNotEmpty
                                ? t('No matching active orders', 'कोई मेल खाता ऑर्डर नहीं मिला', 'No matching active orders')
                                : t('All Orders Fulfilled!', 'सभी ऑर्डर्स पूरे हो चुके हैं!', 'All orders fulfilled!'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _activeSearchQuery.isNotEmpty
                                ? t('Try searching with a different term', 'अलग नाम या नंबर से खोजें', 'Try different search term')
                                : t('New incoming customer orders will appear here live.', 'नए आने वाले ऑर्डर्स यहां लाइव दिखाई देंगे।', 'New orders will appear here live.'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 250.ms)
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        top: 12,
                        left: 14,
                        right: 14,
                        bottom: 100,
                      ),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        return AdminOrderCard(orderDoc: filteredOrders[index])
                            .fadeSlideUp(delay: 30 * (index % 10));
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // Helper widget for metric filter cards matching Inventory & Khata design
  Widget _buildMetricFilterCard({
    required String title,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : const Color(0xFFE2E8F0),
                width: isSelected ? 1.6 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? color : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Order History Tab Content
class _OrderHistoryTab extends StatefulWidget {
  final String Function(String, String, String)? t;
  const _OrderHistoryTab({this.t});

  @override
  State<_OrderHistoryTab> createState() => _OrderHistoryTabState();
}

class _OrderHistoryTabState extends State<_OrderHistoryTab> {
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _orders = [];
  bool _isLoading = false;
  bool _hasMore = true;

  // Search & Metric Filter state
  final TextEditingController _historySearchController = TextEditingController();
  String _historySearchQuery = '';
  int _selectedHistoryFilter = 0; // 0: All Past, 1: Delivered, 2: Cancelled

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchOrders();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      
      final querySnapshot = await FirebaseUtils.firestore
          .collection('orders')
          .where('shop_id', isEqualTo: shopId)
          .where('status', whereIn: const ['Delivered', 'Cancelled', 'Rejected'])
          .get();

      final historyDocs = querySnapshot.docs.toList();
      
      // Sort locally descending by created_at
      historyDocs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aTime = aData['created_at'] as Timestamp?;
        final bTime = bData['created_at'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      _hasMore = false;
      _orders.clear();
      _orders.addAll(historyDocs);

    } catch (e) {
      debugPrint('Error fetching order history: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _orders.clear();
      _hasMore = true;
    });
    await _fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t ?? (String en, String hi, String hinglish) => en;

    if (_orders.isEmpty && _isLoading) {
      return const Center(
        child: ModernLoader(color: Color(0xFF0C831F)),
      );
    }

    // Counts for history cards
    final totalPastCount = _orders.length;
    final deliveredCount = _orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['status'] ?? '').toString() == 'Delivered';
    }).length;
    final cancelledCount = _orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString();
      return status == 'Cancelled' || status == 'Rejected';
    }).length;

    // Filter by metric card
    List<DocumentSnapshot> filteredHistory = _orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString();
      if (_selectedHistoryFilter == 1) return status == 'Delivered';
      if (_selectedHistoryFilter == 2) return status == 'Cancelled' || status == 'Rejected';
      return true; // 0 = All
    }).toList();

    // Filter by search
    if (_historySearchQuery.trim().isNotEmpty) {
      final q = _historySearchQuery.trim().toLowerCase();
      filteredHistory = filteredHistory.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final customerName = (data['customer_name'] ?? '').toString().toLowerCase();
        final phone = (data['phone_number'] ?? data['customer_phone'] ?? '').toString().toLowerCase();
        final docId = doc.id.toLowerCase();
        final orderId = (data['order_id'] ?? '').toString().toLowerCase();
        final address = (data['delivery_address'] ?? '').toString().toLowerCase();

        return customerName.contains(q) ||
            phone.contains(q) ||
            docId.contains(q) ||
            orderId.contains(q) ||
            address.contains(q);
      }).toList();
    }

    return Column(
      children: [
        // Top Controls: Search Bar & Metric Filter Cards
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            children: [
              // Search Bar
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _historySearchController,
                  onChanged: (val) {
                    setState(() => _historySearchQuery = val);
                  },
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: t(
                      'Search customer, mobile, order ID or address...',
                      'ग्राहक का नाम, मोबाइल, ऑर्डर ID या पता खोजें...',
                      'Customer, mobile, order ID ya address se search karein...',
                    ),
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF0C831F),
                      size: 20,
                    ),
                    suffixIcon: _historySearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                            onPressed: () {
                              _historySearchController.clear();
                              setState(() => _historySearchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3 Filter Metric Cards: All Past, Delivered, Cancelled
              Row(
                children: [
                  _buildHistoryMetricCard(
                    title: t('All Past', 'सभी पुराने', 'All Past'),
                    count: totalPastCount,
                    color: const Color(0xFF475569),
                    isSelected: _selectedHistoryFilter == 0,
                    onTap: () => setState(() => _selectedHistoryFilter = 0),
                  ),
                  _buildHistoryMetricCard(
                    title: t('Delivered', 'डिलीवर हुए', 'Delivered'),
                    count: deliveredCount,
                    color: const Color(0xFF0C831F),
                    isSelected: _selectedHistoryFilter == 1,
                    onTap: () => setState(() => _selectedHistoryFilter = 1),
                  ),
                  _buildHistoryMetricCard(
                    title: t('Cancelled', 'रद्द हुए', 'Cancelled'),
                    count: cancelledCount,
                    color: const Color(0xFFDC2626),
                    isSelected: _selectedHistoryFilter == 2,
                    onTap: () => setState(() => _selectedHistoryFilter = 2),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List Content or Empty View
        Expanded(
          child: filteredHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C831F).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _historySearchQuery.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.history_rounded,
                          size: 50,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _historySearchQuery.isNotEmpty
                            ? t('No history matches your search.', 'सर्च से मेल खाता कोई पुराना ऑर्डर नहीं मिला।', 'Search se match karta koi order nahi mila.')
                            : t('No order history found.', 'कोई पुराना ऑर्डर नहीं मिला।', 'Koi order history nahi mili.'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (_historySearchQuery.isNotEmpty || _selectedHistoryFilter != 0) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            _historySearchController.clear();
                            setState(() {
                              _historySearchQuery = '';
                              _selectedHistoryFilter = 0;
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(t('Clear Filters', 'फ़िल्टर हटाएं', 'Clear Filters')),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0C831F),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: const Color(0xFF0C831F),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      top: 12,
                      left: 14,
                      right: 14,
                      bottom: 100,
                    ),
                    itemCount: filteredHistory.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == filteredHistory.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: ModernLoader(color: Color(0xFF0C831F)),
                          ),
                        );
                      }

                      final orderDoc = filteredHistory[index];
                      return AdminOrderCard(orderDoc: orderDoc)
                          .fadeSlideUp(delay: 30 * (index % 10));
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryMetricCard({
    required String title,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : const Color(0xFFE2E8F0),
                width: isSelected ? 1.6 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? color : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
