import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:near_kirana/utils/product_image_widget.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  List<String> _categories = [];
  Map<String, String> _categoryImages = {};
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
      if (doc.exists) {
        final data = doc.data()!;
        if (data.containsKey('categories') && data['categories'] != null) {
          final List<dynamic> fetchedCats = data['categories'];
          _categories = fetchedCats.map((e) => e.toString()).toList();
          _categories.remove('All');
        }
        if (data.containsKey('category_images') && data['category_images'] is Map) {
          final rawMap = data['category_images'] as Map<dynamic, dynamic>;
          _categoryImages = rawMap.map((k, v) => MapEntry(k.toString(), v.toString()));
        } else if (data.containsKey('categoryImages') && data['categoryImages'] is Map) {
          final rawMap = data['categoryImages'] as Map<dynamic, dynamic>;
          _categoryImages = rawMap.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
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

  Future<void> _editCategoryImage(String cat) async {
    final currentImg = _categoryImages[cat] ?? '';
    final urlController = TextEditingController(text: currentImg.startsWith('http') ? currentImg : '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Category Image: $cat'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentImg.isNotEmpty) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ProductImageWidget(
                      imageUrl: currentImg,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config';
                    Navigator.pop(ctx);
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 60,
                    );
                    if (pickedFile != null) {
                      try {
                        final bytes = await pickedFile.readAsBytes();
                        final base64String = base64Encode(bytes);
                        final finalUrl = 'data:image/jpeg;base64,$base64String';

                        await FirebaseUtils.firestore.collection('shops').doc(shopId).update({
                          'category_images.$cat': finalUrl,
                        });
                        if (mounted) {
                          setState(() {
                            _categoryImages[cat] = finalUrl;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Image updated for $cat!')),
                          );
                        }
                      } catch (e) {
                        debugPrint('Error updating category image: $e');
                      }
                    }
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pick Image from Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Or Paste Image URL (https://...)',
                  hintText: 'https://example.com/image.jpg',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (currentImg.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config';
                  await FirebaseUtils.firestore.collection('shops').doc(shopId).update({
                    'category_images.$cat': FieldValue.delete(),
                  });
                  setState(() {
                    _categoryImages.remove(cat);
                  });
                } catch (e) {
                  debugPrint('Error removing category image: $e');
                }
              },
              child: const Text('Remove Image', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                try {
                  final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config';
                  await FirebaseUtils.firestore.collection('shops').doc(shopId).update({
                    'category_images.$cat': url,
                  });
                  setState(() {
                    _categoryImages[cat] = url;
                  });
                } catch (e) {
                  debugPrint('Error saving category image url: $e');
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save URL'),
          ),
        ],
      ),
    );
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
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: isMobile
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: Text(
                'Product Categories',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                  tooltip: 'Refresh',
                  onPressed: _fetchData,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF0C831F)),
                  tooltip: 'Add Category',
                  onPressed: _addCategory,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: const Color(0xFFF1F5F9), height: 1),
              ),
            )
          : null,
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: _addCategory,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              backgroundColor: const Color(0xFF0C831F),
            )
          : null,
      body: Column(
        children: [
          if (!isMobile) const AdminTopHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : isMobile
                    ? _buildMobileBody(filteredCategories)
                    : _buildDesktopBody(filteredCategories),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(List<String> filteredCategories) {
    final withImagesCount = _categories.where((c) => _categoryImages[c] != null && _categoryImages[c]!.isNotEmpty).length;

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          // Search Field
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search categories...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0C831F), width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Stat Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMobileStatChip(
                  icon: Icons.category_rounded,
                  label: '${_categories.length} Categories',
                  color: const Color(0xFF0C831F),
                ),
                const SizedBox(width: 8),
                _buildMobileStatChip(
                  icon: Icons.inventory_2_outlined,
                  label: '$_totalProducts Products',
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                _buildMobileStatChip(
                  icon: Icons.photo_library_outlined,
                  label: '$withImagesCount Photos Set',
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Categories List
          if (filteredCategories.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isEmpty ? 'No categories yet' : 'No categories found for "$_searchQuery"',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _addCategory,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Category'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C831F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCategories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final cat = filteredCategories[i];
                final catImg = _categoryImages[cat] ?? '';
                final hasImg = catImg.isNotEmpty;
                final count = _productCounts[cat] ?? 0;

                return Container(
                  padding: const EdgeInsets.all(12),
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
                  child: Row(
                    children: [
                      // Photo thumbnail with camera button
                      InkWell(
                        onTap: () => _editCategoryImage(cat),
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: hasImg
                                  ? ProductImageWidget(imageUrl: catImg, fit: BoxFit.cover)
                                  : const Icon(Icons.category_rounded, color: Color(0xFF94A3B8), size: 24),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0C831F),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 10, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0C831F).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$count Products',
                                    style: const TextStyle(
                                      color: Color(0xFF0C831F),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hasImg ? '• Photo set' : '• No photo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasImg ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Actions
                      IconButton(
                        icon: const Icon(Icons.add_a_photo_outlined, size: 19, color: Color(0xFF0C831F)),
                        tooltip: 'Change Photo',
                        onPressed: () => _editCategoryImage(cat),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF64748B)),
                        tooltip: 'Edit Name',
                        onPressed: () => _editCategory(cat),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFDC2626)),
                        tooltip: 'Delete',
                        onPressed: () => _deleteCategory(cat),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMobileStatChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(List<String> filteredCategories) {
    return SingleChildScrollView(
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
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Categories', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28, fontFamily: GoogleFonts.inter().fontFamily, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Manage product categories and organize your catalog', style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 15)),
            ],
          ),
        ),
        const SizedBox(width: 16),
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
            initialValue: 'All Status',
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
            initialValue: 'Sort by: Latest',
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
                            InkWell(
                              onTap: () => _editCategoryImage(cats[i]),
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.bgTint),
                                    ),
                                    child: (_categoryImages[cats[i]] != null && _categoryImages[cats[i]]!.isNotEmpty)
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: ProductImageWidget(
                                              imageUrl: _categoryImages[cats[i]]!,
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(Icons.category_rounded, color: Colors.orange, size: 22),
                                  ),
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryDark,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 10),
                                    ),
                                  ),
                                ],
                              ),
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
                            Tooltip(
                              message: 'Set Category Image',
                              child: InkWell(
                                onTap: () => _editCategoryImage(cats[i]),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    border: Border.all(color: Colors.amber.shade200),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.add_photo_alternate_rounded, size: 16, color: Colors.amber.shade900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Showing 1-${cats.length} of ${cats.length} categories', style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
                const SizedBox(width: 24),
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
