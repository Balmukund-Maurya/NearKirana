import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'shop_provider.dart';
import 'firebase_utils.dart';
import 'app_theme.dart';
import 'modern_loader.dart';
import 'admin_order_card.dart';
import 'widgets/admin_top_header.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminOrdersDesktopView extends StatefulWidget {
  const AdminOrdersDesktopView({super.key});

  @override
  State<AdminOrdersDesktopView> createState() => _AdminOrdersDesktopViewState();
}

class _AdminOrdersDesktopViewState extends State<AdminOrdersDesktopView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _historyOrders = [];
  bool _isLoadingHistory = false;
  bool _hasMoreHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
      if (_tabController.index == 1 && _historyOrders.isEmpty) {
        _fetchHistoryOrders();
      }
    });
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _fetchHistoryOrders();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistoryOrders() async {
    if (_isLoadingHistory || !_hasMoreHistory) return;

    setState(() => _isLoadingHistory = true);

    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      
      final querySnapshot = await FirebaseUtils.firestore
          .collection('orders')
          .where('shop_id', isEqualTo: shopId)
          .where('status', whereIn: ['Delivered', 'Cancelled'])
          .get();

      final historyDocs = querySnapshot.docs.toList();
      
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

      _hasMoreHistory = false;
      _historyOrders.clear();
      _historyOrders.addAll(historyDocs);

    } catch (e) {
      debugPrint('Error fetching order history: $e');
    }

    if (mounted) {
      setState(() => _isLoadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AdminTopHeader(),
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC), // Slight off-white background
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _buildMainContent(),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 3,
                    child: _buildRightPanel(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Orders', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text('Manage and track all your orders', style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Create Order', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10703B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Tabs
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 2)),
          ),
          child: Row(
            children: [
              _buildTab(0, 'Active Orders'),
              const SizedBox(width: 32),
              _buildTab(1, 'History'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Filter Row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildTextField('Search by order ID...', Icons.search),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildDropdown('All Status'),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildDropdown('Today', icon: Icons.calendar_today_outlined),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildDropdown('Sort by: Latest', icon: Icons.swap_vert_rounded),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Content
        if (_tabController.index == 0)
          _buildActiveOrders()
        else
          _buildHistoryOrders(),
      ],
    );
  }

  Widget _buildTextField(String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdown(String value, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.grey.shade600, size: 16),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(value, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600, size: 18),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title) {
    final isSelected = _tabController.index == index;
    return InkWell(
      onTap: () {
        _tabController.animateTo(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF10703B) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? const Color(0xFF10703B) : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOrders() {
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseUtils.firestore
          .collection('orders')
          .where('shop_id', isEqualTo: shopId)
          .where(
            'status',
            whereIn: ['Pending', 'Packed', 'Ready', 'Out for Delivery'],
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(48), child: ModernLoader(color: AppColors.primaryDark)));
        }

        final orders = snapshot.data?.docs ?? [];
        if (orders.isEmpty) {
          return _buildEmptyState();
        }

        orders.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return _buildOrdersTable(orders);
      },
    );
  }

  Widget _buildHistoryOrders() {
    if (_historyOrders.isEmpty && _isLoadingHistory) {
      return const Center(child: Padding(padding: EdgeInsets.all(48), child: ModernLoader(color: AppColors.primaryDark)));
    }

    if (_historyOrders.isEmpty && !_isLoadingHistory) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 64),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 80, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text(
              'No order history found.',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return _buildOrdersTable(_historyOrders);
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.done_all_rounded, size: 64, color: Color(0xFF10703B)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No active orders right now.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error loading orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(error, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildOrdersTable(List<DocumentSnapshot> orders) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orders (${orders.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text(_tabController.index == 0 ? 'Recent orders from your customers' : 'Your completed and cancelled orders', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          ),
          
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(color: Colors.grey.shade100)),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(
              children: [
                SizedBox(width: 40, child: Text('#', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text('Customer', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Items', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('Total', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Status', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Order Time', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                SizedBox(width: 100, child: Text('Actions', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          
          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildTableRow(order, index + 1);
            },
          ),
          
          // Pagination Row
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Showing 1-${orders.length} of ${orders.length} orders', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                Row(
                  children: [
                    _buildPageButton(Icons.chevron_left, false),
                    const SizedBox(width: 8),
                    _buildPageButton('1', true),
                    const SizedBox(width: 8),
                    _buildPageButton('2', false),
                    const SizedBox(width: 8),
                    _buildPageButton('3', false),
                    const SizedBox(width: 8),
                    _buildPageButton(Icons.chevron_right, false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton(dynamic content, bool isActive) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF10703B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? const Color(0xFF10703B) : Colors.grey.shade300),
      ),
      child: Center(
        child: content is String
            ? Text(content, style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w600))
            : Icon(content as IconData, color: Colors.grey.shade600, size: 20),
      ),
    );
  }

  Widget _buildTableRow(DocumentSnapshot orderDoc, int index) {
    final data = orderDoc.data() as Map<String, dynamic>;
    final String customerName = data['customer_name'] ?? 'Unknown';
    final String initials = customerName.isNotEmpty ? customerName.substring(0, 2).toUpperCase() : 'U';
    final String phone = data['phone_number'] ?? '';
    final String status = data['status'] ?? 'Pending';
    final double total = double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0.0;
    final List items = data['items'] ?? [];
    
    final Timestamp? createdAt = data['created_at'] as Timestamp?;
    String timeStr = '';
    String dateStr = '';
    if (createdAt != null) {
      final dt = createdAt.toDate();
      timeStr = DateFormat('hh:mm a').format(dt);
      
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        dateStr = 'Today';
      } else {
        dateStr = DateFormat('dd MMM').format(dt);
      }
    }

    Color statusColor = Colors.grey;
    Color statusBg = Colors.grey.shade100;
    String displayStatus = status;
    
    switch (status) {
      case 'Pending':
        statusColor = const Color(0xFF10703B);
        statusBg = const Color(0xFFE8F5E9);
        displayStatus = 'Confirmed';
        break;
      case 'Packed':
      case 'Ready':
        statusColor = const Color(0xFF2563EB);
        statusBg = const Color(0xFFEFF6FF);
        displayStatus = 'Preparing';
        break;
      case 'Out for Delivery':
        statusColor = const Color(0xFFF97316);
        statusBg = const Color(0xFFFFF7ED);
        displayStatus = 'Out for Delivery';
        break;
      case 'Delivered':
        statusColor = const Color(0xFF10703B);
        statusBg = const Color(0xFFE8F5E9);
        displayStatus = 'Completed';
        break;
      case 'Cancelled':
        statusColor = Colors.red;
        statusBg = Colors.red.shade50;
        displayStatus = 'Cancelled';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('$index', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          ),
          
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE8F5E9),
                  child: Text(initials, style: const TextStyle(color: Color(0xFF10703B), fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(phone, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _buildItemPlaceholder(Colors.red.shade100, Colors.red),
                const SizedBox(width: 4),
                _buildItemPlaceholder(Colors.yellow.shade100, Colors.orange),
                const SizedBox(width: 4),
                _buildItemPlaceholder(Colors.blue.shade100, Colors.blue),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${items.length} items', style: const TextStyle(color: Color(0xFF10703B), fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF10703B)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            flex: 1,
            child: Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B))),
          ),
          
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(displayStatus, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(timeStr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
          ),
          
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _showOrderActionsDialog(orderDoc),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('View', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF10703B))),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemPlaceholder(Color bg, Color fg) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(Icons.shopping_bag, size: 12, color: fg),
      ),
    );
  }

  void _showOrderActionsDialog(DocumentSnapshot orderDoc) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AdminOrderCard(orderDoc: orderDoc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseUtils.firestore
          .collection('orders')
          .where('shop_id', isEqualTo: shopId)
          .where(
            'status',
            whereIn: ['Pending', 'Packed', 'Ready', 'Out for Delivery', 'Delivered'],
          )
          .snapshots(),
      builder: (context, snapshot) {
        int totalOrders = 0;
        int preparing = 0;
        int outForDelivery = 0;
        int completed = 0;
        
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          totalOrders = docs.length;
          
          for (var doc in docs) {
            final status = (doc.data() as Map<String, dynamic>)['status'];
            if (status == 'Pending' || status == 'Packed' || status == 'Ready') {
              preparing++;
            } else if (status == 'Out for Delivery') {
              outForDelivery++;
            } else if (status == 'Delivered') {
              completed++;
            }
          }
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, color: Color(0xFF10703B)),
                      SizedBox(width: 8),
                      Text('Order Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildSummaryStatCard('Total\nOrders', '$totalOrders', Icons.shopping_bag_outlined, const Color(0xFF10703B), const Color(0xFFE8F5E9)),
                      const SizedBox(width: 12),
                      _buildSummaryStatCard('Preparing', '$preparing', Icons.access_time_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSummaryStatCard('Out for\nDelivery', '$outForDelivery', Icons.moped_rounded, const Color(0xFFF97316), const Color(0xFFFFF7ED)),
                      const SizedBox(width: 12),
                      _buildSummaryStatCard('Completed', '$completed', Icons.check_circle_outline, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Recent Activity Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.access_time, color: Color(0xFF1E293B), size: 20),
                          SizedBox(width: 8),
                          Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('View All', style: TextStyle(color: Color(0xFF10703B), fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, color: Color(0xFF10703B), size: 14),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildActivityItem('RS', 'Raju Sharma', 'placed a new order', '10:30 AM'),
                  _buildActivityItem('PS', 'Priya Singh', 'order is preparing', '09:45 AM'),
                  _buildActivityItem('AK', 'Amit Kumar', 'order is out for delivery', '09:20 AM'),
                  _buildActivityItem('SM', 'Sneha Mehta', 'order is being processed', '08:15 AM'),
                  _buildActivityItem('VK', 'Vikram Patel', 'order confirmed', '08:00 AM', isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt, color: Color(0xFF1E293B), size: 22),
                      SizedBox(width: 8),
                      Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildQuickAction(Icons.person_add_alt_1_outlined, 'Create New Order', 'Manually create an order for a customer'),
                  _buildQuickAction(Icons.list_alt_rounded, 'View All Orders', 'See all orders and their status'),
                  _buildQuickAction(Icons.download_outlined, 'Download Reports', 'Get order reports and analytics', isLast: true),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityItem(String initials, String name, String action, String time, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE8F5E9),
            child: Text(initials, style: const TextStyle(color: Color(0xFF10703B), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF10703B), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Text(action, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ),
              ],
            ),
          ),
          Text(time, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String title, String subtitle, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E293B), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, color: Colors.grey.shade400, size: 16),
        ],
      ),
    );
  }

  Widget _buildSummaryStatCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                  Text(title, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700, height: 1.1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
