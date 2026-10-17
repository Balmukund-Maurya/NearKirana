import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'language_provider.dart';
import 'loyalty_referral_models.dart';
import 'loyalty_referral_service.dart';

/// Full customer rewards hub displaying live points balance, membership tier progress,
/// referral code sharing via WhatsApp, list of referred friends, and passbook history
/// redesigned with clean Zepto / Blinkit styled aesthetics and multi-language support.
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

  Future<void> _shareOnWhatsApp(String code, String shopName, bool isHindi, bool isHinglish) async {
    HapticFeedback.lightImpact();
    final messageText = isHindi
        ? 'Near Kirana से ऑर्डर करें और छूट पाएं!\n\n'
          'मेरा रेफरल कोड इस्तेमाल करें: $code\n'
          'दुकान: $shopName\n\n'
          'अपनी पहली किराने की खरीदारी पर पाएं आकर्षक लॉयल्टी रिवार्ड्स और छूट!'
        : (isHinglish
            ? 'Near Kirana se grocery order karein aur discount paayein!\n\n'
              'Mera referral code use karein: $code\n'
              'Store: $shopName\n\n'
              'Apne first order par extra loyalty points aur discount payein!'
            : 'Order fresh groceries on Near Kirana and save!\n\n'
              'Use my referral code: $code\n'
              'Store: $shopName\n\n'
              'Get exclusive welcome points and instant discounts on your first order!');

    final message = Uri.encodeComponent(messageText);
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
          SnackBar(
            content: Text(
              isHindi
                  ? 'व्हाट्सएप नहीं खुला। कोड कॉपी कर लिया गया है!'
                  : 'WhatsApp could not be opened. Code copied to clipboard!',
            ),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String code, bool isHindi, bool isHinglish) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isHindi
              ? 'रेफरल कोड कॉपी हुआ: $code'
              : (isHinglish ? 'Referral code copy ho gaya: $code' : 'Referral code copied: $code'),
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showApplyReferralDialog(BuildContext context, bool isHindi, bool isHinglish) async {
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
                      color: const Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isHindi ? 'रेफरल कोड दर्ज करें' : (isHinglish ? 'Referral Code Enter Karein' : 'Enter Referral Code'),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHindi
                        ? 'अपने मित्र का रेफरल कोड दर्ज करें और अपने पहले ऑर्डर पर बोनस अंक पाएं।'
                        : (isHinglish
                            ? 'Apne dost ka referral code enter karein aur first order par bonus points paayein.'
                            : 'Enter your friend\'s referral code to claim bonus points on your first purchase.'),
                    style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _referralCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: isHindi ? 'रेफरल कोड (जैसे: BAL8492)' : 'Referral Code (e.g. BAL8492)',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: _isApplyingCode
                      ? null
                      : () async {
                          final code = _referralCodeController.text.trim();
                          if (code.isEmpty) return;
                          setDialogState(() => _isApplyingCode = true);
                          final result = await _service.applyReferralCode(
                            shopId: widget.shopId,
                            refereePhone: widget.customerPhone,
                            refereeName: widget.customerName,
                            referralCode: code,
                          );
                          setDialogState(() => _isApplyingCode = false);

                          if (context.mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message),
                                backgroundColor: result.success ? AppColors.primaryDark : AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isApplyingCode
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(isHindi ? 'लागू करें' : (isHinglish ? 'Apply karein' : 'Apply Code')),
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
    final langProvider = Provider.of<LanguageProvider>(context);
    final isHindi = langProvider.isHindi;
    final isHinglish = langProvider.isHinglish;

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
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: CircularProgressIndicator(color: AppColors.primaryDark)),
          );
        }

        final initialAccount = snapshot.data;
        if (initialAccount == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              title: Text(
                isHindi ? 'रिवार्ड्स और रेफरल' : 'Rewards & Referrals',
                style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontWeight: FontWeight.w700),
              ),
            ),
            body: Center(
              child: Text(
                isHindi ? 'रिवार्ड्स अकाउंट लोड नहीं हो सका' : 'Unable to load rewards account',
                style: GoogleFonts.poppins(color: const Color(0xFF64748B)),
              ),
            ),
          );
        }

        return StreamBuilder<CustomerLoyaltyAccount?>(
          stream: _service.streamAccount(widget.shopId, widget.customerPhone),
          initialData: initialAccount,
          builder: (context, streamSnap) {
            final account = streamSnap.data ?? initialAccount;
            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
                  onPressed: () => Navigator.maybePop(context),
                ),
                title: Text(
                  isHindi ? 'रिवार्ड्स और रेफरल' : (isHinglish ? 'Rewards & Referrals' : 'Rewards & Referrals'),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: const Color(0xFF0F172A)),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF0F172A)),
                    tooltip: isHindi ? 'नियम और जानकारी' : 'How it Works',
                    onPressed: () => _showHowItWorksBottomSheet(context, isHindi, isHinglish),
                  ),
                ],
              ),
              body: Column(
                children: [
                  _buildHeroPointsCard(account, isHindi, isHinglish),

                  // Segmented Tabs
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.primaryDark,
                      unselectedLabelColor: const Color(0xFF64748B),
                      labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                      unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.people_outline_rounded, size: 18),
                          child: Text(
                            isHindi ? 'रेफर और कमाएं' : (isHinglish ? 'Refer & Earn' : 'Refer & Earn'),
                            maxLines: 1,
                          ),
                        ),
                        Tab(
                          icon: const Icon(Icons.receipt_long_rounded, size: 18),
                          child: Text(
                            isHindi ? 'पासबुक (इतिहास)' : (isHinglish ? 'Passbook' : 'Passbook'),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildReferralTab(account, isHindi, isHinglish),
                        _buildPassbookTab(account, isHindi, isHinglish),
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

  Widget _buildHeroPointsCard(CustomerLoyaltyAccount account, bool isHindi, bool isHinglish) {
    final rupeeSavings = account.rupeeValue();
    final tier = account.tier;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier Badge & Multiplier
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: tier.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tier.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, color: tier.color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      tier.localizedLabel(context),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${tier.pointsMultiplier}x ${isHindi ? "पॉइंट्स मल्टीप्लायर" : "Points Multiplier"}',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Balance & Rupee Savings
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${account.currentPoints}',
                style: GoogleFonts.poppins(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  isHindi ? 'अंक उपलब्ध' : (isHinglish ? 'Points Available' : 'Points Available'),
                  style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      isHindi ? 'बचत मूल्य' : (isHinglish ? 'Savings Value' : 'Savings Value'),
                      style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${rupeeSavings.toStringAsFixed(1)}',
                      style: GoogleFonts.poppins(
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

          const SizedBox(height: 14),

          // Instant Discount Reassurance Pill (Clears user confusion)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDCFCE7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: AppColors.primaryDark, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isHindi
                        ? 'चेकआउट पर तुरंत छूट: हर 10 अंक = ₹1 की बचत'
                        : (isHinglish
                            ? 'Checkout pe instant discount: 10 points = ₹1 off'
                            : 'Checkout discount: 10 points = ₹1.0 off on your order'),
                    style: GoogleFonts.poppins(color: AppColors.primaryDark, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tier Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: account.progressToNextTier,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                account.tier == LoyaltyTier.platinum
                    ? (isHindi ? 'उच्चतम टियर अनलॉक हुआ!' : 'Top Tier Unlocked!')
                    : (isHindi
                        ? '${account.nextTier.localizedLabel(context)} हेतु ${account.pointsNeededForNextTier} अंक और चाहिए'
                        : '${account.pointsNeededForNextTier} pts needed for ${account.nextTier.localizedLabel(context)}'),
                style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 11),
              ),
              Text(
                '${isHindi ? "कुल अर्जित" : "Total Earned"}: ${account.lifetimeEarnedPoints} pts',
                style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralTab(CustomerLoyaltyAccount account, bool isHindi, bool isHinglish) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3-Step Visual Guide (Zepto / Blinkit style) - Removes all confusion
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHindi ? 'रेफरल कैसे काम करता है?' : (isHinglish ? 'Referral kaise kaam karta hai?' : 'How Referral Works'),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReferralStepItem(
                      icon: Icons.share_rounded,
                      step: '1',
                      title: isHindi ? 'कोड भेजें' : 'Share Code',
                      desc: isHindi ? 'व्हाट्सएप पर शेयर करें' : 'Invite friends',
                    ),
                    const SizedBox(width: 8),
                    _buildReferralStepItem(
                      icon: Icons.shopping_bag_outlined,
                      step: '2',
                      title: isHindi ? 'मित्र का ऑर्डर' : 'Friend Orders',
                      desc: isHindi ? 'पहला ऑर्डर करें' : 'Places 1st order',
                    ),
                    const SizedBox(width: 8),
                    _buildReferralStepItem(
                      icon: Icons.card_giftcard_rounded,
                      step: '3',
                      title: isHindi ? '100 अंक पाएं' : 'Get 100 Pts',
                      desc: isHindi ? 'तुरंत वॉलेट में क्रेडिट' : 'Instant bonus',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Share Code Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_rounded, color: Color(0xFF059669), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHindi ? 'आपका एक्सक्लूसिव रेफरल कोड' : (isHinglish ? 'Aapka Referral Code' : 'Your Referral Code'),
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14.5, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            isHindi
                                ? 'दोस्तों को भेजें और प्रत्येक सफल ऑर्डर पर 100 अंक पाएं'
                                : 'Share with friends & get 100 bonus points',
                            style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Code Box with Copy
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          account.referralCode,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _copyToClipboard(account.referralCode, isHindi, isHinglish),
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: Text(
                          isHindi ? 'कॉपी' : 'Copy',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          side: const BorderSide(color: AppColors.primaryDark, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // WhatsApp Share Button (Clean text, ZERO EMOJIS)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareOnWhatsApp(account.referralCode, 'हमारा किराना', isHindi, isHinglish),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      isHindi ? 'व्हाट्सएप पर शेयर करें' : (isHinglish ? 'WhatsApp par Share karein' : 'Share on WhatsApp'),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
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

          const SizedBox(height: 14),

          // Friend's Code Tile
          if (account.referredByCode == null || account.referredByCode!.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFD97706), size: 18),
                  ),
                  title: Text(
                    isHindi ? 'क्या मित्र का रेफरल कोड है?' : 'Have a friend\'s referral code?',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    isHindi ? 'कोड दर्ज करें और पहले ऑर्डर पर अतिरिक्त बोनस पाएं' : 'Enter code & get extra welcome bonus',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _showApplyReferralDialog(context, isHindi, isHinglish),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      isHindi ? 'दर्ज करें' : (isHinglish ? 'Enter' : 'Enter'),
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isHindi
                          ? 'रेफरल कोड लागू हुआ: ${account.referredByCode}'
                          : 'Referral code applied: ${account.referredByCode}',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF065F46),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Referred Friends List
          Text(
            isHindi ? 'आपके द्वारा आमंत्रित मित्र' : (isHinglish ? 'Aapke Invited Friends' : 'Referred Friends'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),

          StreamBuilder<List<ReferralRecord>>(
            stream: _service.streamReferralsByReferrer(widget.shopId, widget.customerPhone),
            builder: (context, refSnap) {
              final referrals = refSnap.data ?? [];
              if (referrals.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.group_add_outlined, size: 38, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        isHindi ? 'अभी कोई मित्र नहीं जुड़ा' : 'No friends referred yet',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF0F172A), fontSize: 13.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isHindi
                            ? 'पॉइंट्स कमाने के लिए व्हाट्सएप पर अपना कोड शेयर करें!'
                            : 'Share your code on WhatsApp to start earning points!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: referrals.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ref = referrals[index];
                  final isCompleted = ref.status == ReferralStatus.completed;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCompleted ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                          child: Icon(
                            isCompleted ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                            color: isCompleted ? const Color(0xFF059669) : const Color(0xFFD97706),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.refereeName,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                '${ref.refereePhone.substring(0, 4)}XXXX${ref.refereePhone.substring(ref.refereePhone.length - 2)}',
                                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isCompleted
                                ? '+${ref.referrerPointsAwarded} pts'
                                : (isHindi ? 'ऑर्डर की प्रतीक्षा' : 'Pending Order'),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCompleted ? const Color(0xFF065F46) : const Color(0xFF92400E),
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

  Widget _buildReferralStepItem({
    required IconData icon,
    required String step,
    required String title,
    required String desc,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFECFDF5),
              child: Icon(icon, color: const Color(0xFF059669), size: 15),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: GoogleFonts.poppins(fontSize: 9.5, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassbookTab(CustomerLoyaltyAccount account, bool isHindi, bool isHinglish) {
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
                const Icon(Icons.history_toggle_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 10),
                Text(
                  isHindi ? 'कोई पॉइंट्स इतिहास नहीं है' : 'No Points History',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  isHindi
                      ? 'जब आप किराना ऑर्डर करेंगे तो आपके अंक यहां दिखाई देंगे।'
                      : 'Your points will appear here when you place grocery orders.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final isPositive = tx.points >= 0;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPositive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPositive ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                      color: isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.description,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year} • ${isHindi ? "शेष अंक" : "Balance"}: ${tx.balanceAfter} pts',
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isPositive ? "+" : ""}${tx.points} pts',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626),
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

  void _showHowItWorksBottomSheet(BuildContext context, bool isHindi, bool isHinglish) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHindi ? 'लॉयल्टी और रेफरल कैसे काम करता है?' : 'How Loyalty & Referrals Work',
                style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildStepRow('1', isHindi ? 'हर ₹100 की खरीदारी पर 10 पॉइंट्स कमाएं।' : 'Earn 10 points for every ₹100 spent.'),
              _buildStepRow('2', isHindi ? 'सिल्वर, गोल्ड, प्लेटिनम टियर अनलॉक करके 2x तक पॉइंट्स पाएं।' : 'Unlock Silver, Gold, Platinum tiers to earn up to 2x points.'),
              _buildStepRow('3', isHindi ? 'मित्रों को अपना कोड शेयर करें और उनके पहले ऑर्डर पर बोनस अंक पाएं।' : 'Invite friends using your code to earn mutual bonus points.'),
              _buildStepRow('4', isHindi ? 'चेकआउट पर तुरंत अंक भुनाकर सीधे रुपये में छूट पाएं (10 अंक = ₹1)।' : 'Redeem points instantly at checkout for direct rupee discounts (10 pts = ₹1)!'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isHindi ? 'समझ गया' : 'Got it'),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: const Color(0xFFECFDF5),
            child: Text(
              number,
              style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }
}
