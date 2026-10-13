import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'desktop_order_tracking_view.dart';
import 'desktop_order_details_view.dart';
import 'package:intl/intl.dart';
import 'package:near_kirana/l10n/app_localizations.dart';

class MyOrdersDesktopWrapper extends StatefulWidget {
  final List<QueryDocumentSnapshot> orders;
  
  const MyOrdersDesktopWrapper({super.key, required this.orders});

  @override
  State<MyOrdersDesktopWrapper> createState() => _MyOrdersDesktopWrapperState();
}

class _MyOrdersDesktopWrapperState extends State<MyOrdersDesktopWrapper> {
  QueryDocumentSnapshot? _selectedOrder;
  bool _showTracking = false;
  
  String _searchQuery = '';
  String _statusFilter = 'All Orders';
  String _dateFilter = 'All Time';

  @override
  Widget build(BuildContext context) {
    if (_selectedOrder != null) {
      if (_showTracking) {
        return DesktopOrderTrackingView(
          order: _selectedOrder!,
          onBack: () {
            setState(() {
              _selectedOrder = null;
              _showTracking = false;
            });
          },
          onViewDetails: () {
            setState(() {
              _showTracking = false;
            });
          },
        );
      } else {
        return DesktopOrderDetailsView(
          order: _selectedOrder!,
          onBack: () {
            setState(() {
              _selectedOrder = null;
            });
          },
          onTrackOrder: () {
            setState(() {
              _showTracking = true;
            });
          },
        );
      }
    }

    // Calculations for summary cards
    int totalOrders = widget.orders.length;
    int deliveredCount = 0;
    int inProgressCount = 0;
    int cancelledCount = 0;

    for (var order in widget.orders) {
      final data = order.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'Pending';
      if (status == 'Delivered') {
        deliveredCount++;
      } else if (status == 'Cancelled') {
        cancelledCount++;
      } else {
        inProgressCount++;
      }
    }
    
    // Filtering logic
    List<QueryDocumentSnapshot> filteredOrders = widget.orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'Pending';
      
      // Status filter
      if (_statusFilter != 'All Orders') {
        if (_statusFilter == 'Delivered' && status != 'Delivered') return false;
        if (_statusFilter == 'Cancelled' && status != 'Cancelled') return false;
        if (_statusFilter == 'In Progress' && (status == 'Delivered' || status == 'Cancelled')) return false;
      }
      
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final orderId = doc.id.toLowerCase();
        final items = data['items'] as List<dynamic>? ?? [];
        final hasItemMatch = items.any((item) => (item['name'] ?? '').toString().toLowerCase().contains(query));
        
        if (!orderId.contains(query) && !hasItemMatch) {
          return false;
        }
      }
      
