import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_home_tab.dart';
import 'admin_orders_tab.dart';
import 'shop_stock_screen.dart';
import 'khata_screen.dart';
import 'admin_more_tab.dart';
import 'app_theme.dart';
import 'package:provider/provider.dart';
import 'shop_provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const AdminHomeTab(),
    const AdminOrdersTab(),
    const ShopStockScreen(),
    const KhataScreen(),
    const AdminMoreTab(),
  ];

  void _onNavTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    final ordersQuery = shopId == null || shopId.isEmpty
        ? FirebaseFirestore.instance.collection('orders').limit(0)
        : FirebaseFirestore.instance
              .collection('orders')
              .where('shop_id', isEqualTo: shopId)
              .where(
                'status',
                whereIn: ['Pending', 'Packed', 'Ready', 'Out for Delivery'],
              );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: ordersQuery.snapshots(),
        builder: (context, snapshot) {
          int activeOrdersCount = 0;
          if (snapshot.hasData) {
            activeOrdersCount = snapshot.data!.docs.length;
          }

          final navItems = [
            _NavItem(
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard_rounded,
              label: 'Home',
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long_rounded,
              label: 'Orders',
              badge: activeOrdersCount,
            ),
            _NavItem(
              icon: Icons.inventory_2_outlined,
              selectedIcon: Icons.inventory_2_rounded,
              label: 'Inventory',
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet_rounded,
              label: 'Khata',
            ),
            _NavItem(
              icon: Icons.more_horiz_outlined,
              selectedIcon: Icons.more_horiz_rounded,
              label: 'More',
            ),
          ];

          return Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: navItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final isSelected = _selectedIndex == i;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onNavTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryLight.withValues(alpha: 0.35)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isSelected ? item.selectedIcon : item.icon,
                                  key: ValueKey(isSelected),
                                  color: isSelected
                                      ? AppColors.primaryDark
                                      : AppColors.textLight,
                                  size: 24,
                                ),
                              ),
                              if (item.badge != null && item.badge! > 0)
                                Positioned(
                                  top: -6,
                                  right: -8,
                                  child:
                                      Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(
                                              color: AppColors.error,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 18,
                                              minHeight: 18,
                                            ),
                                            child: Text(
                                              item.badge! > 9
                                                  ? '9+'
                                                  : '${item.badge}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                          .animate(key: ValueKey(item.badge))
                                          .scale(
                                            begin: const Offset(0.5, 0.5),
                                            end: const Offset(1, 1),
                                            duration: 250.ms,
                                            curve: Curves.elasticOut,
                                          ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 10, // slightly smaller for 5 tabs
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primaryDark
                                  : AppColors.textLight,
                            ),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
        },
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? badge;

  _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge,
  });
}
