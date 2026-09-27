import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'customer_shop_tab.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'customer_profile_tab.dart';
import 'cart_provider.dart';
import 'app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const CustomerShopTab(),
    const CartScreen(isTab: true),
    const MyOrdersScreen(isTab: true),
    const CustomerProfileTab(),
  ];

  void _onNavTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = AppLocalizations.of(context)!;
    final cartProvider = Provider.of<CartProvider>(context);
    final cartCount = cartProvider.itemCount;

    final navItems = [
      _NavItem(
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront_rounded,
        label: langProvider.shop_tab,
      ),
      _NavItem(
        icon: Icons.shopping_cart_outlined,
        selectedIcon: Icons.shopping_cart_rounded,
        label: langProvider.cart_tab,
        badge: cartCount,
      ),
      _NavItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: langProvider.orders_tab,
      ),
      _NavItem(
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: langProvider.profile,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          // DESKTOP LAYOUT (Blinkit Style)
          return Scaffold(
            backgroundColor: const Color(0xFFF0F2F5),
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Row(
                  children: [
                    // Logo
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: AppDecorations.primaryGradient(radius: 12),
                          child: const Icon(
                            Icons.shopping_basket_rounded,
                            color: AppColors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "NearKirana",
                          style: AppTextStyles.heading2(color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Nav Items (Right aligned)
                    Row(
                      children: navItems.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final isSelected = _selectedIndex == i;

                        return Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: InkWell(
                            onTap: () => _onNavTap(i),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryLight.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    color: isSelected
                                        ? AppColors.primaryDark
                                        : AppColors.textMid,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primaryDark
                                          : AppColors.textMid,
                                    ),
                                  ),
                                  if (item.badge != null && item.badge! > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        item.badge.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Container(
                  margin: const EdgeInsets.only(top: 24),
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
                    child: IndexedStack(index: _selectedIndex, children: _tabs),
                  ),
                ),
              ),
            ),
          );
        }

        // MOBILE LAYOUT
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: IndexedStack(index: _selectedIndex, children: _tabs),
          bottomNavigationBar: Container(
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
                            horizontal: 4,
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
                                  fontSize: 11,
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
          ),
        );
      },
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
