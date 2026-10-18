import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'shop_provider.dart';
import 'language_provider.dart';
import 'staff_audit_models.dart';
import 'staff_audit_service.dart';
import 'widgets/add_edit_staff_dialog.dart';
import 'widgets/audit_log_details_dialog.dart';
import 'widgets/quick_stock_adjustment_dialog.dart';

/// Zepto/Blinkit merchant staff accounts & immutable audit trail
class AdminStaffAuditScreen extends StatefulWidget {
  final StaffAuditService? service;

  const AdminStaffAuditScreen({super.key, this.service});

  @override
  State<AdminStaffAuditScreen> createState() => _AdminStaffAuditScreenState();
}

class _AdminStaffAuditScreenState extends State<AdminStaffAuditScreen> with SingleTickerProviderStateMixin {
  late StaffAuditService _service;
  late TabController _tabController;

  String _searchQuery = '';
  AuditActionType? _selectedActionFilter;
  StaffAuditAnalytics _analytics = StaffAuditAnalytics.empty();
  bool _isLoadingAnalytics = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StaffAuditService();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnalytics());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _resolveShopId() {
    try {
      final sp = Provider.of<ShopProvider>(context, listen: false);
      if (sp.currentShopId != null && sp.currentShopId!.isNotEmpty) {
        return sp.currentShopId!;
      }
    } catch (_) {}
    return 'SHOP_DEFAULT';
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    final shopId = _resolveShopId();
    try {
      final data = await _service.fetchAnalyticsSummary(shopId);
      if (mounted) {
        setState(() {
          _analytics = data;
          _isLoadingAnalytics = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAnalytics = false);
    }
  }

  void _openAddStaffDialog(String shopId) async {
    final result = await AddEditStaffDialog.show(
      context,
      shopId: shopId,
      service: _service,
    );
    if (result == true) {
      _loadAnalytics();
    }
  }

  void _openEditStaffDialog(String shopId, StaffMember staff) async {
    final result = await AddEditStaffDialog.show(
      context,
      shopId: shopId,
      existingStaff: staff,
      service: _service,
    );
    if (result == true) {
      _loadAnalytics();
    }
  }

  void _openQuickStockAdjustment(String shopId) async {
    final result = await QuickStockAdjustmentDialog.show(
      context,
      shopId: shopId,
      service: _service,
      actorName: 'Store Partner',
      actorRole: 'owner',
    );
    if (result == true) {
      _loadAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    final shopId = _resolveShopId();

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
              t('Staff & Audit Logs', 'स्टाफ खाते व ऑडिट लॉग', 'Staff & Audit Logs'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            Text(
              t('Roles, PINs & Activity Audit', 'अधिकार, पिन व गतिविधि ऑडिट', 'Roles, PINs & Audit Trail'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            tooltip: t('Refresh', 'रिफ्रेश', 'Refresh'),
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadAnalytics();
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF0C831F)),
            tooltip: t('Quick Stock Adjustment', 'त्वरित स्टॉक बदलाव', 'Quick Stock Adjustment'),
            onPressed: () => _openQuickStockAdjustment(shopId),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0C831F),
          indicatorWeight: 3,
          labelColor: const Color(0xFF0C831F),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(text: t('Staff Accounts', 'कर्मचारी खाते', 'Staff Accounts')),
            Tab(text: t('Audit Trail', 'ऑडिट गतिविधि', 'Audit Trail')),
          ],
        ),
      ),
      body: Column(
        children: [
          // KPI Metric Header
          _buildKpiHeader(t),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStaffTab(shopId, t),
                _buildAuditTrailTab(shopId, t),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openAddStaffDialog(shopId),
              backgroundColor: const Color(0xFF0C831F),
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: Text(
                t('Add Staff Member', 'नया कर्मचारी जोड़ें', 'Add Staff Member'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: () => _openQuickStockAdjustment(shopId),
              backgroundColor: const Color(0xFF4338CA),
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: Text(
                t('Adjust Stock', 'स्टॉक बदलें', 'Adjust Stock'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
    );
  }

  Widget _buildKpiHeader(String Function(String, String, String) t) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _buildKpiCard(
            title: t('Active Staff', 'सक्रिय कर्मचारी', 'Active Staff'),
            subtitle: t('On Duty', 'कार्यरत', 'On Duty'),
            value: _isLoadingAnalytics ? '...' : '${_analytics.activeStaff}/${_analytics.totalStaff}',
            icon: Icons.people_outline_rounded,
            color: const Color(0xFF0C831F),
          ),
          const SizedBox(width: 8),
          _buildKpiCard(
            title: t('Today Logs', 'आज के कार्य', 'Today Logs'),
            subtitle: t('Audit entries', 'ऑडिट रिकॉर्ड्स', 'Audit entries'),
            value: _isLoadingAnalytics ? '...' : '${_analytics.todayLogCount}',
            icon: Icons.assignment_turned_in_rounded,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          _buildKpiCard(
            title: t('Critical Edits', 'महत्वपूर्ण बदलाव', 'Critical Edits'),
            subtitle: t('Stock/Price changes', 'स्टॉक या मूल्य', 'Stock/Price edits'),
            value: _isLoadingAnalytics ? '...' : '${_analytics.criticalChangesCount}',
            icon: Icons.security_rounded,
            color: const Color(0xFFEA580C),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffTab(String shopId, String Function(String, String, String) t) {
    return StreamBuilder<List<StaffMember>>(
      stream: _service.streamShopStaff(shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0C831F)));
        }

        final staffList = snapshot.data ?? [];

        if (staffList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF0C831F)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('No Staff Accounts Added Yet', 'कोई कर्मचारी खाता नहीं है', 'No Staff Accounts Added Yet'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t(
                      'Create employee logins for Cashier or Stock Clerk with granular permissions.',
                      'कैशियर या स्टोर क्लर्क के लिए अलग लॉगिन पिन बनाएं।',
                      'Create employee logins with specific access permissions.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _openAddStaffDialog(shopId),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(t('Add Staff Member', 'कर्मचारी जोड़ें', 'Add Staff Member')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C831F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            return _buildStaffCard(shopId, staff, t);
          },
        );
      },
    );
  }

  Widget _buildStaffCard(String shopId, StaffMember staff, String Function(String, String, String) t) {
    Color roleBadgeColor;
    switch (staff.role) {
      case StaffRole.manager:
        roleBadgeColor = const Color(0xFF7C3AED);
        break;
      case StaffRole.cashier:
        roleBadgeColor = const Color(0xFF0C831F);
        break;
      case StaffRole.stockClerk:
        roleBadgeColor = const Color(0xFF2563EB);
        break;
      case StaffRole.custom:
        roleBadgeColor = const Color(0xFFEA580C);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: staff.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: roleBadgeColor.withValues(alpha: 0.12),
                  child: Text(
                    staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'S',
                    style: TextStyle(fontWeight: FontWeight.w800, color: roleBadgeColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              staff.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleBadgeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              staff.role.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: roleBadgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            staff.phone,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PIN: ****',
                              style: TextStyle(fontSize: 9, color: Color(0xFF475569), fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: staff.isActive,
                  activeThumbColor: const Color(0xFF0C831F),
                  onChanged: (val) async {
                    HapticFeedback.lightImpact();
                    await _service.toggleStaffStatus(
                      staffId: staff.id,
                      shopId: shopId,
                      isActive: val,
                    );
                    _loadAnalytics();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Permissions Preview Chips
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: staff.permissions.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    p.label.split('(').first.trim(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            // Card Action Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openEditStaffDialog(shopId, staff),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: Text(t('Edit', 'बदलें', 'Edit'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: () => _confirmDeleteStaff(shopId, staff, t),
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: Text(t('Delete', 'हटाएं', 'Delete'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteStaff(String shopId, StaffMember staff, String Function(String, String, String) t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          t('Delete Staff Account?', 'कर्मचारी खाता हटाएं?', 'Delete Staff Account?'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          t(
            'Are you sure you want to remove ${staff.name}? This action will be recorded in the audit trail.',
            'क्या आप निश्चित रूप से ${staff.name} का खाता हटाना चाहते हैं? यह क्रिया ऑडिट लॉग में दर्ज होगी।',
            'Kya aap ${staff.name} ka account delete karna chahte hain?',
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('Cancel', 'रद्द करें', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              await _service.deleteStaff(staffId: staff.id, shopId: shopId);
              _loadAnalytics();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(t('Delete', 'हटाएं', 'Delete')),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTrailTab(String shopId, String Function(String, String, String) t) {
    return Column(
      children: [
        // Filter & Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: t('Search by staff, product or order...', 'कर्मचारी, सामान या ऑर्डर खोजें...', 'Search staff, product or order...'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(t('All Actions', 'सभी कार्य', 'All Actions'), null),
                    _buildFilterChip(t('Stock Changes', 'स्टॉक बदलाव', 'Stock Changes'), AuditActionType.stockAdjustment),
                    _buildFilterChip(t('Price Changes', 'कीमत बदलाव', 'Price Changes'), AuditActionType.priceChange),
                    _buildFilterChip(t('Orders', 'ऑर्डर्स', 'Orders'), AuditActionType.orderStatusChanged),
                    _buildFilterChip(t('Staff Changes', 'स्टाफ बदलाव', 'Staff Changes'), AuditActionType.staffCreated),
                    _buildFilterChip(t('Write-Offs', 'खराब सामान', 'Write-Offs'), AuditActionType.stockWriteOff),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Logs Stream
        Expanded(
          child: StreamBuilder<List<AuditLogEntry>>(
            stream: _service.streamAuditLogs(
              shopId,
              filterAction: _selectedActionFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF0C831F)));
              }

              var logs = snapshot.data ?? [];

              if (_searchQuery.isNotEmpty) {
                logs = logs.where((l) {
                  return l.actorName.toLowerCase().contains(_searchQuery) ||
                      l.entityName.toLowerCase().contains(_searchQuery) ||
                      l.description.toLowerCase().contains(_searchQuery) ||
                      (l.reason?.toLowerCase().contains(_searchQuery) ?? false);
                }).toList();
              }

              if (logs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                          ),
                          child: const Icon(Icons.history_edu_rounded, size: 40, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t('No Audit Records Found', 'कोई ऑडिट रिकॉर्ड नहीं मिला', 'No Audit Records Found'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t(
                            'Actions like stock adjustments and price edits will appear here automatically.',
                            'स्टॉक व कीमत बदलाव यहां अपने आप दर्ज होते रहेंगे।',
                            'Stock and price modifications will be logged here automatically.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _buildAuditLogCard(log);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, AuditActionType? action) {
    final isSelected = _selectedActionFilter == action;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
        selectedColor: const Color(0xFF0C831F),
        backgroundColor: const Color(0xFFF1F5F9),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isSelected ? const Color(0xFF0C831F) : Colors.transparent),
        ),
        onSelected: (_) => setState(() => _selectedActionFilter = action),
      ),
    );
  }

  Widget _buildAuditLogCard(AuditLogEntry log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => AuditLogDetailsDialog.show(context, log),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: log.actionType.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(log.actionType.icon, color: log.actionType.color, size: 15),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log.actionType.label.split('(').first.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: log.actionType.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    log.formattedTime,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                log.description,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_pin_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          log.actorName,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF334155), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (log.reason != null && log.reason!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.reason!,
                          style: const TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
