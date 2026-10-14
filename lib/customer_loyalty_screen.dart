import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'loyalty_referral_models.dart';
import 'loyalty_referral_service.dart';
import 'l10n/app_localizations.dart';

/// Full customer rewards hub displaying live points balance, membership tier progress,
/// referral code sharing via WhatsApp, list of referred friends, and passbook history.
class CustomerLoyaltyScreen extends StatefulWidget {
  final String shopId;
  final String customerPhone;
  final String customerName;
  final String? customerUid;
  final LoyaltyReferralService? service;
  final bool enableAnimations;

  const CustomerLoyaltyScreen({
    super.key,
    required this.shopId,
    required this.customerPhone,
    required this.customerName,
    this.customerUid,
    this.service,
    this.enableAnimations = true,
  });

  @override
  State<CustomerLoyaltyScreen> createState() => _CustomerLoyaltyScreenState();
}

class _CustomerLoyaltyScreenState extends State<CustomerLoyaltyScreen>
    with SingleTickerProviderStateMixin {
  late final LoyaltyReferralService _service;
  late TabController _tabController;
  final TextEditingController _referralCodeController = TextEditingController();
  bool _isApplyingCode = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LoyaltyReferralService();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _shareOnWhatsApp(String code, String shopName) async {
    HapticFeedback.lightImpact();
    final message = Uri.encodeComponent(
      '🛒 *Near Kirana से ऑर्डर करें और ₹50 छूट पाएं!*\n\n'
      'मेरा रेफरल कोड इस्तेमाल करें: *$code*\n'
      'दुकान: $shopName\n\n'
      'अपनी पहली किराने की खरीदारी पर पाएं आकर्षक लॉयल्टी रिवार्ड्स और फ्री डिस्काउंट!',
    );
    final url = Uri.parse('whatsapp://send?text=$message');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(
          Uri.parse('https://api.whatsapp.com/send?text=$message'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp launch failed. Code copied to clipboard!')),
        );
      }
    }
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n?.code_copied_snack ?? "Referral code copied"}: $code'),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showApplyReferralDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.card_giftcard_rounded, color: Colors.amber.shade800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n?.apply_referral_title ?? 'Enter Referral Code',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.apply_referral_subtitle ??
                        'Enter your friend\'s code to claim bonus points on your first purchase.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMid),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _referralCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l10n?.referral_code_hint ?? 'Referral Code (e.g. KIR8392)',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(l10n?.cancel ?? 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isApplyingCode
                      ? null
                      : () async {
                          final code = _referralCodeController.text.trim();
                          if (code.isEmpty) return;

                          final messenger = ScaffoldMessenger.of(context);
                          setDialogState(() => _isApplyingCode = true);
                          final res = await _service.applyReferralCode(
                            shopId: widget.shopId,
                            refereePhone: widget.customerPhone,
                            refereeName: widget.customerName,
                            referralCode: code,
                          );
                          setDialogState(() => _isApplyingCode = false);

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: res.success ? AppColors.success : AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isApplyingCode
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n?.apply_btn ?? 'Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<CustomerLoyaltyAccount>(
      future: _service.getOrCreateAccount(
        shopId: widget.shopId,
        customerPhone: widget.customerPhone,
        customerName: widget.customerName,
        customerUid: widget.customerUid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primaryDark)),
          );
        }

        final initialAccount = snapshot.data;
        if (initialAccount == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n?.loyalty_rewards_title ?? 'Rewards & Referrals')),
            body: const Center(child: Text('Unable to load rewards account')),
          );
        }

        return StreamBuilder<CustomerLoyaltyAccount?>(
          stream: _service.streamAccount(widget.shopId, widget.customerPhone),
          initialData: initialAccount,
          builder: (context, streamSnap) {
            final account = streamSnap.data ?? initialAccount;
            return Scaffold(
              backgroundColor: AppColors.surface,
              appBar: AppBar(
                title: Text(
                  l10n?.loyalty_rewards_title ?? 'Rewards & Referrals',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17),
                ),
                backgroundColor: Colors.white,
                elevation: 0,
                foregroundColor: AppColors.textDark,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded),
                    tooltip: l10n?.loyalty_how_it_works ?? 'How it Works',
                    onPressed: () => _showHowItWorksBottomSheet(context),
                  ),
                ],
              ),
              body: Column(
                children: [
                  _buildHeroPointsCard(account),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.primaryDark,
                      unselectedLabelColor: AppColors.textMid,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.people_outline_rounded, size: 18),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l10n?.tab_refer_earn ?? 'Refer & Earn',
                              maxLines: 1,
                            ),
                          ),
                        ),
                        Tab(
                          icon: const Icon(Icons.receipt_long_rounded, size: 18),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l10n?.tab_points_passbook ?? 'Passbook',
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildReferralTab(account),
                        _buildPassbookTab(account),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeroPointsCard(CustomerLoyaltyAccount account) {
    final l10n = AppLocalizations.of(context);
    final rupeeSavings = account.rupeeValue();
    final tier = account.tier;
    final isHindi = l10n?.localeName.startsWith('hi') ?? false;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E5128),
            AppColors.primaryDark,
            Color(0xFF388E3C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, color: tier.color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      tier.localizedLabel(context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${tier.pointsMultiplier}x ${l10n?.points_multiplier_label ?? "Points Multiplier"}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${account.currentPoints}',
                style: GoogleFonts.poppins(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l10n?.points_available_label ?? 'Points Available',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n?.savings_value_label ?? 'Savings Value',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMid, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${rupeeSavings.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Tier Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: account.progressToNextTier,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                account.tier == LoyaltyTier.platinum
                    ? (l10n?.top_tier_unlocked ?? 'Top Tier Unlocked! 🏆')
                    : (isHindi
                        ? '${account.nextTier.localizedLabel(context)} हेतु ${account.pointsNeededForNextTier} ${l10n?.points_needed_for_next ?? "अंक और चाहिए"}'
                        : '${account.pointsNeededForNextTier} ${l10n?.points_needed_for_next ?? "points needed for"} ${account.nextTier.localizedLabel(context)}'),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                '${l10n?.total_earned_label ?? "Total Earned"}: ${account.lifetimeEarnedPoints} pts',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralTab(CustomerLoyaltyAccount account) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Share Code Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.bgTint, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_rounded, color: AppColors.primaryDark, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.your_referral_code_title ?? 'Your Exclusive Referral Code',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            l10n?.share_code_subtitle ?? 'Share with friends & get 100 points',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8EE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.bgTint, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: SelectableText(
                            account.referralCode,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _copyToClipboard(account.referralCode),
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: Text(l10n?.copy_code_btn ?? 'Copy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          side: const BorderSide(color: AppColors.primaryDark, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareOnWhatsApp(account.referralCode, 'हमारा किराना'),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n?.share_whatsapp_btn ?? 'Share on WhatsApp',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Enter Friend's Code Tile (if not yet referred)
          if (account.referredByCode == null || account.referredByCode!.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bgTint, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: Colors.amber),
                ),
                title: Text(
                  l10n?.have_referral_code_title ?? 'Have a friend\'s referral code?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  l10n?.have_referral_code_subtitle ?? 'Enter code & get extra bonus on your first order',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMid),
                ),
                trailing: ElevatedButton(
                  onPressed: () => _showApplyReferralDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(l10n?.enter_code_btn ?? 'Enter', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
          )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${l10n?.referred_by_code_label ?? "Referral code applied"}: ${account.referredByCode}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Referred Friends List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.referred_friends_title ?? 'Referred Friends',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<ReferralRecord>>(
            stream: _service.streamReferralsByReferrer(widget.shopId, widget.customerPhone),
            builder: (context, refSnap) {
              final referrals = refSnap.data ?? [];
              if (referrals.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.group_add_outlined, size: 44, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        l10n?.no_referrals_yet ?? 'No referrals yet',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n?.share_code_prompt ?? 'Share your code on WhatsApp to start earning points!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: referrals.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final ref = referrals[index];
                  final isCompleted = ref.status == ReferralStatus.completed;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isCompleted ? Colors.green.shade100 : Colors.amber.shade100,
                          child: Icon(
                            isCompleted ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                            color: isCompleted ? Colors.green : Colors.amber.shade800,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.refereeName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '${ref.refereePhone.substring(0, 4)}XXXX${ref.refereePhone.substring(ref.refereePhone.length - 2)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCompleted ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCompleted ? Colors.green.shade300 : Colors.amber.shade300,
                            ),
                          ),
                          child: Text(
                            isCompleted ? '+${ref.referrerPointsAwarded} pts' : (l10n?.pending_order_status ?? 'Pending Order'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? Colors.green.shade800 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPassbookTab(CustomerLoyaltyAccount account) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<List<LoyaltyTransaction>>(
      stream: _service.streamCustomerTransactions(widget.shopId, widget.customerPhone),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
        }

        final transactions = snap.data ?? [];
        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 54, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  l10n?.no_transactions_title ?? 'No Points History',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n?.no_transactions_subtitle ?? 'Your points will appear here when you place grocery orders.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final isPositive = tx.points >= 0;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPositive ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                      color: isPositive ? Colors.green : Colors.red,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.description,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year} • ${l10n?.balance_pts_prefix ?? "Balance"}: ${tx.balanceAfter} pts',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMid),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isPositive ? "+" : ""}${tx.points} pts',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isPositive ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHowItWorksBottomSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.how_it_works_title ?? 'How Loyalty & Referrals Work',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildStepRow('1', l10n?.how_step_1 ?? 'Earn 10 points for every ₹100 spent.'),
              _buildStepRow('2', l10n?.how_step_2 ?? 'Unlock Silver, Gold, Platinum tiers to earn up to 2x points.'),
              _buildStepRow('3', l10n?.how_step_3 ?? 'Invite friends using your code to earn mutual bonus points on their first order.'),
              _buildStepRow('4', l10n?.how_step_4 ?? 'Redeem your points instantly at checkout for direct rupee discounts!'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n?.got_it_btn ?? 'Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
            child: Text(
              number,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
