import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'firebase_utils.dart';
import 'user_provider.dart';
import 'shop_provider.dart';
import 'cart_provider.dart';
import 'shopping_list_model.dart';
import 'shopping_list_service.dart';
import 'widgets/reorder_summary_dialog.dart';

/// Screen displaying customer saved shopping lists (e.g., "Weekly Grocery", "Monthly Ration")
/// and recent orders for fast 1-tap reordering.
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

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);
    final customerPhone = userProvider.phoneNumber;
    final shopId = shopProvider.currentShopId ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Shopping Lists & Reorder',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textMid,
          indicatorColor: AppColors.primaryDark,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.bookmark_border_rounded), text: 'Saved Lists'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Past Orders'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create New List',
            onPressed: () => _showCreateListDialog(context, customerPhone, shopId),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSavedListsTab(customerPhone, shopId),
          _buildPastOrdersTab(customerPhone, shopId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateListDialog(context, customerPhone, shopId),
        backgroundColor: AppColors.primaryDark,
        icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
        label: const Text(
          'New List',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- TAB 1: SAVED LISTS ---

  Widget _buildSavedListsTab(String customerPhone, String shopId) {
    if (customerPhone.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_off_rounded,
        title: 'Login Required',
        subtitle: 'Please sign in to view and save your custom grocery lists.',
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
            title: 'No Saved Lists Yet',
            subtitle:
                'Save your weekly staples (e.g., "Weekly Grocery", "Sunday Breakfast") to reorder them in seconds!',
            actionLabel: 'Create Weekly List',
            onAction: () => _showCreateListDialog(context, customerPhone, shopId),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: lists.length,
          itemBuilder: (context, index) {
            final list = lists[index];
            return _buildShoppingListCard(context, list, shopId);
          },
        );
      },
    );
  }

  Widget _buildShoppingListCard(
    BuildContext context,
    ShoppingListModel list,
    String currentShopId,
  ) {
    final bool isDifferentShop =
        currentShopId.isNotEmpty && list.shopId.isNotEmpty && list.shopId != currentShopId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(16),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.format_list_bulleted_rounded,
              color: AppColors.primaryDark,
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  list.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (isDifferentShop)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Text(
                    'Diff Store',
                    style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Text(
                  '${list.itemCount} items',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 8),
                Text(
                  'Est. ₹${list.totalEstimatedCost.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            // Items list preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: list.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${item.quantity.toStringAsFixed(item.isLoose ? 1 : 0)} x ₹${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMid),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            // Action row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    tooltip: 'Delete list',
                    onPressed: () => _confirmDeleteList(context, list.id),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final activeShop = currentShopId.isNotEmpty ? currentShopId : list.shopId;
                      ReorderSummaryDialog.showForItems(
                        context: context,
                        sourceTitle: list.name,
                        shopId: activeShop,
                        items: list.items.map((i) => i.toMap()).toList(),
                      );
                    },
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('Reorder to Cart'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // --- TAB 2: PAST ORDERS TO REORDER ---

  Widget _buildPastOrdersTab(String customerPhone, String currentShopId) {
    if (customerPhone.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_off_rounded,
        title: 'Login Required',
        subtitle: 'Please sign in to view past orders.',
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
            title: 'No Orders Yet',
            subtitle: 'Place an order first to reorder quickly anytime.',
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final items = data['items'] as List<dynamic>? ?? [];
            final total = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
            final status = data['status']?.toString() ?? 'Delivered';
            final orderShopId = data['shop_id']?.toString() ?? currentShopId;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${doc.id.length > 8 ? doc.id.substring(doc.id.length - 8) : doc.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${items.length} items • ₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppColors.textMid, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _saveOrderAsList(context, doc.id, customerPhone, orderShopId, items),
                        icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                        label: const Text('Save as List'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final targetShop = currentShopId.isNotEmpty ? currentShopId : orderShopId;
                          ReorderSummaryDialog.showForItems(
                            context: context,
                            sourceTitle: 'Order #${doc.id}',
                            shopId: targetShop,
                            items: items.map((i) => Map<String, dynamic>.from(i as Map)).toList(),
                          );
                        },
                        icon: const Icon(Icons.replay_rounded, size: 16),
                        label: const Text('Reorder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _showCreateListDialog(
    BuildContext context,
    String customerPhone,
    String shopId,
  ) {
    final nameCtrl = TextEditingController(text: 'Weekly Grocery');
    final cart = Provider.of<CartProvider>(context, listen: false);
    bool useCartItems = cart.items.isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create Shopping List', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Give your list a name (e.g. Weekly Grocery, Monthly Ration):',
                  style: TextStyle(fontSize: 13, color: AppColors.textMid)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Sunday Essentials',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                ),
              ),
              if (cart.items.isNotEmpty) ...[
                const SizedBox(height: 14),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: useCartItems,
                  onChanged: (val) => setDialogState(() => useCartItems = val ?? false),
                  title: Text(
                    'Add ${cart.itemCount} items currently in cart',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                      content: Text('List "$name" created successfully!'),
                      backgroundColor: AppColors.primaryDark,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Create List'),
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
  ) {
    final nameCtrl = TextEditingController(text: 'Reorder List #$orderId');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Save Order as List', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Save items from this order into a reusable shopping list:'),
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
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                    content: Text('Saved "${nameCtrl.text}" to your shopping lists!'),
                    backgroundColor: AppColors.primaryDark,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save List'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteList(BuildContext context, String listId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete List?'),
        content: const Text('Are you sure you want to delete this shopping list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _listService.deleteList(listId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: AppColors.textMid),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
