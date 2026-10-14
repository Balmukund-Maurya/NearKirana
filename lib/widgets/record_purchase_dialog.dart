import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../supplier_models.dart';
import '../supplier_service.dart';
import '../utils/snackbar_helper.dart';
import 'add_supplier_dialog.dart';

/// Interactive modal for recording a Purchase Order / Stock In from Wholesalers
class RecordPurchaseDialog extends StatefulWidget {
  final String shopId;
  final SupplierModel? preselectedSupplier;
  final SupplierService? service;

  const RecordPurchaseDialog({
    super.key,
    required this.shopId,
    this.preselectedSupplier,
    this.service,
  });

  static Future<PurchaseOrderModel?> show(
    BuildContext context, {
    required String shopId,
    SupplierModel? preselectedSupplier,
    SupplierService? service,
  }) {
    return showDialog<PurchaseOrderModel?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecordPurchaseDialog(
        shopId: shopId,
        preselectedSupplier: preselectedSupplier,
        service: service,
      ),
    );
  }

  @override
  State<RecordPurchaseDialog> createState() => _RecordPurchaseDialogState();
}

class _LineItemDraft {
  String productId = '';
  String productName = '';
  double orderedQty = 1.0;
  double receivedQty = 1.0;
  String unit = 'Pcs';
  double costPrice = 0.0;
  double sellingPrice = 0.0;

  double get subtotal => receivedQty * costPrice;

  double get marginPercent {
    if (sellingPrice <= 0 || sellingPrice <= costPrice) return 0.0;
    return ((sellingPrice - costPrice) / sellingPrice) * 100;
  }
}

