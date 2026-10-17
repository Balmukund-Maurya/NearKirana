import 'package:flutter/material.dart';
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
  int _previousPendingCount = 0;

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
          _buildLiveOrdersStream(context, t),
          _OrderHistoryTab(t: t),
        ],
      ),
    );
  }

  Widget _buildLiveOrdersStream(BuildContext context, String Function(String, String, String) t) {
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    
    return StreamBuilder<QuerySnapshot>(
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
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${t('Error loading orders', 'ऑर्डर्स लोड करने में त्रुटि', 'Orders load karne me error')}: ${snapshot.error}',
              style: AppTextStyles.bodyMedium(color: AppColors.error),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: ModernLoader(color: Color(0xFF0C831F)),
          );
        }

        final orders = snapshot.data?.docs ?? [];

        // Sort orders manually descending
        orders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['created_at'] as Timestamp?;
          final bTime = bData['created_at'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // Descending
        });

        final currentCount = orders.length;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (currentCount > _previousPendingCount) {
            NotificationService.showOrderNotification(
              t('New Order Received!', 'नया ऑर्डर आया है!', 'Naya Order Aaya Hai!'),
              t('Total $currentCount pending orders. Check immediately.', 'कुल $currentCount ऑर्डर्स पेंडिंग हैं। तुरंत चेक करें।', 'Total $currentCount pending orders hai. Jaldi check karein.'),
            );
          }
          _previousPendingCount = currentCount;
        });

        if (orders.isEmpty) {
          return Center(
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
                    Icons.done_all_rounded,
                    size: 54,
                    color: Color(0xFF0C831F),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t('No active orders right now.', 'अभी कोई नया ऑर्डर नहीं है।', 'Abhi koi active order nahi hai.'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            top: 14,
            left: 14,
            right: 14,
            bottom: 100,
          ),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return AdminOrderCard(orderDoc: orders[index])
                .fadeSlideUp(delay: 40 * (index % 10));
          },
        );
      },
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

  Future<void> _fetchOrders() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      
      // Fetch without orderBy to avoid requiring a composite index. 
      // We will fetch all history and sort locally.
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

      _hasMore = false; // We fetched all history
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

    if (_orders.isEmpty && !_isLoading) {
      return Center(
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
                Icons.history_rounded,
                size: 54,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('No order history found.', 'कोई पुराना ऑर्डर नहीं मिला।', 'Koi order history nahi mili.'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF0C831F),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(
          top: 14,
          left: 14,
          right: 14,
          bottom: 100,
        ),
        itemCount: _orders.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _orders.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: ModernLoader(color: Color(0xFF0C831F)),
              ),
            );
          }

          final orderDoc = _orders[index];
          
          return AdminOrderCard(orderDoc: orderDoc)
              .fadeSlideUp(delay: 30 * (index % 10));
        },
      ),
    );
  }
}
