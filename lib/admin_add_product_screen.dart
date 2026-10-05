import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:near_kirana/admin_desktop_dashboard.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/firestore_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:near_kirana/modern_loader.dart';
import 'package:near_kirana/utils/product_image_widget.dart';
import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:near_kirana/sound_service.dart';
import 'package:near_kirana/utils/snackbar_helper.dart';

class AdminAddProductScreen extends StatefulWidget {
  final String? barcode; // if null, it's Add Mode. if provided, it's Edit Mode

  const AdminAddProductScreen({super.key, this.barcode});

  @override
  State<AdminAddProductScreen> createState() => _AdminAddProductScreenState();
}

class _AdminAddProductScreenState extends State<AdminAddProductScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockController = TextEditingController();
  final _quantityController = TextEditingController();
  final _barcodeController = TextEditingController();
  
  bool _isLoose = false;
  bool _isFoodItem = true;
  bool _isVegetarian = true;
  
  File? _pickedImage;
  String? _fetchedImageUrl;
  bool _isUploading = false;
  bool _isLoading = true;
  
  List<String> _selectedCategories = [];
  List<String> _categories = [];
  bool _isFetchingCategories = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  Future<void> _initData() async {
    setState(() => _isLoading = true);
    
    // Fetch Categories
    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config';
      final doc = await FirebaseUtils.firestore.collection('shops').doc(shopId).get();
      if (doc.exists && doc.data()!.containsKey('categories')) {
        final List<dynamic> fetchedCats = doc['categories'];
        _categories = fetchedCats.map((e) => e.toString()).toList();
        _categories.remove('All');
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
    
    // Fetch Product Data if Edit Mode
    if (widget.barcode != null) {
      _barcodeController.text = widget.barcode!;
      try {
        final existingProduct = await FirestoreService().getProduct(widget.barcode!);
        if (existingProduct != null) {
          _nameController.text = existingProduct['name'] ?? '';
          _priceController.text = existingProduct['price']?.toString() ?? '';
          _mrpController.text = existingProduct['mrp']?.toString() ?? '';
          _stockController.text = existingProduct['stock_quantity']?.toString() ?? '';
          _quantityController.text = existingProduct['quantity']?.toString() ?? '';
          _isLoose = existingProduct['is_loose'] ?? false;
          _isVegetarian = existingProduct['isVegetarian'] ?? true;
          _isFoodItem = existingProduct['isFoodItem'] ?? true;
          if (existingProduct['image_url'] != null) {
            _fetchedImageUrl = existingProduct['image_url'];
          }
          if (existingProduct['categories'] != null) {
            _selectedCategories = List<String>.from(existingProduct['categories']);
          }
        }
      } catch (e) {
        debugPrint("Error fetching product: $e");
      }
    }
    
    if (mounted) {
      setState(() {
        _isFetchingCategories = false;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    _quantityController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  }
  
  Future<void> _saveProduct() async {
    if (_nameController.text.trim().isEmpty || _priceController.text.trim().isEmpty) {
      SnackbarHelper.showSnackBar(context, 'Please enter name and price.', isError: true);
      return;
    }
    
    if (widget.barcode == null && _barcodeController.text.trim().isEmpty) {
      SnackbarHelper.showSnackBar(context, 'Please enter SKU/Barcode.', isError: true);
      return;
    }

    final price = double.tryParse(_priceController.text) ?? 0.0;
    final mrp = double.tryParse(_mrpController.text) ?? 0.0;
    final stock = double.tryParse(_stockController.text) ?? 0.0;

    if (price <= 0 || stock < 0) {
      SnackbarHelper.showSnackBar(context, AppLocalizations.of(context)!.err_price_stock, isError: true);
      return;
    }
    
    setState(() => _isUploading = true);
    
    try {
      String? finalImageUrl = _fetchedImageUrl;
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        final base64String = base64Encode(bytes);
        finalImageUrl = 'data:image/jpeg;base64,$base64String';
      }
      
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      final barcode = widget.barcode ?? _barcodeController.text.trim();
      
      Map<String, dynamic> extraData = {
        'isVegetarian': _isVegetarian,
        'isFoodItem': _isFoodItem,
      };
      
      if (_mrpController.text.isNotEmpty) {
        extraData['mrp'] = mrp;
      }
      if (_selectedCategories.isNotEmpty) {
        extraData['categories'] = _selectedCategories;
      }
      if (_quantityController.text.isNotEmpty) {
        extraData['quantity'] = _quantityController.text;
      }

      await FirestoreService().updateProduct(
        barcode,
        _nameController.text.trim(),
        price,
        _isLoose,
        stock,
        finalImageUrl,
        extraData,
        shopId,
      );
      
      SoundService().play('add_cart.mp3');
      if (mounted) {
        SnackbarHelper.showSnackBar(context, widget.barcode == null ? 'Product Added Successfully' : 'Product Updated Successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _deleteProduct() {
    if (widget.barcode == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${_nameController.text}"?'),
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
                  Navigator.pop(context); // close screen
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        
        final content = _isLoading 
            ? const Center(child: ModernLoader(color: AppColors.primaryDark))
            : isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
            
        if (isDesktop) {
          return AdminDesktopDashboard(
            selectedIndex: 2, // Products
            onNavTap: (index) => Navigator.pop(context), // Let the back navigation handle it
            child: Scaffold(
              backgroundColor: const Color(0xFFF8F9FA),
              body: Column(
                children: [
                  const AdminTopHeader(),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(title: Text(widget.barcode == null ? 'Add Product' : 'Edit Product')),
          body: content,
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBasicInformationCard(),
                    const SizedBox(height: 24),
                    _buildPricingInformationCard(),
                    const SizedBox(height: 24),
                    _buildInventoryInformationCard(),
                    const SizedBox(height: 24),
                    _buildAdditionalInformationCard(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Column
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProductPreviewCard(),
                    const SizedBox(height: 24),
                    _buildProductDetailsCard(),
                    const SizedBox(height: 24),
                    _buildQuickActionsCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBasicInformationCard(),
          const SizedBox(height: 16),
          _buildPricingInformationCard(),
          const SizedBox(height: 16),
          _buildInventoryInformationCard(),
          const SizedBox(height: 16),
          _buildAdditionalInformationCard(),
          const SizedBox(height: 16),
          _buildProductPreviewCard(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _saveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.barcode == null ? 'Save Product' : 'Update Product', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.bgTint),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, size: 18),
                    const SizedBox(width: 8),
                    Text('Back', style: AppTextStyles.bodyMedium(color: AppColors.textDark)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.barcode == null ? 'Add Product' : 'Edit Product', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28)),
                const SizedBox(height: 4),
                Text('Add a new product or update existing product information', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add Product'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.1),
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primaryLight),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Product'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: const BorderSide(color: AppColors.bgTint),
                foregroundColor: AppColors.textDark,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading2(color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildBasicInformationCard() {
    return _buildCard(
      title: 'Basic Information',
      subtitle: 'Enter the basic details about this product',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Uploader
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5), width: 1.5, style: BorderStyle.solid), // Reference shows solid border but maybe dashed is better. Wait, ref shows solid light border with green icon
              ),
              child: _pickedImage != null 
                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_pickedImage!, fit: BoxFit.cover))
                  : (_fetchedImageUrl != null && _fetchedImageUrl!.isNotEmpty)
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: ProductImageWidget(imageUrl: _fetchedImageUrl, width: 160, height: 160, fit: BoxFit.cover))
                      : Stack(
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt_outlined, color: AppColors.primaryDark, size: 32),
                                  const SizedBox(height: 8),
                                  Text('Add Product Images', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('JPG, PNG (Max 5MB each)', style: TextStyle(color: AppColors.textMid, fontSize: 11)),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Text('0/5 images', style: TextStyle(color: AppColors.textMid, fontSize: 10)),
                            ),
                          ],
                        ),
            ),
          ),
          const SizedBox(width: 24),
          // Fields
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField('Product Name *', _nameController, Icons.person_outline, 'Aashirvaad Atta 5kg')), // Reference uses person_outline? No, we don't have exact icons. Let's omit prefix icons for products if we want to match reference closely. Wait, reference shows prefix icons! product name has person-like icon, category has list icon.
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category *', style: AppTextStyles.bodySemiBold(color: AppColors.textDark).copyWith(fontSize: 13)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedCategories.isNotEmpty ? _selectedCategories.first : null,
                            hint: Text('Select Category', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.category_outlined, color: AppColors.textMid, size: 20),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
                            ),
                            items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedCategories.clear();
                                  _selectedCategories.add(val);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              text: 'Brand',
                              style: AppTextStyles.bodySemiBold(color: AppColors.textDark).copyWith(fontSize: 13, fontFamily: GoogleFonts.inter().fontFamily),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: 'Aashirvaad',
                            hint: Text('Select Brand', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppColors.textMid, size: 20),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
                            ),
                            items: ['Aashirvaad', 'Tata', 'Fortune'].map((brand) => DropdownMenuItem(value: brand, child: Text(brand))).toList(),
                            onChanged: (val) {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('SKU (Optional)', _barcodeController, Icons.qr_code_2_outlined, 'ASH-ATTA-5KG')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingInformationCard() {
    return _buildCard(
      title: 'Pricing Information',
      subtitle: 'Set the product pricing and tax details',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField('Purchase Price (₹) *', TextEditingController(), Icons.shopping_bag_outlined, '220.00')), // We don't have purchase price in model, but leaving field for visual match
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Selling Price (₹) *', _priceController, Icons.sell_outlined, '260.00', isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('MRP (₹)', _mrpController, Icons.local_offer_outlined, '280.00', isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Tax (%)', TextEditingController(), Icons.percent_outlined, '5% (GST)')), // We don't have tax in model
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart, color: AppColors.primaryDark, size: 18),
                    const SizedBox(width: 8),
                    Text('Profit Margin: - (-)', style: AppTextStyles.bodyMedium(color: AppColors.primaryDark)),
                  ],
                ),
                Text('Total Price (incl. tax): ₹${_priceController.text.isNotEmpty ? _priceController.text : "0.00"}', style: AppTextStyles.bodySemiBold(color: AppColors.primaryDark)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInventoryInformationCard() {
    return _buildCard(
      title: 'Inventory Information',
      subtitle: 'Manage stock and availability details',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField('Stock Quantity *', _stockController, Icons.inventory_2_outlined, '50', isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Minimum Stock Alert', TextEditingController(), Icons.notifications_active_outlined, '10')), // not in model
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Unit', _quantityController, Icons.straighten_outlined, 'Kilogram (kg)')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text('Track Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Enable stock tracking for this product', style: TextStyle(fontSize: 11)),
                  value: true,
                  onChanged: (val) {},
                  activeColor: AppColors.primaryDark,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  title: const Text('Low Stock Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Get notified when stock is low', style: TextStyle(fontSize: 11)),
                  value: true,
                  onChanged: (val) {},
                  activeColor: AppColors.primaryDark,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInformationCard() {
    return _buildCard(
      title: 'Additional Information',
      subtitle: 'Add more details about this product',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  'Product Description (Optional)', 
                  TextEditingController(), 
                  Icons.description_outlined, 
                  'High quality product...', 
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Khula Saman (Loose Item)'),
                      value: _isLoose,
                      onChanged: (val) => setState(() => _isLoose = val),
                      activeColor: AppColors.primaryDark,
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Food Item'),
                      value: _isFoodItem,
                      onChanged: (val) => setState(() => _isFoodItem = val),
                      activeColor: AppColors.primaryDark,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_isFoodItem)
                      SwitchListTile(
                        title: const Text('Vegetarian'),
                        value: _isVegetarian,
                        onChanged: (val) => setState(() => _isVegetarian = val),
                        activeColor: Colors.green,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppColors.textMid),
                  foregroundColor: AppColors.textDark,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _saveProduct,
                icon: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_outlined),
                label: Text(widget.barcode == null ? 'Save Product' : 'Update Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProductPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product Preview', style: AppTextStyles.heading2(color: AppColors.textDark)),
          const SizedBox(height: 16),
          Center(
            child: _pickedImage != null 
                ? Image.file(_pickedImage!, height: 180, fit: BoxFit.contain)
                : (_fetchedImageUrl != null && _fetchedImageUrl!.isNotEmpty)
                    ? ProductImageWidget(imageUrl: _fetchedImageUrl, height: 180, fit: BoxFit.contain)
                    : Container(height: 180, width: 180, color: AppColors.bgTint, child: const Icon(Icons.image, size: 64, color: AppColors.textMid)),
          ),
          const SizedBox(height: 24),
          Text(_nameController.text.isNotEmpty ? _nameController.text : 'Product Name', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text('${_selectedCategories.isNotEmpty ? _selectedCategories.first : "Category"}', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${_priceController.text.isNotEmpty ? _priceController.text : "0"}', style: AppTextStyles.heading1(color: AppColors.primaryDark).copyWith(fontSize: 24)),
              const SizedBox(width: 8),
              if (_mrpController.text.isNotEmpty)
                Text('₹${_mrpController.text}', style: TextStyle(color: AppColors.textMid, decoration: TextDecoration.lineThrough, fontSize: 16)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.primaryDark, size: 12),
                    const SizedBox(width: 4),
                    Text('In Stock (${_stockController.text.isNotEmpty ? _stockController.text : "0"})', style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Product Details', style: AppTextStyles.heading2(color: AppColors.textDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.bgTint.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 12, color: AppColors.textDark),
                    const SizedBox(width: 4),
                    const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('SKU', _barcodeController.text.isNotEmpty ? _barcodeController.text : '-'),
          const SizedBox(height: 12),
          _buildInfoRow('Unit', _quantityController.text.isNotEmpty ? _quantityController.text : '-'),
          const SizedBox(height: 12),
          _buildInfoRow('Category', _selectedCategories.isNotEmpty ? _selectedCategories.first : '-'),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppTextStyles.heading2(color: AppColors.textDark)),
          const SizedBox(height: 16),
          if (widget.barcode != null)
            _buildActionRow(Icons.delete_outline, 'Delete Product', 'Remove this product', Colors.red, _deleteProduct)
          else
            const Text('Save product first to see more actions.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
        Text(value, style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
      ],
    );
  }

  Widget _buildActionRow(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle, style: TextStyle(color: AppColors.textMid, fontSize: 11)),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, String hint, {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label.replaceAll(' *', ''),
            style: AppTextStyles.bodySemiBold(color: AppColors.textDark).copyWith(fontSize: 13, fontFamily: GoogleFonts.inter().fontFamily),
            children: [
              if (label.contains('*'))
                const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          onChanged: (v) => setState(() {}), // Update preview
          style: AppTextStyles.bodyMedium(color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textMid, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryDark)),
          ),
        ),
      ],
    );
  }
}
