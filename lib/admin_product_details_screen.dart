import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';
import 'package:near_kirana/admin_product_forms.dart';
import 'package:near_kirana/utils/product_image_widget.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/sound_service.dart';

class AdminProductDetailsScreen extends StatefulWidget {
  final String barcode;
  final String productName;
  final VoidCallback onBack;

  const AdminProductDetailsScreen({
    super.key,
    required this.barcode,
    required this.productName,
    required this.onBack,
  });

  @override
  State<AdminProductDetailsScreen> createState() => _AdminProductDetailsScreenState();
}

class _AdminProductDetailsScreenState extends State<AdminProductDetailsScreen> {
  Map<String, dynamic>? productData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  Future<void> _fetchProductDetails() async {
    try {
      final doc = await FirebaseUtils.firestore.collection('products').doc(widget.barcode).get();
      if (doc.exists && mounted) {
        setState(() {
          productData = doc.data();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _markOutOfStock() {
    FirebaseUtils.firestore.collection('products').doc(widget.barcode).update({
      'stock_quantity': 0,
    }).then((_) {
      if (!mounted) return;
      _fetchProductDetails();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as out of stock')));
    });
  }

  void _deleteProduct() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${widget.productName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseUtils.firestore.collection('products').doc(widget.barcode).delete().then((_) {
                if (mounted) {
                  widget.onBack(); // Go back to products list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product deleted successfully')),
                  );
                }
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF04456)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _quickAdjustStock(double delta) async {
    final currentStock = (productData?['stock_quantity'] as num?)?.toDouble() ?? 0.0;
    final newStock = (currentStock + delta).clamp(0.0, 99999.0);
    HapticFeedback.lightImpact();
    setState(() {
      if (productData != null) {
        productData!['stock_quantity'] = newStock;
      }
    });

    try {
      await FirebaseUtils.firestore.collection('products').doc(widget.barcode).update({
        'stock_quantity': newStock,
      });
      SoundService().success();
    } catch (e) {
      debugPrint('Error updating stock: $e');
      _fetchProductDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 800;
        if (isMobile) {
          return _buildMobileProductDetails(context);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          body: Column(
            children: [
              const AdminTopHeader(),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF136633)))
                    : productData == null
                        ? const Center(child: Text('Product not found'))
                        : _buildBody(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileProductDetails(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
            onPressed: widget.onBack,
          ),
          title: const Text('Product Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF0C831F))),
      );
    }

    if (productData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
            onPressed: widget.onBack,
          ),
          title: const Text('Product Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 56, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              const Text('Product not found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: widget.onBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C831F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back to Inventory'),
              ),
            ],
          ),
        ),
      );
    }

    final name = productData?['name'] ?? widget.productName;
    final barcode = productData?['barcode'] ?? widget.barcode;
    final imageUrl = productData?['image_url'];
    final quantity = productData?['quantity']?.toString() ?? '';
    final isLoose = productData?['is_loose'] ?? false;
    final unit = isLoose ? 'kg' : 'pcs';
    final categories = productData?['categories'] as List<dynamic>? ?? [];
    final category = categories.isNotEmpty ? categories.first.toString() : 'General';
    final stock = (productData?['stock_quantity'] as num?)?.toDouble() ?? 0.0;
    final isVeg = productData?['isVegetarian'] ?? true;
    final isFoodItem = productData?['isFoodItem'] ?? true;

    final priceStr = productData?['price']?.toString() ?? '0';
    final mrpStr = productData?['mrp']?.toString();
    final priceVal = double.tryParse(priceStr) ?? 0.0;
    final mrpVal = mrpStr != null ? double.tryParse(mrpStr) : null;

    int? discountPercent;
    double? savingsVal;
    if (mrpVal != null && mrpVal > priceVal && priceVal > 0) {
      discountPercent = ((mrpVal - priceVal) / mrpVal * 100).round();
      savingsVal = mrpVal - priceVal;
    }

    final threshold = isLoose ? 2.0 : 5.0;
    String status = 'In Stock';
    Color statusColor = const Color(0xFF16A34A);
    Color statusBg = const Color(0xFFDCFCE7);
    Color statusBorder = const Color(0xFFBBF7D0);
    if (stock <= 0) {
      status = 'Out of Stock';
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
      statusBorder = const Color(0xFFFECACA);
    } else if (stock <= threshold) {
      status = 'Low Stock';
      statusColor = const Color(0xFFEA580C);
      statusBg = const Color(0xFFFFEDD5);
      statusBorder = const Color(0xFFFED7AA);
    }

    final stockDisplay = isLoose ? stock.toStringAsFixed(1) : stock.toInt().toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: widget.onBack,
        ),
        title: Text(
          name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_rounded, color: Color(0xFF0C831F), size: 18),
            ),
            tooltip: 'Edit Product',
            onPressed: () {
              AdminProductForms.showEditProductDialog(context, widget.barcode);
            },
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
            ),
            tooltip: 'Delete Product',
            onPressed: _deleteProduct,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Zepto Hero Product Image Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ProductImageWidget(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Stock Status Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Veg / Non-Veg Indicator
                  if (isFoodItem)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
                          ],
                        ),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 2. Product Information Card
            Container(
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
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (quantity.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$quantity $unit',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C831F).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0C831F).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.category_rounded, size: 13, color: Color(0xFF0C831F)),
                            const SizedBox(width: 4),
                            Text(
                              category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0C831F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_rounded, size: 13, color: Color(0xFF475569)),
                            const SizedBox(width: 4),
                            Text(
                              barcode,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLoose)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.scale_rounded, size: 13, color: Color(0xFFB45309)),
                              SizedBox(width: 4),
                              Text(
                                'Loose Item',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
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

            const SizedBox(height: 14),

            // 3. Pricing & Savings Card
            Container(
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
                  const Text(
                    'Price & Margins',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹$priceStr',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (mrpStr != null && mrpStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹$mrpStr',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      if (discountPercent != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$discountPercent% OFF',
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (savingsVal != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.savings_rounded, color: Color(0xFF16A34A), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Customer saves ₹${savingsVal.toStringAsFixed(0)} per unit',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 4. Stock & Quick Controls Card
            Container(
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
                      const Text(
                        'Stock Level',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => AdminProductForms.showEditProductDialog(context, widget.barcode),
                        icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0C831F)),
                        label: const Text('Update', style: TextStyle(color: Color(0xFF0C831F), fontWeight: FontWeight.w700, fontSize: 13)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                stockDisplay,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                unit,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Low stock alert at $threshold $unit',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      // Quick Adjust +/- stepper
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_rounded, color: Color(0xFF0F172A), size: 18),
                              onPressed: () => _quickAdjustStock(-1.0),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                stockDisplay,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_rounded, color: Color(0xFF0C831F), size: 18),
                              onPressed: () => _quickAdjustStock(1.0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 5. Actions: Edit, Out of Stock, Delete
            ElevatedButton.icon(
              onPressed: () {
                AdminProductForms.showEditProductDialog(context, widget.barcode);
              },
              icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
              label: const Text('Edit Product Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C831F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _markOutOfStock,
                    icon: const Icon(Icons.block_rounded, size: 16, color: Color(0xFFEA580C)),
                    label: const Text('Mark Out of Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEA580C))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFFED7AA)),
                      backgroundColor: const Color(0xFFFFF7ED),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteProduct,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                    label: const Text('Delete Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          Row(
            children: [
              Text('Products', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 16),
              ),
              const Text('Product Details', style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 24),
          // Page Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product Details', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  Text('View and manage product information, pricing, stock and more', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 18),
                    label: const Text('Back to Products', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      AdminProductForms.showEditProductDialog(context, widget.barcode);
                    },
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    label: const Text('Edit Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF136633),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Main Content
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          _buildMainProductCard(),
                          const SizedBox(height: 24),
                          _buildAdditionalInfoCard(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildPricingCard(),
                          const SizedBox(height: 24),
                          _buildStockCard(),
                          const SizedBox(height: 24),
                          _buildActionsCard(),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildMainProductCard(),
                    const SizedBox(height: 24),
                    _buildPricingCard(),
                    const SizedBox(height: 24),
                    _buildStockCard(),
                    const SizedBox(height: 24),
                    _buildAdditionalInfoCard(),
                    const SizedBox(height: 24),
                    _buildActionsCard(),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainProductCard() {
    final name = productData?['name'] ?? widget.productName;
    final barcode = productData?['barcode'] ?? widget.barcode;
    final imageUrl = productData?['image_url'];
    final quantity = productData?['quantity']?.toString() ?? '';
    final isLoose = productData?['is_loose'] ?? false;
    final unit = isLoose ? 'kg' : 'pcs';
    final categories = productData?['categories'] as List<dynamic>? ?? [];
    final category = categories.isNotEmpty ? categories.first.toString() : 'Unknown';
    final stock = (productData?['stock_quantity'] as num?)?.toDouble() ?? 0.0;
    final isVeg = productData?['isVegetarian'] ?? true;
    
    // Status Logic
    final threshold = isLoose ? 2.0 : 5.0;
    String status = 'In Stock';
    Color statusColor = const Color(0xFF1F9444);
    if (stock <= 0) {
      status = 'Out of Stock';
      statusColor = const Color(0xFFF04456);
    } else if (stock <= threshold) {
      status = 'Low Stock';
      statusColor = const Color(0xFFFF7B00);
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Area
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ProductImageWidget(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Icon(Icons.favorite_border, color: Colors.grey.shade400),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildThumbnail(imageUrl, isActive: true),
                    const SizedBox(width: 12),
                    _buildThumbnail(null, icon: Icons.add, isAdd: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
          // Info Area
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                Text('$quantity $unit', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Row(
                      children: List.generate(5, (index) => Icon(Icons.star, color: index < 4 ? Colors.amber : Colors.grey.shade300, size: 18)),
                    ),
                    const SizedBox(width: 8),
                    Text('4.0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    const SizedBox(width: 4),
                    Text('(Reviews N/A)', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Bestseller', style: TextStyle(color: Color(0xFF1F9444), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                _buildInfoRow('Category', category, isTag: true),
                _buildInfoRow('Barcode', barcode),
                _buildInfoRow('Unit / Weight', '$quantity $unit'),
                _buildInfoRow('Product Type', isVeg ? 'Vegetarian' : 'Non-Vegetarian'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String? imageUrl, {bool isActive = false, bool isAdd = false, IconData? icon}) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? const Color(0xFF136633) : Colors.grey.shade200, width: isActive ? 2 : 1),
      ),
      child: isAdd 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.grey.shade400, size: 24),
                const SizedBox(height: 4),
                Text('Add Image', style: TextStyle(color: Colors.grey.shade500, fontSize: 8)),
              ],
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ProductImageWidget(imageUrl: imageUrl, fit: BoxFit.cover),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTag = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
          ),
          Expanded(
            child: isTag
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(value, style: TextStyle(color: Colors.blue.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  )
                : Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    final price = productData?['price']?.toString() ?? '0';
    final mrp = productData?['mrp']?.toString();
    String? discountBadge;
    String? savingsText;

    if (mrp != null && mrp.isNotEmpty) {
      final p = double.tryParse(price) ?? 0;
      final m = double.tryParse(mrp) ?? 0;
      if (m > p && m > 0) {
        final off = ((m - p) / m * 100).round();
        discountBadge = '$off% OFF';
        savingsText = '₹${(m - p).toStringAsFixed(0)} per unit';
      }
    }

    return _buildCardWrapper(
      title: 'Pricing',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selling Price', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Text('₹$price', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),
              if (mrp != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MRP (Original Price)', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      Text('₹$mrp', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough)),
                    ],
                  ),
                ),
              if (discountBadge != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discount', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                        child: Text(discountBadge, style: const TextStyle(color: Color(0xFF1F9444), fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (savingsText != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFF1F9444), shape: BoxShape.circle),
                    child: const Icon(Icons.savings_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('You Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                      Text(savingsText, style: const TextStyle(fontSize: 14, color: Color(0xFF1F9444), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStockCard() {
    final stock = (productData?['stock_quantity'] as num?)?.toDouble() ?? 0.0;
    final isLoose = productData?['is_loose'] ?? false;
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

    final stockDisplay = isLoose ? stock.toStringAsFixed(1) : stock.toInt().toString();

    return _buildCardWrapper(
      title: 'Stock Information',
      action: OutlinedButton.icon(
        onPressed: () => AdminProductForms.showEditProductDialog(context, widget.barcode),
        icon: const Icon(Icons.edit, size: 16, color: Colors.black87),
        label: const Text('Update Stock', style: TextStyle(color: Colors.black87)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStockStatCard('Current Stock', stockDisplay, Icons.inventory_2_outlined, const Color(0xFF1F9444), const Color(0xFFE8F5E9)),
              const SizedBox(width: 16),
              _buildStockStatCard('Low Stock Alert', '$threshold', Icons.warning_amber_rounded, const Color(0xFFFF7B00), const Color(0xFFFFF3E0)),
              const SizedBox(width: 16),
              _buildStockStatCard('Reserved Stock', '0', Icons.block, const Color(0xFFF04456), const Color(0xFFFFEBEE)),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(width: 120, child: Text('Stock Status', style: TextStyle(fontSize: 15, color: Colors.grey.shade600))),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(status, style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Text('Product is ${stock > 0 ? 'available' : 'unavailable'} for purchase', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockStatCard(String label, String value, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bgColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.1), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoCard() {
    return _buildCardWrapper(
      title: 'Additional Information',
      child: Column(
        children: [
          _buildInfoRow('Short Description', 'Not available'),
          _buildInfoRow('Long Description', 'Not available'),
          _buildInfoRow('Ingredients', 'Not available'),
          _buildInfoRow('Shelf Life', 'Not available'),
          _buildInfoRow('Storage Instructions', 'Not available'),
          _buildInfoRow('Tags', 'Not available'),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return _buildCardWrapper(
      title: 'Product Actions',
      child: Column(
        children: [
          _buildActionRow('Edit Product', Icons.edit_outlined, const Color(0xFF1F9444), const Color(0xFFE8F5E9), () {
            AdminProductForms.showEditProductDialog(context, widget.barcode);
          }),
          const SizedBox(height: 12),
          _buildActionRow('Update Stock', Icons.inventory_2_outlined, const Color(0xFF007AFF), const Color(0xFFE3F2FD), () {
            AdminProductForms.showEditProductDialog(context, widget.barcode);
          }),
          const SizedBox(height: 12),
          _buildActionRow('Mark as Out of Stock', Icons.block, const Color(0xFFFF7B00), const Color(0xFFFFF3E0), _markOutOfStock),
          const SizedBox(height: 12),
          _buildActionRow('Delete Product', Icons.delete_outline, const Color(0xFFF04456), const Color(0xFFFFEBEE), _deleteProduct),
        ],
      ),
    );
  }

  Widget _buildActionRow(String label, IconData icon, Color color, Color bgColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bgColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15))),
            Icon(Icons.chevron_right, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCardWrapper({required String title, required Widget child, Widget? action}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ?action,
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