      return true;
    }).toList();

    return Container(
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Area
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF111827)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.my_orders,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View and track all your orders',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Summary Cards
          Row(
            children: [
              Expanded(child: _buildSummaryCard('Total Orders', totalOrders.toString(), 'All time orders', Icons.inventory_2_outlined, const Color(0xFF059669), const Color(0xFFD1FAE5))),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryCard('Delivered', deliveredCount.toString(), 'Completed orders', Icons.local_shipping_outlined, const Color(0xFF2563EB), const Color(0xFFDBEAFE))),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryCard('In Progress', inProgressCount.toString(), 'Processing & delivery', Icons.access_time, const Color(0xFFD97706), const Color(0xFFFEF3C7))),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryCard('Cancelled', cancelledCount.toString(), 'Cancelled orders', Icons.cancel_outlined, const Color(0xFFDC2626), const Color(0xFFFEE2E2))),
            ],
          ),
          const SizedBox(height: 32),
          
          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search orders by order ID, product name...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                    items: ['All Orders', 'Delivered', 'In Progress', 'Cancelled']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _statusFilter = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _dateFilter,
                        icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                        items: ['All Time', 'Last 7 Days', 'Last 30 Days']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _dateFilter = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list, size: 18, color: Color(0xFF374151)),
                label: const Text('Filter', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  side: BorderSide(color: Colors.grey.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Orders Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text('Order Details', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13))),
                        Expanded(flex: 3, child: Text('Items', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13))),
                        Expanded(flex: 2, child: Text('Total Amount', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13))),
                        Expanded(flex: 2, child: Text('Order Status', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13))),
                        Expanded(flex: 2, child: Text('Order Date', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13))),
                        Expanded(flex: 2, child: Text('Actions', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13))),
                      ],
                    ),
                  ),
                  
                  // Table Body
                  Expanded(
                    child: filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text('No orders found', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: filteredOrders.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                            itemBuilder: (context, index) {
                              final doc = filteredOrders[index];
                              return _buildOrderRow(doc);
                            },
                          ),
                  ),
                  
                  // Pagination Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Showing 1 to ${filteredOrders.length} of ${widget.orders.length} orders', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        Row(
                          children: [
                            _buildPaginationBtn(Icons.chevron_left, false),
                            const SizedBox(width: 8),
                            _buildPaginationBtn('1', true),
                            const SizedBox(width: 8),
                            _buildPaginationBtn(Icons.chevron_right, false),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor == const Color(0xFFF0FDF4) ? const Color(0xFFDCFCE7) : bgColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: iconColor.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))]),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: iconColor.withValues(alpha: 0.8), fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: Color(0xFF111827))),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String orderId = doc.id.substring(0, 8).toUpperCase();
    final String shopName = data['shop_name'] ?? 'NearKirana Store';
    final items = data['items'] as List<dynamic>? ?? [];
    final double total = double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0.0;
    final String status = data['status'] ?? 'Pending';
    final Timestamp? createdAt = data['created_at'] as Timestamp?;
    
    String dateStr = '';
    String timeStr = '';
    if (createdAt != null) {
      final dt = createdAt.toDate();
      dateStr = DateFormat('dd MMM yyyy').format(dt);
      timeStr = DateFormat('hh:mm a').format(dt);
    }

    final bool isCompleted = status == 'Delivered' || status == 'Cancelled';
    
    // Status color mapping
    Color statusBgColor;
    Color statusTextColor;
    IconData statusIcon;
    
    if (status == 'Delivered') {
      statusBgColor = const Color(0xFFDCFCE7);
      statusTextColor = const Color(0xFF166534);
      statusIcon = Icons.check_circle;
    } else if (status == 'Cancelled') {
      statusBgColor = const Color(0xFFFEE2E2);
      statusTextColor = const Color(0xFFB91C1C);
      statusIcon = Icons.cancel;
    } else if (status == 'Out for Delivery') {
      statusBgColor = const Color(0xFFDCFCE7);
      statusTextColor = const Color(0xFF166534);
      statusIcon = Icons.local_shipping;
    } else {
      statusBgColor = const Color(0xFFEFF6FF);
      statusTextColor = const Color(0xFF1D4ED8);
      statusIcon = Icons.settings;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedOrder = doc;
          _showTracking = false;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
          // Order Details Column
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#NK$orderId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                    const SizedBox(height: 4),
                    Text(shopName, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('${items.length} items', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          
          // Items Thumbnails Column
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ...items.take(4).map((item) {
                  final itemData = item as Map<String, dynamic>;
                  final image = itemData['image'];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: image != null && image.toString().isNotEmpty
                        ? ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 16, color: Colors.grey)))
                        : const Icon(Icons.image, size: 16, color: Colors.grey),
                  );
                }),
                if (items.length > 4)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    alignment: Alignment.center,
                    child: Text('+${items.length - 4}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600)),
                  ),
              ],
            ),
          ),
          
          // Total Amount Column
          Expanded(
            flex: 2,
            child: Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827))),
          ),
          
          // Order Status Column
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusTextColor),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(color: statusTextColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Order Date Column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                const SizedBox(height: 4),
                Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          
          // Actions Column
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedOrder = doc;
                        _showTracking = !isCompleted;
                      });
                    },
                    icon: Icon(
                      isCompleted ? Icons.description_outlined : Icons.remove_red_eye,
                      size: 16,
                      color: const Color(0xFF111827),
                    ),
                    label: Text(
                      isCompleted ? 'View Details' : 'Track Order',
                      style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert, size: 20),
                  color: Colors.grey.shade600,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildPaginationBtn(dynamic content, bool active) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF047857) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? const Color(0xFF047857) : Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: content is String
          ? Text(content, style: TextStyle(color: active ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13))
          : Icon(content as IconData, size: 16, color: active ? Colors.white : Colors.grey.shade700),
    );
  }
}
