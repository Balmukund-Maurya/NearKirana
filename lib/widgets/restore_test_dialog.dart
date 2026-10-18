import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../language_provider.dart';
import '../data_export_backup_models.dart';
import '../data_export_backup_service.dart';

/// Modal dialog for running automated Restore Testing, verifying backup integrity,
/// viewing verification health score, and safely executing disaster recovery.
class RestoreTestDialog extends StatefulWidget {
  final BackupSnapshot backup;
  final DataExportBackupService? service;
  final String actorName;

  const RestoreTestDialog({
    super.key,
    required this.backup,
    this.service,
    this.actorName = 'Shop Owner',
  });

  static Future<void> show(
    BuildContext context, {
    required BackupSnapshot backup,
    DataExportBackupService? service,
    String actorName = 'Shop Owner',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RestoreTestDialog(
        backup: backup,
        service: service,
        actorName: actorName,
      ),
    );
  }

  @override
  State<RestoreTestDialog> createState() => _RestoreTestDialogState();
}

class _RestoreTestDialogState extends State<RestoreTestDialog> {
  bool _isRunningTest = false;
  bool _isRestoring = false;
  RestoreTestResult? _result;

  @override
  void initState() {
    super.initState();
    _result = widget.backup.lastRestoreTestResult;
  }

  Future<void> _executeRestoreTest(String Function(String, String, String) t) async {
    setState(() => _isRunningTest = true);
    try {
      final service = widget.service ?? DataExportBackupService();
      final res = await service.runRestoreTest(
        backup: widget.backup,
        testedBy: widget.actorName,
      );
      if (mounted) {
        setState(() {
          _isRunningTest = false;
          _result = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRunningTest = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('Test execution failed: $e', 'टेस्ट विफल हुआ: $e', 'Test execution failed: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSafeRestore(String Function(String, String, String) t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Text(t('Confirm Safe Restore?', 'सुरक्षित रिस्टोर की पुष्टि करें?', 'Confirm Safe Restore?')),
          ],
        ),
        content: Text(
          t(
            'This will safely recover and sync products and customer records from this verified cloud snapshot. Are you sure you wish to proceed?',
            'यह इस क्लाउड स्नैपशॉट से उत्पादों और ग्राहकों के खातों को सुरक्षित रूप से पुनर्प्राप्त करेगा। क्या आप जारी रखना चाहते हैं?',
            'This will safely recover products and customer records from this verified cloud snapshot. Proceed?',
          ),
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Cancel', 'रद्द करें', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            child: Text(t('Proceed with Recovery', 'रिकवरी शुरू करें', 'Proceed with Recovery')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRestoring = true);
    try {
      final service = widget.service ?? DataExportBackupService();
      final success = await service.executeSafeRestore(
        backup: widget.backup,
        ownerPin: '0000',
        executedBy: widget.actorName,
      );
      if (mounted) {
        setState(() => _isRestoring = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('Data successfully restored and verified from snapshot!', 'स्नैपशॉट से डेटा सफलतापूर्वक रिस्टोर हो गया!', 'Data successfully restored from snapshot!')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('Restore failed: $e', 'रिस्टोर विफल: $e', 'Restore failed: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _result != null;
    final lang = Provider.of<LanguageProvider>(context);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
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
                            color: Colors.deepPurple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.health_and_safety_rounded, color: Colors.deepPurple, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t('Restore Testing & Integrity', 'डेटा रिकवरी टेस्ट रिपोर्ट', 'Restore Testing & Integrity'),
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Snapshot Meta Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${t('Snapshot', 'स्नैपशॉट', 'Snapshot')}: ${widget.backup.formattedDate}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.backup.formattedSize,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SHA-256: ${widget.backup.checksumSha256}',
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textLight),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Verification Steps & Status
                      if (!hasResult) ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Icon(Icons.verified_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                Text(
                                  t('No dry-run test performed yet.', 'अभी तक कोई टेस्ट नहीं चलाया गया।', 'No test performed yet.'),
                                  style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t(
                                    'Run an automated restore simulation to verify cryptographic integrity.',
                                    'क्रिप्टोग्राफिक सुरक्षा और डेटा अखंडता जांचने के लिए टेस्ट चलाएं।',
                                    'Run restore simulation to verify data integrity.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textLight, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Health Score Badge
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _result!.status.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _result!.status.color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(_result!.status.icon, color: _result!.status.color, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${t('Health Score', 'स्वास्थ्य स्कोर', 'Health Score')}: ${_result!.healthScorePercent.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _result!.status.color,
                                      ),
                                    ),
                                    Text(
                                      '${_result!.status.label} • ${_result!.executionDurationMs}ms execution',
                                      style: TextStyle(fontSize: 11, color: _result!.status.color),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          t('Integrity Verification Steps', 'सत्यापन के चरण', 'Verification Steps'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),

                        ..._result!.stepsPassed.map((step) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      step,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                                    ),
                                  ),
                                ],
                              ),
                            )),

                        // Warnings / Errors if any
                        if (_result!.warnings.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ..._result!.warnings.map((w) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(w, style: const TextStyle(fontSize: 12, color: Colors.amber)),
                                    ),
                                  ],
                                ),
                              )),
                        ],

                        if (_result!.errors.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ..._result!.errors.map((err) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.cancel_outlined, color: Colors.red, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(err, style: const TextStyle(fontSize: 12, color: Colors.red)),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isRunningTest || _isRestoring ? null : () => _executeRestoreTest(t),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        hasResult
                            ? t('Re-Run Test', 'पुनः टेस्ट करें', 'Re-Run Test')
                            : t('Run Restore Test', 'रिस्टोर टेस्ट चलाएं', 'Run Restore Test'),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (hasResult && _result!.status != RestoreTestStatus.failed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRunningTest || _isRestoring ? null : () => _handleSafeRestore(t),
                        icon: _isRestoring
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.restore_page_rounded, size: 18),
                        label: Text(
                          _isRestoring
                              ? t('Restoring...', 'रिस्टोर हो रहा है...', 'Restoring...')
                              : t('Safe Restore', 'सुरक्षित रिस्टोर', 'Safe Restore'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
