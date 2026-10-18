import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'shop_provider.dart';
import 'language_provider.dart';
import 'data_export_backup_models.dart';
import 'data_export_backup_service.dart';
import 'widgets/export_filter_modal.dart';
import 'widgets/restore_test_dialog.dart';
import 'widgets/create_backup_modal.dart';

/// Zepto/Blinkit merchant Data Export & Cloud Backup Hub
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

  Future<void> _quickExportMonthEnd(ExportFormat format, String Function(String, String, String) t) async {
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    if (shopId == null || shopId.isEmpty) return;

    HapticFeedback.mediumImpact();
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
          SnackBar(
            content: Text(t('Quick export failed: $e', 'एक्सपोर्ट विफल: $e', 'Quick export failed: $e')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
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

    final shopId = Provider.of<ShopProvider>(context).currentShopId ?? '';

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
              t('Data Export & Backup', 'डेटा व बैकअप', 'Data Export & Backup'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            Text(
              t('CA Reports & Cloud Recovery', 'अकाउंटेंट रिपोर्ट व रिकवरी', 'CA Reports & Cloud Recovery'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
            tooltip: t('About Backups', 'बैकअप जानकारी', 'About Backups'),
            onPressed: () => _showInfoDialog(context, t),
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
            Tab(
              icon: const Icon(Icons.file_download_outlined, size: 18),
              text: t('Export Reports', 'रिपोर्ट डाउनलोड', 'Export Reports'),
            ),
            Tab(
              icon: const Icon(Icons.cloud_sync_outlined, size: 18),
              text: t('Cloud Backups', 'क्लाउड बैकअप', 'Cloud Backups'),
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
              // KPI Header Cards (responsive 4-card grid)
              _buildKpiHeader(analytics, t),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExportTab(context, shopId, t),
                    _buildBackupsTab(context, shopId, snapshots, t),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiHeader(BackupAnalyticsSummary analytics, String Function(String, String, String) t) {
    final lastBackupText = analytics.lastBackupDate != null
        ? DateFormat('dd MMM, hh:mm a').format(analytics.lastBackupDate!)
        : t('No backups yet', 'कोई बैकअप नहीं', 'No backups yet');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _kpiCard(
              title: t('Last Backup', 'अंतिम बैकअप', 'Last Backup'),
              value: lastBackupText,
              icon: Icons.cloud_done_rounded,
              color: const Color(0xFF0C831F),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpiCard(
              title: t('Snapshots', 'कुल स्नैपशॉट', 'Snapshots'),
              value: '${analytics.totalBackups}',
              icon: Icons.layers_rounded,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpiCard(
              title: t('Health Score', 'स्वास्थ्य स्कोर', 'Health Score'),
              value: '${analytics.averageHealthScore.toStringAsFixed(0)}%',
              icon: Icons.health_and_safety_rounded,
              color: const Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpiCard(
              title: t('Retention', 'अवधि', 'Retention'),
              value: '${analytics.activeRetentionDays}d',
              icon: Icons.schedule_rounded,
              color: const Color(0xFFEA580C),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
                  style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildExportTab(BuildContext context, String shopId, String Function(String, String, String) t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Month-End Special Hero Card for Accountant / CA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: const Color(0xFF065F46).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
              ],
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
                          const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t('Month-End Sales Report', 'मंथ-एंड सेल्स रिपोर्ट', 'Month-End Sales Report'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        t('For CA / Audit', 'CA / ऑडिट के लिए', 'Accountant Special'),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'Instantly export verified sales records with revenue, net orders, discounts, and payment methods for tax filing.',
                    'टैक्स फाइलिंग और सीए के लिए बिक्री, छूट व पेमेंट मोड का सत्यापित डेटा तुरंत डाउनलोड करें।',
                    'Verified sales records with revenue, discounts and payment methods for accounting.',
                  ),
                  style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isQuickExporting ? null : () => _quickExportMonthEnd(ExportFormat.csv, t),
                        icon: const Icon(Icons.table_chart_rounded, size: 16),
                        label: const Text('Export CSV (Excel)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF065F46),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isQuickExporting ? null : () => _quickExportMonthEnd(ExportFormat.pdf, t),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Export PDF (Print)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Domain Cards Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t('Available Record Categories', 'उपलब्ध रिपोर्ट श्रेणियां', 'Export Categories'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              TextButton.icon(
                onPressed: () => ExportFilterModal.show(context, shopId: shopId, service: _service),
                icon: const Icon(Icons.tune_rounded, size: 15, color: Color(0xFF0C831F)),
                label: Text(
                  t('Custom Range', 'कस्टम तारीख', 'Custom Range'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0C831F)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4 Domain Tiles
          _buildDomainTile(
            domain: ExportDomain.salesReport,
            title: t('Sales & Revenue Orders', 'बिक्री व ऑर्डर विवरण', 'Sales & Revenue Orders'),
            subtitle: t('Gross revenue, payment modes, customer orders, and discounts', 'दैनिक कमाई, ऑर्डर्स और डिस्काउंट लिस्ट', 'Gross revenue, orders and payment modes'),
            shopId: shopId,
          ),
          const SizedBox(height: 10),
          _buildDomainTile(
            domain: ExportDomain.inventoryCatalog,
            title: t('Inventory & Stock Catalog', 'स्टॉक व सामान सूची', 'Inventory & Stock Catalog'),
            subtitle: t('Product list, barcodes, unit prices, and valuation', 'सभी प्रॉडक्ट्स, बारकोड और स्टॉक वैल्यू', 'Product catalog, barcodes and valuation'),
            shopId: shopId,
          ),
          const SizedBox(height: 10),
          _buildDomainTile(
            domain: ExportDomain.khataStatements,
            title: t('Customer Khata Statements', 'ग्राहक खाता बही रिकॉर्ड', 'Customer Khata Statements'),
            subtitle: t('Outstanding balances, customer phone list, and limits', 'बाकी उधार, ग्राहक नंबर और लिमिट लिस्ट', 'Udhaar balance, phone numbers and limits'),
            shopId: shopId,
          ),
          const SizedBox(height: 10),
          _buildDomainTile(
            domain: ExportDomain.auditLogs,
            title: t('Staff Activity & Audit Trail', 'स्टाफ कार्य व ऑडिट लॉग', 'Staff Activity & Audit Trail'),
            subtitle: t('Immutable log of stock adjustments and changes', 'स्टॉक बदलाव और कर्मचारी एक्टिविटी', 'History of edits and adjustments'),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: domain.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(domain.icon, color: domain.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            onPressed: () => ExportFilterModal.show(context, shopId: shopId, initialDomain: domain, service: _service),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupsTab(BuildContext context, String shopId, List<BackupSnapshot> snapshots, String Function(String, String, String) t) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Automated Cloud Backups', 'स्वचालित क्लाउड बैकअप', 'Automated Cloud Backups'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      t('30-day auto retention with SHA-256 verification', '30 दिन की पॉलिसी और सुरक्षित सत्यापन', '30-day retention with SHA-256'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => CreateBackupModal.show(context, shopId: shopId, service: _service),
                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                label: Text(t('Backup Now', 'बैकअप लें', 'Backup Now')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C831F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: snapshots.isEmpty
                ? _buildEmptyBackupsState(context, shopId, t)
                : ListView.separated(
                    itemCount: snapshots.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final backup = snapshots[index];
                      return _buildBackupCard(context, backup, t);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBackupsState(BuildContext context, String shopId, String Function(String, String, String) t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0C831F).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_done_rounded, size: 44, color: Color(0xFF0C831F)),
          ),
          const SizedBox(height: 14),
          Text(
            t('No Cloud Backups Yet', 'अभी तक कोई बैकअप नहीं है', 'No Cloud Backups Yet'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            t(
              'Create your first cloud snapshot to safely backup your store records.',
              'अपनी दुकान का पहला क्लाउड बैकअप बनाएं ताकि डेटा सुरक्षित रहे।',
              'Create your first cloud snapshot for disaster recovery.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => CreateBackupModal.show(context, shopId: shopId, service: _service),
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(t('Create First Cloud Backup', 'पहला बैकअप बनाएं', 'Create Cloud Backup')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C831F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard(BuildContext context, BackupSnapshot backup, String Function(String, String, String) t) {
    final testResult = backup.lastRestoreTestResult;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
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
                        color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF0C831F), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            backup.formattedDate,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${backup.totalRecords} Records • ${backup.formattedSize} • ${backup.retentionDays}d',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  backup.status.label.split('(').first.trim(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Domains Breakdown & SHA-256
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'SHA-256: ${backup.shortChecksum}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
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
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: testResult.status.color),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  t('Not Tested', 'सत्यापित नहीं', 'Not Tested'),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                tooltip: t('Delete Snapshot', 'स्नैपशॉट हटाएं', 'Delete Snapshot'),
                onPressed: () => _confirmDeleteBackup(context, backup, t),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: () => RestoreTestDialog.show(context, backup: backup, service: _service),
                icon: const Icon(Icons.health_and_safety_rounded, size: 15, color: Color(0xFF0C831F)),
                label: Text(
                  testResult != null
                      ? t('View Integrity Report', 'जांच रिपोर्ट देखें', 'View Integrity Report')
                      : t('Run Restore Test', 'रिस्टोर टेस्ट चलाएं', 'Run Restore Test'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0C831F)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF86EFAC)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteBackup(BuildContext context, BackupSnapshot backup, String Function(String, String, String) t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Delete Backup?', 'बैकअप हटाएं?', 'Delete Backup?')),
        content: Text(t(
          'Are you sure you want to delete backup snapshot from ${backup.formattedDate}?',
          'क्या आप वाकई ${backup.formattedDate} का बैकअप स्नैपशॉट हटाना चाहते हैं?',
          'Are you sure you want to delete backup snapshot from ${backup.formattedDate}?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Cancel', 'रद्द करें', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Delete', 'हटाएं', 'Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.firestore.collection('backups').doc(backup.id).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('Backup deleted', 'बैकअप हटा दिया गया', 'Backup deleted')),
              backgroundColor: const Color(0xFF0C831F),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('Failed to delete backup: $e', 'बैकअप हटाने में विफल: $e', 'Failed to delete backup: $e')),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  void _showInfoDialog(BuildContext context, String Function(String, String, String) t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          t('About Data Export & Backups', 'डेटा एक्सपोर्ट व बैकअप', 'About Data Export & Backups'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          t(
            '1. Export Reports:\nMonth-end sales, inventory, and khata records can be exported to CSV or PDF for accounting, tax filing, and audits.\n\n'
            '2. Cloud Backups & Retention:\nEncrypted snapshots of your entire store are stored in the cloud. Expired backups are automatically pruned per your retention policy.\n\n'
            '3. Restore Testing:\nPerforms simulated dry-run recovery in a sandbox to verify cryptographic checksums and catalog integrity without affecting active store records.',
            '1. रिपोर्ट डाउनलोड:\nमहीने के अंत में बिक्री, स्टॉक और खाता बही का डेटा एक्सेल (CSV) या PDF में डाउनलोड करें।\n\n'
            '2. सुरक्षित क्लाउड बैकअप:\nआपकी पूरी दुकान का डेटा एन्क्रिप्टेड स्नैपशॉट के रूप में क्लाउड पर सुरक्षित रहता है।\n\n'
            '3. रिस्टोर टेस्ट:\nबैकअप फाइल को बिना दुकान को प्रभावित किए टेस्ट करें कि डेटा सही से सुरक्षित है या नहीं।',
            '1. Reports Export:\nMonthly sales, inventory & khata records can be shared via CSV/PDF for taxes.\n\n'
            '2. Cloud Snapshots:\nEncrypted snapshots backup all store databases safely.\n\n'
            '3. Restore Testing:\nSandbox simulation to verify store data integrity.',
          ),
          style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('Got it', 'समझ गया', 'Got it'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
