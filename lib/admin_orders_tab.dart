import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'notification_service.dart';
import 'admin_order_card.dart';
import 'app_theme.dart';
import 'modern_loader.dart';
import 'animation_helpers.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';

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
    final langProvider = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(langProvider.translate('orders_tab')),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: AppTextStyles.bodySemiBold(color: AppColors.white),
          unselectedLabelStyle: AppTextStyles.bodyMedium(
            color: AppColors.white.withValues(alpha: 0.7),
          ),
          indicatorColor: AppColors.white,
          indicatorWeight: 3,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'Active Orders'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildLiveOrdersStream(), const _OrderHistoryTab()],
      ),
    );
  }

  Widget _buildLiveOrdersStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where(
            'status',
            whereIn: ['Pending', 'Packed', 'Ready', 'Out for Delivery'],
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading orders: ${snapshot.error}',
              style: AppTextStyles.bodyMedium(color: AppColors.error),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: ModernLoader(color: AppColors.primaryDark),
          );
        }

        final orders = snapshot.data?.docs ?? [];

        // Sort orders manually
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
              'Naya Order Aaya Hai!',
              'Total $currentCount pending orders hai. Jaldi check karein.',
            );
          }
          _previousPendingCount = currentCount;
        });

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.done_all_rounded, size: 80, color: AppColors.bgTint),
                const SizedBox(height: 16),
                Text(
                  'No active orders right now.',
                  style: AppTextStyles.bodySemiBold(color: AppColors.textMid),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: 100,
          ),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return AdminOrderCard(orderDoc: orders[index])
                .fadeSlideUp(delay: 50 * index);
          },
        );
      },
    );
  }
}

// Order History Tab Content
class _OrderHistoryTab extends StatefulWidget {
  const _OrderHistoryTab();

  @override
  State<_OrderHistoryTab> createState() => _OrderHistoryTabState();
}

class _OrderHistoryTabState extends State<_OrderHistoryTab> {
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _orders = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;

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
      // Fetch latest orders globally to avoid Composite Index errors
      Query q = FirebaseFirestore.instance
          .collection('orders')
          .orderBy('created_at', descending: true)
          .limit(_limit);

      if (_lastDocument != null) {
        q = q.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await q.get();

      if (querySnapshot.docs.length < _limit) {
        _hasMore = false;
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        
        // Filter locally
        final historyDocs = querySnapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          return status == 'Delivered' || status == 'Cancelled';
        }).toList();

        _orders.addAll(historyDocs);

        // If we filtered out all items in this batch but more exist, fetch next batch automatically
        if (historyDocs.isEmpty && _hasMore) {
          if (mounted) {
            setState(() => _isLoading = false);
            Future.microtask(() => _fetchOrders());
            return;
          }
        }
      }
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
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    if (_orders.isEmpty && _isLoading) {
      return const Center(
        child: ModernLoader(color: AppColors.primaryDark),
      );
    }

    if (_orders.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 80, color: AppColors.bgTint),
            const SizedBox(height: 16),
            Text(
              'No order history found.',
              style: AppTextStyles.bodySemiBold(color: AppColors.textMid),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primaryDark,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: 100,
        ),
        itemCount: _orders.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _orders.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: ModernLoader(color: AppColors.primaryDark),
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
