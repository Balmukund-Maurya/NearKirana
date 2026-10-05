import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  List<String> _categories = [];
  Map<String, int> _productCounts = {};
  int _totalProducts = 0;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config';
      
      // Fetch Categories
      final doc = await FirebaseUtils.firestore.collection('shops').doc(shopId).get();
      if (doc.exists && doc.data()!.containsKey('categories')) {
        final List<dynamic> fetchedCats = doc['categories'];
        _categories = fetchedCats.map((e) => e.toString()).toList();
        _categories.remove('All');
      }

      // Fetch Product counts
      final productsSnapshot = await FirebaseUtils.firestore
          .collection('products')
          .where('shop_id', isEqualTo: shopId)
          .get();
          
      _totalProducts = productsSnapshot.docs.length;
      _productCounts = {};
      
      for (var pDoc in productsSnapshot.docs) {
        final data = pDoc.data();
        if (data.containsKey('categories')) {
          final cats = data['categories'] as List<dynamic>;
          for (var c in cats) {
            final catStr = c.toString();
            _productCounts[catStr] = (_productCounts[catStr] ?? 0) + 1;
          }
        }
      }

    } catch (e) {
      debugPrint("Error fetching data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addCategory() {
    final newCatController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Category'),
          content: TextField(
            controller: newCatController,
            decoration: const InputDecoration(labelText: 'Category Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = newCatController.text.trim();
                if (val.isNotEmpty && !_categories.contains(val)) {
                  try {
                    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config';
                    await FirebaseUtils.firestore.collection('shops').doc(shopId).update({
                      'categories': FieldValue.arrayUnion([val])
                    });
                    setState(() => _categories.add(val));
                  } catch (e) {
                    debugPrint('Error adding category: $e');
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add Category'),
            ),
          ],
        );
      },
    );
  }

  void _editCategory(String oldCat) {
    final editCatController = TextEditingController(text: oldCat);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Category'),
          content: TextField(
            controller: editCatController,
            decoration: const InputDecoration(labelText: 'Category Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = editCatController.text.trim();
                if (val.isNotEmpty && val != oldCat && !_categories.contains(val)) {
                  try {
                    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config';
                    await FirebaseUtils.firestore.collection('shops').doc(shopId).update({
                      'categories': FieldValue.arrayRemove([oldCat])
                    });
                    await FirebaseUtils.firestore.collection('shops').doc(shopId).update({
                      'categories': FieldValue.arrayUnion([val])
                    });
                    setState(() {
                      _categories.remove(oldCat);
                      _categories.add(val);
                    });
                  } catch (e) {
                    debugPrint('Error editing category: $e');
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteCategory(String cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "$cat"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config';
                await FirebaseUtils.firestore.collection('shops').doc(shopId).update({
                  'categories': FieldValue.arrayRemove([cat])
                });
                setState(() => _categories.remove(cat));
              } catch (e) {
                debugPrint('Error deleting category: $e');
              }
              if (context.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories.where((c) => c.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          const AdminTopHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPageHeader(),
                        const SizedBox(height: 24),
                        _buildSearchRow(),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _buildCategoriesCard(filteredCategories),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  _buildCategorySummary(),
                                  const SizedBox(height: 24),
                                  _buildQuickActions(),
                                  const SizedBox(height: 24),
                                  _buildCategoryTips(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categories', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28, fontFamily: GoogleFonts.inter().fontFamily, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Manage product categories and organize your catalog', style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 15)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _addCategory,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search categories...',
              hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMid),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: 'All Status',
            items: ['All Status', 'Active', 'Inactive'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
            onChanged: (v) {},
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: 'Sort by: Latest',
            items: ['Sort by: Latest', 'Sort by: Oldest', 'Sort by: Name'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
            onChanged: (v) {},
            icon: const Icon(Icons.keyboard_arrow_down),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.sort, size: 20, color: AppColors.textMid),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesCard(List<String> cats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Categories (${cats.length})', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Manage and organize your product categories', style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.bgTint),
          if (cats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(child: Text('No categories found', style: TextStyle(color: Colors.grey))),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth > 750 ? constraints.maxWidth : 750,
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FixedColumnWidth(50),
                        1: FlexColumnWidth(1),
                        2: FixedColumnWidth(90),
                        3: FixedColumnWidth(110),
                        4: FixedColumnWidth(110),
                        5: FixedColumnWidth(150),
                      },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.bgTint)),
                  ),
                  children: [
                    _buildTableHeader('#'),
                    _buildTableHeader('Category'),
                    _buildTableHeader('Products'),
                    _buildTableHeader('Status'),
                    _buildTableHeader('Created On'),
                    _buildTableHeader('Actions'),
                  ],
                ),
                for (int i = 0; i < cats.length; i++)
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.bgTint)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Text('${i + 1}', style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.category, color: Colors.orange, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cats[i], style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text('Category for ${cats[i]}', style: const TextStyle(color: AppColors.textMid, fontSize: 12), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Text('${_productCounts[cats[i]] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 13)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text('Active', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Text('12 Aug 2024', style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _editCategory(cats[i]),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textDark),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {}, // View Products placeholder
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.remove_red_eye_outlined, size: 16, color: AppColors.textDark),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _deleteCategory(cats[i]),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
              ],
            ),
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Showing 1-${cats.length} of ${cats.length} categories', style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6), color: Colors.white),
                      child: const Icon(Icons.chevron_left, size: 16, color: AppColors.textMid),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(6)),
                      child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6), color: Colors.white),
                      child: const Text('2', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6), color: Colors.white),
                      child: const Icon(Icons.chevron_right, size: 16, color: AppColors.textMid),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(text, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _buildCategorySummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: AppColors.textDark, size: 20),
              const SizedBox(width: 8),
              Text('Category Summary', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.inventory_2_outlined,
                  iconColor: Colors.green.shade700,
                  bgColor: Colors.green.shade50,
                  count: '${_categories.length}',
                  label: 'Total\nCategories',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.blue.shade700,
                  bgColor: Colors.blue.shade50,
                  count: '${_categories.length}',
                  label: 'Active\nCategories',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.remove_circle_outline,
                  iconColor: Colors.red.shade700,
                  bgColor: Colors.red.shade50,
                  count: '0',
                  label: 'Inactive\nCategories',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.widgets_outlined,
                  iconColor: Colors.purple.shade700,
                  bgColor: Colors.purple.shade50,
                  count: '$_totalProducts',
                  label: 'Total\nProducts',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({required IconData icon, required Color iconColor, required Color bgColor, required String count, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count, style: TextStyle(color: iconColor, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: iconColor.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500, height: 1.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.textDark, size: 20),
              const SizedBox(width: 8),
              Text('Quick Actions', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 24),
          _buildQuickActionRow(Icons.add_circle, Colors.green.shade700, 'Add Category', 'Create a new product category', onTap: _addCategory),
          const SizedBox(height: 16),
          _buildQuickActionRow(Icons.insert_drive_file_outlined, AppColors.textDark, 'Import Categories', 'Import categories from file'),
          const SizedBox(height: 16),
          _buildQuickActionRow(Icons.insert_drive_file_outlined, AppColors.textDark, 'Export Categories', 'Export categories to file'),
        ],
      ),
    );
  }

  Widget _buildQuickActionRow(IconData icon, Color iconColor, String title, String subtitle, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor == AppColors.textDark ? Colors.grey.shade100 : iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(subtitle, style: const TextStyle(color: AppColors.textMid, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: AppColors.textDark, size: 16),
        ],
      ),
    );
  }

  Widget _buildCategoryTips() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: AppColors.textDark, size: 20),
              const SizedBox(width: 8),
              Text('Category Tips', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          _buildTipRow('Use clear and descriptive category names'),
          const SizedBox(height: 12),
          _buildTipRow('Keep categories organized and relevant'),
          const SizedBox(height: 12),
          _buildTipRow('Add images to make categories more visual'),
          const SizedBox(height: 12),
          _buildTipRow('Inactive categories won\'t appear in product listing'),
        ],
      ),
    );
  }

  Widget _buildTipRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle, color: Colors.blue, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.textMid, fontSize: 12, height: 1.5, fontWeight: FontWeight.w500))),
      ],
    );
  }
}
