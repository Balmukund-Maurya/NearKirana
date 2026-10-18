import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'loyalty_referral_models.dart';
import 'loyalty_referral_service.dart';
import 'shop_provider.dart';
import 'language_provider.dart';
import 'sound_service.dart';

/// Zepto/Blinkit merchant loyalty & referral hub
class AdminLoyaltyScreen extends StatefulWidget {
  final String? shopId;
  final LoyaltyReferralService? service;

  const AdminLoyaltyScreen({super.key, this.shopId, this.service});

  @override
  State<AdminLoyaltyScreen> createState() => _AdminLoyaltyScreenState();
}

class _AdminLoyaltyScreenState extends State<AdminLoyaltyScreen> with SingleTickerProviderStateMixin {
  late final LoyaltyReferralService _service;
  late TabController _tabController;
  String _effectiveShopId = 'primary_shop';
  bool _isLoading = true;

  // Search filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Settings form controllers
  bool _programEnabled = true;
  final TextEditingController _pointsPerHundredController = TextEditingController(text: '10');
  final TextEditingController _pointValueController = TextEditingController(text: '0.10');
  final TextEditingController _minPointsRedeemController = TextEditingController(text: '50');
  final TextEditingController _maxRedeemPercentController = TextEditingController(text: '30');
  final TextEditingController _minOrderPointsController = TextEditingController(text: '50');
  bool _referralEnabled = true;
  final TextEditingController _referrerRewardController = TextEditingController(text: '100');
  final TextEditingController _refereeRewardController = TextEditingController(text: '50');
  final TextEditingController _minOrderReferralController = TextEditingController(text: '100');
  final TextEditingController _welcomeBonusController = TextEditingController(text: '20');

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LoyaltyReferralService();
    _tabController = TabController(length: 3, vsync: this);
    _initializeShop();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _pointsPerHundredController.dispose();
    _pointValueController.dispose();
    _minPointsRedeemController.dispose();
    _maxRedeemPercentController.dispose();
    _minOrderPointsController.dispose();
    _referrerRewardController.dispose();
    _refereeRewardController.dispose();
    _minOrderReferralController.dispose();
    _welcomeBonusController.dispose();
    super.dispose();
  }

  Future<void> _initializeShop() async {
    if (widget.shopId != null && widget.shopId!.isNotEmpty) {
      _effectiveShopId = widget.shopId!;
    } else {
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      if (shopProvider.currentShopId != null && shopProvider.currentShopId!.isNotEmpty) {
        _effectiveShopId = shopProvider.currentShopId!;
      } else {
        final prefs = await SharedPreferences.getInstance();
        _effectiveShopId = prefs.getString('current_shop_id') ??
            prefs.getString('shop_id') ??
            'primary_shop';
      }
    }

    final config = await _service.getProgramConfig(_effectiveShopId);
    if (mounted) {
      setState(() {
        _programEnabled = config.isEnabled;
        _pointsPerHundredController.text = config.pointsPerHundredRupees.toString();
        _pointValueController.text = config.pointValueInRupees.toString();
        _minPointsRedeemController.text = config.minPointsToRedeem.toString();
        _maxRedeemPercentController.text = (config.maxRedemptionPercentage * 100).toInt().toString();
        _minOrderPointsController.text = config.minQualifyingOrderForPoints.toStringAsFixed(0);
        _referralEnabled = config.referralEnabled;
        _referrerRewardController.text = config.referrerRewardPoints.toString();
        _refereeRewardController.text = config.refereeRewardPoints.toString();
        _minOrderReferralController.text = config.minQualifyingOrderForReferral.toStringAsFixed(0);
        _welcomeBonusController.text = config.welcomeBonusPoints.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings(String Function(String, String, String) t) async {
    HapticFeedback.mediumImpact();
    final config = LoyaltyProgramConfig(
      shopId: _effectiveShopId,
      isEnabled: _programEnabled,
      pointsPerHundredRupees: int.tryParse(_pointsPerHundredController.text.trim()) ?? 10,
      pointValueInRupees: double.tryParse(_pointValueController.text.trim()) ?? 0.10,
      minPointsToRedeem: int.tryParse(_minPointsRedeemController.text.trim()) ?? 50,
      maxRedemptionPercentage: ((double.tryParse(_maxRedeemPercentController.text.trim()) ?? 30) / 100.0).clamp(0.05, 1.0),
      minQualifyingOrderForPoints: double.tryParse(_minOrderPointsController.text.trim()) ?? 50.0,
      referralEnabled: _referralEnabled,
      referrerRewardPoints: int.tryParse(_referrerRewardController.text.trim()) ?? 100,
      refereeRewardPoints: int.tryParse(_refereeRewardController.text.trim()) ?? 50,
      minQualifyingOrderForReferral: double.tryParse(_minOrderReferralController.text.trim()) ?? 100.0,
      welcomeBonusPoints: int.tryParse(_welcomeBonusController.text.trim()) ?? 20,
    );

    await _service.updateProgramConfig(config);

    if (mounted) {
      SoundService().success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('Loyalty & referral settings saved', 'लॉयल्टी व रेफरल सेटिंग्स सुरक्षित हो गईं', 'Loyalty & referral settings saved')),
          backgroundColor: const Color(0xFF0C831F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAdjustPointsBottomSheet(CustomerLoyaltyAccount account, String Function(String, String, String) t) {
    final pointsController = TextEditingController();
    final reasonController = TextEditingController();
    bool isCredit = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.stars_rounded, color: Color(0xFF0C831F), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('Adjust Customer Coins', 'ग्राहक पॉइंट्स में बदलाव', 'Adjust Customer Points'),
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                '${account.customerName} • ${t('Current', 'मौजूदा', 'Current')}: ${account.currentPoints} pts',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 16),

                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => isCredit = true),
                              borderRadius: BorderRadius.circular(9),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isCredit ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: isCredit
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 16,
                                      color: isCredit ? const Color(0xFF0C831F) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      t('+ Add Coins', '+ पॉइंट्स जोड़ें', '+ Add Points'),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isCredit ? const Color(0xFF0C831F) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => isCredit = false),
                              borderRadius: BorderRadius.circular(9),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !isCredit ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: !isCredit
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.remove_circle_outline_rounded,
                                      size: 16,
                                      color: !isCredit ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      t('- Deduct', '- पॉइंट्स घटाएं', '- Deduct'),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: !isCredit ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t('Points Amount', 'पॉइंट्स संख्या', 'Points Amount'),
                        prefixIcon: const Icon(Icons.stars_rounded, color: Color(0xFF0C831F)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: t('Reason / Note', 'कारण व विवरण', 'Reason / Note'),
                        hintText: t('e.g. Festival gift, Goodwill compensation', 'उदा. त्योहार का गिफ्ट, असुविधा पर भरपाई', 'e.g. Goodwill bonus, store gift'),
                        prefixIcon: const Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick suggestion chips
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.card_giftcard_rounded, size: 14, color: Color(0xFF0C831F)),
                          label: Text(t('Store Goodwill', 'सद्भावना बोनस', 'Store Goodwill'), style: const TextStyle(fontSize: 11)),
                          onPressed: () => setModalState(() => reasonController.text = 'Customer Goodwill'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.sync_problem_rounded, size: 14, color: Color(0xFFEA580C)),
                          label: Text(t('Delay Compensation', 'देरी की भरपाई', 'Delay Compensation'), style: const TextStyle(fontSize: 11)),
                          onPressed: () => setModalState(() => reasonController.text = 'Delivery Delay Compensation'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF7C3AED)),
                          label: Text(t('Festival Bonus', 'त्योहार का उपहार', 'Festival Bonus'), style: const TextStyle(fontSize: 11)),
                          onPressed: () => setModalState(() => reasonController.text = 'Festival Reward'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount = int.tryParse(pointsController.text.trim()) ?? 0;
                          final reason = reasonController.text.trim();
                          if (amount <= 0 || reason.isEmpty) return;

                          final delta = isCredit ? amount : -amount;
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(dialogCtx);
                          HapticFeedback.mediumImpact();

                          await _service.adminAdjustPoints(
                            shopId: account.shopId,
                            customerPhone: account.customerPhone,
                            pointsDelta: delta,
                            reason: reason,
                            adminName: 'Store Partner',
                          );

                          if (mounted) {
                            SoundService().success();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('${account.customerName}: ${delta > 0 ? "+$delta" : "$delta"} pts ($reason)'),
                                backgroundColor: const Color(0xFF0C831F),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCredit ? const Color(0xFF0C831F) : const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          isCredit
                              ? t('Confirm Add Points', 'पॉइंट्स जोड़ें', 'Confirm Add Points')
                              : t('Confirm Deduct Points', 'पॉइंट्स घटाएं', 'Confirm Deduct Points'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0C831F))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('Loyalty & Referrals', 'लॉयल्टी व रेफरल प्रोग्राम', 'Loyalty & Referrals'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            Text(
              t('Rewards & Customer Coins', 'रिवॉर्ड्स व ग्राहक कॉइन्स', 'Rewards & Coins Hub'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0C831F),
          indicatorWeight: 3,
          labelColor: const Color(0xFF0C831F),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(text: t('Passbook', 'पासबुक', 'Passbook')),
            Tab(text: t('Referrals', 'रेफरल्स', 'Referrals')),
            Tab(text: t('Rules & Setup', 'नियम व सेटिंग्स', 'Rules & Setup')),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildKpiSummaryBar(t),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCustomersTab(t),
                _buildReferralsTab(t),
                _buildSettingsTab(t),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryBar(String Function(String, String, String) t) {
    return FutureBuilder(
      future: _service.getShopAnalytics(_effectiveShopId),
      builder: (context, snap) {
        final data = snap.data;
        final issued = data?.totalPointsIssued ?? 0;
        final redeemed = data?.totalPointsRedeemed ?? 0;
        final referrals = data?.totalReferralsCompleted ?? 0;
        final discountGiven = data?.totalDiscountGivenRupees ?? 0.0;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              _buildMiniKpi(t('Issued', 'जारी', 'Issued'), '$issued', Icons.stars_rounded, const Color(0xFFD97706)),
              _buildMiniKpi(t('Redeemed', 'खर्च', 'Redeemed'), '$redeemed', Icons.redeem_rounded, const Color(0xFF7C3AED)),
              _buildMiniKpi(t('Referrals', 'रेफरल', 'Referrals'), '$referrals', Icons.people_alt_rounded, const Color(0xFF2563EB)),
              _buildMiniKpi(t('Savings', 'छूट राशि', 'Savings'), '₹${discountGiven.toStringAsFixed(0)}', Icons.savings_rounded, const Color(0xFF0C831F)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniKpi(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomersTab(String Function(String, String, String) t) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: t('Search customer name, phone, code...', 'ग्राहक का नाम, फोन या कोड खोजें...', 'Search name, phone, code...'),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CustomerLoyaltyAccount>>(
            stream: _service.streamShopAccounts(_effectiveShopId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF0C831F)));
              }

              final accounts = (snap.data ?? []).where((a) {
                if (_searchQuery.isEmpty) return true;
                return a.customerName.toLowerCase().contains(_searchQuery) ||
                    a.customerPhone.contains(_searchQuery) ||
                    a.referralCode.toLowerCase().contains(_searchQuery);
              }).toList();

              if (accounts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                        ),
                        child: const Icon(Icons.person_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('No customer passbooks found', 'कोई ग्राहक रिकॉर्ड नहीं मिला', 'No customer passbooks found'),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                itemCount: accounts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final acc = accounts[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: acc.tier.color.withValues(alpha: 0.15),
                            border: Border.all(color: acc.tier.color.withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: Icon(Icons.stars_rounded, color: acc.tier.color, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc.customerName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${acc.customerPhone} • ${t('Code', 'कोड', 'Code')}: ${acc.referralCode}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: acc.tier.color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      acc.tier.simpleName.toUpperCase(),
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: acc.tier.color),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${t('Earned', 'कुल कमाई', 'Earned')}: ${acc.lifetimeEarnedPoints} pts',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${acc.currentPoints} pts',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF0C831F),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _showAdjustPointsBottomSheet(acc, t),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 4),
                                    Text(
                                      t('Adjust', 'बदलें', 'Adjust'),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReferralsTab(String Function(String, String, String) t) {
    return StreamBuilder<List<ReferralRecord>>(
      stream: _service.streamShopReferrals(_effectiveShopId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0C831F)));
        }

        final referrals = snap.data ?? [];
        if (referrals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                  ),
                  child: const Icon(Icons.share_outlined, size: 40, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                Text(
                  t('No referral conversions yet', 'अभी तक कोई रेफरल नहीं हुआ', 'No referral conversions yet'),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: referrals.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final ref = referrals[index];
            final isCompleted = ref.status == ReferralStatus.completed;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.qr_code_rounded, size: 16, color: Color(0xFF0C831F)),
                          const SizedBox(width: 6),
                          Text(
                            '${t('Code', 'रेफरल कोड', 'Code')}: ${ref.referralCode}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isCompleted ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          isCompleted
                              ? t('Completed', 'सफल रेफरल', 'Completed')
                              : t('Pending 1st Order', 'पहले ऑर्डर का इंतज़ार', 'Pending 1st Order'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isCompleted ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('Referred By (Inviter)', 'आमंत्रित करने वाला', 'Inviter'), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            Text(ref.referrerPhone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(t('New Friend', 'नया ग्राहक', 'New Customer'), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            Text(ref.refereePhone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsTab(String Function(String, String, String) t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Loyalty Program
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFF0C831F), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          t('Loyalty Points Program', 'लॉयल्टी पॉइंट्स प्रोग्राम', 'Loyalty Points Program'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    Switch(
                      value: _programEnabled,
                      activeThumbColor: const Color(0xFF0C831F),
                      onChanged: (val) => setState(() => _programEnabled = val),
                    ),
                  ],
                ),
                Text(
                  t(
                    'Reward frequent buyers with cashback points for every purchase.',
                    'हर खरीदारी पर ग्राहकों को कैशबैकिंग पॉइंट्स दें ताकि वे बार-बार आएं।',
                    'Reward customers with points on every order.',
                  ),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),

                TextField(
                  controller: _pointsPerHundredController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t('Points per ₹100 spent', 'हर ₹100 की खरीदारी पर पॉइंट्स', 'Points per ₹100 spent'),
                    hintText: '10',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pointValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: t('Value of 1 Point in ₹', '1 पॉइंट का रुपया मूल्य', 'Value of 1 Point in ₹'),
                    hintText: '0.10',
                    prefixText: '₹ ',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _minPointsRedeemController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t('Minimum Points to Redeem', 'छूट पाने के लिए न्यूनतम पॉइंट्स', 'Minimum Points to Redeem'),
                    hintText: '50',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _welcomeBonusController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t('Welcome Bonus Points (New Customer)', 'नए ग्राहक को वेलकम बोनस पॉइंट्स', 'Welcome Bonus Points'),
                    hintText: '20',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Section 2: Referral Setup
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          t('Refer & Earn Program', 'रेफर और कमाओ प्रोग्राम', 'Refer & Earn Setup'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    Switch(
                      value: _referralEnabled,
                      activeThumbColor: const Color(0xFF2563EB),
                      onChanged: (val) => setState(() => _referralEnabled = val),
                    ),
                  ],
                ),
                Text(
                  t(
                    'Encourage customers to share store QR with neighborhood friends.',
                    'ग्राहकों को अपनी दुकान का लिंक पड़ोसियों के साथ साझा करने पर इनाम दें।',
                    'Reward customers when their friends place their 1st order.',
                  ),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),

                TextField(
                  controller: _referrerRewardController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t('Referrer Reward Points (Friend)', 'रेफर करने वाले को पॉइंट्स', 'Referrer Reward Points'),
                    hintText: '100',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _refereeRewardController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t('New Customer Reward Points', 'नए आने वाले दोस्त को पॉइंट्स', 'Referee Reward Points'),
                    hintText: '50',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _minOrderReferralController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t('Min Qualifying Order for Referral (₹)', 'रेफरल मान्य होने का न्यूनतम ऑर्डर (₹)', 'Min Order for Referral (₹)'),
                    prefixText: '₹ ',
                    hintText: '100',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _saveSettings(t),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                t('Save Program Settings', 'सेटिंग्स सुरक्षित करें', 'Save Program Settings'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C831F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
