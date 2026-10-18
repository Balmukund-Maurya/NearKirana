import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'utils/product_image_widget.dart';
import 'utils/snackbar_helper.dart';
import 'api_service.dart';
import 'modern_loader.dart';
import 'sound_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'shop_provider.dart';
import 'language_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'admin_categories_screen.dart';

class AdminProductForms {
  static void showEditProductDialog(BuildContext context, String barcode) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final quantityController = TextEditingController();
    bool isLoose = false;
    bool isFoodItem = true;
    bool isVegetarian = true;
    File? pickedImage;
    String? fetchedImageUrl;
    List<String> productImages = [];
    bool isFetching = true;
    bool isUploading = false;
    bool hasFetched = false;
    List<String> selectedCategories = [];
    List<String> categories = [];
    bool isFetchingCategories = true;

    FirebaseUtils.firestore
        .collection('shops').doc(Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config')
        .get()
        .then((doc) {
      if (doc.exists && doc.data()!.containsKey('categories')) {
        final List<dynamic> fetchedCats = doc['categories'];
        categories = fetchedCats.map((e) => e.toString()).toList();
        categories.remove('All');
      }
      isFetchingCategories = false;
    }).catchError((e) {
      isFetchingCategories = false;
    });
    Map<String, dynamic>? fetchedExtraDetails;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final lang = Provider.of<LanguageProvider>(context);
        String t(String en, String hi, String hinglish) {
          if (lang.isHindi) return hi;
          if (lang.isHinglish) return hinglish;
          return en;
        }

        return StatefulBuilder(
          builder: (context, setState) {
            if (isFetchingCategories) {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (context.mounted) setState(() {});
              });
            }

            // Only fetch once
            if (!hasFetched) {
              hasFetched = true;

              FirestoreService()
                  .getProduct(barcode)
                  .then((existingProduct) {
                    if (!context.mounted) return;

                    if (existingProduct != null) {
                      setState(() {
                        isFetching = false;
                        nameController.text = existingProduct['name'] ?? '';
                        priceController.text = existingProduct['price']?.toString() ?? '';
                        stockController.text = existingProduct['stock_quantity']?.toString() ?? '';
                        isLoose = existingProduct['is_loose'] ?? false;
                        if (existingProduct['image_url'] != null) {
                          fetchedImageUrl = existingProduct['image_url'];
                        }
                        if (existingProduct['images'] != null && existingProduct['images'] is List) {
                          productImages = List<String>.from(existingProduct['images']);
                        } else if (existingProduct['image_urls'] != null && existingProduct['image_urls'] is List) {
                          productImages = List<String>.from(existingProduct['image_urls']);
                        }
                        if (productImages.isEmpty && fetchedImageUrl != null && fetchedImageUrl!.isNotEmpty) {
                          productImages.add(fetchedImageUrl!);
                        }
                        if (existingProduct['quantity'] != null) {
                          quantityController.text = existingProduct['quantity'].toString();
                        }
                        if (existingProduct['isVegetarian'] != null) {
                          isVegetarian = existingProduct['isVegetarian'];
                        }
                        if (existingProduct['isFoodItem'] != null) {
                          isFoodItem = existingProduct['isFoodItem'];
                        }
                        if (existingProduct['categories'] != null) {
                          List<dynamic> productCats = existingProduct['categories'];
                          selectedCategories = productCats.map((e) => e.toString()).toList();
                        } else if (existingProduct['category'] != null) {
                          selectedCategories = [existingProduct['category'].toString()];
                        }
                        fetchedExtraDetails = {
                          'brand': existingProduct['brand'],
                          'ingredients': existingProduct['ingredients'],
                          if (existingProduct['purchase_price'] != null)
                            'purchase_price': existingProduct['purchase_price'],
                          if (existingProduct['cost_price'] != null)
                            'cost_price': existingProduct['cost_price'],
                          if (existingProduct['mrp'] != null)
                            'mrp': existingProduct['mrp'],
                        };
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(t('Product details loaded for editing', 'उत्पाद विवरण लोड हो गया है', 'Product details loaded')),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else {
                      ApiService.fetchProductData(barcode)
                          .then((data) {
                            if (!context.mounted) return;
                            setState(() {
                              isFetching = false;
                              if (data != null) {
                                if (data['name']!.isNotEmpty && nameController.text.isEmpty) {
                                  String productName = data['name']!;
                                  if (data['quantity'] != null && data['quantity'].toString().isNotEmpty) {
                                    productName += ' - ${data['quantity']}';
                                  }
                                  nameController.text = productName;
                                }
                                if (data['imageUrl']!.isNotEmpty) {
                                  fetchedImageUrl = data['imageUrl'];
                                  if (!productImages.contains(fetchedImageUrl)) {
                                    productImages.add(fetchedImageUrl!);
                                  }
                                }
                                if (data['quantity'] != null && data['quantity'].toString().isNotEmpty) {
                                  quantityController.text = data['quantity'].toString();
                                }
                                if (data['isVegetarian'] != null) {
                                  isVegetarian = data['isVegetarian'];
                                }
                                if (data['isFoodItem'] != null) {
                                  isFoodItem = data['isFoodItem'];
                                }
                                fetchedExtraDetails = {
                                  'brand': data['brand'],
                                  'ingredients': data['ingredients'],
                                };
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(t('Online product details found', 'उत्पाद विवरण प्राप्त हुआ', 'Product info fetched')),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                          })
                          .catchError((e) {
                            if (context.mounted) setState(() => isFetching = false);
                          });
                    }
                  })
                  .catchError((e) {
                    if (context.mounted) setState(() => isFetching = false);
                  });
            }

            void showImageSourcePicker() {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                      ),
                      Text(
                        t('Product Photo', 'उत्पाद की फोटो', 'Product Photo'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFF0C831F).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0C831F), size: 22),
                        ),
                        title: Text(t('Take Photo (Camera)', 'कैमरे से फोटो खींचें', 'Take Photo (Camera)'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final picker = ImagePicker();
                          final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 800, maxHeight: 800);
                          if (file != null) {
                            final bytes = await file.readAsBytes();
                            final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                            setState(() {
                              productImages.add(b64);
                              fetchedImageUrl = productImages.first;
                            });
                          }
                        },
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        title: Text(t('Choose from Gallery', 'गैलरी से फोटो चुनें', 'Choose from Gallery'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text(t('Can select multiple photos', 'एक साथ कई फोटो चुन सकते हैं', 'Can select multiple photos'), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final picker = ImagePicker();
                          try {
                            final files = await picker.pickMultiImage(imageQuality: 50, maxWidth: 800, maxHeight: 800);
                            if (files.isNotEmpty) {
                              for (final f in files) {
                                final bytes = await f.readAsBytes();
                                final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                if (!productImages.contains(b64)) {
                                  productImages.add(b64);
                                }
                              }
                              setState(() {
                                if (productImages.isNotEmpty) fetchedImageUrl = productImages.first;
                              });
                              return;
                            }
                          } catch (_) {}
                          final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800, maxHeight: 800);
                          if (file != null) {
                            final bytes = await file.readAsBytes();
                            final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                            setState(() {
                              if (!productImages.contains(b64)) productImages.add(b64);
                              fetchedImageUrl = productImages.first;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            }

            return Container(
              margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Zepto style Drag Handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Header Top Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_note_rounded, color: Color(0xFF0C831F), size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t('Edit Product', 'उत्पाद विवरण बदलें', 'Product Edit Karein'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    t('Update price, stock & category', 'कीमत, स्टॉक और श्रेणी अपडेट करें', 'Price, stock aur category update karein'),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            if (hasFetched && fetchedExtraDetails != null)
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                ),
                                tooltip: t('Delete Product', 'उत्पाद हटाएं', 'Delete Product'),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (deleteCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              t('Delete Product?', 'उत्पाद हटाएं?', 'Delete Product?'),
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: Text(
                                        t('Are you sure you want to permanently delete this product from your inventory?',
                                          'क्या आप वाकई इस उत्पाद को इन्वेंट्री से हमेशा के लिए हटाना चाहते हैं?',
                                          'Kya aap is product ko permanent delete karna chahte hain?'),
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(deleteCtx),
                                          child: Text(
                                            t('Cancel', 'रद्द करें', 'Cancel'),
                                            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            Navigator.pop(deleteCtx);
                                            Navigator.pop(context);
                                            try {
                                              await FirebaseUtils.firestore.collection('products').doc(barcode).delete();
                                              if (context.mounted) {
                                                SnackbarHelper.showSnackBar(
                                                  context,
                                                  t('Product deleted successfully', 'उत्पाद सफलता से हटा दिया गया', 'Product deleted successfully'),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                SnackbarHelper.showSnackBar(
                                                  context,
                                                  t('Error deleting product', 'उत्पाद हटाने में त्रुटि', 'Error deleting product'),
                                                  isError: true,
                                                );
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFDC2626),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          child: Text(
                                            t('Delete', 'हटाएं', 'Delete'),
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // Form Body
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Hero Media & Barcode Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          width: 108,
                                          height: 108,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.04),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          clipBehavior: Clip.hardEdge,
                                          child: isFetching
                                              ? const Center(child: ModernLoader(color: Color(0xFF0C831F)))
                                              : (productImages.isNotEmpty
                                                  ? ProductImageWidget(
                                                      imageUrl: productImages.first,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : (fetchedImageUrl != null
                                                      ? ProductImageWidget(
                                                          imageUrl: fetchedImageUrl!,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : const Center(
                                                          child: Icon(Icons.image_outlined, size: 40, color: Color(0xFF94A3B8)),
                                                        ))),
                                        ),
                                        Positioned(
                                          right: -4,
                                          bottom: -4,
                                          child: InkWell(
                                            onTap: showImageSourcePicker,
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0C831F),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.15),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Multi-photo Row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${t('Product Photos', 'उत्पाद की फोटो', 'Product Photos')} (${productImages.length})',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                        ),
                                        InkWell(
                                          onTap: showImageSourcePicker,
                                          child: Text(
                                            t('+ Add Photo', '+ फोटो जोड़ें', '+ Add Photo'),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0C831F)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 62,
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        children: [
                                          ...productImages.asMap().entries.map((entry) {
                                            final idx = entry.key;
                                            final imgUrl = entry.value;
                                            final isCover = idx == 0;

                                            return Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: Stack(
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      if (idx > 0) {
                                                        setState(() {
                                                          final item = productImages.removeAt(idx);
                                                          productImages.insert(0, item);
                                                          fetchedImageUrl = item;
                                                        });
                                                      }
                                                    },
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: Container(
                                                      width: 58,
                                                      height: 58,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                          color: isCover ? const Color(0xFF0C831F) : const Color(0xFFCBD5E1),
                                                          width: isCover ? 2.0 : 1.0,
                                                        ),
                                                      ),
                                                      clipBehavior: Clip.hardEdge,
                                                      child: Stack(
                                                        fit: StackFit.expand,
                                                        children: [
                                                          ProductImageWidget(imageUrl: imgUrl, fit: BoxFit.cover),
                                                          if (isCover)
                                                            Positioned(
                                                              bottom: 0,
                                                              left: 0,
                                                              right: 0,
                                                              child: Container(
                                                                color: const Color(0xFF0C831F),
                                                                padding: const EdgeInsets.symmetric(vertical: 1),
                                                                child: const Text(
                                                                  'MAIN',
                                                                  textAlign: TextAlign.center,
                                                                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 0,
                                                    right: 0,
                                                    child: InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          productImages.removeAt(idx);
                                                          fetchedImageUrl = productImages.isNotEmpty ? productImages.first : null;
                                                        });
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.all(2),
                                                        decoration: const BoxDecoration(
                                                          color: Color(0xFFDC2626),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(Icons.close, size: 10, color: Colors.white),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                          InkWell(
                                            onTap: showImageSourcePicker,
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              width: 58,
                                              height: 58,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                              ),
                                              child: const Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.add_photo_alternate_rounded, size: 20, color: Color(0xFF0C831F)),
                                                  Text('Add', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0C831F))),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.qr_code_2_rounded, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Barcode/ID: $barcode',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Item Name Field
                              _buildModernTextField(
                                controller: nameController,
                                label: t('Item Name', 'उत्पाद का नाम', 'Item Name'),
                                hint: t('e.g. Ashirvaad Shudh Chakki Atta', 'उदा. आशीर्वाद आटा', 'e.g. Ashirvaad Shudh Chakki Atta'),
                                prefixIcon: Icons.shopping_bag_outlined,
                              ),
                              const SizedBox(height: 14),

                              // Pricing & Stock Fields
                              if (isLoose) ...[
                                _buildModernTextField(
                                  controller: priceController,
                                  label: t('Price per Kg / Litre (₹)', 'प्रति किग्रा / लीटर कीमत (₹)', 'Price per Kg / Litre (₹)'),
                                  hint: '0.00',
                                  prefixIcon: Icons.currency_rupee_rounded,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                ),
                                const SizedBox(height: 14),
                                _buildModernTextField(
                                  controller: stockController,
                                  label: t('Stock (in Kg / Litre)', 'स्टॉक (किग्रा / लीटर में)', 'Stock (Kg / Litre)'),
                                  hint: '0.0',
                                  prefixIcon: Icons.scale_rounded,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                ),
                                const SizedBox(height: 14),
                                _buildModernTextField(
                                  controller: quantityController,
                                  label: t('Base Unit (e.g. 1 Kg, 500 g)', 'बेस यूनिट (उदा. 1 किग्रा)', 'Base Unit (e.g. 1 Kg)'),
                                  hint: '1 Kg',
                                  prefixIcon: Icons.straighten_rounded,
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModernTextField(
                                        controller: priceController,
                                        label: t('Price (₹)', 'कीमत (₹)', 'Price (₹)'),
                                        hint: '0.00',
                                        prefixIcon: Icons.currency_rupee_rounded,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildModernTextField(
                                        controller: stockController,
                                        label: t('Stock Qty', 'स्टॉक मात्रा', 'Stock Qty'),
                                        hint: '0',
                                        prefixIcon: Icons.inventory_2_outlined,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _buildModernTextField(
                                  controller: quantityController,
                                  label: t('Pkg Size / Qty (e.g., 1 Kg, 500 ml)', 'पैकेज साइज / वजन (उदा. 1 किग्रा, 500 मिली)', 'Pkg Size / Qty (e.g., 1 Kg, 500 ml)'),
                                  hint: '10kg',
                                  prefixIcon: Icons.scale_outlined,
                                ),
                              ],
                              const SizedBox(height: 18),

                              // Categories Section (Zepto Pill Style)
                              if (!isFetchingCategories) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.category_rounded, size: 16, color: Color(0xFF0C831F)),
                                    const SizedBox(width: 6),
                                    Text(
                                      t('Categories', 'उत्पाद श्रेणियां', 'Categories'),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(width: 10),
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const AdminCategoriesScreen()),
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.photo_library_outlined, size: 13, color: Color(0xFF0C831F)),
                                          const SizedBox(width: 3),
                                          Text(
                                            t('Category Photos', 'श्रेणी फोटो लगाएं', 'Category Photos'),
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0C831F)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${selectedCategories.length} ${t('selected', 'चुने गए', 'selected')}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...categories.map((cat) {
                                      final isSelected = selectedCategories.contains(cat);
                                      return InkWell(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            if (isSelected) {
                                              selectedCategories.remove(cat);
                                            } else {
                                              selectedCategories.add(cat);
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF0C831F) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isSelected ? const Color(0xFF0C831F) : const Color(0xFFE2E8F0),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isSelected) ...[
                                                const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                                const SizedBox(width: 4),
                                              ],
                                              Text(
                                                cat,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                  color: isSelected ? Colors.white : const Color(0xFF334155),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                    InkWell(
                                      onTap: () {
                                        final newCatController = TextEditingController();
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            title: Text(
                                              t('Add New Category', 'नई श्रेणी जोड़ें', 'Add New Category'),
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                            ),
                                            content: TextField(
                                              controller: newCatController,
                                              decoration: InputDecoration(
                                                hintText: t('Category Name', 'श्रेणी का नाम', 'Category Name'),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text(t('Cancel', 'रद्द करें', 'Cancel'), style: const TextStyle(color: Color(0xFF64748B))),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  final val = newCatController.text.trim();
                                                  if (val.isNotEmpty) {
                                                    setState(() {
                                                      if (!categories.contains(val)) categories.add(val);
                                                      if (!selectedCategories.contains(val)) selectedCategories.add(val);
                                                    });
                                                    try {
                                                      await FirebaseUtils.firestore
                                                          .collection('shops')
                                                          .doc(Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config')
                                                          .update({
                                                        'categories': FieldValue.arrayUnion([val])
                                                      });
                                                    } catch (e) {
                                                      debugPrint('Error adding category: $e');
                                                    }
                                                  }
                                                  if (context.mounted) Navigator.pop(context);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF0C831F),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                child: Text(t('Add', 'जोड़ें', 'Add')),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFFDE68A)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.add_rounded, size: 14, color: Color(0xFFD97706)),
                                            const SizedBox(width: 4),
                                            Text(
                                              t('Add New', 'नई जोड़ें', 'Add New'),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 18),

                              // Clean Unified Diet / Food Type Selector (Replaces redundant 2 buttons)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _buildFssaiSquareDot(isVeg: isVegetarian, isFood: isFoodItem),
                                        const SizedBox(width: 8),
                                        Text(
                                          t('Dietary Type (FSSAI)', 'खाद्य प्रकार (वेज / नॉन-वेज)', 'Dietary Type (FSSAI)'),
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        // Veg Button
                                        Expanded(
                                          child: InkWell(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                isFoodItem = true;
                                                isVegetarian = true;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(12),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              decoration: BoxDecoration(
                                                color: (isFoodItem && isVegetarian) ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: (isFoodItem && isVegetarian) ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                                                  width: (isFoodItem && isVegetarian) ? 1.8 : 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  _buildFssaiSquareDot(isVeg: true, isFood: true),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    t('Veg', 'शाकाहारी (वेज)', 'Veg'),
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: (isFoodItem && isVegetarian) ? FontWeight.w800 : FontWeight.w600,
                                                      color: (isFoodItem && isVegetarian) ? const Color(0xFF16A34A) : const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Non-Veg Button
                                        Expanded(
                                          child: InkWell(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                isFoodItem = true;
                                                isVegetarian = false;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(12),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              decoration: BoxDecoration(
                                                color: (isFoodItem && !isVegetarian) ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: (isFoodItem && !isVegetarian) ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                                                  width: (isFoodItem && !isVegetarian) ? 1.8 : 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  _buildFssaiSquareDot(isVeg: false, isFood: true),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    t('Non-Veg', 'मांसाहारी (नॉन-वेज)', 'Non-Veg'),
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: (isFoodItem && !isVegetarian) ? FontWeight.w800 : FontWeight.w600,
                                                      color: (isFoodItem && !isVegetarian) ? const Color(0xFFDC2626) : const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Non-Food Button
                                        Expanded(
                                          child: InkWell(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                isFoodItem = false;
                                                isVegetarian = false;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(12),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              decoration: BoxDecoration(
                                                color: (!isFoodItem) ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: (!isFoodItem) ? const Color(0xFF64748B) : const Color(0xFFE2E8F0),
                                                  width: (!isFoodItem) ? 1.8 : 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFF64748B)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    t('Non-Food', 'गैर-खाद्य', 'Non-Food'),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: (!isFoodItem) ? FontWeight.w800 : FontWeight.w600,
                                                      color: (!isFoodItem) ? const Color(0xFF0F172A) : const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildModernToggleCard(
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.balance_rounded, size: 18, color: Color(0xFFD97706)),
                                ),
                                title: t('Khula Saman (Loose Item)', 'खुला सामान (तोलकर बिकने वाला)', 'Khula Saman (Loose Item)'),
                                subtitle: t('Sold by loose weight/volume (Kg/Litre)', 'वजन या माप से बिकने वाला उत्पाद', 'Sold by weight or volume'),
                                value: isLoose,
                                activeColor: const Color(0xFFD97706),
                                onChanged: (val) => setState(() => isLoose = val),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),

                      // Sticky Bottom Save Action Button (Zepto Style)
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.grey.shade100)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: isUploading
                                ? null
                                : () async {
                                    if (nameController.text.trim().isEmpty || priceController.text.trim().isEmpty) {
                                      SnackbarHelper.showSnackBar(
                                        context,
                                        t('Please enter product name and price', 'कृपया उत्पाद का नाम और मूल्य दर्ज करें', 'Please enter name and price'),
                                        isError: true,
                                      );
                                      return;
                                    }

                                    setState(() => isUploading = true);

                                    try {
                                      String? finalImageUrl = productImages.isNotEmpty ? productImages.first : fetchedImageUrl;

                                      if (pickedImage != null) {
                                        final bytes = await pickedImage!.readAsBytes();
                                        final base64String = base64Encode(bytes);
                                        finalImageUrl = 'data:image/jpeg;base64,$base64String';
                                        if (!productImages.contains(finalImageUrl)) {
                                          productImages.insert(0, finalImageUrl);
                                        }
                                      }

                                      Map<String, dynamic> extraData = {};
                                      if (fetchedExtraDetails != null) {
                                        extraData.addAll(fetchedExtraDetails!);
                                      }
                                      if (productImages.isNotEmpty) {
                                        extraData['images'] = productImages;
                                        extraData['image_urls'] = productImages;
                                      }
                                      if (selectedCategories.isNotEmpty) {
                                        extraData['categories'] = selectedCategories;
                                      }
                                      if (quantityController.text.trim().isNotEmpty) {
                                        extraData['quantity'] = quantityController.text.trim();
                                      } else {
                                        extraData.remove('quantity');
                                      }
                                      extraData['isVegetarian'] = isVegetarian;
                                      extraData['isFoodItem'] = isFoodItem;

                                      if (!context.mounted) return;
                                      final price = double.tryParse(priceController.text) ?? 0.0;
                                      final stock = double.tryParse(stockController.text) ?? 0.0;

                                      if (price <= 0 || stock < 0) {
                                        SnackbarHelper.showSnackBar(
                                          context,
                                          t('Price must be greater than 0 and stock cannot be negative',
                                            'मूल्य 0 से अधिक होना चाहिए और स्टॉक नकारात्मक नहीं हो सकता',
                                            'Price > 0 and stock >= 0 required'),
                                          isError: true,
                                        );
                                        setState(() => isUploading = false);
                                        return;
                                      }

                                      final mrp = (extraData['mrp'] as num?)?.toDouble() ?? 0.0;
                                      if (mrp > 0 && price > mrp) {
                                        SnackbarHelper.showSnackBar(
                                          context,
                                          '${t('Selling price', 'बिक्री मूल्य', 'Selling price')} (₹${price.toStringAsFixed(2)}) ${t('cannot exceed MRP', 'MRP से अधिक नहीं हो सकता', 'cannot exceed MRP')} (₹${mrp.toStringAsFixed(2)})',
                                          isError: true,
                                        );
                                        setState(() => isUploading = false);
                                        return;
                                      }

                                      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
                                      await FirestoreService().updateProduct(
                                        barcode,
                                        nameController.text.trim(),
                                        price,
                                        isLoose,
                                        stock,
                                        finalImageUrl,
                                        extraData,
                                        shopId,
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        SoundService().productSaved();
                                        SnackbarHelper.showSnackBar(
                                          context,
                                          t('Product updated successfully!', 'उत्पाद सफलतापूर्वक अपडेट हो गया!', 'Product updated successfully!'),
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint('Error saving product: $e');
                                      setState(() => isUploading = false);
                                    }
                                  },
                            icon: isUploading
                                ? const SizedBox.shrink()
                                : const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                            label: isUploading
                                ? const ModernLoader(color: Colors.white)
                                : Text(
                                    t('Save Item', 'उत्पाद सुरक्षित करें', 'Save Item'),
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0C831F),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
            prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF0C831F)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF0C831F), width: 1.8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  static Widget _buildModernToggleCard({
    required Widget leading,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color activeColor = const Color(0xFF0C831F),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? activeColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
          width: value ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeColor,
            activeTrackColor: activeColor.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }

  static Widget _buildFssaiSquareDot({required bool isVeg, required bool isFood}) {
    if (!isFood) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Icon(Icons.block_rounded, size: 12, color: Color(0xFF94A3B8)),
      );
    }
    final color = isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: isVeg
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              )
            : Container(
                width: 0,
                height: 0,
                decoration: BoxDecoration(
                  border: Border(
                    left: const BorderSide(color: Colors.transparent, width: 4),
                    right: const BorderSide(color: Colors.transparent, width: 4),
                    bottom: BorderSide(color: color, width: 7),
                  ),
                ),
              ),
      ),
    );
  }

  static void showManualAddProductForm(
    BuildContext context, {
    String? initialName,
    String? initialBarcode,
  }) {
    final nameController = TextEditingController(text: initialName);

    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final quantityController = TextEditingController();
    bool isLoose = initialName != null; // True by default for Quick Add items
    bool isFoodItem = true;
    bool isVegetarian = true;
    File? pickedImage;
    bool isUploading = false;
    Map<String, dynamic>? fetchedExtraDetails;
    List<String> selectedCategories = [];
    List<String> categories = [];
    bool isFetchingCategories = true;

    // Fetch categories asynchronously
    FirebaseUtils.firestore
        .collection('shops').doc(Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config')
        .get()
        .then((doc) {
      if (doc.exists && doc.data()!.containsKey('categories')) {
        final List<dynamic> fetchedCats = doc['categories'];
        categories = fetchedCats.map((e) => e.toString()).toList();
        // Remove 'All' from categories if it exists, admin shouldn't assign to 'All' explicitly
        categories.remove('All');
      }
      isFetchingCategories = false;
    }).catchError((e) {
      isFetchingCategories = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Re-render when categories are fetched
            if (isFetchingCategories) {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (context.mounted) setState(() {});
              });
            }

            return Container(
              margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    left: 20,
                    right: 20,
                    top: 14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.add_box_rounded,
                                  color: Color(0xFF0C831F),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Naya Item Jodein',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Image Preview & Picker
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: pickedImage != null
                                  ? Image.file(pickedImage!, fit: BoxFit.cover)
                                  : const Icon(
                                      Icons.image_outlined,
                                      size: 38,
                                      color: Color(0xFF94A3B8),
                                    ),
                            ),
                            Positioned(
                              bottom: -4,
                              right: -4,
                              child: IconButton(
                                icon: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Color(0xFF0C831F),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final pickedFile = await picker.pickImage(
                                    source: ImageSource.camera,
                                    imageQuality: 40,
                                    maxWidth: 800,
                                    maxHeight: 800,
                                  );
                                  if (pickedFile != null) {
                                    setState(() {
                                      pickedImage = File(pickedFile.path);
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Loose Item Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.scale_rounded, color: Color(0xFFEA580C), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Khula Saman (Loose Item)',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    isLoose
                                        ? 'Daam Kilo/Litre ke hisaab se hoga'
                                        : 'Daam Packet/Piece ke hisaab se hoga',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Transform.scale(
                              scale: 0.85,
                              child: Switch(
                                value: isLoose,
                                onChanged: (val) => setState(() => isLoose = val),
                                activeThumbColor: const Color(0xFF0C831F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: nameController,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Item Name',
                          hintText: 'e.g. Maggi Masala Noodles',
                          prefixIcon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0C831F), size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0C831F), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (!isFetchingCategories)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Categories',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...categories.map((cat) {
                                  final isSelected = selectedCategories.contains(cat);
                                  return FilterChip(
                                    label: Text(cat),
                                    selected: isSelected,
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      color: isSelected ? const Color(0xFF0C831F) : const Color(0xFF475569),
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    selectedColor: const Color(0xFF0C831F).withValues(alpha: 0.15),
                                    checkmarkColor: const Color(0xFF0C831F),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: isSelected ? const Color(0xFF0C831F) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    onSelected: (bool selected) {
                                      setState(() {
                                        if (selected) {
                                          selectedCategories.add(cat);
                                        } else {
                                          selectedCategories.remove(cat);
                                        }
                                      });
                                    },
                                  );
                                }),
                                ActionChip(
                                  avatar: const Icon(Icons.add, size: 14, color: Color(0xFF0C831F)),
                                  label: const Text('Add New'),
                                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0C831F)),
                                  backgroundColor: const Color(0xFF0C831F).withValues(alpha: 0.08),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: const Color(0xFF0C831F).withValues(alpha: 0.3)),
                                  ),
                                  onPressed: () {
                                    final newCatController = TextEditingController();
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('Add New Category'),
                                          content: TextField(
                                            controller: newCatController,
                                            decoration: const InputDecoration(
                                              labelText: 'Category Name',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                final val = newCatController.text.trim();
                                                if (val.isNotEmpty) {
                                                  setState(() {
                                                    if (!categories.contains(val)) {
                                                      categories.add(val);
                                                    }
                                                    if (!selectedCategories.contains(val)) {
                                                      selectedCategories.add(val);
                                                    }
                                                  });
                                                  try {
                                                    await FirebaseUtils.firestore
                                                        .collection('shops').doc(Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config')
                                                        .update({
                                                      'categories': FieldValue.arrayUnion([val])
                                                    });
                                                  } catch (e) {
                                                    debugPrint('Error adding category: $e');
                                                  }
                                                }
                                                if (context.mounted) Navigator.pop(context);
                                              },
                                              child: const Text('Add'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),

                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: isLoose ? 'Price per Kg / Litre (₹)' : 'Price per Packet / Unit (₹)',
                          prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF0C831F), size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0C831F), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: stockController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: isLoose ? 'Stock (in Kg / Litre)' : 'Stock (Number of Packets)',
                          prefixIcon: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0C831F), size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0C831F), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: quantityController,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: isLoose ? 'Base Unit (e.g., 1 Kg) - Optional' : 'Packet Size (e.g., 50g, 1 Ltr, 1 Pcs)',
                          prefixIcon: const Icon(Icons.straighten_rounded, color: Color(0xFF0C831F), size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0C831F), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Clean Unified Diet / Food Type Selector (Replaces redundant 2 buttons)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dietary Type (FSSAI)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        isFoodItem = true;
                                        isVegetarian = true;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: (isFoodItem && isVegetarian) ? const Color(0xFFF0FDF4) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: (isFoodItem && isVegetarian) ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                                          width: (isFoodItem && isVegetarian) ? 1.8 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF16A34A)),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Veg',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: (isFoodItem && isVegetarian) ? FontWeight.w800 : FontWeight.w600,
                                              color: (isFoodItem && isVegetarian) ? const Color(0xFF16A34A) : const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        isFoodItem = true;
                                        isVegetarian = false;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: (isFoodItem && !isVegetarian) ? const Color(0xFFFEF2F2) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: (isFoodItem && !isVegetarian) ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                                          width: (isFoodItem && !isVegetarian) ? 1.8 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDC2626)),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Non-Veg',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: (isFoodItem && !isVegetarian) ? FontWeight.w800 : FontWeight.w600,
                                              color: (isFoodItem && !isVegetarian) ? const Color(0xFFDC2626) : const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        isFoodItem = false;
                                        isVegetarian = false;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: (!isFoodItem) ? const Color(0xFFF1F5F9) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: (!isFoodItem) ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                                          width: (!isFoodItem) ? 1.8 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.shopping_bag_outlined, size: 12, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Non-Food',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: (!isFoodItem) ? FontWeight.w800 : FontWeight.w600,
                                              color: (!isFoodItem) ? const Color(0xFF0F172A) : const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: isUploading
                            ? null
                            : () async {
                                if (nameController.text.isEmpty ||
                                    priceController.text.isEmpty) {
                                  SnackbarHelper.showSnackBar(
                                    context,
                                    AppLocalizations.of(context)!.err_name_price,
                                    isError: true,
                                  );
                                  return;
                                }

                                setState(() => isUploading = true);

                                try {
                                  String? finalImageUrl;
                                  if (pickedImage != null) {
                                    final bytes = await pickedImage!.readAsBytes();
                                    final base64String = base64Encode(bytes);
                                    finalImageUrl = 'data:image/jpeg;base64,$base64String';
                                  }

                                  String barcode = initialBarcode ?? 'ITEM_${DateTime.now().millisecondsSinceEpoch}';

                                  fetchedExtraDetails ??= {};
                                  if (quantityController.text.isNotEmpty) {
                                    fetchedExtraDetails!['quantity'] = quantityController.text.trim();
                                  }
                                  fetchedExtraDetails!['isFoodItem'] = isFoodItem;
                                  fetchedExtraDetails!['isVegetarian'] = isVegetarian;
                                  if (selectedCategories.isNotEmpty) {
                                    fetchedExtraDetails!['categories'] = selectedCategories;
                                  }

                                  if (!context.mounted) return;
                                  final price =
                                      double.tryParse(priceController.text) ?? 0.0;
                                  final stock =
                                      double.tryParse(stockController.text) ?? 0.0;

                                  if (price <= 0 || stock < 0) {
                                    SnackbarHelper.showSnackBar(
                                      context,
                                      AppLocalizations.of(context)!.err_price_stock,
                                      isError: true,
                                    );
                                    setState(() => isUploading = false);
                                    return;
                                  }
                                  final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
                                  await FirestoreService().addNewProduct(
                                    barcode,
                                    nameController.text,
                                    price,
                                    isLoose,
                                    stock,
                                    finalImageUrl,
                                    fetchedExtraDetails,
                                    shopId,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    SoundService().productSaved();
                                    SnackbarHelper.showSnackBar(
                                      context,
                                      AppLocalizations.of(context)!.product_added,
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error saving product: $e');
                                  setState(() => isUploading = false);
                                  if (context.mounted) {
                                    SnackbarHelper.showSnackBar(
                                      context,
                                      AppLocalizations.of(context)!.error_loading.replaceAll('{error}', e.toString().replaceAll('Exception: ', '')),
                                      isError: true,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C831F),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Add Product',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                    ].animate(interval: 20.ms).fade(duration: 250.ms).slideY(begin: 0.05, end: 0),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

}
