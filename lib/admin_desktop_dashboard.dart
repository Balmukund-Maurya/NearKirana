import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/widgets/weekly_sales_chart.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:near_kirana/gateway_screen.dart';

class AdminDesktopDashboard extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onNavTap;
  final Widget child;

  const AdminDesktopDashboard({
    super.key,
    required this.selectedIndex,
    required this.onNavTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDEBAR
          _buildSidebar(context),
          
          // MAIN DASHBOARD AREA
          Expanded(
            child: selectedIndex == 0 ? AdminDesktopHome(onNavTap: onNavTap) : child,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    // 10 items as requested
    final navItems = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Orders'},
      {'icon': Icons.inventory_2_rounded, 'label': 'Products'},
      {'icon': Icons.category_rounded, 'label': 'Categories'},
      {'icon': Icons.people_alt_rounded, 'label': 'Customers'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Khata / Udhaar'},
      {'icon': Icons.person_rounded, 'label': 'Shop Boys'},
      {'icon': Icons.analytics_rounded, 'label': 'Analytics'},
      {'icon': Icons.local_offer_rounded, 'label': 'Discounts'},
      {'icon': Icons.settings_rounded, 'label': 'Settings'},
    ];

    // Map desktop indices to mobile tabs
    // 0: Home, 1: Orders, 2: Inventory, 3: Khata, 4: More
    int mapToMobileIndex(int desktopIndex) {
      if (desktopIndex == 0) return 0; // Dashboard
      if (desktopIndex == 1) return 1; // Orders
      if (desktopIndex == 2) return 2; // Products
      if (desktopIndex == 3) return 2; // Categories -> mapping to Products
      if (desktopIndex == 4) return 4; // Customers -> mapping to More
      if (desktopIndex == 5) return 3; // Khata
      if (desktopIndex == 9) return 4; // Settings -> mapping to More
      return 0; // default fallback
    }

    return Container(
      width: 260,
      color: const Color(0xFF136633), // Solid deep green
      child: Column(
        children: [
          // Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Row(
              children: [
                const Icon(Icons.energy_savings_leaf, color: Colors.white, size: 36),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NearKirana', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    Text('Shop Owner Panel', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                final item = navItems[index];
                
                // Show red badge for Orders (index 1)
                final isOrders = index == 1;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      onNavTap(index); // update desktop index
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1D8745) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            color: isSelected ? Colors.white : Colors.white70,
                            size: 22,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (isOrders)
                            _buildOrdersBadge(context),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Logout
          Padding(
            padding: const EdgeInsets.all(24),
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    content: const Text(
                      'Are you sure you want to logout?',
                      style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);

                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('isAdminLoggedIn');
                          await prefs.remove('customerName');
                          await prefs.remove('customerPhone');
                          await prefs.remove('global_phone');
                          await prefs.remove('app_role');

                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GatewayScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded, color: Colors.white70, size: 22),
                  const SizedBox(width: 16),
                  const Text('Logout', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersBadge(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    if (shopId == null || shopId.isEmpty) return const SizedBox();
    
    final query = FirebaseUtils.firestore
        .collection('orders')
        .where('shop_id', isEqualTo: shopId)
        .where('status', whereIn: ['Pending', 'Packed', 'Ready', 'Out for Delivery']);
        
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
        final count = snapshot.data!.docs.length;
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN DASHBOARD CONTENT AREA
// -----------------------------------------------------------------------------

class AdminDesktopHome extends StatelessWidget {
  final Function(int) onNavTap;
  const AdminDesktopHome({super.key, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopHeader(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeSection(context),
                const SizedBox(height: 32),
                _buildKPICards(context),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildSalesOverview()),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: _buildBigSavingsBanner()),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: _buildQuickActions()),
                    const SizedBox(width: 24),
                    Expanded(flex: 5, child: _buildCategories()),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildRecentOrders(context)),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: _buildTopProducts(context)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Search Bar
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                height: 48,
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.search, color: Colors.grey),
                  ),
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search products, customers, orders...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Text('Ctrl + K', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          ),
          const Spacer(),
          // Actions
          _buildHeaderIcon(Icons.notifications_none_rounded, showBadge: true),
          const SizedBox(width: 16),
          _buildHeaderIcon(Icons.chat_bubble_outline_rounded),
          const SizedBox(width: 16),
          _buildHeaderIcon(Icons.settings_outlined),
          const SizedBox(width: 24),
          // Profile
          InkWell(
            onTap: () => onNavTap(10),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.person, color: Color(0xFF136633)),
                  ),
                  const SizedBox(width: 12),
                  const Text('Admin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, {bool showBadge = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: Colors.black87, size: 20),
          if (showBadge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 36,
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.person, size: 40, color: Color(0xFF136633)),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('Good Morning, Admin!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black87)),
                SizedBox(width: 8),
                Text('👋', style: TextStyle(fontSize: 28)),
              ],
            ),
            const SizedBox(height: 4),
            Text("Here's what's happening with your store today", style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICards(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    if (shopId == null || shopId.isEmpty) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseUtils.firestore.collection('orders').where('shop_id', isEqualTo: shopId).snapshots(),
      builder: (context, ordersSnapshot) {
        int todaysOrders = 0;
        double todaysRevenue = 0;
        
        if (ordersSnapshot.hasData) {
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);
          
          for (var doc in ordersSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['created_at'] as Timestamp?;
            if (timestamp != null && timestamp.toDate().isAfter(startOfDay)) {
              todaysOrders++;
              if (['Delivered'].contains(data['status'])) {
                todaysRevenue += double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0;
              }
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseUtils.firestore.collection('customers').where('shop_ids', arrayContains: shopId).snapshots(),
          builder: (context, customersSnapshot) {
            int totalCustomers = 0;
            double totalUdhaar = 0.0;

            if (customersSnapshot.hasData) {
              totalCustomers = customersSnapshot.data!.docs.length;
              for (var doc in customersSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                totalUdhaar += (data['shop_balances']?[shopId] ?? 0).toDouble();
              }
            }

            return Row(
              children: [
                _buildStatCard("Today's Orders", '$todaysOrders', Icons.shopping_bag_rounded, const Color(0xFF1F9444), const Color(0xFFE8F5E9)),
                const SizedBox(width: 20),
                _buildStatCard("Today's Revenue", '₹${todaysRevenue.toStringAsFixed(0)}', Icons.currency_rupee_rounded, const Color(0xFFFF7B00), const Color(0xFFFFF3E0)),
                const SizedBox(width: 20),
                _buildStatCard('Total Customers', '$totalCustomers', Icons.people_alt_rounded, const Color(0xFF007AFF), const Color(0xFFE3F2FD)),
                const SizedBox(width: 20),
                _buildStatCard('Total Udhaar', '₹${totalUdhaar.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded, const Color(0xFFF04456), const Color(0xFFFFEBEE)),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(title, style: TextStyle(fontSize: 14, color: Colors.black.withValues(alpha: 0.6), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesOverview() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sales Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Text('This Week', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const WeeklySalesChart(isDesktop: true),
        ],
      ),
    );
  }

  Widget _buildBigSavingsBanner() {
    return Container(
      height: 275,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1F9444), // Green background
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/images/kirana_web_hero.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Big Savings', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('On Daily Essentials\nUpto 40% OFF', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500, height: 1.4)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1F9444),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Shop Now', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildActionItem('Add Product', Icons.add_circle, Colors.green),
            const SizedBox(width: 16),
            _buildActionItem('Manage Orders', Icons.format_list_bulleted_rounded, Colors.green),
            const SizedBox(width: 16),
            _buildActionItem('Customers', Icons.people_alt_rounded, Colors.blue),
            const SizedBox(width: 16),
            _buildActionItem('Khata', Icons.account_balance_wallet_rounded, Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final categories = [
      {'name': 'Rice', 'icon': Icons.rice_bowl},
      {'name': 'Dal', 'icon': Icons.soup_kitchen},
      {'name': 'Oil', 'icon': Icons.water_drop},
      {'name': 'Spices', 'icon': Icons.spa},
      {'name': 'Snacks', 'icon': Icons.fastfood},
      {'name': 'More', 'icon': Icons.more_horiz},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
            Row(
              children: [
                const Text('See All', style: TextStyle(color: Color(0xFF1F9444), fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: const Color(0xFF1F9444).withValues(alpha: 0.8), size: 16),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: categories.map((cat) {
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Icon(cat['icon'] as IconData, color: const Color(0xFF1F9444), size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(cat['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrders(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    if (shopId == null || shopId.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
            Row(
              children: [
                const Text('View All', style: TextStyle(color: Color(0xFF1F9444), fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: const Color(0xFF1F9444).withValues(alpha: 0.8), size: 16),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseUtils.firestore.collection('orders').where('shop_id', isEqualTo: shopId).orderBy('created_at', descending: true).limit(5).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
              
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(32), child: Text('No recent orders'));

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length + 1,
                separatorBuilder: (context, index) => index == 0 ? const SizedBox() : Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text('Order ID', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 3, child: Text('Customer', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text('Items', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text('Amount', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text('Status', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text('Date', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                          SizedBox(width: 60, child: Text('Action', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                        ],
                      ),
                    );
                  }

                  final data = docs[index - 1].data() as Map<String, dynamic>;
                  final orderId = docs[index - 1].id;
                  final shortId = '#${orderId.substring(orderId.length > 6 ? orderId.length - 6 : 0).toUpperCase()}';
                  final items = (data['items'] as List?)?.length ?? 0;
                  final amount = data['total_amount']?.toString() ?? '0';
                  final status = data['status']?.toString() ?? 'Pending';
                  
                  Color statusColor = Colors.orange;
                  Color statusBg = Colors.orange.shade50;
                  if (status == 'Delivered') {
                    statusColor = Colors.green;
                    statusBg = Colors.green.shade50;
                  } else if (status == 'Cancelled') {
                    statusColor = Colors.red;
                    statusBg = Colors.red.shade50;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(shortId, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 13))),
                        Expanded(flex: 3, child: Row(
                          children: [
                            CircleAvatar(radius: 12, backgroundColor: Colors.grey.shade200, child: const Icon(Icons.person, size: 16, color: Colors.grey)),
                            const SizedBox(width: 8),
                            const Text('Customer', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                          ],
                        )),
                        Expanded(flex: 2, child: Text('$items items', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                        Expanded(flex: 2, child: Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        Expanded(flex: 2, child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                          child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        )),
                        Expanded(flex: 2, child: Text('Today', style: TextStyle(color: Colors.grey.shade500, fontSize: 12))),
                        SizedBox(
                          width: 60,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('View', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildTopProducts(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    if (shopId == null || shopId.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Top Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
            Row(
              children: [
                const Text('See All', style: TextStyle(color: Color(0xFF1F9444), fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: const Color(0xFF1F9444).withValues(alpha: 0.8), size: 16),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseUtils.firestore.collection('products').where('shop_id', isEqualTo: shopId).limit(4).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Text('No products available');

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name']?.toString() ?? 'Product';
                  final price = data['price']?.toString() ?? '0';
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('₹$price', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text('120 Sales', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.black.withValues(alpha: 0.4))),
                      ],
                    ),
                  );
                }).toList(),
              );
            }
          ),
        ),
      ],
    );
  }
}
