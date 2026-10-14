import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'loyalty_referral_models.dart';
import 'loyalty_referral_service.dart';
import 'l10n/app_localizations.dart';

/// Admin control hub for managing loyalty points rules, viewing customer point passbooks,
/// auditing referral conversions, and adjusting customer point balances with reason notes.
class AdminLoyaltyScreen extends StatefulWidget {
  final String? shopId;
  final LoyaltyReferralService? service;

  const AdminLoyaltyScreen({super.key, this.shopId, this.service});

  @override
  State<AdminLoyaltyScreen> createState() => _AdminLoyaltyScreenState();
}

class _AdminLoyaltyScreenState extends State<AdminLoyaltyScreen>
    with SingleTickerProviderStateMixin {
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
      final prefs = await SharedPreferences.getInstance();
      _effectiveShopId = prefs.getString('current_shop_id') ??
          prefs.getString('shop_id') ??
          'primary_shop';
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

  Future<void> _saveSettings() async {
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
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.settings_saved_snack ?? 'Loyalty & referral settings saved'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAdjustPointsDialog(CustomerLoyaltyAccount account) {
    final l10n = AppLocalizations.of(context);
    final pointsController = TextEditingController();
    final reasonController = TextEditingController();
    bool isCredit = true;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                '${l10n?.adjust_points_title ?? "Adjust Points"}\n${account.customerName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text(l10n?.add_points_chip ?? '+ Add'),
                            selected: isCredit,
                            selectedColor: Colors.green.shade100,
                            onSelected: (val) => setModalState(() => isCredit = true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Text(l10n?.deduct_points_chip ?? '- Deduct'),
                            selected: !isCredit,
                            selectedColor: Colors.red.shade100,
                            onSelected: (val) => setModalState(() => isCredit = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n?.points_amount_label ?? 'Points amount',
                        prefixIcon: const Icon(Icons.stars_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: l10n?.adjust_reason_label ?? 'Reason / Note',
                        hintText: l10n?.adjust_reason_hint ?? 'e.g. Birthday gift, Goodwill credit',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(l10n?.cancel ?? 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = int.tryParse(pointsController.text.trim()) ?? 0;
                    final reason = reasonController.text.trim();
                    if (amount <= 0 || reason.isEmpty) return;

                    final delta = isCredit ? amount : -amount;
                    final messenger = ScaffoldMessenger.of(context);
                    await _service.adminAdjustPoints(
                      shopId: account.shopId,
                      customerPhone: account.customerPhone,
                      pointsDelta: delta,
                      reason: reason,
                      adminName: 'Store Owner',
                    );

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('${account.customerName}: $delta pts ($reason)'),
                          backgroundColor: AppColors.primaryDark,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCredit ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(l10n?.apply_btn ?? 'Apply'),
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryDark)),
      );
    }

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          l10n?.admin_loyalty_title ?? 'Loyalty & Referrals',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryDark,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textMid,
          tabs: [
            Tab(text: l10n?.admin_tab_customers ?? 'Customers'),
            Tab(text: l10n?.admin_tab_referrals ?? 'Referrals'),
            Tab(text: l10n?.admin_tab_settings ?? 'Settings'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildKpiSummaryBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCustomersTab(),
                _buildReferralsTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryBar() {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder(
      future: _service.getShopAnalytics(_effectiveShopId),
      builder: (context, snap) {
        final data = snap.data;
        final issued = data?.totalPointsIssued ?? 0;
        final redeemed = data?.totalPointsRedeemed ?? 0;
        final referrals = data?.totalReferralsCompleted ?? 0;
        final discountGiven = data?.totalDiscountGivenRupees ?? 0.0;

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              _buildMiniKpi(l10n?.kpi_total_issued ?? 'Total Issued', '$issued', Icons.stars_rounded, Colors.amber.shade700),
              _buildMiniKpi(l10n?.kpi_total_redeemed ?? 'Total Redeemed', '$redeemed', Icons.redeem_rounded, Colors.purple),
              _buildMiniKpi(l10n?.kpi_successful_referrals ?? 'Successful Referrals', '$referrals', Icons.people_rounded, Colors.blue),
              _buildMiniKpi(l10n?.kpi_total_discount_given ?? 'Discounts Given', '₹${discountGiven.toStringAsFixed(0)}', Icons.savings_rounded, Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniKpi(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMid),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersTab() {
    final l10n = AppLocalizations.of(context);
    final isHindi = l10n?.localeName.startsWith('hi') ?? false;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: l10n?.search_customer_hint ?? 'Search customer name or phone...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CustomerLoyaltyAccount>>(
            stream: _service.streamShopAccounts(_effectiveShopId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
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
                      Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        l10n?.no_customers_found ?? 'No customer accounts found',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: accounts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final acc = accounts[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: acc.tier.color.withValues(alpha: 0.15),
                          child: Icon(Icons.stars_rounded, color: acc.tier.color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc.customerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                isHindi
                                    ? '${acc.customerPhone} • कोड: ${acc.referralCode}'
                                    : '${acc.customerPhone} • Code: ${acc.referralCode}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${acc.tier.localizedLabel(context)} • ${l10n?.total_earned_label ?? "Total Earned"}: ${acc.lifetimeEarnedPoints} pts',
                                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${acc.currentPoints} pts',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _showAdjustPointsDialog(acc),
                              icon: const Icon(Icons.tune_rounded, size: 14),
                              label: Text(l10n?.modify_btn ?? 'Modify', style: const TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _buildReferralsTab() {
    final l10n = AppLocalizations.of(context);
    final isHindi = l10n?.localeName.startsWith('hi') ?? false;

    return StreamBuilder<List<ReferralRecord>>(
      stream: _service.streamShopReferrals(_effectiveShopId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
        }

        final referrals = snap.data ?? [];
        if (referrals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  isHindi ? 'कोई रेफरल रिकॉर्ड नहीं मिला' : 'No referral records found',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
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
                border: Border.all(color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isHindi ? 'रेफरल कोड: ${ref.referralCode}' : 'Code: ${ref.referralCode}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isCompleted ? Colors.green : Colors.amber),
                        ),
                        child: Text(
                          ref.status.localizedLabel(context),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? Colors.green.shade800 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isHindi ? 'रेफरर: ${ref.referrerName} (${ref.referrerPhone})' : 'Referrer: ${ref.referrerName} (${ref.referrerPhone})',
                          style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textMid),
                      Expanded(
                        child: Text(
                          isHindi ? 'मित्र: ${ref.refereeName} (${ref.refereePhone})' : 'Friend: ${ref.refereeName} (${ref.refereePhone})',
                          style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  if (isCompleted && ref.qualifyingOrderAmount != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isHindi
                                ? 'पात्र ऑर्डर: ₹${ref.qualifyingOrderAmount!.toStringAsFixed(0)} (#${ref.qualifyingOrderId})'
                                : 'Qualifying Order: ₹${ref.qualifyingOrderAmount!.toStringAsFixed(0)} (#${ref.qualifyingOrderId})',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                          ),
                          Text(
                            isHindi
                                ? '+${ref.referrerPointsAwarded} pts (रेफरर) • +${ref.refereePointsAwarded} pts (मित्र)'
                                : '+${ref.referrerPointsAwarded} pts (Referrer) • +${ref.refereePointsAwarded} pts (Friend)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                          ),
                        ],
                      ),
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

  Widget _buildSettingsTab() {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Loyalty Switch
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n?.enable_loyalty_switch ?? 'Enable Loyalty Program', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(l10n?.loyalty_program_desc ?? 'Customers earn reward points on purchases'),
                    value: _programEnabled,
                    activeThumbColor: AppColors.primaryDark,
                    onChanged: (val) => setState(() => _programEnabled = val),
                  ),
                ),
                const Divider(),
                _buildTextField(l10n?.points_per_hundred_spend_label ?? 'Points per ₹100 spend', _pointsPerHundredController),
                const SizedBox(height: 12),
                _buildTextField(l10n?.point_rupee_value_label ?? '1 Point value in ₹', _pointValueController),
                const SizedBox(height: 12),
                _buildTextField(l10n?.min_points_redeem_label ?? 'Min points to redeem', _minPointsRedeemController),
                const SizedBox(height: 12),
                _buildTextField(l10n?.max_discount_percent_label ?? 'Max discount % on order', _maxRedeemPercentController),
                const SizedBox(height: 12),
                _buildTextField(l10n?.min_order_points_label ?? 'Min order for points (₹)', _minOrderPointsController),
                const SizedBox(height: 12),
                _buildTextField(l10n?.welcome_bonus_label ?? 'Welcome Bonus Points', _welcomeBonusController),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Referral Switch
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n?.enable_referral_switch ?? 'Enable Refer & Earn Program', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(l10n?.referral_program_desc ?? 'Rewards for friend & referrer on first order'),
                    value: _referralEnabled,
                    activeThumbColor: AppColors.primaryDark,
                    onChanged: (val) => setState(() => _referralEnabled = val),
                  ),
                ),
                const Divider(),
                _buildTextField(l10n?.referrer_reward_label ?? 'Referrer Reward Points', _referrerRewardController),
                const SizedBox(height: 12),
                _buildTextField(l10n?.referee_reward_label ?? 'Friend Welcome Points', _refereeRewardController),
                const SizedBox(height: 12),
                _buildTextField(l10n?.min_order_referral_label ?? 'Min qualifying order (₹)', _minOrderReferralController),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(l10n?.save_settings_btn ?? 'Save Settings', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
