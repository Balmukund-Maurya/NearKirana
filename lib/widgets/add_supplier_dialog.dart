import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../supplier_models.dart';
import '../supplier_service.dart';
import '../utils/snackbar_helper.dart';

/// Modal dialog for adding or editing a Wholesaler / Supplier
class AddSupplierDialog extends StatefulWidget {
  final String shopId;
  final SupplierModel? initialSupplier;
  final SupplierService? service;

  const AddSupplierDialog({
    super.key,
    required this.shopId,
    this.initialSupplier,
    this.service,
  });

  static Future<SupplierModel?> show(
    BuildContext context, {
    required String shopId,
    SupplierModel? initialSupplier,
    SupplierService? service,
  }) {
    return showDialog<SupplierModel?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddSupplierDialog(
        shopId: shopId,
        initialSupplier: initialSupplier,
        service: service,
      ),
    );
  }

  @override
  State<AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends State<AddSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gstinController = TextEditingController();
  final _addressController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _notesController = TextEditingController();

  static const List<String> _categories = [
    'General',
    'FMCG & Packaged Foods',
    'Grains, Atta & Pulses',
    'Dairy & Bakery',
    'Beverages & Cold Drinks',
    'Spices & Edible Oils',
    'Personal & Home Care',
  ];

  late String _selectedCategory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSupplier;
    _nameController.text = s?.name ?? '';
    _contactPersonController.text = s?.contactPerson ?? '';
    _phoneController.text = s?.phone ?? '';
    _gstinController.text = s?.gstin ?? '';
    _addressController.text = s?.address ?? '';
    _notesController.text = s?.notes ?? '';
    _selectedCategory = s?.category ?? 'General';
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = 'General';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _gstinController.dispose();
    _addressController.dispose();
    _openingBalanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = widget.service ?? SupplierService();

      if (widget.initialSupplier != null) {
        // Update existing
        await service.updateSupplier(
          supplierId: widget.initialSupplier!.id,
          name: _nameController.text,
          contactPerson: _contactPersonController.text.isNotEmpty
              ? _contactPersonController.text
              : null,
          phone: _phoneController.text,
          gstin: _gstinController.text.isNotEmpty ? _gstinController.text : null,
          address: _addressController.text.isNotEmpty ? _addressController.text : null,
          category: _selectedCategory,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );

        if (mounted) {
          SnackbarHelper.showSuccessSnackBar(context, 'Supplier updated successfully');
          Navigator.pop(
            context,
            widget.initialSupplier!.copyWith(
              name: _nameController.text,
              contactPerson: _contactPersonController.text,
              phone: _phoneController.text,
              gstin: _gstinController.text,
              address: _addressController.text,
              category: _selectedCategory,
              notes: _notesController.text,
            ),
          );
        }
      } else {
        // Create new
        final openingBal = double.tryParse(_openingBalanceController.text) ?? 0.0;
        final created = await service.createSupplier(
          shopId: widget.shopId,
          name: _nameController.text,
          contactPerson: _contactPersonController.text.isNotEmpty
              ? _contactPersonController.text
              : null,
          phone: _phoneController.text,
          gstin: _gstinController.text.isNotEmpty ? _gstinController.text : null,
          address: _addressController.text.isNotEmpty ? _addressController.text : null,
          category: _selectedCategory,
          openingBalanceDue: openingBal,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );

        if (mounted) {
          SnackbarHelper.showSuccessSnackBar(context, 'Supplier "${created.name}" added');
          Navigator.pop(context, created);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackBar(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialSupplier != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Supplier' : 'Add New Wholesaler / Supplier',
                          style: AppTextStyles.heading2(color: AppColors.textDark),
                        ),
                        Text(
                          isEditing ? 'Update wholesaler profile & terms' : 'Register distributor to track purchases & dues',
                          style: AppTextStyles.caption(color: AppColors.textMid),
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
              const Divider(height: 24),

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Business Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Supplier / Business Name *',
                            hintText: 'e.g., M/s Agarwal Wholesalers',
                            prefixIcon: const Icon(Icons.storefront_outlined),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter supplier name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Contact Person & Phone
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _contactPersonController,
                                decoration: InputDecoration(
                                  labelText: 'Contact Person',
                                  hintText: 'e.g., Rajesh Ji',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number *',
                                  hintText: '10 digits',
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                  counterText: '',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Phone is required';
                                  }
                                  if (val.trim().length < 10) {
                                    return 'Enter 10 digits';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Category Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Supply Category',
                            prefixIcon: const Icon(Icons.category_outlined),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _categories.map((cat) {
                            return DropdownMenuItem(value: cat, child: Text(cat));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        // GSTIN & Address
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _gstinController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  labelText: 'GSTIN (Optional)',
                                  hintText: 'e.g. 07AAAAA0000A1Z5',
                                  prefixIcon: const Icon(Icons.receipt_long_outlined),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _addressController,
                                decoration: InputDecoration(
                                  labelText: 'Market / City',
                                  hintText: 'e.g., Grain Market, Shop #12',
                                  prefixIcon: const Icon(Icons.location_on_outlined),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Opening Balance Due (only on new creation)
                        if (!isEditing) ...[
                          TextFormField(
                            controller: _openingBalanceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Opening Balance Due (पुरानी बाकी उधारी ₹)',
                              hintText: '0.00 (leave 0 if no prior balance)',
                              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                              helperText: 'Amount already owed to this supplier before using this app',
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Payment Terms / Notes',
                            hintText: 'e.g., 7 days credit limit, supplies every Tuesday',
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
              ),

              const SizedBox(height: 16),

              // Action Buttons
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
                      onPressed: _isLoading ? null : _handleSave,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(isEditing ? Icons.save_rounded : Icons.check_circle_rounded),
                      label: Text(
                        isEditing ? 'Save Changes' : 'Register Supplier',
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
}
