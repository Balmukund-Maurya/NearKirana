import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'user_provider.dart';
import 'shop_provider.dart';
import 'cart_provider.dart';
import 'language_provider.dart';
import 'app_theme.dart';
import 'firebase_utils.dart';
import 'utils/product_image_widget.dart';

class DesktopCustomerDashboard extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onNavTap;
  final Widget child; // For other tabs

  const DesktopCustomerDashboard({
    super.key,
    required this.selectedIndex,
    required this.onNavTap,
    required this.child,
  });

  @override
  State<DesktopCustomerDashboard> createState() =>
      _DesktopCustomerDashboardState();
}

class _DesktopCustomerDashboardState extends State<DesktopCustomerDashboard> {
  int? _localSelectedIndex;

  @override
  void initState() {
    super.initState();
    _localSelectedIndex = _getDesktopIndex(widget.selectedIndex);
  }

  @override
  void didUpdateWidget(DesktopCustomerDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      int currentMappedTarget = _getTargetIndex(_localSelectedIndex ?? 0);
      if (currentMappedTarget != widget.selectedIndex) {
        _localSelectedIndex = _getDesktopIndex(widget.selectedIndex);
      }
    }
  }

  int _getDesktopIndex(int mobileIndex) {
    if (mobileIndex == 0) return 0; // Browse Products
    if (mobileIndex == 1)
      return 0; // Cart (Shown on right side of Browse Products)
    if (mobileIndex == 2) return 1; // My Orders
    if (mobileIndex == 3) return 5; // My Profile
    if (mobileIndex == 4) return 2; // My Khata
    if (mobileIndex == 5) return 3; // Offers & Discounts
    if (mobileIndex == 6) return 4; // My Wishlist
    if (mobileIndex == 7) return 6; // Settings
    return 0;
  }

  int _getTargetIndex(int desktopIndex) {
    if (desktopIndex == 0) return 0; // Browse Products -> CustomerShopTab
    if (desktopIndex == 1) return 2; // My Orders -> MyOrdersScreen
    if (desktopIndex == 2) return 4; // My Khata -> DesktopKhataView
    if (desktopIndex == 3) return 5; // Offers & Discounts -> DesktopOffersView
    if (desktopIndex == 4) return 6; // My Wishlist -> DesktopWishlistView
    if (desktopIndex == 5) return 3; // My Profile -> CustomerProfileTab
    if (desktopIndex == 6) return 7; // Settings -> DesktopSettingsView
    return 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT: Fixed dark-green customer sidebar
          _buildSidebar(context),

          // CENTER & RIGHT
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(context),
                Expanded(
                  child: _localSelectedIndex == 0
                      ? _buildDashboardLayout(context, widget.child)
                      : widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final cartCount = Provider.of<CartProvider>(context).itemCount;

    final navItems = [
      {'icon': Icons.storefront_rounded, 'label': 'Browse Products'},
      {'icon': Icons.receipt_long_outlined, 'label': 'My Orders'},
      {'icon': Icons.menu_book_rounded, 'label': 'My Khata'},
      {'icon': Icons.local_offer_outlined, 'label': 'Offers & Discounts'},
      {'icon': Icons.favorite_border_rounded, 'label': 'My Wishlist'},
      {'icon': Icons.person_outline_rounded, 'label': 'My Profile'},
      {'icon': Icons.settings_outlined, 'label': 'Settings'},
      {'icon': Icons.logout_rounded, 'label': 'Logout'},
    ];

    return Container(
      width: 240,
      color: AppColors.primaryDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Area
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.energy_savings_leaf,
                    color: AppColors.primaryDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NearKirana',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Your Neighborhood Store',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Nav Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = _localSelectedIndex == index;

                int targetIndex = _getTargetIndex(index);

                if (index == navItems.length - 1) {
                  // Logout
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: _buildNavItem(item, false, () {
                      UserProvider userProvider = Provider.of<UserProvider>(
                        context,
                        listen: false,
                      );
                      userProvider.logout().then((_) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (route) => false,
                        );
                      });
                    }),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildNavItem(item, isSelected, () {
                    setState(() => _localSelectedIndex = index);
                    widget.onNavTap(targetIndex);
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    Map<String, dynamic> item,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF138855) // Lighter green for active state
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFF1B8B5B), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              item['icon'] as IconData,
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              item['label'] as String,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (item['badge'] != null && (item['badge'] as int) > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${item['badge']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardLayout(BuildContext context, Widget centerChild) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CENTER COLUMN
        Expanded(flex: 7, child: centerChild),

        // RIGHT COLUMN
        Container(
          width: 320,
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMyCartRightCol(context),
                const SizedBox(height: 24),
                _buildRecentOrdersRightCol(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCenter(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(context),
          const SizedBox(height: 32),
          _buildSummaryCards(context),
          const SizedBox(height: 32),
          _buildPromoSection(context),
          const SizedBox(height: 32),
          _buildCategoriesSection(context),
          const SizedBox(height: 32),
          _buildRecommendedSection(context),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final customerName = userProvider.customerName;

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Colors.grey),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText:
                            'Search for products, shops, or categories...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'Ctrl + K',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Location
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primaryDark,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  userProvider.autoLocality.isNotEmpty
                      ? userProvider.autoLocality
                      : 'Location',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Actions
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              const CircleAvatar(
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/150?img=11',
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Rahul Kumar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(
                      'https://i.pravatar.cc/150?img=11',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Welcome back, Rahul!',
                                style: AppTextStyles.heading1(
                                  color: AppColors.textDark,
                                ).copyWith(fontSize: 28),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('👋', style: TextStyle(fontSize: 24)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Find fresh groceries and daily essentials from your nearby shops',
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.textMid,
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
        const SizedBox(width: 16),
        // Delivery Location Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deliver to',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const Text(
                      'Home, Sector 62...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryLight.withValues(
                    alpha: 0.2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(
          'Your Orders',
          '12',
          'Total Orders',
          Icons.shopping_bag_rounded,
          const Color(0xFF1F9444),
          const Color(0xFFE8F5E9),
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Saved Items',
          '8',
          'Items',
          Icons.favorite_rounded,
          const Color(0xFFFF7B00),
          const Color(0xFFFFF3E0),
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Available Offers',
          '6',
          'Active',
          Icons.local_offer_rounded,
          const Color(0xFF007AFF),
          const Color(0xFFE3F2FD),
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Your Khata',
          '₹1,250',
          'Outstanding',
          Icons.account_balance_wallet_rounded,
          const Color(0xFFF04456),
          const Color(0xFFFFEBEE),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor, // Use the bgColor for the card background
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoSection(BuildContext context) {
    return Row(
      children: [
        // Main Banner
        Expanded(
          flex: 7,
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(24),
              image: const DecorationImage(
                image: AssetImage('assets/images/kirana_web_hero.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Fresh Groceries\nAt Your Doorstep',
                          style: AppTextStyles.heading1(
                            color: AppColors.primaryDark,
                          ).copyWith(fontSize: 28, height: 1.2),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Wide range of daily essentials\nfrom your nearby shops',
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Shop Now',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.shopping_basket_rounded,
                    size: 100,
                    color: AppColors.primaryDark,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Small Offer Card
        Expanded(
          flex: 3,
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Big Savings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'On Daily Essentials\nUpto 40% OFF',
                  style: TextStyle(color: Colors.black87, fontSize: 16),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('View Offers →'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection(BuildContext context) {
    List<Map<String, dynamic>> categories = [
      {
        'name': 'Rice',
        'image': 'https://cdn-icons-png.flaticon.com/512/3014/3014502.png',
      },
      {
        'name': 'Dal',
        'image': 'https://cdn-icons-png.flaticon.com/512/5029/5029253.png',
      },
      {
        'name': 'Oil',
        'image': 'https://cdn-icons-png.flaticon.com/512/3014/3014524.png',
      },
      {
        'name': 'Spices',
        'image': 'https://cdn-icons-png.flaticon.com/512/3361/3361131.png',
      },
      {
        'name': 'Snacks',
        'image': 'https://cdn-icons-png.flaticon.com/512/2733/2733470.png',
      },
      {
        'name': 'Beverages',
        'image': 'https://cdn-icons-png.flaticon.com/512/2738/2738730.png',
      },
      {
        'name': 'Personal Care',
        'image': 'https://cdn-icons-png.flaticon.com/512/3055/3055416.png',
      },
      {
        'name': 'Household',
        'image': 'https://cdn-icons-png.flaticon.com/512/2857/2857218.png',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Shop by Category',
              style: AppTextStyles.heading2(color: AppColors.textDark),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'See All →',
                style: TextStyle(color: AppColors.primaryDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...categories.map(
                (cat) => _buildCategoryCard(cat['name'], cat['image']),
              ),
              _buildCategoryCard('More', null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String name, String? imageUrl) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(color: Colors.transparent),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    width: 28,
                    height: 28,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.category_rounded,
                      color: AppColors.primaryDark,
                      size: 28,
                    ),
                  )
                : const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.primaryDark,
                    size: 28,
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection(BuildContext context) {
    List<Map<String, dynamic>> products = [
      {
        'name': 'Daawat Basmati Rice',
        'price': 520,
        'mrp': 600,
        'unit': '5 kg',
        'image': 'https://cdn-icons-png.flaticon.com/512/3014/3014502.png',
        'off': '10% OFF',
      },
      {
        'name': 'Fortune Sunflower Oil',
        'price': 150,
        'mrp': 150,
        'unit': '1 L',
        'image': 'https://cdn-icons-png.flaticon.com/512/3014/3014524.png',
        'off': null,
      },
      {
        'name': 'Tata Salt',
        'price': 28,
        'mrp': 28,
        'unit': '1 kg',
        'image': 'https://cdn-icons-png.flaticon.com/512/3361/3361131.png',
        'off': null,
      },
      {
        'name': 'Maggi Noodles',
        'price': 14,
        'mrp': 14,
        'unit': '70 g',
        'image': 'https://cdn-icons-png.flaticon.com/512/2733/2733470.png',
        'off': null,
      },
      {
        'name': 'Aashirvaad Atta',
        'price': 210,
        'mrp': 225,
        'unit': '5 kg',
        'image': 'https://cdn-icons-png.flaticon.com/512/3014/3014502.png',
        'off': '5% OFF',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommended for You',
              style: AppTextStyles.heading2(color: AppColors.textDark),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'See All →',
                style: TextStyle(color: AppColors.primaryDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: products
                .map((data) => _buildMockProductCard(context, data))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMockProductCard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final name = data['name'];
    final price = data['price'];
    final unit = data['unit'];
    final off = data['off'];

    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 20, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Icon(
              Icons.favorite_border_rounded,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ),
          Center(
            child: SizedBox(
              height: 100,
              width: 100,
              child: Image.network(
                data['image'],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 50),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹$price',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (off != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    off,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Add to Cart'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCartRightCol(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final items = cartProvider.itemsList;
    final totalAmount = cartProvider.cartTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cart Container
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'My Cart (${items.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        cartProvider.clearCart();
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 36),
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          color: Color(0xFF1976D2),
                          fontSize: 13,
                        ), // Blue text
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      'Your cart is empty',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 60,
                            width: 60,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: item.imageUrl != null
                                ? Image.network(
                                    item.imageUrl!,
                                    fit: BoxFit.contain,
                                  )
                                : const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.isLoose ? item.quantity : item.quantity.toInt()} ${item.isLoose ? 'kg' : 'units'}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              if (item.quantity >
                                                  (item.isLoose ? 0.5 : 1)) {
                                                cartProvider.setQuantity(
                                                  item.id,
                                                  item.quantity -
                                                      (item.isLoose ? 0.5 : 1),
                                                );
                                              } else {
                                                cartProvider.removeItem(
                                                  item.id,
                                                );
                                              }
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              child: Text(
                                                '-',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${item.isLoose ? item.quantity : item.quantity.toInt()}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              cartProvider.setQuantity(
                                                item.id,
                                                item.quantity +
                                                    (item.isLoose ? 0.5 : 1),
                                              );
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              child: Text(
                                                '+',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
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
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${item.price.toInt()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () {
                                  cartProvider.removeItem(item.id);
                                },
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const Divider(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      '₹${totalAmount.toInt()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: items.isEmpty ? null : () {},
                  icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                  label: const Text(
                    'Place Order',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Special Offers Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.percent_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Special Offers',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Get up to 20% off on selected products',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.primaryDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Free Delivery Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.primaryDark,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free Delivery',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'On orders above ₹499',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrdersRightCol(BuildContext context) {
    List<Map<String, dynamic>> orders = [
      {
        'id': '#AK1024',
        'date': '12 Aug 2024, 4:32 PM',
        'amount': 866,
        'status': 'Preparing',
        'image': 'https://cdn-icons-png.flaticon.com/512/3014/3014502.png',
      },
      {
        'id': '#AK1023',
        'date': '12 Aug 2024, 2:15 PM',
        'amount': 920,
        'status': 'Delivered',
        'image': 'https://cdn-icons-png.flaticon.com/512/3014/3014524.png',
      },
      {
        'id': '#AK1022',
        'date': '10 Aug 2024, 9:10 AM',
        'amount': 450,
        'status': 'Cancelled',
        'image': 'https://cdn-icons-png.flaticon.com/512/3361/3361131.png',
      },
      {
        'id': '#AK1021',
        'date': '8 Aug 2024, 9:10 AM',
        'amount': 1250,
        'status': 'Delivered',
        'image': 'https://cdn-icons-png.flaticon.com/512/2733/2733470.png',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Recent Orders',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 36),
                ),
                child: const Text(
                  'View All →',
                  style: TextStyle(color: AppColors.primaryDark, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: orders.map((order) {
              Color statusColor = Colors.orange;
              Color statusBg = Colors.orange.shade50;
              if (order['status'] == 'Delivered') {
                statusColor = Colors.green;
                statusBg = Colors.green.shade50;
              } else if (order['status'] == 'Cancelled') {
                statusColor = Colors.red;
                statusBg = Colors.red.shade50;
              } else if (order['status'] == 'Preparing') {
                statusColor = Colors.orange;
                statusBg = Colors.orange.shade50;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.network(order['image']),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['id'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            order['date'],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${order['amount']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order['status'],
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
