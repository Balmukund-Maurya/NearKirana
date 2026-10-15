import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../cart_provider.dart';
import '../cart_screen.dart';
import '../shopping_list_model.dart';
import '../shopping_list_service.dart';

/// Interactive modal dialog displaying the validated stock & price breakdown
/// before adding items from a past order or saved list into Cart.
class ReorderSummaryDialog extends StatelessWidget {
  final String sourceTitle;
  final ReorderValidationResult validationResult;
  final VoidCallback? onCartUpdated;
  final BuildContext? parentContext;

  const ReorderSummaryDialog({
    super.key,
    required this.sourceTitle,
    required this.validationResult,
    this.onCartUpdated,
    this.parentContext,
  });

  /// Convenient helper to validate and show the dialog in 1 step.
  static Future<void> showForItems({
    required BuildContext context,
    required String sourceTitle,
    required String shopId,
    required List<Map<String, dynamic>> items,
    VoidCallback? onCartUpdated,
  }) async {
    // Show validation loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryDark),
      ),
    );

    try {
      final service = ShoppingListService();
      final result = await service.validateItemsForReorder(
        currentShopId: shopId,
        items: items,
      );

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loader
        await showDialog(
          context: context,
          builder: (ctx) => ReorderSummaryDialog(
            sourceTitle: sourceTitle,
            validationResult: result,
            onCartUpdated: onCartUpdated,
            parentContext: context,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to validate items: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = validationResult.availableItems;
    final priceChanged = validationResult.priceChangedItems;
    final outOfStock = validationResult.outOfStockItems;
    final discontinued = validationResult.discontinuedItems;
    final unavailableCount = outOfStock.length + discontinued.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.replay_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review & Reorder',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          sourceTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Status Metrics Pills
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetricPill(
                    icon: Icons.check_circle_rounded,
                    label: '${available.length} Available',
                    bgColor: const Color(0xFFECFDF5),
                    textColor: const Color(0xFF047857),
                    borderColor: const Color(0xFFA7F3D0),
                  ),
                  if (priceChanged.isNotEmpty)
                    _buildMetricPill(
                      icon: Icons.price_change_outlined,
                      label: '${priceChanged.length} Price Updated',
                      bgColor: const Color(0xFFFFFBEB),
                      textColor: const Color(0xFFB45309),
                      borderColor: const Color(0xFFFDE68A),
                    ),
                  if (unavailableCount > 0)
                    _buildMetricPill(
                      icon: Icons.remove_shopping_cart_rounded,
                      label: '$unavailableCount Unavailable',
                      bgColor: const Color(0xFFFEF2F2),
                      textColor: const Color(0xFFB91C1C),
                      borderColor: const Color(0xFFFECACA),
                    ),
                ],
              ),
            ),

            // Item Validation List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: validationResult.items.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 16, color: Color(0xFFF3F4F6)),
                itemBuilder: (context, index) {
                  final item = validationResult.items[index];
                  return _buildItemRow(item);
                },
              ),
            ),

            // Cost Summary & Add to Cart Action
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimated Total',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMid,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '₹${validationResult.totalCurrentCost.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              if (validationResult.totalOriginalCost !=
                                  validationResult.totalCurrentCost) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '₹${validationResult.totalOriginalCost.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '${available.length} of ${validationResult.items.length} items',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMid,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: available.isEmpty
                              ? null
                              : () => _handleAddToCart(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            available.isEmpty
                                ? 'No Items in Stock'
                                : 'Add ${available.length} to Cart',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(ReorderItemValidation item) {
    Color statusBg;
    Color statusFg;
    String statusText;

    switch (item.status) {
      case ReorderItemStatus.available:
        statusBg = const Color(0xFFECFDF5);
        statusFg = const Color(0xFF047857);
        statusText = 'In Stock';
        break;
      case ReorderItemStatus.priceChanged:
        statusBg = const Color(0xFFFFFBEB);
        statusFg = const Color(0xFFB45309);
        statusText = item.isPriceHigher ? 'Price Up' : 'Price Down';
        break;
      case ReorderItemStatus.partialStock:
        statusBg = const Color(0xFFEFF6FF);
        statusFg = const Color(0xFF1D4ED8);
        statusText = 'Low Stock (${item.availableQuantity.toStringAsFixed(item.isLoose ? 1 : 0)})';
        break;
      case ReorderItemStatus.outOfStock:
        statusBg = const Color(0xFFFEF2F2);
        statusFg = const Color(0xFFDC2626);
        statusText = 'Out of Stock';
        break;
      case ReorderItemStatus.discontinued:
        statusBg = const Color(0xFFF3F4F6);
        statusFg = const Color(0xFF6B7280);
        statusText = 'Unavailable';
        break;
    }

    final bool canAdd = item.availableQuantity > 0;
    final qtyDisplay = item.isLoose
        ? item.availableQuantity.toStringAsFixed(1)
        : item.availableQuantity.toStringAsFixed(0);

    return Opacity(
      opacity: canAdd ? 1.0 : 0.55,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Availability check icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: canAdd
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              canAdd ? Icons.check_rounded : Icons.close_rounded,
              size: 16,
              color: canAdd ? const Color(0xFF059669) : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 12),

          // Name and quantity
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: canAdd ? AppColors.textDark : Colors.grey.shade600,
                    decoration: canAdd ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Qty: $qtyDisplay',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Price display
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${(item.currentPrice * (canAdd ? item.availableQuantity : item.requestedQuantity)).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: canAdd ? AppColors.textDark : Colors.grey,
                ),
              ),
              if (item.hasPriceChange && canAdd)
                Text(
                  '₹${item.originalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleAddToCart(BuildContext context) {
    HapticFeedback.mediumImpact();
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final count = ShoppingListService().applyItemsToCart(
      cartProvider: cartProvider,
      itemsToAdd: validationResult.availableItems,
    );

    onCartUpdated?.call();

    // Capture effective mounted screen context before popping the dialog
    final effectiveContext = parentContext ?? context;
    Navigator.pop(context);

    if (effectiveContext.mounted) {
      ScaffoldMessenger.of(effectiveContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$count items added to your cart!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.amberAccent,
            onPressed: () {
              if (effectiveContext.mounted) {
                Navigator.push(
                  effectiveContext,
                  MaterialPageRoute(builder: (ctx) => const CartScreen(isTab: false)),
                );
              }
            },
          ),
        ),
      );
    }
  }
}
