import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'loyalty_referral_models.dart';
import 'loyalty_referral_service.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('रेफरल कोड कॉपी किया: $code (Code Copied)'),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showApplyReferralDialog(BuildContext context) async {
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
                  const Expanded(
                    child: Text(
                      'रेफरल कोड दर्ज करें\n(Apply Referral Code)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'अपने मित्र द्वारा दिया गया रेफरल कोड दर्ज करें और पहली सफल खरीदारी पर बोनस अंक प्राप्त करें।',
                    style: TextStyle(fontSize: 13, color: AppColors.textMid),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _referralCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'रेफरल कोड (e.g. KIR8392)',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('रद्द करें (Cancel)'),
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
                      : const Text('लागू करें (Apply)'),
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
            appBar: AppBar(title: const Text('Loyalty & Rewards')),
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
                  'लॉयल्टी रिवार्ड्स (Rewards & Referrals)',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17),
                ),
                backgroundColor: Colors.white,
                elevation: 0,
                foregroundColor: AppColors.textDark,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded),
                    tooltip: 'नियम व शर्तें (How it Works)',
                    onPressed: () => _showHowItWorksBottomSheet(context),
                  ),
                ],
              ),
              body: Column(
                children: [
                  _buildHeroPointsCard(account),
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primaryDark,
                      labelColor: AppColors.primaryDark,
                      unselectedLabelColor: AppColors.textMid,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.people_outline_rounded, size: 20),
                          text: 'रेफर और कमाएं (Refer & Earn)',
                        ),
                        Tab(
                          icon: Icon(Icons.receipt_long_rounded, size: 20),
                          text: 'अंक पासबुक (Passbook)',
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
    final rupeeSavings = account.rupeeValue();
    final tier = account.tier;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tier.color.withValues(alpha: 0.9),
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tier.color.withValues(alpha: 0.3),
            blurRadius: 16,
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white38),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      tier.label,
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
                '${tier.pointsMultiplier}x Points Multiplier',
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
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'अंक (Points Available)',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
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
                    const Text(
                      'बचत मूल्य',
                      style: TextStyle(fontSize: 10, color: AppColors.textMid, fontWeight: FontWeight.bold),
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
                    ? 'सर्वोच्च टियर प्राप्त (Top Platinum Tier) 🏆'
                    : '${account.nextTier.simpleName} हेतु ${account.pointsNeededForNextTier} अंक और चाहिए',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                'कुल अर्जित: ${account.lifetimeEarnedPoints} pts',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralTab(CustomerLoyaltyAccount account) {
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
              border: Border.all(color: Colors.grey.shade200),
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'आपका विशेष रेफरल कोड',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'दोस्त को शेयर करें और 100 अंक पाएं',
                            style: TextStyle(fontSize: 12, color: AppColors.textMid),
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryLight, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        account.referralCode,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _copyToClipboard(account.referralCode),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('कॉपी (Copy)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          elevation: 0,
                          side: const BorderSide(color: AppColors.primaryDark),
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
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: const Text(
                      'व्हाट्सएप पर शेयर करें (Share on WhatsApp)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
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
                border: Border.all(color: Colors.amber.shade200),
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
                title: const Text(
                  'क्या आपके पास किसी मित्र का रेफरल कोड है?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: const Text(
                  'कोड दर्ज करें और अपनी पहली खरीदारी पर अतिरिक्त बोनस पाएं',
                  style: TextStyle(fontSize: 11, color: AppColors.textMid),
                ),
                trailing: ElevatedButton(
                  onPressed: () => _showApplyReferralDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('दर्ज करें', style: TextStyle(fontSize: 12)),
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
                      'रेफरल कोड प्रयुक्त: ${account.referredByCode} (Referred by friend)',
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
                'रेफर किए गए मित्र (Referred Friends)',
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
                      const Text(
                        'अभी तक कोई रेफरल नहीं मिला',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'ऊपर दिए गए कोड को व्हाट्सएप पर दोस्तों को भेजें और अंक कमाएं!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textMid),
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
                            isCompleted ? '+${ref.referrerPointsAwarded} pts' : 'Pending Order',
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
                const Text(
                  'कोई लेन-देन नहीं मिला (No Points History)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                const Text(
                  'किराना ऑर्डर करने पर आपके अंक यहां दर्ज होंगे।',
                  style: TextStyle(fontSize: 12, color: AppColors.textMid),
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
                          '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year} • बैलेंस: ${tx.balanceAfter} pts',
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
                'लॉयल्टी और रेफरल कैसे काम करता है?',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildStepRow('1', 'हर ₹100 की खरीदारी पर 10 अंक अर्जित करें।'),
              _buildStepRow('2', 'ज्यादा खरीदारी करके Silver, Gold, Platinum टियर अनलॉक करें और 2x अंक कमाएं।'),
              _buildStepRow('3', 'मित्र को अपना रेफरल कोड भेजें। जब मित्र पहली खरीदारी करेगा, दोनों को बोनस अंक मिलेंगे।'),
              _buildStepRow('4', 'चेकआउट पर अंकों को तुरंत रुपये की छूट के रूप में भुनाएं!'),
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
                  child: const Text('समझ गया (Got it)'),
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
