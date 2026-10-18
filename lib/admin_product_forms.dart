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
import 'package:near_kirana/firebase_utils.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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

              // First, check if item already exists in our Firestore inventory
              FirestoreService()
                  .getProduct(barcode)
                  .then((existingProduct) {
                    if (!context.mounted) return;

                    if (existingProduct != null) {
                      // Item already exists! Pre-fill with our existing data
                      setState(() {
                        isFetching = false;
                        nameController.text = existingProduct['name'] ?? '';
                        priceController.text =
                            existingProduct['price']?.toString() ?? '';
                        stockController.text =
                            existingProduct['stock_quantity']?.toString() ?? '';
                        isLoose = existingProduct['is_loose'] ?? false;
                        if (existingProduct['image_url'] != null) {
                          fetchedImageUrl = existingProduct['image_url'];
                        }
                        if (existingProduct['quantity'] != null) {
                          quantityController.text = existingProduct['quantity']
                              .toString();
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
                        };
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.item_exists_update,
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    } else {
                      // Item does not exist, fetch from Open Food Facts API
                      ApiService.fetchProductData(barcode)
                          .then((data) {
                            if (!context.mounted) return;
                            setState(() {
                              isFetching = false;
                              if (data != null) {
                                if (data['name']!.isNotEmpty &&
                                    nameController.text.isEmpty) {
                                  String productName = data['name']!;
                                  if (data['quantity'] != null &&
                                      data['quantity'].toString().isNotEmpty) {
                                    productName += ' - ${data['quantity']}';
                                  }
                                  nameController.text = productName;
                                }
                                if (data['imageUrl']!.isNotEmpty) {
                                  fetchedImageUrl = data['imageUrl'];
                                }
                                if (data['quantity'] != null &&
                                    data['quantity'].toString().isNotEmpty) {
                                  quantityController.text = data['quantity']
                                      .toString();
                                }
                                if (data['isVegetarian'] != null) {
                                  isVegetarian = data['isVegetarian'];
                                }
                                if (data['isFoodItem'] != null) {
                                  isFoodItem = data['isFoodItem'];
                                }
                                // Save extra details
                                fetchedExtraDetails = {
                                  'brand': data['brand'],
                                  'ingredients': data['ingredients'],
                                };
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppLocalizations.of(context)!.product_fetched),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.of(context)!.barcode_not_found,
                                    ),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }

                              // Category fetching is already handled at the top of the dialog
                            });
                          })
                          .catchError((e) {
                            if (context.mounted) {
                              setState(() => isFetching = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      AppLocalizations.of(context)!.err_network_fetch,
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          });
                    }
                  })
                  .catchError((e) {
                    // If firestore fails, just fallback to empty state
                    if (context.mounted) setState(() => isFetching = false);
                  });
            }

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 
                        MediaQuery.of(context).padding.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Item',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasFetched &&
                          fetchedExtraDetails !=
                              null) // Only show if item exists
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (deleteCtx) => AlertDialog(
                                title: const Text('Delete Product?'),
                                content: const Text(
                                  'Are you sure you want to permanently delete this product?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(deleteCtx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(deleteCtx); // close dialog
                                      Navigator.pop(
                                        context,
                                      ); // close bottom sheet
                                      try {
                                        await FirebaseUtils.firestore
                                            .collection('products')
                                            .doc(barcode)
                                            .delete();

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                AppLocalizations.of(context)!.product_deleted,
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                AppLocalizations.of(context)!.err_deleting_product,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Image Preview & Picker
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: pickedImage != null
                              ? Image.file(pickedImage!, fit: BoxFit.cover)
                              : (isFetching
                                    ? const Center(
                                        child: ModernLoader(),
                                      )
                                    : (fetchedImageUrl != null
                                          ? ProductImageWidget(
                                              imageUrl: fetchedImageUrl!,
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(
                                              Icons.image,
                                              size: 40,
                                              color: Colors.grey,
                                            ))),
                        ),
                        Positioned(
                          bottom: -10,
                          right: -10,
                          child: IconButton(
                            icon: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFFFF8C00),
                              child: Icon(
                                Icons.camera_alt,
                                size: 16,
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
                  Text(
                    'Barcode/ID: $barcode',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isLoose) ...[
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Price per Kg / Litre (₹)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: stockController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Stock (in Kg / Litre)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Base Unit (e.g., 1 Kg) - Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Price (₹)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: stockController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Stock Qty',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Pkg Size / Qty (e.g., 1 Kg, 500 ml)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!isFetchingCategories)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Categories',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedCategories.add(cat);
                                    } else {
                                      selectedCategories.remove(cat);
                                    }
                                  });
                                },
                                selectedColor: Colors.blue.withValues(alpha: 0.2),
                                checkmarkColor: Colors.blue,
                              );
                            }),
                            ActionChip(
                              label: const Text('+ Add New'),
                              backgroundColor: Colors.orange.withValues(alpha: 0.1),
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
                      ],
                    ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Food Item (Show Veg/Non-Veg dot)'),
                    value: isFoodItem,
                    onChanged: (val) => setState(() => isFoodItem = val),
                    activeThumbColor: Colors.blue,
                  ),
                  if (isFoodItem)
                    SwitchListTile(
                      title: const Text('Vegetarian Product'),
                      value: isVegetarian,
                      onChanged: (val) => setState(() => isVegetarian = val),
                      activeThumbColor: Colors.green,
                    ),
                  SwitchListTile(
                    title: const Text('Khula Saman (Loose Item)'),
                    value: isLoose,
                    onChanged: (val) => setState(() => isLoose = val),
                    activeThumbColor: const Color(0xFFFF8C00),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            if (nameController.text.isEmpty ||
                                priceController.text.isEmpty) {
                              return;
                            }

                            setState(() => isUploading = true);

                            try {
                              String? finalImageUrl = fetchedImageUrl;

                              if (pickedImage != null) {
                                final bytes = await pickedImage!.readAsBytes();
                                final base64String = base64Encode(bytes);
                                finalImageUrl = 'data:image/jpeg;base64,$base64String';
                              }

                              Map<String, dynamic> extraData = {};
                              if (fetchedExtraDetails != null) {
                                extraData.addAll(fetchedExtraDetails!);
                              }
                              if (selectedCategories.isNotEmpty) {
                                extraData['categories'] = selectedCategories;
                              }
                              if (quantityController.text.isNotEmpty) {
                                extraData['quantity'] = quantityController.text;
                              } else {
                                extraData.remove('quantity'); // Remove if empty
                              }
                              extraData['isVegetarian'] = isVegetarian;
                              extraData['isFoodItem'] = isFoodItem;

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

                              final mrp = (extraData['mrp'] as num?)?.toDouble() ?? 0.0;
                              if (mrp > 0 && price > mrp) {
                                SnackbarHelper.showSnackBar(
                                  context,
                                  'Selling price (₹${price.toStringAsFixed(2)}) cannot exceed MRP (₹${mrp.toStringAsFixed(2)})',
                                  isError: true,
                                );
                                setState(() => isUploading = false);
                                return;
                              }

                              final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
                              await FirestoreService().updateProduct(
                                barcode,
                                nameController.text,
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
                                  AppLocalizations.of(context)!.product_updated,
                                );
                              }
                            } catch (e) {
                              debugPrint('Error saving product: $e');
                              setState(() => isUploading = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isUploading
                        ? ModernLoader(color: Colors.white)
                        : const Text(
                            'Save Item',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 24),
                ].animate(interval: 30.ms).fade(duration: 300.ms).slideY(begin: 0.1, end: 0),
              ),
            );
          },
        );
      },
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

                      // Food Item & Veg switches
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Food Item (Show Veg/Non-Veg dot)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                                Transform.scale(
                                  scale: 0.85,
                                  child: Switch(
                                    value: isFoodItem,
                                    onChanged: (val) => setState(() => isFoodItem = val),
                                    activeThumbColor: const Color(0xFF0C831F),
                                  ),
                                ),
                              ],
                            ),
                            if (isFoodItem) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isVegetarian ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isVegetarian ? 'Vegetarian Product' : 'Non-Vegetarian Product',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isVegetarian ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Transform.scale(
                                    scale: 0.85,
                                    child: Switch(
                                      value: isVegetarian,
                                      onChanged: (val) => setState(() => isVegetarian = val),
                                      activeThumbColor: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