class _RecordPurchaseDialogState extends State<RecordPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumController = TextEditingController();
  final _transportController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _paidAmountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  late SupplierService _service;
  List<SupplierModel> _suppliers = [];
  SupplierModel? _selectedSupplier;
  DateTime _purchaseDate = DateTime.now();

  PurchaseOrderStatus _status = PurchaseOrderStatus.received;
  PurchasePaymentMethod _paymentMethod = PurchasePaymentMethod.cash;
  bool _updateInventoryStock = true;
  bool _isLoading = false;
  bool _fetchingSuppliers = true;

  final List<_LineItemDraft> _items = [];

  // Cached product catalog for autocompletion
  List<Map<String, dynamic>> _productCatalog = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SupplierService();
    _invoiceNumController.text = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // Start with 1 blank item
    _items.add(_LineItemDraft());

    _loadSuppliersAndProducts();
  }

  Future<void> _loadSuppliersAndProducts() async {
    try {
      final sups = await _service.streamSuppliers(widget.shopId).first;
      final prods = await _service.searchProducts(widget.shopId, '');

      if (mounted) {
        setState(() {
          _suppliers = sups;
          _productCatalog = prods;
          if (widget.preselectedSupplier != null) {
            _selectedSupplier = widget.preselectedSupplier;
          } else if (_suppliers.isNotEmpty) {
            _selectedSupplier = _suppliers.first;
          }
          _fetchingSuppliers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _fetchingSuppliers = false);
    }
  }

  @override
  void dispose() {
    _invoiceNumController.dispose();
    _transportController.dispose();
    _discountController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (sum, it) => sum + it.subtotal);
  double get _transport => double.tryParse(_transportController.text) ?? 0.0;
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _totalAmount => (_subtotal + _transport - _discount).clamp(0.0, double.infinity);
  double get _paidAmount => double.tryParse(_paidAmountController.text) ?? 0.0;
  double get _balanceDue => (_totalAmount - _paidAmount).clamp(0.0, double.infinity);

  void _addItem() {
    setState(() {
      _items.add(_LineItemDraft());
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) {
      SnackbarHelper.showErrorSnackBar(context, 'At least 1 item is required');
      return;
    }
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _handleQuickAddSupplier() async {
    final newSup = await AddSupplierDialog.show(
      context,
      shopId: widget.shopId,
      service: _service,
    );
    if (newSup != null && mounted) {
      setState(() {
        _suppliers.insert(0, newSup);
        _selectedSupplier = newSup;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _savePurchaseOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSupplier == null) {
      SnackbarHelper.showErrorSnackBar(context, 'Please select a supplier');
      return;
    }

    // Validate that items have product name and valid cost
    for (int i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.productName.trim().isEmpty) {
        SnackbarHelper.showErrorSnackBar(context, 'Item #${i + 1} has no product name');
        return;
      }
      if (it.receivedQty <= 0) {
        SnackbarHelper.showErrorSnackBar(context, 'Item #${i + 1} received quantity must be > 0');
        return;
      }
      if (it.costPrice <= 0) {
        SnackbarHelper.showErrorSnackBar(context, 'Item #${i + 1} cost price must be > 0');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final orderItems = _items.map((draft) {
        return PurchaseItemModel(
          productId: draft.productId,
          productName: draft.productName.trim(),
          orderedQuantity: draft.orderedQty,
          receivedQuantity: draft.receivedQty,
          unit: draft.unit,
          costPrice: draft.costPrice,
          sellingPrice: draft.sellingPrice,
        );
      }).toList();

      final created = await _service.createPurchaseOrder(
        shopId: widget.shopId,
        supplierId: _selectedSupplier!.id,
        supplierName: _selectedSupplier!.name,
        supplierPhone: _selectedSupplier!.phone,
        invoiceNumber: _invoiceNumController.text.trim(),
        purchaseDate: _purchaseDate,
        status: _status,
        items: orderItems,
        discount: _discount,
        transportCharges: _transport,
        paidAmount: _paidAmount,
        paymentMethod: _paidAmount > 0 ? _paymentMethod : PurchasePaymentMethod.credit,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        updateStock: _updateInventoryStock,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        SnackbarHelper.showSuccessSnackBar(
          context,
          'Purchase bill saved! ${_updateInventoryStock ? 'Inventory updated.' : ''}',
        );
        Navigator.pop(context, created);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackBar(context, 'Failed to save purchase: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 860),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Record Purchase / Stock In (खरीद दर्ज करें)',
                            style: AppTextStyles.heading2(color: AppColors.textDark)),
                        Text('Record wholesaler bill, verify received stock, and sync inventory',
                            style: AppTextStyles.caption(color: AppColors.textMid)),
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

              // Content Body
              Expanded(
                child: _fetchingSuppliers
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
                    : Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Supplier & Invoice Metadata Header Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Supplier Selector
                                        Expanded(
                                          flex: 3,
                                          child: DropdownButtonFormField<SupplierModel>(
                                            initialValue: _selectedSupplier,
                                            decoration: InputDecoration(
                                              labelText: 'Wholesaler / Supplier *',
                                              prefixIcon: const Icon(Icons.storefront_rounded),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            items: _suppliers.map((sup) {
                                              return DropdownMenuItem(
                                                value: sup,
                                                child: Text(
                                                  '${sup.name}${sup.balanceDue > 0 ? ' (Due: ₹${sup.balanceDue.toStringAsFixed(0)})' : ''}',
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) setState(() => _selectedSupplier = val);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filledTonal(
                                          tooltip: 'Add New Supplier',
                                          style: IconButton.styleFrom(
                                            backgroundColor: AppColors.primaryDark.withValues(alpha: 0.12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.all(14),
                                          ),
                                          onPressed: _handleQuickAddSupplier,
                                          icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryDark),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Invoice No & Date & Status
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: _invoiceNumController,
                                            decoration: InputDecoration(
                                              labelText: 'Bill / Invoice Number *',
                                              prefixIcon: const Icon(Icons.receipt_outlined),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 2,
                                          child: InkWell(
                                            onTap: _pickDate,
                                            borderRadius: BorderRadius.circular(12),
                                            child: InputDecorator(
                                              decoration: InputDecoration(
                                                labelText: 'Purchase Date',
                                                prefixIcon: const Icon(Icons.calendar_today_outlined),
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              child: Text(dateFormat.format(_purchaseDate), style: const TextStyle(fontSize: 14)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 2,
                                          child: DropdownButtonFormField<PurchaseOrderStatus>(
                                            initialValue: _status,
                                            decoration: InputDecoration(
                                              labelText: 'Status',
                                              prefixIcon: const Icon(Icons.check_circle_outline),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: PurchaseOrderStatus.received, child: Text('Received (स्टॉक प्राप्त)')),
                                              DropdownMenuItem(value: PurchaseOrderStatus.ordered, child: Text('Ordered (आर्डर दिया)')),
                                              DropdownMenuItem(value: PurchaseOrderStatus.draft, child: Text('Draft Bill')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) setState(() => _status = val);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 2. Line Items Table Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Purchased Items (${_items.length})',
                                    style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                                  ),
                                  TextButton.icon(
                                    onPressed: _addItem,
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    label: const Text('Add Product Item'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Line Items Cards
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _items.length,
                                separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  return _buildItemRow(index);
                                },
                              ),

                              const SizedBox(height: 16),

                              // 3. Financial Calculation & Payment Settlement Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _transportController,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: 'Freight / Transport (₹)',
                                              prefixIcon: const Icon(Icons.local_shipping_outlined),
                                              filled: true,
                                              fillColor: AppColors.surface,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _discountController,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: 'Discount on Bill (₹)',
                                              prefixIcon: const Icon(Icons.discount_outlined),
                                              filled: true,
                                              fillColor: AppColors.surface,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Subtotal, Total, Paid, Balance Due Row
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildFinancialPill('Items Total', '₹${_subtotal.toStringAsFixed(2)}', Colors.black87),
                                          _buildFinancialPill('Final Bill', '₹${_totalAmount.toStringAsFixed(2)}', AppColors.primaryDark),
                                          _buildFinancialPill('Paid Now', '₹${_paidAmount.toStringAsFixed(2)}', Colors.teal),
                                          _buildFinancialPill('Udhaar / Due', '₹${_balanceDue.toStringAsFixed(2)}', _balanceDue > 0 ? Colors.red.shade700 : Colors.green.shade700),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Payment Mode & Paid Amount Entry
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: _paidAmountController,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: 'Amount Paid Now (₹)',
                                              prefixIcon: const Icon(Icons.currency_rupee),
                                              helperText: _balanceDue > 0 ? 'Remaining ₹${_balanceDue.toStringAsFixed(0)} will be added to supplier udhaar ledger' : 'Bill marked fully paid',
                                              filled: true,
                                              fillColor: AppColors.surface,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _paidAmountController.text = _totalAmount.toStringAsFixed(0);
                                            });
                                          },
                                          child: const Text('Pay Full'),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 2,
                                          child: DropdownButtonFormField<PurchasePaymentMethod>(
                                            initialValue: _paymentMethod,
                                            decoration: InputDecoration(
                                              labelText: 'Payment Mode',
                                              prefixIcon: const Icon(Icons.payments_outlined),
                                              filled: true,
                                              fillColor: AppColors.surface,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: PurchasePaymentMethod.cash, child: Text('Cash (नकद)')),
                                              DropdownMenuItem(value: PurchasePaymentMethod.upi, child: Text('UPI / QR')),
                                              DropdownMenuItem(value: PurchasePaymentMethod.bankTransfer, child: Text('Bank Transfer')),
                                              DropdownMenuItem(value: PurchasePaymentMethod.cheque, child: Text('Cheque')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) setState(() => _paymentMethod = val);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // 4. Auto-update Inventory Switch Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _updateInventoryStock
                                      ? Colors.green.shade50
                                      : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _updateInventoryStock
                                        ? Colors.green.shade200
                                        : Colors.amber.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _updateInventoryStock ? Icons.inventory_2_rounded : Icons.inventory_2_outlined,
                                      color: _updateInventoryStock ? Colors.green.shade800 : Colors.amber.shade900,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Auto-update Store Inventory (स्टॉक में जोड़ें)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _updateInventoryStock ? Colors.green.shade900 : Colors.amber.shade900,
                                            ),
                                          ),
                                          Text(
                                            _updateInventoryStock
                                                ? 'Received quantities will immediately increase store stock and update purchase cost prices.'
                                                : 'Stock will NOT be added to inventory yet (use for accounting records only).',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _updateInventoryStock ? Colors.green.shade800 : Colors.amber.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _updateInventoryStock,
                                      activeThumbColor: AppColors.primaryDark,
                                      onChanged: (val) => setState(() => _updateInventoryStock = val),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _savePurchaseOrder,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _updateInventoryStock ? 'Save & Update Inventory' : 'Save Purchase Bill',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Name with autocomplete from catalog
              Expanded(
                flex: 4,
                child: Autocomplete<Map<String, dynamic>>(
                  initialValue: TextEditingValue(text: item.productName),
                  displayStringForOption: (option) => option['name'] as String,
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.toLowerCase();
                    if (query.isEmpty) return const Iterable.empty();
                    return _productCatalog.where((prod) {
                      final name = (prod['name'] as String).toLowerCase();
                      final barcode = (prod['barcode'] as String).toLowerCase();
                      return name.contains(query) || barcode.contains(query);
                    });
                  },
                  onSelected: (selected) {
                    setState(() {
                      item.productId = selected['id'] as String;
                      item.productName = selected['name'] as String;
                      item.unit = selected['unit'] as String? ?? 'Pcs';
                      if ((selected['cost_price'] as double) > 0) {
                        item.costPrice = selected['cost_price'] as double;
                      }
                      if ((selected['selling_price'] as double) > 0) {
                        item.sellingPrice = selected['selling_price'] as double;
                      }
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Product / Item Name *',
                        hintText: 'Search or type name (e.g. Parle-G)',
                        prefixIcon: const Icon(Icons.fastfood_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) => item.productName = val,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Unit Selector
              SizedBox(
                width: 95,
                child: DropdownButtonFormField<String>(
                  initialValue: item.unit,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Pcs', child: Text('Pcs')),
                    DropdownMenuItem(value: 'Packets', child: Text('Packets')),
                    DropdownMenuItem(value: 'Kg', child: Text('Kg')),
                    DropdownMenuItem(value: 'Litre', child: Text('Litre')),
                    DropdownMenuItem(value: 'Boxes', child: Text('Boxes')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => item.unit = val);
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Delete Item Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                tooltip: 'Remove Item',
                onPressed: () => _removeItem(index),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quantities and Prices Row
          Row(
            children: [
              // Ordered Qty
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.orderedQty.toStringAsFixed(0),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Qty Ordered',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) {
                    setState(() {
                      item.orderedQty = double.tryParse(v) ?? 1.0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Received Qty (verified)
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.receivedQty.toStringAsFixed(0),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Qty Received *',
                    helperText: 'Verified stock',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) {
                    setState(() {
                      item.receivedQty = double.tryParse(v) ?? 1.0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Cost Price per unit
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.costPrice > 0 ? item.costPrice.toStringAsFixed(2) : '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Purchase Rate (₹) *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) {
                    setState(() {
                      item.costPrice = double.tryParse(v) ?? 0.0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Selling Price / MRP
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.sellingPrice > 0 ? item.sellingPrice.toStringAsFixed(2) : '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Selling MRP (₹)',
                    helperText: item.sellingPrice > item.costPrice
                        ? '${item.marginPercent.toStringAsFixed(1)}% margin'
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) {
                    setState(() {
                      item.sellingPrice = double.tryParse(v) ?? 0.0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Line Subtotal Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      '₹${item.subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialPill(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
