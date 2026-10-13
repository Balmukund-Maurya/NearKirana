import 'package:flutter/material.dart';
import 'package:near_kirana/sound_service.dart';
import 'package:near_kirana/review_model.dart';
import 'package:near_kirana/rating_review_service.dart';

/// Interactive 5-star rating selector widget
class StarRatingSelector extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;
  final double size;
  final Color activeColor;

  const StarRatingSelector({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.size = 32,
    this.activeColor = const Color(0xFFF59E0B), // Warm amber
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1.0;
        final isFilled = rating >= starValue;

        return IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(),
          iconSize: size,
          icon: Icon(
            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isFilled ? activeColor : Colors.grey.shade400,
          ),
          onPressed: () => onRatingChanged(starValue),
        );
      }),
    );
  }
}

/// Modal dialog allowing verified buyers to submit ratings and reviews for delivered orders
class RatingReviewDialog extends StatefulWidget {
  final String orderId;
  final String shopId;
  final List<dynamic> items;
  final String? customerName;
  final String? customerPhone;

  const RatingReviewDialog({
    super.key,
    required this.orderId,
    required this.shopId,
    this.items = const [],
    this.customerName,
    this.customerPhone,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String orderId,
    required String shopId,
    List<dynamic> items = const [],
    String? customerName,
    String? customerPhone,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => RatingReviewDialog(
        orderId: orderId,
        shopId: shopId,
        items: items,
        customerName: customerName,
        customerPhone: customerPhone,
      ),
    );
  }

  @override
  State<RatingReviewDialog> createState() => _RatingReviewDialogState();
}

class _RatingReviewDialogState extends State<RatingReviewDialog> {
  double _shopRating = 5.0;
  double _deliveryRating = 5.0;
  final Map<String, double> _productRatings = {};
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      final pid = item['id']?.toString() ?? item['productId']?.toString() ?? '';
      if (pid.isNotEmpty) {
        _productRatings[pid] = 5.0;
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    try {
      final List<ProductReviewItem> prodReviews = [];
      for (final item in widget.items) {
        final pid = item['id']?.toString() ?? item['productId']?.toString() ?? '';
        final pname = item['name']?.toString() ?? 'Product';
        if (pid.isNotEmpty && _productRatings.containsKey(pid)) {
          prodReviews.add(ProductReviewItem(
            productId: pid,
            productName: pname,
            rating: _productRatings[pid]!,
          ));
        }
      }

      await RatingReviewService.instance.submitOrderReview(
        orderId: widget.orderId,
        shopRating: _shopRating,
        deliveryRating: _deliveryRating,
        comment: _commentController.text.trim(),
        productReviews: prodReviews,
        customerName: widget.customerName,
        customerPhone: widget.customerPhone,
      );

      if (mounted) {
        SoundService().success();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your verified review has been submitted.'),
            backgroundColor: Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('ArgumentError: ', '').replaceAll('StateError: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortId = widget.orderId.length >= 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF59E0B),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rate & Review Order',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                          ),
                          Text(
                            'Order #$shortId',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Verified Buyer Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 16, color: Color(0xFF047857)),
                    SizedBox(width: 6),
                    Text(
                      'Verified Purchase Review',
                      style: TextStyle(color: Color(0xFF047857), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 1. Store / Shop Experience
              const Text(
                'Store & Item Quality',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StarRatingSelector(
                    rating: _shopRating,
                    onRatingChanged: (r) => setState(() => _shopRating = r),
                  ),
                  Text(
                    '${_shopRating.toStringAsFixed(0)} / 5 Stars',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Delivery Experience
              const Text(
                'Delivery Speed & Experience',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StarRatingSelector(
                    rating: _deliveryRating,
                    onRatingChanged: (r) => setState(() => _deliveryRating = r),
                  ),
                  Text(
                    '${_deliveryRating.toStringAsFixed(0)} / 5 Stars',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Optional Product Ratings
              if (widget.items.isNotEmpty) ...[
                const Text(
                  'Item Ratings (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: widget.items.map((item) {
                      final pid = item['id']?.toString() ?? item['productId']?.toString() ?? '';
                      final pname = item['name']?.toString() ?? 'Item';
                      final currentRating = _productRatings[pid] ?? 5.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                pname,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            StarRatingSelector(
                              rating: currentRating,
                              size: 20,
                              onRatingChanged: (r) => setState(() => _productRatings[pid] = r),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. Detailed Comment
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Feedback / Comment',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${_commentController.text.length}/500',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: 500,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Share your experience with freshness, packing, and delivery...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(_isSubmitting ? 'Submitting...' : 'Submit Review'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
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

/// Visual pill widget displaying verified rating summary on an order
class RatingDisplayPill extends StatelessWidget {
  final double rating;
  final String? label;

  const RatingDisplayPill({
    super.key,
    required this.rating,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 4),
          Text(
            '${rating.toStringAsFixed(1)} / 5',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF92400E),
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              '• $label',
              style: TextStyle(
                fontSize: 11,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Prompt banner that encourages customer to rate delivered orders
class OrderReviewPromptBanner extends StatelessWidget {
  final String orderId;
  final String shopId;
  final List<dynamic> items;
  final String? customerName;
  final String? customerPhone;
  final VoidCallback? onReviewed;

  const OrderReviewPromptBanner({
    super.key,
    required this.orderId,
    required this.shopId,
    this.items = const [],
    this.customerName,
    this.customerPhone,
    this.onReviewed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF047857),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How was your order experience?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF065F46),
                  ),
                ),
                Text(
                  'Rate your delivery and store to help other buyers.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.star, size: 14),
            label: const Text('Rate Order', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final result = await RatingReviewDialog.show(
                context,
                orderId: orderId,
                shopId: shopId,
                items: items,
                customerName: customerName,
                customerPhone: customerPhone,
              );
              if (result == true) {
                onReviewed?.call();
              }
            },
          ),
        ],
      ),
    );
  }
}
