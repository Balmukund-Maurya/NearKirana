import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../language_provider.dart';
import '../data_export_backup_models.dart';
import '../data_export_backup_service.dart';

/// Modal dialog for creating an on-demand Cloud Backup Snapshot with retention policy selection.
class CreateBackupModal extends StatefulWidget {
  final String shopId;
  final DataExportBackupService? service;
  final String createdBy;

  const CreateBackupModal({
    super.key,
    required this.shopId,
    this.service,
    this.createdBy = 'Shop Owner',
  });

  static Future<BackupSnapshot?> show(
    BuildContext context, {
    required String shopId,
    DataExportBackupService? service,
    String createdBy = 'Shop Owner',
  }) {
    return showDialog<BackupSnapshot>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateBackupModal(
        shopId: shopId,
        service: service,
        createdBy: createdBy,
      ),
    );
  }

  @override
  State<CreateBackupModal> createState() => _CreateBackupModalState();
}

class _CreateBackupModalState extends State<CreateBackupModal> {
  int _selectedRetentionDays = 30;
  bool _isCreating = false;

  Future<void> _handleCreate(String Function(String, String, String) t) async {
    setState(() => _isCreating = true);
    try {
      final service = widget.service ?? DataExportBackupService();
      final snapshot = await service.createBackupSnapshot(
        shopId: widget.shopId,
        createdBy: widget.createdBy,
        retentionDays: _selectedRetentionDays,
      );

      if (mounted) {
        setState(() => _isCreating = false);
        Navigator.pop(context, snapshot);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('Failed to create backup: $e', 'बैकअप बनाने में विफल: $e', 'Failed to create backup: $e')),
            backgroundColor: Colors.red,
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.cloud_upload_rounded, color: Colors.teal, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t('Create Cloud Backup', 'क्लाउड बैकअप लें', 'Create Cloud Backup'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textLight),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Description
                      Text(
                        t(
                          'This creates a full encrypted snapshot of your store catalog, customer ledger, orders, and audit trail with cryptographic SHA-256 verification.',
                          'यह आपकी दुकान के सभी प्रॉडक्ट्स, ग्राहकों के खाते, ऑर्डर्स और ऑडिट का सुरक्षित स्नैपशॉट बनाता है।',
                          'This creates a verified cloud snapshot of catalog, customer ledger, orders, and audit trail.',
                        ),
                        style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                      ),
                      const SizedBox(height: 16),

                      // Retention Policy Selector
                      Text(
                        t('Select Retention Lifespan *', 'बैकअप की सुरक्षित अवधि चुनें *', 'Select Retention Lifespan *'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _retentionCard(7, t('7 Days', '7 दिन', '7 Days'), t('Weekly Cycle', 'साप्ताहिक चक्र', 'Weekly Cycle')),
                          const SizedBox(width: 8),
                          _retentionCard(30, t('30 Days', '30 दिन', '30 Days'), t('Recommended', 'अनुशंसित (1 महीना)', 'Recommended')),
                          const SizedBox(width: 8),
                          _retentionCard(90, t('90 Days', '90 दिन', '90 Days'), t('Quarterly Audit', 'तिमाही ऑडिट', 'Quarterly Audit')),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Domains Included
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _IncludedRow(Icons.inventory_2_rounded, t('Products & Stock Inventory', 'उत्पाद व स्टॉक सूची', 'Products & Inventory')),
                            const SizedBox(height: 6),
                            _IncludedRow(Icons.menu_book_rounded, t('Customers & Khata Balances', 'ग्राहक व उधारी बहीखाता', 'Customers & Khata Ledger')),
                            const SizedBox(height: 6),
                            _IncludedRow(Icons.shopping_bag_rounded, t('Order History & Statuses', 'ऑर्डर इतिहास व विवरण', 'Order History & Status')),
                            const SizedBox(height: 6),
                            _IncludedRow(Icons.verified_user_rounded, t('Immutable Audit Logs', 'सुरक्षित ऑडिट लॉग्स', 'Immutable Audit Logs')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isCreating ? null : () => _handleCreate(t),
                icon: _isCreating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_done_rounded, size: 18),
                label: Text(
                  _isCreating
                      ? t('Creating Snapshot...', 'स्नैपशॉट बन रहा है...', 'Creating Snapshot...')
                      : t('Create Snapshot Now', 'अभी बैकअप लें', 'Create Snapshot Now'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _retentionCard(int days, String title, String subtitle) {
    final isSelected = _selectedRetentionDays == days;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedRetentionDays = days),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal.shade50 : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? Colors.teal.shade900 : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.teal.shade800 : AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncludedRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IncludedRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.teal.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: AppColors.textDark),
          ),
        ),
        const Icon(Icons.check_rounded, size: 14, color: Colors.green),
      ],
    );
  }
}
