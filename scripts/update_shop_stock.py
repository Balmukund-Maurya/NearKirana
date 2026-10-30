import re
import sys

file_path = '/Users/macbook/Desktop/Kirana_Store_Builder/lib/shop_stock_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

# 1. Add AdminTopHeader import if not present
if "admin_top_header.dart" not in content:
    content = content.replace("import 'package:near_kirana/firebase_utils.dart';", "import 'package:near_kirana/firebase_utils.dart';\nimport 'widgets/admin_top_header.dart';")

# 2. Modify build method to use LayoutBuilder
# Find the exact start of the build method
build_method_start = """  @override
  Widget build(BuildContext context) {
    return Scaffold("""
  
build_replacement = """  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return _buildDesktopLayout(context);
        }
        return Scaffold("""

if build_method_start in content:
    content = content.replace(build_method_start, build_replacement)
else:
    print("Could not find build method start")
    sys.exit(1)

# Find the end of the Scaffold inside build method
# It ends with:
#       ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
#     );
#   }
scaffold_end = """      ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
    );"""
layout_builder_close = """      ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
    );
      }
    );"""

if scaffold_end in content:
    content = content.replace(scaffold_end, layout_builder_close)
else:
    print("Could not find Scaffold end")
    sys.exit(1)

# 4. Add desktop layout methods at the end of the class
desktop_methods = """
  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      children: [
        const AdminTopHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDesktopPageHeader(),
                const SizedBox(height: 32),
                _buildDesktopSummaryCards(),
                const SizedBox(height: 32),
                _buildDesktopFiltersAndSearch(),
                const SizedBox(height: 24),
                _buildDesktopProductTable(),
                const SizedBox(height: 24),
                _buildDesktopPagination(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Products', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 8),
            Text('Manage your products, update stock, prices and more', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {
            AdminProductForms.showManualAddProductForm(context);
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF136633),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSummaryCards() {
    int totalProducts = _products.length;
    int inStock = 0;
    int lowStock = 0;
    int outOfStock = 0;

    for (var doc in _products) {
      final data = doc.data() as Map<String, dynamic>;
      final stock = (data['stock_quantity'] as num?)?.toDouble() ?? 0.0;
      final isLoose = data['is_loose'] ?? false;
      final threshold = isLoose ? 2.0 : 5.0;
      if (stock <= 0) {
        outOfStock++;
      } else if (stock <= threshold) {
        lowStock++;
      } else {
        inStock++;
      }
    }

    return Row(
      children: [
        buildSummaryCard('Total Products', '$totalProducts', Icons.inventory_2_rounded, const Color(0xFF1F9444), const Color(0xFFE8F5E9)),
        const SizedBox(width: 24),
        buildSummaryCard('In Stock', '$inStock', Icons.shopping_cart_rounded, const Color(0xFF007AFF), const Color(0xFFE3F2FD)),
        const SizedBox(width: 24),
        buildSummaryCard('Low Stock', '$lowStock', Icons.warning_rounded, const Color(0xFFFF7B00), const Color(0xFFFFF3E0)),
        const SizedBox(width: 24),
        buildSummaryCard('Out of Stock', '$outOfStock', Icons.block_rounded, const Color(0xFFF04456), const Color(0xFFFFEBEE)),
      ],
    );
  }

  Widget buildSummaryCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopFiltersAndSearch() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() => _searchQuery = value.trim().toLowerCase());
                        _refresh();
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products by name, category, or brand...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Text('Filters', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            buildDropdownFilter('All Categories'),
            const SizedBox(width: 16),
            buildDropdownFilter('All Status'),
            const SizedBox(width: 16),
            buildDropdownFilter('All Stock Levels'),
            const SizedBox(width: 16),
            buildDropdownFilter('Sort by Name'),
          ],
        ),
      ],
    );
  }

  Widget buildDropdownFilter(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
          const SizedBox(width: 32),
          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600, size: 20),
        ],
      ),
    );
  }

  Widget _buildDesktopProductTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 24, child: Icon(Icons.check_box_outline_blank, color: Colors.grey, size: 20)),
                const SizedBox(width: 24),
                Expanded(flex: 3, child: Text('Product', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Category', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Price', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Stock', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Status', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold))),
                const SizedBox(width: 100, child: Text('Actions', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Table Body
          if (_isLoading && _products.isEmpty)
            const Padding(padding: EdgeInsets.all(48), child: ModernLoader(color: Color(0xFF136633)))
          else if (_products.isEmpty)
            const Padding(padding: EdgeInsets.all(48), child: Text('No products found.', style: TextStyle(color: Colors.grey)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _products.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final doc = _products[index];
                final data = doc.data() as Map<String, dynamic>;
                
                final name = data['name'] ?? 'Unknown';
                final barcode = data['barcode'] ?? doc.id;
                final imageUrl = data['image_url'];
                final quantity = data['quantity']?.toString() ?? '';
                final isLoose = data['is_loose'] ?? false;
                final unit = isLoose ? 'kg' : 'pcs';
                final price = data['price']?.toString() ?? '0';
                final originalPrice = data['mrp']?.toString();
                final stock = (data['stock_quantity'] as num?)?.toDouble() ?? 0.0;
                final categories = data['categories'] as List<dynamic>? ?? [];
                final primaryCategory = categories.isNotEmpty ? categories.first.toString() : 'Other';

                // Status logic
                final threshold = isLoose ? 2.0 : 5.0;
                String status = 'In Stock';
                Color statusColor = const Color(0xFF1F9444);
                Color statusBg = const Color(0xFFE8F5E9);
                if (stock <= 0) {
                  status = 'Out of Stock';
                  statusColor = const Color(0xFFF04456);
                  statusBg = const Color(0xFFFFEBEE);
                } else if (stock <= threshold) {
                  status = 'Low Stock';
                  statusColor = const Color(0xFFFF7B00);
                  statusBg = const Color(0xFFFFF3E0);
                }

                // Discount logic
                String? discountBadge;
                if (originalPrice != null && originalPrice.isNotEmpty) {
                  final p = double.tryParse(price) ?? 0;
                  final m = double.tryParse(originalPrice) ?? 0;
                  if (m > p && m > 0) {
                    final off = ((m - p) / m * 100).round();
                    discountBadge = '$off% OFF';
                  }
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      const SizedBox(width: 24, child: Icon(Icons.check_box_outline_blank, color: Colors.grey, size: 20)),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ProductImageWidget(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  Text('$quantity $unit', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(6)),
                            child: Text(primaryCategory, style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Text('₹$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (originalPrice != null && discountBadge != null) ...[
                              const SizedBox(width: 8),
                              Text('₹$originalPrice', style: TextStyle(color: Colors.grey.shade400, decoration: TextDecoration.lineThrough, fontSize: 13)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                                child: Text(discountBadge, style: const TextStyle(color: Color(0xFF1F9444), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(isLoose ? stock.toStringAsFixed(1) : stock.toInt().toString(), style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                            child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () => AdminProductForms.showEditProductDialog(context, barcode),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                                child: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showDeleteConfirmation(context, barcode, name),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFFFFF1F1), border: Border.all(color: const Color(0xFFFFE4E4)), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFF04456)),
                              ),
                            ),
                          ],
                        ),
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

  void _showDeleteConfirmation(BuildContext context, String barcode, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Handle delete (would delete from Firestore in real app)
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF04456)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Showing 1 to ${_products.length} products', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        Row(
          children: [
            buildPaginationButton(Icons.chevron_left_rounded),
            const SizedBox(width: 8),
            buildPaginationPage('1', true),
            const SizedBox(width: 8),
            buildPaginationPage('2', false),
            const SizedBox(width: 8),
            buildPaginationPage('3', false),
            const SizedBox(width: 8),
            Text('...', style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(width: 8),
            buildPaginationPage('15', false),
            const SizedBox(width: 8),
            buildPaginationButton(Icons.chevron_right_rounded),
          ],
        ),
      ],
    );
  }

  Widget buildPaginationButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Icon(icon, color: Colors.grey.shade700, size: 18),
    );
  }

  Widget buildPaginationPage(String page, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF136633) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? const Color(0xFF136633) : Colors.grey.shade200),
      ),
      child: Text(page, style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade700, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
    );
  }
"""

content = content.rsplit("}", 1)[0] + desktop_methods + "\n}\n"

with open(file_path, 'w') as f:
    f.write(content)
print("Successfully modified shop_stock_screen.dart")
