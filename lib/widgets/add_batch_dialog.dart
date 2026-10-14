import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../batch_models.dart';
import '../batch_service.dart';
import '../firebase_utils.dart';
import '../utils/snackbar_helper.dart';

/// Modal dialog for adding or editing a product batch with expiry tracking
class AddBatchDialog extends StatefulWidget {
  final String shopId;
  final BatchModel? initialBatch;
  final String? initialProductId;
  final String? initialProductName;
  final BatchService? service;

  const AddBatchDialog({
    super.key,
    required this.shopId,
    this.initialBatch,
    this.initialProductId,
    this.initialProductName,
    this.service,
  });

  static Future<BatchModel?> show(
    BuildContext context, {
    required String shopId,
    BatchModel? initialBatch,
    String? initialProductId,
    String? initialProductName,
    BatchService? service,
  }) {
    return showDialog<BatchModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddBatchDialog(
        shopId: shopId,
        initialBatch: initialBatch,
        initialProductId: initialProductId,
        initialProductName: initialProductName,
        service: service,
      ),
    );
  }

  @override
  State<AddBatchDialog> createState() => _AddBatchDialogState();
}

class _AddBatchDialogState extends State<AddBatchDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _batchNumberController;
  late TextEditingController _qtyController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _storageLocationController;
  late TextEditingController _notesController;

  String _selectedProductId = '';
  String _selectedProductName = '';
  String _unit = 'Pcs';
  DateTime? _mfgDate;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 90));
  bool _isLoading = false;

  List<Map<String, dynamic>> _storeProducts = [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    final b = widget.initialBatch;

    _selectedProductId = b?.productId ?? widget.initialProductId ?? '';
    _selectedProductName = b?.productName ?? widget.initialProductName ?? '';

    _batchNumberController = TextEditingController(
      text: b?.batchNumber ?? _generateSuggestedBatchNumber(),
    );
    _qtyController = TextEditingController(
      text: b != null ? b.quantity.toStringAsFixed(0) : '24',
    );
    _costPriceController = TextEditingController(
      text: b != null ? b.costPrice.toStringAsFixed(2) : '0',
    );
    _sellingPriceController = TextEditingController(
      text: b != null ? b.sellingPrice.toStringAsFixed(2) : '0',
    );
    _storageLocationController = TextEditingController(
      text: b?.storageLocation ?? '',
    );
    _notesController = TextEditingController(text: b?.notes ?? '');

    _unit = b?.unit ?? 'Pcs';
    _mfgDate = b?.mfgDate;
    if (b != null) {
      _expiryDate = b.expiryDate;
    }

    _fetchStoreProducts();
  }

  String _generateSuggestedBatchNumber() {
    final now = DateTime.now();
    final yr = now.year.toString().substring(2);
    final mo = now.month.toString().padLeft(2, '0');
    final rand = (now.millisecondsSinceEpoch % 900 + 100).toString();
    return 'B-$yr$mo-$rand';
  }

  Future<void> _fetchStoreProducts() async {
    try {
      final snap = await FirebaseUtils.firestore
          .collection('products')
          .where('shop_id', isEqualTo: widget.shopId)
          .limit(100)
          .get();

      if (mounted) {
        setState(() {
          _storeProducts = snap.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name']?.toString() ?? 'Unnamed Product',
              'cost_price': (data['cost_price'] as num?)?.toDouble() ??
                  (data['purchase_price'] as num?)?.toDouble() ??
                  0.0,
              'price': (data['price'] as num?)?.toDouble() ?? 0.0,
              'unit': data['unit']?.toString() ?? 'Pcs',
            };
          }).toList();

          // Prefill price/cost if selected product matches
          if (_selectedProductId.isNotEmpty) {
            final match = _storeProducts.firstWhere(
              (p) => p['id'] == _selectedProductId,
              orElse: () => {},
            );
            if (match.isNotEmpty && widget.initialBatch == null) {
              _costPriceController.text = (match['cost_price'] as double).toStringAsFixed(2);
              _sellingPriceController.text = (match['price'] as double).toStringAsFixed(2);
              _unit = match['unit'] as String? ?? 'Pcs';
            }
          }
          _loadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  @override
  void dispose() {
    _batchNumberController.dispose();
    _qtyController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _storageLocationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickMfgDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _mfgDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _mfgDate = picked);
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProductId.isEmpty && _selectedProductName.trim().isEmpty) {
      SnackbarHelper.showErrorSnackBar(context, 'Please select or enter product name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = widget.service ?? BatchService();
      final qty = double.tryParse(_qtyController.text) ?? 1.0;
      final cost = double.tryParse(_costPriceController.text) ?? 0.0;
      final selling = double.tryParse(_sellingPriceController.text) ?? 0.0;
      final batchNo = _batchNumberController.text.trim();
      final location = _storageLocationController.text.trim();
      final notes = _notesController.text.trim();

      BatchModel resultBatch;

      if (widget.initialBatch == null) {
        resultBatch = await service.createBatch(
          shopId: widget.shopId,
          productId: _selectedProductId,
          productName: _selectedProductName,
          batchNumber: batchNo,
          quantity: qty,
          unit: _unit,
          expiryDate: _expiryDate,
          mfgDate: _mfgDate,
          costPrice: cost,
          sellingPrice: selling,
          storageLocation: location.isNotEmpty ? location : null,
          notes: notes.isNotEmpty ? notes : null,
        );
      } else {
        await service.updateBatch(
          batchId: widget.initialBatch!.id,
          batchNumber: batchNo,
          quantity: qty,
          expiryDate: _expiryDate,
          mfgDate: _mfgDate,
          costPrice: cost,
          sellingPrice: selling,
          storageLocation: location.isNotEmpty ? location : null,
          notes: notes.isNotEmpty ? notes : null,
        );

        resultBatch = widget.initialBatch!.copyWith(
          batchNumber: batchNo,
          quantity: qty,
          expiryDate: _expiryDate,
          mfgDate: _mfgDate,
          costPrice: cost,
          sellingPrice: selling,
          storageLocation: location,
          notes: notes,
        );
      }

      if (!mounted) return;
      SnackbarHelper.showSuccessSnackBar(
        context,
        widget.initialBatch == null ? 'Batch added successfully!' : 'Batch updated successfully!',
      );
      Navigator.pop(context, resultBatch);
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackBar(context, 'Error saving batch: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final isEdit = widget.initialBatch != null;

    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final expiryClean = DateTime(_expiryDate.year, _expiryDate.month, _expiryDate.day);
    final daysRemaining = expiryClean.difference(todayClean).inDays;

    Color urgencyColor;
    String urgencyText;
    if (daysRemaining < 0) {
      urgencyColor = Colors.red.shade700;
      urgencyText = 'Expired (${-daysRemaining} days ago)';
    } else if (daysRemaining <= 7) {
      urgencyColor = Colors.red.shade600;
      urgencyText = 'Critical! Expires in $daysRemaining days';
    } else if (daysRemaining <= 15) {
      urgencyColor = Colors.orange.shade800;
      urgencyText = 'Warning! Expires in $daysRemaining days';
    } else if (daysRemaining <= 30) {
      urgencyColor = Colors.amber.shade900;
      urgencyText = 'Expiring soon ($daysRemaining days)';
    } else {
      urgencyColor = Colors.green.shade700;
      urgencyText = 'Fresh ($daysRemaining days safe)';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: AppColors.primaryDark,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isEdit ? 'Edit Batch' : 'Add Batch (नया बैच जोड़ें)',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textLight),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Form Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Selection Autocomplete / Dropdown
                        if (!isEdit) ...[
                          const Text(
                            'Select Product (उत्पाद चुनें) *',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Autocomplete<Map<String, dynamic>>(
                            optionsBuilder: (textVal) {
                              if (textVal.text.isEmpty) {
                                return _storeProducts.take(15);
                              }
                              return _storeProducts.where((p) => p['name']
                                  .toString()
                                  .toLowerCase()
                                  .contains(textVal.text.toLowerCase()));
                            },
                            displayStringForOption: (p) => p['name'].toString(),
                            onSelected: (selection) {
                              setState(() {
                                _selectedProductId = selection['id']?.toString() ?? '';
                                _selectedProductName = selection['name']?.toString() ?? '';
                                _costPriceController.text =
                                    (selection['cost_price'] as double).toStringAsFixed(2);
                                _sellingPriceController.text =
                                    (selection['price'] as double).toStringAsFixed(2);
                                _unit = selection['unit'] as String? ?? 'Pcs';
                              });
                            },
                            fieldViewBuilder: (ctx, textCtrl, focusNode, onFieldSubmitted) {
                              if (_selectedProductName.isNotEmpty && textCtrl.text.isEmpty) {
                                textCtrl.text = _selectedProductName;
                              }
                              return TextFormField(
                                controller: textCtrl,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  hintText: 'Search product from store catalog...',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _loadingProducts
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onChanged: (val) {
                                  _selectedProductName = val;
                                  if (_selectedProductId.isNotEmpty &&
                                      val != _selectedProductName) {
                                    _selectedProductId = '';
                                  }
                                },
                                validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Product required' : null,
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, color: AppColors.primaryDark),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _selectedProductName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Batch Number & Suggest Generator
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _batchNumberController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  labelText: 'Batch / Lot Number *',
                                  hintText: 'e.g. B-2610-01',
                                  prefixIcon: const Icon(Icons.tag_rounded),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Batch number required' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Suggest Batch Code',
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.all(14),
                              ),
                              onPressed: () {
                                setState(() {
                                  _batchNumberController.text = _generateSuggestedBatchNumber();
                                });
                              },
                              icon: const Icon(Icons.autorenew_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Expiry Date Card with Live Preview
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: urgencyColor.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(Icons.event_busy_rounded, color: urgencyColor, size: 20),
                                        const SizedBox(width: 8),
                                        const Flexible(
                                          child: Text(
                                            'Expiry Date *',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: urgencyColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      urgencyText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _pickExpiryDate,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateFormat.format(_expiryDate),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const Icon(Icons.edit_calendar_rounded, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Optional Mfg Date Picker
                        InkWell(
                          onTap: _pickMfgDate,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Manufacturing Date (उत्पादन तिथि) - Optional',
                              prefixIcon: const Icon(Icons.factory_outlined),
                              suffixIcon: _mfgDate != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () => setState(() => _mfgDate = null),
                                    )
                                  : null,
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              _mfgDate != null ? dateFormat.format(_mfgDate!) : 'Select Mfg Date...',
                              style: TextStyle(
                                fontSize: 14,
                                color: _mfgDate != null ? Colors.black87 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Quantity & Unit
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _qtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Stock Quantity *',
                                  prefixIcon: const Icon(Icons.production_quantity_limits_rounded),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Enter quantity';
                                  final n = double.tryParse(v);
                                  if (n == null || n < 0) return 'Invalid quantity';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: _unit,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Unit',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Pcs', child: Text('Pcs')),
                                  DropdownMenuItem(value: 'Packets', child: Text('Packets')),
                                  DropdownMenuItem(value: 'Boxes', child: Text('Boxes')),
                                  DropdownMenuItem(value: 'Kg', child: Text('Kg')),
                                  DropdownMenuItem(value: 'Litre', child: Text('Litre')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _unit = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Cost Price & Selling Price
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _costPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Cost Price (₹)',
                                  prefixIcon: const Icon(Icons.currency_rupee_rounded),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _sellingPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Selling Price (₹)',
                                  prefixIcon: const Icon(Icons.currency_rupee_rounded),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Storage Location & Notes
                        TextFormField(
                          controller: _storageLocationController,
                          decoration: InputDecoration(
                            labelText: 'Storage Location / Rack (स्टोरेज जगह)',
                            hintText: 'e.g. Rack A-2, Deep Freezer, Top Shelf',
                            prefixIcon: const Icon(Icons.shelves),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notes / Storage Instructions',
                            hintText: 'e.g. Keep away from direct sunlight',
                            prefixIcon: const Icon(Icons.notes_rounded),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                // Submit Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _isLoading
                        ? 'Saving Batch...'
                        : (isEdit ? 'Update Batch' : 'Save Batch (बैच सेव करें)'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
