import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../loyalty_referral_models.dart';
import '../loyalty_referral_service.dart';

/// Interactive checkout widget allowing customers to redeem accumulated loyalty points
/// for instant rupee discounts on their cart order.
class LoyaltyRedemptionCard extends StatefulWidget {
  final String shopId;
  final String customerPhone;
  final String customerName;
  final double subtotal;
  final LoyaltyReferralService? service;
  final ValueChanged<({int points, double discountRupees})?> onRedemptionChanged;

  const LoyaltyRedemptionCard({
    super.key,
    required this.shopId,
    required this.customerPhone,
    required this.customerName,
    required this.subtotal,
    this.service,
    required this.onRedemptionChanged,
  });

  @override
  State<LoyaltyRedemptionCard> createState() => _LoyaltyRedemptionCardState();
}

class _LoyaltyRedemptionCardState extends State<LoyaltyRedemptionCard> {
  late final LoyaltyReferralService _service;
  bool _isRedemptionApplied = false;
  int _appliedPoints = 0;
  double _appliedDiscount = 0.0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LoyaltyReferralService();
  }

  @override
  void didUpdateWidget(covariant LoyaltyRedemptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subtotal != widget.subtotal && _isRedemptionApplied) {
      // Re-evaluate discount if subtotal changes
      _recalculateDiscount();
    }
  }

  Future<void> _recalculateDiscount() async {
    final config = await _service.getProgramConfig(widget.shopId);
    final account = await _service.getOrCreateAccount(
      shopId: widget.shopId,
      customerPhone: widget.customerPhone,
      customerName: widget.customerName,
    );

    final maxRedeemable = config.calculateMaxRedeemablePoints(widget.subtotal, account.currentPoints);
    if (maxRedeemable < config.minPointsToRedeem) {
      setState(() {
        _isRedemptionApplied = false;
        _appliedPoints = 0;
        _appliedDiscount = 0.0;
      });
      widget.onRedemptionChanged(null);
    } else {
      final points = _appliedPoints.clamp(0, maxRedeemable);
      final discount = config.pointsToRupees(points);
      setState(() {
        _appliedPoints = points;
        _appliedDiscount = discount;
      });
      widget.onRedemptionChanged((points: points, discountRupees: discount));
    }
  }

  void _toggleRedemption(bool value, CustomerLoyaltyAccount account, LoyaltyProgramConfig config) {
    if (value) {
      final maxRedeemable = config.calculateMaxRedeemablePoints(widget.subtotal, account.currentPoints);
      final discount = config.pointsToRupees(maxRedeemable);

      setState(() {
        _isRedemptionApplied = true;
        _appliedPoints = maxRedeemable;
        _appliedDiscount = discount;
      });
      widget.onRedemptionChanged((points: maxRedeemable, discountRupees: discount));
    } else {
      setState(() {
        _isRedemptionApplied = false;
        _appliedPoints = 0;
        _appliedDiscount = 0.0;
      });
      widget.onRedemptionChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoyaltyProgramConfig>(
      future: _service.getProgramConfig(widget.shopId),
      builder: (context, configSnap) {
        final config = configSnap.data;
        if (config == null || !config.isEnabled) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<CustomerLoyaltyAccount?>(
          stream: _service.streamAccount(widget.shopId, widget.customerPhone),
          builder: (context, accSnap) {
            final account = accSnap.data;
            if (account == null) {
              return const SizedBox.shrink();
            }

            final currentPoints = account.currentPoints;
            final canRedeem = currentPoints >= config.minPointsToRedeem;
            final maxRedeemable = config.calculateMaxRedeemablePoints(widget.subtotal, currentPoints);
            final potentialSavings = config.pointsToRupees(maxRedeemable);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isRedemptionApplied ? Colors.amber.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isRedemptionApplied ? Colors.amber.shade400 : Colors.grey.shade200,
                  width: _isRedemptionApplied ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: account.tier.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.stars_rounded, color: account.tier.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'लॉयल्टी रिवार्ड्स (Loyalty Points)',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              'उपलब्ध: $currentPoints pts (${account.tier.simpleName} Member)',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMid),
                            ),
                          ],
                        ),
                      ),
                      if (canRedeem && maxRedeemable > 0)
                        Switch(
                          value: _isRedemptionApplied,
                          activeThumbColor: AppColors.primaryDark,
                          onChanged: (val) => _toggleRedemption(val, account, config),
                        ),
                    ],
                  ),
                  if (canRedeem && maxRedeemable > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isRedemptionApplied
                              ? '$_appliedPoints अंक भुनाए गए'
                              : 'अधिकतम $maxRedeemable अंक भुनाएं',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isRedemptionApplied ? Colors.green.shade800 : AppColors.textMid,
                          ),
                        ),
                        Text(
                          _isRedemptionApplied
                              ? '-₹${_appliedDiscount.toStringAsFixed(1)} छूट'
                              : 'बचत: ₹${potentialSavings.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _isRedemptionApplied ? Colors.green.shade800 : AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      currentPoints < config.minPointsToRedeem
                          ? 'छूट हेतु न्यूनतम ${config.minPointsToRedeem} अंक आवश्यक हैं (कम से कम ${config.minPointsToRedeem - currentPoints} अंक और चाहिए)'
                          : 'इस ऑर्डर मूल्य पर रिडेम्पशन सीमा पूरी हो चुकी है',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMid),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
