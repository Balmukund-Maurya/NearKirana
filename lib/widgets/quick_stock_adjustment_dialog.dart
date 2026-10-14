import 'package:flutter/material.dart';
import 'package:near_kirana/firebase_utils.dart';
import '../app_theme.dart';
import '../staff_audit_service.dart';

/// Interactive modal allowing authorized users to adjust product stock with a mandatory audit reason.
/// Directly demonstrates: "Stock 20 se 12 units hua. Audit log se pata chal sakega ki
/// authorized user ne kab aur kis wajah se adjustment kiya."
class QuickStockAdjustmentDialog extends StatefulWidget {
  final String shopId;
  final String? initialProductId;
  final String? initialProductName;
  final double? initialStock;
  final StaffAuditService service;
  final String actorName;
  final String actorRole;

  const QuickStockAdjustmentDialog({
    super.key,
    required this.shopId,
    this.initialProductId,
    this.initialProductName,
    this.initialStock,
    required this.service,
    this.actorName = 'Store Owner',
    this.actorRole = 'owner',
  });

  static Future<bool?> show(
    BuildContext context, {
    required String shopId,
    String? initialProductId,
    String? initialProductName,
    double? initialStock,
    StaffAuditService? service,
    String actorName = 'Store Owner',
    String actorRole = 'owner',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuickStockAdjustmentDialog(
        shopId: shopId,
        initialProductId: initialProductId,
        initialProductName: initialProductName,
        initialStock: initialStock,
        service: service ?? StaffAuditService(),
        actorName: actorName,
        actorRole: actorRole,
      ),
    );
  }

  @override
  State<QuickStockAdjustmentDialog> createState() => _QuickStockAdjustmentDialogState();
}

class _QuickStockAdjustmentDialogState extends State<QuickStockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedProductId;
  String _selectedProductName = '';
  double _currentStock = 0.0;

  late TextEditingController _newStockController;
  late TextEditingController _notesController;

  String _selectedReasonCategory = 'Physical stock audit discrepancy';
  final List<String> _reasonOptions = [
    'Physical stock audit discrepancy',
    'Damaged / Broken goods',
    'Customer return / Exchange',
    'Direct supplier restock',
    'Direct counter cash sale',
    'Spoilage / Expiry write-off',
    'Other reason',
  ];

  bool _isLoadingProducts = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _availableProducts = [];

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.initialProductId;
    _selectedProductName = widget.initialProductName ?? '';
    _currentStock = widget.initialStock ?? 0.0;

    _newStockController = TextEditingController();
    _notesController = TextEditingController();

    if (_selectedProductId == null) {
      _loadShopProducts();
    }
  }

  @override
  void dispose() {
    _newStockController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadShopProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final snap = await FirebaseUtils.firestore
          .collection('products')
          .where('shop_id', isEqualTo: widget.shopId)
          .limit(50)
          .get();

      final list = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name']?.toString() ?? 'Unnamed Product',
          'stock': (data['stock_quantity'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _availableProducts = list;
          if (list.isNotEmpty && _selectedProductId == null) {
            _selectedProductId = list.first['id'] as String?;
            _selectedProductName = list.first['name'] as String? ?? '';
            _currentStock = (list.first['stock'] as num?)?.toDouble() ?? 0.0;
          }
        });
      }
    } catch (_) {
      // Non-fatal
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null || _selectedProductId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    final newStock = double.tryParse(_newStockController.text.trim());
    if (newStock == null || newStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid non-negative stock quantity')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final fullReason = _notesController.text.trim().isNotEmpty
          ? '$_selectedReasonCategory (${_notesController.text.trim()})'
          : _selectedReasonCategory;

      await widget.service.adjustStockWithAudit(
        shopId: widget.shopId,
        productId: _selectedProductId!,
        productName: _selectedProductName,
        oldStock: _currentStock,
        newStock: newStock,
        reason: fullReason,
        actorId: 'user_active',
        actorName: widget.actorName,
        actorRole: widget.actorRole,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock adjusted from ${_currentStock.toStringAsFixed(1)} to ${newStock.toStringAsFixed(1)} and logged in Audit Trail!',
            ),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adjustment failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                              color: Colors.indigo.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.edit_note_rounded, color: Colors.indigo.shade800, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Adjust Stock & Log Audit\n(स्टॉक समायोजन एवं ऑडिट लॉग)',
                              style: TextStyle(
                                fontSize: 16,
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

                // Form Fields
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product selection
                        const Text('Product (उत्पाद) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        if (widget.initialProductId != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              _selectedProductName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ] else if (_isLoadingProducts) ...[
                          const LinearProgressIndicator(),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedProductId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            items: _availableProducts.map((p) {
                              return DropdownMenuItem<String>(
                                value: p['id'] as String,
                                child: Text('${p['name']} (Current: ${p['stock']})', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              final match = _availableProducts.firstWhere((p) => p['id'] == val);
                              setState(() {
                                _selectedProductId = val;
                                _selectedProductName = match['name'] as String;
                                _currentStock = match['stock'] as double;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Current vs New Stock Comparison Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Current Stock', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_currentStock.toStringAsFixed(1)} units',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('New Target Stock *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                    const SizedBox(height: 2),
                                    TextFormField(
                                      controller: _newStockController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        hintText: 'e.g. 12',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return 'Required';
                                        if (double.tryParse(val) == null) return 'Invalid';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Reason Selector
                        const Text('Reason for Adjustment (वजह / कारण) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedReasonCategory,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          items: _reasonOptions.map((r) {
                            return DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedReasonCategory = val);
                          },
                        ),
                        const SizedBox(height: 12),

                        // Additional Notes
                        const Text('Additional Notes (अतिरिक्त टिप्पणी)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'e.g. Physical inventory audit revealed 8 missing packets',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _submitAdjustment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save & Log Adjustment (सेव करें)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
