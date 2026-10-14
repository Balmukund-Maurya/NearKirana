import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'shop_provider.dart';
import 'data_export_backup_models.dart';
import 'data_export_backup_service.dart';
import 'widgets/export_filter_modal.dart';
import 'widgets/restore_test_dialog.dart';
import 'widgets/create_backup_modal.dart';

/// Main Admin dashboard for Data Export, Cloud Backups, Retention policy,
/// and automated Restore Testing (Feature 57).
class AdminDataExportBackupScreen extends StatefulWidget {
  final DataExportBackupService? service;

  const AdminDataExportBackupScreen({super.key, this.service});

  @override
  State<AdminDataExportBackupScreen> createState() => _AdminDataExportBackupScreenState();
}

class _AdminDataExportBackupScreenState extends State<AdminDataExportBackupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DataExportBackupService _service;
  bool _isQuickExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _service = widget.service ?? DataExportBackupService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _quickExportMonthEnd(ExportFormat format) async {
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    if (shopId == null || shopId.isEmpty) return;

    setState(() => _isQuickExporting = true);
    try {
      final range = DateRangePreset.thisMonth.getDateRange();
      final filter = ExportFilter(
        shopId: shopId,
        domain: ExportDomain.salesReport,
        format: format,
        startDate: range.start,
        endDate: range.end,
        preset: DateRangePreset.thisMonth,
      );

      final result = await _service.generateExport(filter);
      if (mounted) {
        setState(() => _isQuickExporting = false);
        await _service.shareExport(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isQuickExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quick export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId ?? '';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Data Export & Backup (डेटा व बैकअप)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'About Exports & Backups',
            onPressed: () => _showInfoDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primaryDark,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.file_download_outlined, size: 20),
              text: 'Export Reports (डेटा निर्यात)',
            ),
            Tab(
              icon: Icon(Icons.cloud_sync_outlined, size: 20),
              text: 'Cloud Backups (क्लाउड बैकअप)',
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<BackupSnapshot>>(
        stream: _service.streamShopBackups(shopId),
        builder: (context, snapshot) {
          final snapshots = snapshot.data ?? [];
          final analytics = BackupAnalyticsSummary.fromSnapshots(snapshots);

          return Column(
            children: [
              // KPI Header Cards
              _buildKpiHeader(analytics),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Export Reports
                    _buildExportTab(context, shopId),

                    // Tab 2: Cloud Backups & Restore Testing
                    _buildBackupsTab(context, shopId, snapshots),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // KPI Header
  // =========================================================================

  Widget _buildKpiHeader(BackupAnalyticsSummary analytics) {
    final lastBackupText = analytics.lastBackupDate != null
        ? DateFormat('dd MMM, hh:mm a').format(analytics.lastBackupDate!)
        : 'No backups yet';

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Expanded(
                child: _kpiCard(
                  title: 'Last Cloud Backup',
                  value: lastBackupText,
                  icon: Icons.cloud_done_rounded,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiCard(
                  title: 'Total Snapshots',
                  value: '${analytics.totalBackups} Backups',
                  icon: Icons.layers_rounded,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiCard(
                  title: 'Restore Health',
                  value: '${analytics.averageHealthScore.toStringAsFixed(0)}% Score',
                  icon: Icons.health_and_safety_rounded,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiCard(
                  title: 'Retention Lifespan',
                  value: '${analytics.activeRetentionDays} Days Policy',
                  icon: Icons.schedule_rounded,
                  color: Colors.purple,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
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
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.9)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: EXPORT BUSINESS REPORTS
  // =========================================================================

  Widget _buildExportTab(BuildContext context, String shopId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Month-End Special Hero Card for Accountant / CA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade800, Colors.teal.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.teal.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Month-End Sales Report (मंथ-एंड सेल्स रिपोर्ट)',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Accountant Special',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Instantly generate verified sales records with gross revenue, net orders, discounts, and payment methods for your accountant or tax auditor.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isQuickExporting ? null : () => _quickExportMonthEnd(ExportFormat.csv),
                        icon: const Icon(Icons.table_chart_rounded, size: 16),
                        label: const Text('Export CSV (Excel)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.teal.shade900,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isQuickExporting ? null : () => _quickExportMonthEnd(ExportFormat.pdf),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Export PDF (Print)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade900,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Domain Cards Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Available Record Domains (निर्यात श्रेणियां)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => ExportFilterModal.show(context, shopId: shopId, service: _service),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Custom Export'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Grid of 4 Domains
          _buildDomainTile(
            domain: ExportDomain.salesReport,
            title: 'Sales & Revenue Orders',
            subtitle: 'Gross revenue, payment modes, customer orders, and discounts',
            shopId: shopId,
          ),
          const SizedBox(height: 10),
          _buildDomainTile(
            domain: ExportDomain.inventoryCatalog,
            title: 'Inventory & Stock Catalog',
            subtitle: 'Product list, barcodes, unit prices, stock levels & total asset valuation',
            shopId: shopId,
          ),
          const SizedBox(height: 10),
          _buildDomainTile(
            domain: ExportDomain.khataStatements,
            title: 'Customer Khata Statements',
            subtitle: 'Outstanding credit balances, customer phone list, and limits',
            shopId: shopId,
          ),
          const SizedBox(height: 10),
          _buildDomainTile(
            domain: ExportDomain.auditLogs,
            title: 'Staff Activity & Audit Trail',
            subtitle: 'Immutable record of who changed what, stock adjustments, and timestamps',
            shopId: shopId,
          ),
        ],
      ),
    );
  }

  Widget _buildDomainTile({
    required ExportDomain domain,
    required String title,
    required String subtitle,
    required String shopId,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: domain.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(domain.icon, color: domain.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
            onPressed: () => ExportFilterModal.show(context, shopId: shopId, initialDomain: domain, service: _service),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: CLOUD BACKUPS & RESTORE TESTING
  // =========================================================================

  Widget _buildBackupsTab(BuildContext context, String shopId, List<BackupSnapshot> snapshots) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action Bar & Retention Notice
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Automated Cloud Backups (बैकअप स्नैपशॉट्स)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                    ),
                    Text(
                      '30-day auto retention policy with SHA-256 verification',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => CreateBackupModal.show(context, shopId: shopId, service: _service),
                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                label: const Text('Backup Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Snapshots List
          Expanded(
            child: snapshots.isEmpty
                ? _buildEmptyBackupsState(context, shopId)
                : ListView.separated(
                    itemCount: snapshots.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final backup = snapshots[index];
                      return _buildBackupCard(context, backup);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBackupsState(BuildContext context, String shopId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_done_rounded, size: 48, color: Colors.teal.shade700),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Cloud Backups Yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Create your first cloud snapshot to safely backup your store and test data recovery.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => CreateBackupModal.show(context, shopId: shopId, service: _service),
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: const Text('Create First Cloud Backup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard(BuildContext context, BackupSnapshot backup) {
    final testResult = backup.lastRestoreTestResult;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cloud_done_rounded, color: Colors.teal, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            backup.formattedDate,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${backup.totalRecords} Records • ${backup.formattedSize} • Retention: ${backup.retentionDays}d',
                            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  backup.status.label.split('(').first.trim(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Domains Breakdown & SHA-256
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'SHA-256: ${backup.shortChecksum}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (testResult != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: testResult.status.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(testResult.status.icon, size: 12, color: testResult.status.color),
                      const SizedBox(width: 4),
                      Text(
                        'Verified ${testResult.healthScorePercent.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: testResult.status.color),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Text(
                  'Not Tested',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => RestoreTestDialog.show(context, backup: backup, service: _service),
                icon: const Icon(Icons.health_and_safety_rounded, size: 15),
                label: Text(testResult != null ? 'View Integrity Report' : 'Run Restore Test'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Data Export & Backups'),
        content: const Text(
          '1. Export Reports:\nMonth-end sales, inventory, and khata records can be exported to CSV or PDF for accounting, tax filing, and audits.\n\n'
          '2. Cloud Backups & Retention:\nEncrypted snapshots of your entire store are stored in the cloud. Expired backups are automatically pruned per your retention policy.\n\n'
          '3. Restore Testing:\nPerforms simulated dry-run recovery in a sandbox to verify cryptographic checksums and catalog integrity without affecting active store records.',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
