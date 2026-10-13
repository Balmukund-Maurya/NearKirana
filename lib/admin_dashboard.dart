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
import 'package:near_kirana/firebase_utils.dart';
import 'admin_desktop_dashboard.dart';
import 'admin_customers_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_shop_boys_screen.dart';
import 'admin_discounts_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_user_profile_screen.dart';
import 'admin_language_theme_screen.dart';
import 'admin_orders_desktop_view.dart';
import 'admin_customers_desktop_view.dart';
import 'admin_khata_desktop_view.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  /// Static callback so child screens can trigger sidebar navigation
  /// without requiring a direct reference to the state.
  static Function(int)? navCallback;

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
  void initState() {
    super.initState();
    AdminDashboard.navCallback = _onNavTap;
  }

  @override
  void dispose() {
    AdminDashboard.navCallback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    final ordersQuery = shopId == null || shopId.isEmpty
        ? FirebaseUtils.firestore.collection('orders').limit(0)
        : FirebaseUtils.firestore
              .collection('orders')
              .where('shop_id', isEqualTo: shopId)
              .where(
                'status',
                whereIn: ['Pending', 'Packed', 'Ready', 'Out for Delivery'],
              );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          // Map desktop 10-item index to our mobile tabs when needed
          // 0: AdminHomeTab (but desktop has its own Home)
          // 1: AdminOrdersTab
          // 2: ShopStockScreen
          // 3: Categories (mapped to 2 or 4)
          // 4: Customers (mapped to 4)
          // 5: KhataScreen (mapped to 3)
          // 6: Shop Boys
          // 7: Analytics
          // 8: Discounts
          // 9: AdminSettingsScreen (mapped to 4)
          
          int effectiveIndex = 0;
          if (_selectedIndex == 0) effectiveIndex = 0;
          else if (_selectedIndex == 1) effectiveIndex = 1;
          else if (_selectedIndex == 2) effectiveIndex = 2; // Products
          else if (_selectedIndex == 3) effectiveIndex = 2; // Categories -> Stock
          else if (_selectedIndex == 4) effectiveIndex = 4; // Customers -> More
          else if (_selectedIndex == 5) effectiveIndex = 3; // Khata
          else if (_selectedIndex == 6) effectiveIndex = 4; // Shop Boys -> More
          else if (_selectedIndex == 7) effectiveIndex = 0; // Analytics -> Home
          else if (_selectedIndex == 8) effectiveIndex = 4; // Discounts -> More
          else if (_selectedIndex == 9) effectiveIndex = 4; // Settings -> More
          else if (_selectedIndex == 10) effectiveIndex = 0; // Profile -> Doesn't matter
          else if (_selectedIndex == 11) effectiveIndex = 0; // Language & Theme -> Doesn't matter

          print('AdminDashboard BUILD: _selectedIndex=$_selectedIndex, effectiveIndex=$effectiveIndex');

          return AdminDesktopDashboard(
            selectedIndex: _selectedIndex,
            onNavTap: _onNavTap,
            child: (_selectedIndex == 1 || _selectedIndex == 4 || _selectedIndex == 5 || effectiveIndex == 2 || _selectedIndex == 9 || _selectedIndex == 6 || _selectedIndex == 8 || _selectedIndex == 7 || _selectedIndex == 10 || _selectedIndex == 11)
                ? _buildDesktopScreen(_selectedIndex)
                : Scaffold(
              backgroundColor: const Color(0xFFF0F2F5),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Container(
                    margin: const EdgeInsets.only(top: 24, left: 24, right: 24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: _buildDesktopScreen(_selectedIndex),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

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
      },
    );
  }

  Widget _buildDesktopScreen(int index) {
    print('BUILDING DESKTOP SCREEN FOR INDEX: $index');
    switch (index) {
      case 0:
        return const AdminHomeTab();
      case 1:
        return const AdminOrdersDesktopView();
      case 2:
        return const ShopStockScreen();
      case 3:
        return const AdminCategoriesScreen();
      case 4:
        return const AdminCustomersDesktopView();
      case 5:
        return const AdminKhataDesktopView();
      case 6:
        return const AdminShopBoysScreen();
      case 7:
        return const AdminAnalyticsScreen();
      case 8:
        return const AdminDiscountsScreen();
      case 9:
        return const AdminSettingsScreen();
      case 10:
        return const AdminUserProfileScreen();
      case 11:
        return const AdminLanguageThemeScreen();
      default:
        return const AdminMoreTab();
    }
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
