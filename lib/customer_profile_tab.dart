import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'user_provider.dart';
import 'cart_provider.dart';
import 'gateway_screen.dart';
import 'language_provider.dart';
import 'app_theme.dart';
import 'sound_service.dart';
import 'my_orders_screen.dart';
import 'khata_statement_screen.dart';
import 'shop_provider.dart';
import 'shop_selector_screen.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'utils/product_image_widget.dart';
import 'modern_loader.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'customer_profile_desktop_wrapper.dart';
import 'address_selection_bottom_sheet.dart';
import 'shopping_lists_screen.dart';
import 'customer_loyalty_screen.dart';

class CustomerProfileTab extends StatefulWidget {
  const CustomerProfileTab({super.key});

  @override
  State<CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends State<CustomerProfileTab> {
  bool _isLoadingKhata = true;
  bool _hasKhata = false;
  String? _khataCustomerId;
  String? _checkedPhone;
  String? _checkedShopId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCustomerKhata();
    });
  }

  /// Verifies if the customer has an active Khata created by the shop owner for this shop
  Future<void> _checkCustomerKhata() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final String rawPhone = userProvider.phoneNumber.trim();
      final String shopId = shopProvider.currentShopId ?? '';

      if (rawPhone == _checkedPhone && shopId == _checkedShopId && !_isLoadingKhata) {
        return;
      }
      _checkedPhone = rawPhone;
      _checkedShopId = shopId;

      if (rawPhone.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingKhata = false;
            _hasKhata = false;
            _khataCustomerId = null;
          });
        }
        return;
      }

      String cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length > 10) {
        cleanPhone = cleanPhone.substring(cleanPhone.length - 10);
      }

      final phonesToSearch = <String>{
        rawPhone,
        cleanPhone,
        if (cleanPhone.isNotEmpty) '+91$cleanPhone',
        if (cleanPhone.isNotEmpty) '91$cleanPhone',
      }.where((p) => p.isNotEmpty).toList();

      final querySnapshot = await FirebaseUtils.firestore
          .collection('customers')
          .where('mobile', whereIn: phonesToSearch.take(10).toList())
          .get();

      bool foundKhata = false;
      String? foundCustomerId;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final shopIds = (data['shop_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final shopBalances = data['shop_balances'] as Map<String, dynamic>?;

        // Customer must be created by shop owner for this shop
        if (shopId.isEmpty ||
            shopIds.contains(shopId) ||
            (shopBalances != null && shopBalances.containsKey(shopId))) {
          if (data['is_banned'] != true) {
            foundKhata = true;
            foundCustomerId = doc.id;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingKhata = false;
          _hasKhata = foundKhata;
          _khataCustomerId = foundCustomerId;
        });
      }
    } catch (e) {
      debugPrint('Error verifying Khata for customer profile: $e');
      if (mounted) {
        setState(() {
          _isLoadingKhata = false;
          _hasKhata = false;
          _khataCustomerId = null;
        });
      }
    }
  }

  void _showEditNameDialog(BuildContext context, UserProvider userProvider, bool isHindi, bool isHinglish) {
    final controller = TextEditingController(text: userProvider.customerName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isHindi ? 'नाम बदलें' : (isHinglish ? 'Name Edit Karein' : 'Edit Your Name'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: isHindi ? 'अपना नाम दर्ज करें' : (isHinglish ? 'Apna naam enter karein' : 'Enter your full name'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isHindi ? 'रद्द करें' : 'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await userProvider.updateCustomerName(newName);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isHindi ? 'सहेजें' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 800) {
      return const CustomerProfileDesktopWrapper();
    }

    final userProvider = Provider.of<UserProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);

    final isHindi = langProvider.isHindi;
    final isHinglish = langProvider.isHinglish;

    // Check Khata if shop or phone changed
    final currentPhone = userProvider.phoneNumber.trim();
    final currentShopId = shopProvider.currentShopId ?? '';
    if ((currentPhone != _checkedPhone || currentShopId != _checkedShopId) && !_isLoadingKhata) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkCustomerKhata());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          isHindi ? 'मेरी प्रोफाइल' : (isHinglish ? 'My Profile' : 'My Profile'),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zepto / Blinkit Style Profile Header Card
            _buildProfileHeaderCard(
              context: context,
              userProvider: userProvider,
              shopProvider: shopProvider,
              isHindi: isHindi,
              isHinglish: isHinglish,
            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 16),

            // Quick Actions 2x2 Grid (Orders, Khata, Addresses, Lists)
            _buildQuickActionGrid(
              context: context,
              userProvider: userProvider,
              shopProvider: shopProvider,
              isHindi: isHindi,
              isHinglish: isHinglish,
            ).animate().fadeIn(delay: 50.ms, duration: 250.ms),

            const SizedBox(height: 16),

            // Section 1: Savings & Rewards (Zepto / Blinkit Group Card)
            _buildSectionHeader(
              isHindi ? 'बचत और रिवार्ड्स' : (isHinglish ? 'SAVINGS & REWARDS' : 'SAVINGS & REWARDS'),
            ),
            const SizedBox(height: 8),
            _buildRewardsCard(
              context: context,
              userProvider: userProvider,
              shopProvider: shopProvider,
              isHindi: isHindi,
              isHinglish: isHinglish,
            ).animate().fadeIn(delay: 100.ms, duration: 250.ms),

            const SizedBox(height: 20),

            // Section 2: Preferences (Language & Saved Addresses)
            _buildSectionHeader(
              isHindi ? 'ऐप सेटिंग्स' : (isHinglish ? 'PREFERENCES' : 'PREFERENCES'),
            ),
            const SizedBox(height: 8),
            _buildPreferencesCard(
              context: context,
              langProvider: langProvider,
              userProvider: userProvider,
              isHindi: isHindi,
              isHinglish: isHinglish,
            ).animate().fadeIn(delay: 150.ms, duration: 250.ms),

            const SizedBox(height: 20),

            // Section 3: Store & Helpdesk Support
            _buildSectionHeader(
              isHindi ? 'दुकान और सहायता' : (isHinglish ? 'STORE & SUPPORT' : 'STORE & SUPPORT'),
            ),
            const SizedBox(height: 8),
            _buildSupportGroupCard(
              context: context,
              shopProvider: shopProvider,
              userProvider: userProvider,
              isHindi: isHindi,
              isHinglish: isHinglish,
            ).animate().fadeIn(delay: 200.ms, duration: 250.ms),

            const SizedBox(height: 20),

            // Section 4: Account Actions (Logout)
            _buildLogoutCard(
              context: context,
              userProvider: userProvider,
              isHindi: isHindi,
              isHinglish: isHinglish,
            ).animate().fadeIn(delay: 250.ms, duration: 250.ms),

            const SizedBox(height: 24),

            // App Branding & Version Footer
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.store_mall_directory_rounded,
                          size: 14,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'NearKirana • v1.0.0',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHindi
                        ? 'स्थानीय किराना स्टोर द्वारा संचालित'
                        : (isHinglish
                            ? 'Local Kirana stores ke liye banaya gaya'
                            : 'Empowering your neighborhood Kirana stores'),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// Modern Zepto / Blinkit Profile Header Card
  Widget _buildProfileHeaderCard({
    required BuildContext context,
    required UserProvider userProvider,
    required ShopProvider shopProvider,
    required bool isHindi,
    required bool isHinglish,
  }) {
    final customerName = userProvider.customerName.trim().isNotEmpty
        ? userProvider.customerName.trim()
        : (isHindi ? 'ग्राहक' : (isHinglish ? 'Customer' : 'Customer'));
    final phone = userProvider.phoneNumber.trim();
    final shopName = shopProvider.shopName ?? 'Kirana Store';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with camera icon
              _ProfileAvatar(userProvider: userProvider),
              const SizedBox(width: 16),
              // User Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customerName,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showEditNameDialog(context, userProvider, isHindi, isHinglish);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          phone.isNotEmpty ? phone : '+91 9XXXXXXXXX',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 11,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isHindi ? 'वेरीफाइड' : 'Verified',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF15803D),
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
            ],
          ),
          const SizedBox(height: 14),
          // Current Connected Kirana Store Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isHindi
                        ? 'किराना दुकान: $shopName'
                        : (isHinglish ? 'Connected Store: $shopName' : 'Active Store: $shopName'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _handleSwitchShop(context, isHindi, isHinglish),
                  child: Text(
                    isHindi ? 'बदलें' : (isHinglish ? 'Badlein' : 'Change'),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2-column Quick Action Grid (My Orders, Khata, Addresses, Lists)
  Widget _buildQuickActionGrid({
    required BuildContext context,
    required UserProvider userProvider,
    required ShopProvider shopProvider,
    required bool isHindi,
    required bool isHinglish,
  }) {
    // Collect visible tiles
    final tiles = <Widget>[];

    // 1. My Orders (Always visible)
    tiles.add(
      _buildGridActionTile(
        icon: Icons.receipt_long_rounded,
        iconBg: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF059669),
        title: isHindi ? 'मेरे ऑर्डर' : (isHinglish ? 'My Orders' : 'My Orders'),
        subtitle: isHindi
            ? 'ऑर्डर इतिहास देखें'
            : (isHinglish ? 'Track & past orders' : 'Track & past orders'),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
          );
        },
      ),
    );

    // 2. Kirana Khata (STRICT RULE: ONLY visible if shop owner has created this customer's khata)
    if (_hasKhata && _khataCustomerId != null) {
      tiles.add(
        _buildGridActionTile(
          icon: Icons.menu_book_rounded,
          iconBg: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          title: isHindi ? 'किराना खाता' : (isHinglish ? 'Kirana Khata' : 'Kirana Khata'),
          subtitle: isHindi
              ? 'बहीखाता और उधार'
              : (isHinglish ? 'Ledger & udhaar balance' : 'Shop ledger & balance'),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KhataStatementScreen(
                  customerId: _khataCustomerId!,
                  customerName: userProvider.customerName.isNotEmpty
                      ? userProvider.customerName
                      : 'Customer',
                  isAdmin: false,
                ),
              ),
            );
          },
        ),
      );
    }

    // 3. Saved Addresses
    tiles.add(
      _buildGridActionTile(
        icon: Icons.location_on_rounded,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        title: isHindi ? 'डिलीवरी पते' : (isHinglish ? 'Saved Addresses' : 'Addresses'),
        subtitle: isHindi
            ? 'पते प्रबंधित करें'
            : (isHinglish ? 'Manage saved locations' : 'Manage delivery addresses'),
        onTap: () {
          HapticFeedback.lightImpact();
          AddressSelectionBottomSheet.show(context, isCheckoutMode: false);
        },
      ),
    );

    // 4. Shopping Lists & Reorder
    tiles.add(
      _buildGridActionTile(
        icon: Icons.bookmark_border_rounded,
        iconBg: const Color(0xFFF3E8FF),
        iconColor: const Color(0xFF7C3AED),
        title: isHindi ? 'शॉपिंग लिस्ट' : (isHinglish ? 'Shopping Lists' : 'Shopping Lists'),
        subtitle: isHindi
            ? 'साप्ताहिक सामान और रिपीट'
            : (isHinglish ? 'Weekly grocery & reorder' : 'Saved lists & reorder'),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ShoppingListsScreen()),
          );
        },
      ),
    );

    // Render as a 2-column Wrap/Row grid
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tiles.map((t) => SizedBox(width: itemWidth, child: t)).toList(),
        );
      },
    );
  }

  Widget _buildGridActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Section 1: Rewards Card
  Widget _buildRewardsCard({
    required BuildContext context,
    required UserProvider userProvider,
    required ShopProvider shopProvider,
    required bool isHindi,
    required bool isHinglish,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.stars_rounded,
            color: Color(0xFFD97706),
            size: 22,
          ),
        ),
        title: Text(
          isHindi
              ? 'रिवार्ड्स और रेफरल'
              : (isHinglish ? 'Rewards & Referrals' : 'Rewards & Referrals'),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          isHindi
              ? 'किराने पर पॉइंट कमाएं, कोड शेयर करें और छूट पाएं'
              : (isHinglish
                  ? 'Points earn karein aur grocery discounts paayein'
                  : 'Earn grocery points, invite neighbors & get discounts'),
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: const Color(0xFF64748B),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF94A3B8),
          size: 20,
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          final effectiveShopId = shopProvider.currentShopId ?? 'primary_shop';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerLoyaltyScreen(
                shopId: effectiveShopId,
                customerPhone: userProvider.phoneNumber,
                customerName: userProvider.customerName.isNotEmpty
                    ? userProvider.customerName
                    : 'Customer',
              ),
            ),
          );
        },
      ),
    );
  }

  /// Section 2: Preferences Group Card (Language & Delivery Address)
  Widget _buildPreferencesCard({
    required BuildContext context,
    required LanguageProvider langProvider,
    required UserProvider userProvider,
    required bool isHindi,
    required bool isHinglish,
  }) {
    final addresses = userProvider.savedAddressesList;
    final defaultAddr = addresses.where((a) => a.isDefault).firstOrNull ??
        addresses.firstOrNull;
    final displayAddress = defaultAddr?.address ?? userProvider.deliveryAddress;
    final displayLabel = defaultAddr?.label ?? userProvider.addressLabel;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Language Row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        color: Color(0xFF2563EB),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isHindi ? 'ऐप की भाषा' : (isHinglish ? 'App Language' : 'App Language'),
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildLanguageChip(
                      langProvider: langProvider,
                      code: 'en',
                      label: 'English',
                    ),
                    const SizedBox(width: 8),
                    _buildLanguageChip(
                      langProvider: langProvider,
                      code: 'hi',
                      label: 'हिंदी',
                    ),
                    const SizedBox(width: 8),
                    _buildLanguageChip(
                      langProvider: langProvider,
                      code: 'hinglish',
                      label: 'Hinglish',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Address Row
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.home_work_outlined,
                color: Color(0xFF059669),
                size: 18,
              ),
            ),
            title: Text(
              displayLabel.isNotEmpty ? displayLabel : (isHindi ? 'प्राथमिक पता' : 'Primary Address'),
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              displayAddress.isNotEmpty
                  ? displayAddress
                  : (isHindi ? 'कोई पता नहीं जोड़ा गया' : 'No saved address added yet'),
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              isHindi ? 'बदलें' : (isHinglish ? 'Manage' : 'Manage'),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              AddressSelectionBottomSheet.show(context, isCheckoutMode: false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageChip({
    required LanguageProvider langProvider,
    required String code,
    required String label,
  }) {
    final isSelected = langProvider.currentLanguage == code;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          langProvider.setLanguage(code);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primaryDark : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  /// Section 3: Support Group Card (Call Store, WhatsApp, Switch Shop)
  Widget _buildSupportGroupCard({
    required BuildContext context,
    required ShopProvider shopProvider,
    required UserProvider userProvider,
    required bool isHindi,
    required bool isHinglish,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Call Store
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: Color(0xFFEA580C),
                size: 18,
              ),
            ),
            title: Text(
              isHindi ? 'दुकानदार से बात करें' : (isHinglish ? 'Store ko Call karein' : 'Call Store'),
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              isHindi ? 'सीधे दुकान पर फोन मिलाएं' : 'Speak directly with store owner',
              style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
            onTap: () => _handleCallShop(context, shopProvider, isHindi),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // WhatsApp Support
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF16A34A),
                size: 18,
              ),
            ),
            title: Text(
              isHindi ? 'व्हाट्सएप पर सहायता' : (isHinglish ? 'WhatsApp Helpdesk' : 'WhatsApp Support'),
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              isHindi ? 'ऑर्डर या डिलीवरी के लिए चैट करें' : 'Chat for queries & delivery assistance',
              style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
            onTap: () => _handleWhatsApp(context, shopProvider, userProvider),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Change Shop
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFF2563EB),
                size: 18,
              ),
            ),
            title: Text(
              isHindi ? 'दुकान बदलें' : (isHinglish ? 'Kirana Shop badlein' : 'Switch Kirana Store'),
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              isHindi ? 'पास की अन्य दुकान चुनें' : 'Browse or scan another neighborhood shop',
              style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
            onTap: () => _handleSwitchShop(context, isHindi, isHinglish),
          ),
        ],
      ),
    );
  }

  /// Section 4: Logout Card
  Widget _buildLogoutCard({
    required BuildContext context,
    required UserProvider userProvider,
    required bool isHindi,
    required bool isHinglish,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.logout_rounded,
            color: Color(0xFFDC2626),
            size: 18,
          ),
        ),
        title: Text(
          isHindi ? 'लॉग आउट' : (isHinglish ? 'Logout karein' : 'Log Out'),
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFDC2626),
          ),
        ),
        subtitle: Text(
          isHindi ? 'इस डिवाइस से बाहर निकलें' : 'Sign out of your account on this phone',
          style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
        onTap: () => _handleLogout(context, userProvider, isHindi, isHinglish),
      ),
    );
  }

  Future<void> _handleCallShop(BuildContext context, ShopProvider shopProvider, bool isHindi) async {
    HapticFeedback.lightImpact();
    try {
      String phone = shopProvider.shopSupportPhone?.toString() ?? shopProvider.shopMobile?.toString() ?? '';
      phone = phone.replaceAll(RegExp(r'\D'), '');
      if (phone.length == 10) phone = '91$phone';
      if (phone.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isHindi ? 'इस दुकान का संपर्क नंबर उपलब्ध नहीं है।' : 'Store contact number is not available.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final Uri launchUri = Uri(scheme: 'tel', path: '+$phone');
      await launchUrl(launchUri);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open dialer.'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _handleWhatsApp(
    BuildContext context,
    ShopProvider shopProvider,
    UserProvider userProvider,
  ) async {
    HapticFeedback.lightImpact();
    try {
      final String userName = userProvider.customerName.isNotEmpty ? userProvider.customerName : 'Customer';
      final String userPhone = userProvider.phoneNumber.isNotEmpty ? userProvider.phoneNumber : '';

      String template = shopProvider.shopWhatsAppTemplate?.toString() ??
          "नमस्ते {shopName}, मेरा नाम {name} है और मेरा मोबाइल नंबर {phone} है। मुझे अपने ऑर्डर / अकाउंट के बारे में कुछ मदद चाहिए।";
      template = template.replaceAll('{shopName}', shopProvider.shopName ?? 'My Shop');
      String message = template
          .replaceAll('{name}', userName)
          .replaceAll('{phone}', userPhone.isNotEmpty ? '($userPhone)' : '');

      final String encodedMessage = Uri.encodeComponent(message);
      String phone = shopProvider.shopSupportPhone?.toString() ?? shopProvider.shopMobile?.toString() ?? '';
      phone = phone.replaceAll(RegExp(r'\D'), '');
      if (phone.length == 10) phone = '91$phone';
      if (phone.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Is dukan ka WhatsApp number available nahi hai.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final Uri launchUri = Uri.parse('https://wa.me/$phone?text=$encodedMessage');
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _handleSwitchShop(BuildContext context, bool isHindi, bool isHinglish) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isHindi ? 'दुकान बदलें?' : (isHinglish ? 'Shop Badlein?' : 'Switch Kirana Store?'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          isHindi
              ? 'क्या आप दूसरी दुकान चुनना चाहते हैं? आपका वर्तमान कार्ट खाली हो जाएगा।'
              : (isHinglish
                  ? 'Kya aap doosri dukan select karna chahte hain? Cart items clear ho jayenge.'
                  : 'Do you want to switch to another store? Your current cart will be cleared.'),
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              isHindi ? 'रद्द करें' : 'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isHindi ? 'हाँ, दुकान बदलें' : (isHinglish ? 'Haan, Badlein' : 'Yes, Switch Store')),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await Provider.of<ShopProvider>(context, listen: false).clearShop();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ShopSelectorScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleLogout(
    BuildContext context,
    UserProvider userProvider,
    bool isHindi,
    bool isHinglish,
  ) async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isHindi ? 'लॉग आउट' : (isHinglish ? 'Logout karein?' : 'Log Out?'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          isHindi
              ? 'क्या आप वाकई लॉग आउट करना चाहते हैं?'
              : (isHinglish
                  ? 'Kya aap sach me logout karna chahte hain?'
                  : 'Are you sure you want to log out of your account on this device?'),
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              isHindi ? 'रद्द करें' : 'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(isHindi ? 'लॉग आउट' : 'Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      SoundService().success();
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await userProvider.logout();
      cartProvider.clearCart();

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const GatewayScreen()),
          (route) => false,
        );
      }
    }
  }
}

class _ProfileAvatar extends StatefulWidget {
  final UserProvider userProvider;
  const _ProfileAvatar({required this.userProvider});

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        final finalImageUrl = 'data:image/jpeg;base64,$base64String';
        await widget.userProvider.updateProfileImage(finalImageUrl);
      } catch (e) {
        debugPrint('Error uploading profile pic: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFDCFCE7),
              border: Border.all(
                color: const Color(0xFF22C55E),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _isUploading
                  ? const Center(child: ModernLoader(color: AppColors.primaryDark))
                  : (widget.userProvider.profileImageUrl != null &&
                          widget.userProvider.profileImageUrl!.isNotEmpty)
                      ? ProductImageWidget(
                          imageUrl: widget.userProvider.profileImageUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 38,
                          color: Color(0xFF15803D),
                        ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
          ),
        ],
      ),
    );
  }
}
