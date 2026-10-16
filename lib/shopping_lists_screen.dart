import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'firebase_utils.dart';
import 'user_provider.dart';
import 'shop_provider.dart';
import 'cart_provider.dart';
import 'language_provider.dart';
import 'shopping_list_model.dart';
import 'shopping_list_service.dart';
import 'widgets/reorder_summary_dialog.dart';

/// Screen displaying customer saved shopping lists (e.g., "Weekly Grocery", "Monthly Ration")
/// and recent orders for fast 1-tap reordering with Zepto / Blinkit styled aesthetics.
class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ShoppingListService _listService = ShoppingListService();

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

  String _formatDisplayListName(String rawName, bool isHindi, bool isHinglish) {
    if (rawName.isEmpty) {
      return isHindi ? 'किराना लिस्ट' : (isHinglish ? 'Grocery List' : 'Grocery List');
    }
    if (rawName.contains('#ord_') || rawName.contains('ord_desktop_')) {
      final parts = rawName.split('_');
      if (parts.isNotEmpty) {
        final lastPart = parts.last;
        final shortCode = lastPart.length > 6 ? lastPart.substring(lastPart.length - 6) : lastPart;
        return isHindi
            ? 'ऑर्डर लिस्ट (#$shortCode)'
            : (isHinglish ? 'Order List (#$shortCode)' : 'Saved Order (#$shortCode)');
      }
      return isHindi ? 'पिछला ऑर्डर लिस्ट' : 'Previous Order List';
    }
    return rawName;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final customerPhone = userProvider.phoneNumber;
    final shopId = shopProvider.currentShopId ?? '';
    final isHindi = langProvider.isHindi;
    final isHinglish = langProvider.isHinglish;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          isHindi
              ? 'शॉपिंग लिस्ट'
              : (isHinglish ? 'Shopping Lists' : 'Shopping Lists & Reorder'),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryDark),
            tooltip: isHindi ? 'नई लिस्ट बनाएं' : 'Create New List',
            onPressed: () => _showCreateListDialog(context, customerPhone, shopId, isHindi, isHinglish),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppColors.primaryDark,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13.5),
          tabs: [
            Tab(
              icon: const Icon(Icons.bookmark_border_rounded, size: 20),
              text: isHindi ? 'सेव की गई लिस्ट' : (isHinglish ? 'Saved Lists' : 'Saved Lists'),
            ),
            Tab(
              icon: const Icon(Icons.history_rounded, size: 20),
              text: isHindi ? 'पुराने ऑर्डर' : (isHinglish ? 'Past Orders' : 'Past Orders'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSavedListsTab(customerPhone, shopId, isHindi, isHinglish),
          _buildPastOrdersTab(customerPhone, shopId, isHindi, isHinglish),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateListDialog(context, customerPhone, shopId, isHindi, isHinglish),
        backgroundColor: AppColors.primaryDark,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          isHindi ? 'नई लिस्ट' : (isHinglish ? 'New List' : 'New List'),
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  // --- TAB 1: SAVED LISTS ---

  Widget _buildSavedListsTab(String customerPhone, String shopId, bool isHindi, bool isHinglish) {
    if (customerPhone.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_off_rounded,
        title: isHindi ? 'लॉगिन आवश्यक है' : 'Login Required',
        subtitle: isHindi
            ? 'अपनी सहेजी गई किराना लिस्ट देखने के लिए कृपया साइन इन करें।'
            : 'Please sign in to view and save your custom grocery lists.',
      );
    }

    return StreamBuilder<List<ShoppingListModel>>(
      stream: _listService.streamCustomerLists(customerPhone),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryDark),
          );
        }

        final lists = snapshot.data ?? [];

        if (lists.isEmpty) {
          return _buildEmptyState(
            icon: Icons.playlist_add_check_rounded,
            title: isHindi ? 'कोई सहेजी गई लिस्ट नहीं है' : 'No Saved Lists Yet',
            subtitle: isHindi
                ? 'अपने साप्ताहिक जरूरी सामान (दूध, आटा, तेल) की लिस्ट बनाएं और 1-क्लिक में दोबारा ऑर्डर करें!'
                : 'Save your weekly staples (e.g. "Weekly Grocery", "Sunday Breakfast") to reorder them in 1-tap!',
            actionLabel: isHindi ? 'नई लिस्ट बनाएं' : 'Create Weekly List',
            onAction: () => _showCreateListDialog(context, customerPhone, shopId, isHindi, isHinglish),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: lists.length,
          itemBuilder: (context, index) {
            final list = lists[index];
            return _buildShoppingListCard(context, list, shopId, isHindi, isHinglish);
          },
        );
      },
    );
  }

  Widget _buildShoppingListCard(
    BuildContext context,
    ShoppingListModel list,
    String currentShopId,
    bool isHindi,
    bool isHinglish,
  ) {
    final bool isDifferentShop =
        currentShopId.isNotEmpty && list.shopId.isNotEmpty && list.shopId != currentShopId;
    final displayName = _formatDisplayListName(list.name, isHindi, isHinglish);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.format_list_bulleted_rounded,
                    color: Color(0xFF059669),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isDifferentShop)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                isHindi ? 'अन्य स्टोर' : (isHinglish ? 'Other Store' : 'Other Store'),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            isHindi
                                ? '${list.itemCount} सामान'
                                : '${list.itemCount} ${list.itemCount == 1 ? "item" : "items"}',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                          const SizedBox(width: 8),
                          Text(
                            'Est. ₹${list.totalEstimatedCost.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Items preview tags (Zepto / Blinkit style chips)
          if (list.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...list.items.take(3).map((item) {
                    final qtyStr = item.quantity.toStringAsFixed(item.isLoose ? 1 : 0);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.name} ($qtyStr)',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  if (list.items.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${list.items.length - 3} ${isHindi ? "और" : "more"}',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Actions Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Edit / Rename Button
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF64748B)),
                  tooltip: isHindi ? 'नाम बदलें' : 'Rename list',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showRenameDialog(context, list, isHindi, isHinglish),
                ),
                const SizedBox(width: 14),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFDC2626)),
                  tooltip: isHindi ? 'हटाएं' : 'Delete list',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDeleteList(context, list.id, isHindi, isHinglish),
                ),
                const Spacer(),

                // Reorder All Button
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final activeShop = currentShopId.isNotEmpty ? currentShopId : list.shopId;
                    ReorderSummaryDialog.showForItems(
                      context: context,
                      sourceTitle: displayName,
                      shopId: activeShop,
                      items: list.items.map((i) => i.toMap()).toList(),
                    );
                  },
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: Text(
                    isHindi ? 'री-ऑर्डर करें' : (isHinglish ? 'Reorder karein' : 'Reorder to Cart'),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: PAST ORDERS TO REORDER ---

  Widget _buildPastOrdersTab(String customerPhone, String currentShopId, bool isHindi, bool isHinglish) {
    if (customerPhone.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_off_rounded,
        title: isHindi ? 'लॉगिन आवश्यक है' : 'Login Required',
        subtitle: isHindi
            ? 'पुराने ऑर्डर देखने के लिए कृपया साइन इन करें।'
            : 'Please sign in to view past orders.',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseUtils.firestore
          .collection('orders')
          .where('phone_number', isEqualTo: customerPhone)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryDark),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.shopping_basket_outlined,
            title: isHindi ? 'कोई पुराना ऑर्डर नहीं' : 'No Orders Yet',
            subtitle: isHindi
                ? 'जल्दी से दोबारा ऑर्डर करने के लिए पहले एक ऑर्डर प्लेस करें।'
                : 'Place an order first to reorder quickly anytime.',
          );
        }

        // Sort by created_at desc in-memory
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final tA = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final tB = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final items = data['items'] as List<dynamic>? ?? [];
            final total = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
            final status = data['status']?.toString() ?? 'Delivered';
            final orderShopId = data['shop_id']?.toString() ?? currentShopId;
            final shortOrderId = doc.id.length > 6 ? doc.id.substring(doc.id.length - 6) : doc.id;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #$shortOrderId',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isHindi
                        ? '${items.length} सामान • ₹${total.toStringAsFixed(0)}'
                        : '${items.length} ${items.length == 1 ? "item" : "items"} • ₹${total.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _saveOrderAsList(
                          context,
                          doc.id,
                          customerPhone,
                          orderShopId,
                          items,
                          isHindi,
                          isHinglish,
                        ),
                        icon: const Icon(Icons.bookmark_add_outlined, size: 15),
                        label: Text(
                          isHindi ? 'लिस्ट सेव करें' : (isHinglish ? 'List save karein' : 'Save as List'),
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final targetShop = currentShopId.isNotEmpty ? currentShopId : orderShopId;
                          ReorderSummaryDialog.showForItems(
                            context: context,
                            sourceTitle: 'Order #$shortOrderId',
                            shopId: targetShop,
                            items: items.map((i) => Map<String, dynamic>.from(i as Map)).toList(),
                          );
                        },
                        icon: const Icon(Icons.replay_rounded, size: 15),
                        label: Text(
                          isHindi ? 'री-ऑर्डर करें' : (isHinglish ? 'Reorder karein' : 'Reorder'),
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- DIALOGS & ACTIONS ---

  void _showRenameDialog(
    BuildContext context,
    ShoppingListModel list,
    bool isHindi,
    bool isHinglish,
  ) {
    final nameCtrl = TextEditingController(text: list.name);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isHindi ? 'लिस्ट का नाम बदलें' : (isHinglish ? 'List Name Badlein' : 'Rename Shopping List'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.edit_note_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(dialogCtx);
                final updated = ShoppingListModel(
                  id: list.id,
                  name: newName,
                  customerPhone: list.customerPhone,
                  shopId: list.shopId,
                  items: list.items,
                  createdAt: list.createdAt,
                  updatedAt: DateTime.now(),
                );
                await _listService.saveList(updated);
              }
            },
            child: Text(isHindi ? 'सहेजें' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showCreateListDialog(
    BuildContext context,
    String customerPhone,
    String shopId,
    bool isHindi,
    bool isHinglish,
  ) {
    final nameCtrl = TextEditingController(
      text: isHindi ? 'साप्ताहिक किराना' : (isHinglish ? 'Weekly Grocery' : 'Weekly Grocery'),
    );
    final cart = Provider.of<CartProvider>(context, listen: false);
    bool useCartItems = cart.items.isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isHindi ? 'नई शॉपिंग लिस्ट बनाएं' : (isHinglish ? 'Nayi List Banayein' : 'Create Shopping List'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHindi
                    ? 'अपनी लिस्ट को एक नाम दें (जैसे: साप्ताहिक किराना, मासिक राशन):'
                    : 'Give your list a name (e.g. Weekly Grocery, Monthly Ration):',
                style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isHindi ? 'जैसे: रविवार राशन' : 'e.g. Sunday Essentials',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                ),
              ),
              if (cart.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: useCartItems,
                  onChanged: (val) => setDialogState(() => useCartItems = val ?? false),
                  title: Text(
                    isHindi
                        ? 'वर्तमान कार्ट के ${cart.itemCount} सामान जोड़ें'
                        : 'Add ${cart.itemCount} items currently in cart',
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                Navigator.pop(dialogCtx);

                if (useCartItems && cart.items.isNotEmpty) {
                  await _listService.createListFromCart(
                    name: name,
                    customerPhone: customerPhone,
                    shopId: shopId,
                    cartItems: cart.itemsList,
                  );
                } else {
                  final now = DateTime.now();
                  await _listService.saveList(
                    ShoppingListModel(
                      id: ShoppingListService.generateListId(),
                      name: name,
                      customerPhone: customerPhone,
                      shopId: shopId,
                      items: const [],
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isHindi
                            ? 'लिस्ट "$name" सफलतापूर्वक बनाई गई!'
                            : 'List "$name" created successfully!',
                      ),
                      backgroundColor: AppColors.primaryDark,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(isHindi ? 'लिस्ट बनाएं' : 'Create List'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveOrderAsList(
    BuildContext context,
    String orderId,
    String customerPhone,
    String shopId,
    List<dynamic> items,
    bool isHindi,
    bool isHinglish,
  ) {
    final shortId = orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId;
    final defaultTitle = isHindi ? 'ऑर्डर लिस्ट #$shortId' : 'Order List #$shortId';
    final nameCtrl = TextEditingController(text: defaultTitle);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isHindi ? 'ऑर्डर को लिस्ट के रूप में सेव करें' : 'Save Order as List',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHindi
                  ? 'अगली बार तुरंत ऑर्डर करने के लिए इस ऑर्डर के सामान को लिस्ट में सेव करें:'
                  : 'Save items from this order into a reusable shopping list:',
              style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.bookmark_border_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _listService.createListFromOrder(
                orderId: orderId,
                name: nameCtrl.text.trim(),
                customerPhone: customerPhone,
                shopId: shopId,
                items: items,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isHindi
                          ? '"${nameCtrl.text}" आपकी शॉपिंग लिस्ट में सेव हो गई!'
                          : 'Saved "${nameCtrl.text}" to your shopping lists!',
                    ),
                    backgroundColor: AppColors.primaryDark,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(isHindi ? 'सेव करें' : 'Save List'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteList(BuildContext context, String listId, bool isHindi, bool isHinglish) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isHindi ? 'लिस्ट हटाएं?' : (isHinglish ? 'List Delete karein?' : 'Delete List?'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          isHindi
              ? 'क्या आप निश्चित रूप से इस शॉपिंग लिस्ट को हटाना चाहते हैं?'
              : 'Are you sure you want to delete this shopping list?',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _listService.deleteList(listId);
            },
            child: Text(
              isHindi ? 'हटाएं' : 'Delete',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: const Color(0xFF059669)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
