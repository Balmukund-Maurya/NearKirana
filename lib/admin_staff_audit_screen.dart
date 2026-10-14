import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'shop_provider.dart';
import 'staff_audit_models.dart';
import 'staff_audit_service.dart';
import 'widgets/add_edit_staff_dialog.dart';
import 'widgets/audit_log_details_dialog.dart';
import 'widgets/quick_stock_adjustment_dialog.dart';

/// Main Admin Screen for Staff Accounts and Immutable Audit Trail.
/// Allows shop owners to manage employee accounts, assign granular permissions,
/// and review a comprehensive audit log of who changed what, when, and why.
class AdminStaffAuditScreen extends StatefulWidget {
  final StaffAuditService? service;

  const AdminStaffAuditScreen({super.key, this.service});

  @override
  State<AdminStaffAuditScreen> createState() => _AdminStaffAuditScreenState();
}

class _AdminStaffAuditScreenState extends State<AdminStaffAuditScreen>
    with SingleTickerProviderStateMixin {
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
      actorName: 'Store Owner',
      actorRole: 'owner',
    );
    if (result == true) {
      _loadAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopId = _resolveShopId();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Staff & Audit Logs',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'कर्मचारी खाते और गतिविधि ऑडिट',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh analytics',
            onPressed: _loadAnalytics,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Quick Stock Adjustment',
            onPressed: () => _openQuickStockAdjustment(shopId),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Staff Accounts'),
            Tab(icon: Icon(Icons.history_edu_rounded), text: 'Audit Trail'),
          ],
        ),
      ),
      body: Column(
        children: [
          // KPI Metric Header
          _buildKpiHeader(),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStaffTab(shopId),
                _buildAuditTrailTab(shopId),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openAddStaffDialog(shopId),
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Staff (कर्मचारी जोड़ें)'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _openQuickStockAdjustment(shopId),
              backgroundColor: Colors.indigo.shade800,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Adjust Stock (स्टॉक बदलें)'),
            ),
    );
  }

  // ===========================================================================
  // KPI METRICS HEADER
  // ===========================================================================
  Widget _buildKpiHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildKpiCard(
            title: 'Active Staff',
            subtitle: 'सक्रिय कर्मचारी',
            value: _isLoadingAnalytics ? '...' : '${_analytics.activeStaff}/${_analytics.totalStaff}',
            icon: Icons.people_outline_rounded,
            color: Colors.teal,
          ),
          const SizedBox(width: 8),
          _buildKpiCard(
            title: 'Today Logs',
            subtitle: 'आज के कार्य',
            value: _isLoadingAnalytics ? '...' : '${_analytics.todayLogCount}',
            icon: Icons.assignment_turned_in_rounded,
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          _buildKpiCard(
            title: 'Critical Changes',
            subtitle: 'स्टॉक/कीमत बदलाव',
            value: _isLoadingAnalytics ? '...' : '${_analytics.criticalChangesCount}',
            icon: Icons.warning_amber_rounded,
            color: Colors.deepOrange,
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: STAFF ACCOUNTS
  // ===========================================================================
  Widget _buildStaffTab(String shopId) {
    return StreamBuilder<List<StaffMember>>(
      stream: _service.streamShopStaff(shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_outline_rounded, size: 54, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Staff Accounts Added Yet',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create employee logins for Cashier or Manager to delegate tasks with controlled permissions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _openAddStaffDialog(shopId),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Staff Member'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            return _buildStaffCard(shopId, staff);
          },
        );
      },
    );
  }

  Widget _buildStaffCard(String shopId, StaffMember staff) {
    Color roleBadgeColor;
    switch (staff.role) {
      case StaffRole.manager:
        roleBadgeColor = Colors.purple;
        break;
      case StaffRole.cashier:
        roleBadgeColor = Colors.green.shade800;
        break;
      case StaffRole.stockClerk:
        roleBadgeColor = Colors.indigo;
        break;
      case StaffRole.custom:
        roleBadgeColor = Colors.blueGrey;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: staff.isActive ? Colors.grey.shade200 : Colors.red.shade100,
          width: 1,
        ),
      ),
      elevation: 0,
      color: staff.isActive ? Colors.white : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Name, Role, Switch
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: roleBadgeColor.withValues(alpha: 0.15),
                  child: Text(
                    staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'S',
                    style: TextStyle(fontWeight: FontWeight.bold, color: roleBadgeColor),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: roleBadgeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              staff.role.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: roleBadgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_android_rounded, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '+91 ${staff.phone}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PIN: ****',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Toggle active
                Switch(
                  value: staff.isActive,
                  activeThumbColor: AppColors.primaryDark,
                  onChanged: (val) async {
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
                return Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: Colors.grey.shade300),
                  label: Text(
                    p.label.split('(').first.trim(),
                    style: const TextStyle(fontSize: 10, color: AppColors.textDark),
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
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit (संपादित करें)', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: () => _confirmDeleteStaff(shopId, staff),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('Delete (हटाएं)', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteStaff(String shopId, StaffMember staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff Account?'),
        content: Text('Are you sure you want to delete ${staff.name}\'s login account? This action will be recorded in the audit trail.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deleteStaff(staffId: staff.id, shopId: shopId);
              _loadAnalytics();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: AUDIT TRAIL
  // ===========================================================================
  Widget _buildAuditTrailTab(String shopId) {
    return Column(
      children: [
        // Filter & Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            children: [
              // Search field
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by actor, product or order...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All Actions', null),
                    _buildFilterChip('Stock Changes', AuditActionType.stockAdjustment),
                    _buildFilterChip('Price Changes', AuditActionType.priceChange),
                    _buildFilterChip('Orders', AuditActionType.orderStatusChanged),
                    _buildFilterChip('Staff Changes', AuditActionType.staffCreated),
                    _buildFilterChip('Write-Offs', AuditActionType.stockWriteOff),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Logs Stream
        Expanded(
          child: StreamBuilder<List<AuditLogEntry>>(
            stream: _service.streamAuditLogs(
              shopId,
              filterAction: _selectedActionFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
              }

              var logs = snapshot.data ?? [];

              // Local text search
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
                        Icon(Icons.history_edu_rounded, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No Audit Records Found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Actions like stock adjustments, price changes, and staff updates will appear here automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
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
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.textDark)),
        selectedColor: AppColors.primaryDark,
        backgroundColor: AppColors.surface,
        onSelected: (_) => setState(() => _selectedActionFilter = action),
      ),
    );
  }

  Widget _buildAuditLogCard(AuditLogEntry log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => AuditLogDetailsDialog.show(context, log),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Action badge + Actor + Timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: log.actionType.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(log.actionType.icon, color: log.actionType.color, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log.actionType.label.split('(').first.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                log.description,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),

              // Actor + Reason Tag Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_pin_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          log.actorName,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
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
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Text(
                          'Reason: ${log.reason!}',
                          style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
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
