import 'package:flutter/material.dart';
import '../app_theme.dart';
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

  Future<void> _executeRestoreTest() async {
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
          SnackBar(content: Text('Test execution failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleSafeRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('Confirm Safe Restore?'),
          ],
        ),
        content: const Text(
          'This will safely recover and sync products and customer records from this verified cloud snapshot. Are you sure you wish to proceed?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            child: const Text('Proceed with Recovery'),
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
            const SnackBar(
              content: Text('Data successfully restored and verified from snapshot!'),
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
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _result != null;

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
                        const Expanded(
                          child: Text(
                            'Restore Testing & Integrity\n(डेटा रिकवरी टेस्ट रिपोर्ट)',
                            style: TextStyle(
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
                                    'Snapshot: ${widget.backup.formattedDate}',
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
                            Row(
                              children: [
                                const Icon(Icons.fingerprint_rounded, size: 14, color: AppColors.textLight),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'SHA-256: ${widget.backup.shortChecksum}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'Retention: ${widget.backup.retentionDays} days',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // If no test has run yet
                      if (!hasResult && !_isRunningTest) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.published_with_changes_rounded, size: 40, color: Colors.purple),
                              const SizedBox(height: 10),
                              const Text(
                                'Run Dry-Run Restore Test',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purple),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Simulates disaster recovery in a safe sandbox without altering active store records. Validates archive integrity, database schema, and reference consistency.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.purple.shade900),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Test In Progress
                      if (_isRunningTest) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: Colors.deepPurple),
                                SizedBox(height: 16),
                                Text(
                                  'Executing Restore Test...\nVerifying SHA-256 Checksum and Schemas',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Test Results
                      if (hasResult && !_isRunningTest) ...[
                        // Health Score Banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _result!.status.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _result!.status.color),
                          ),
                          child: Row(
                            children: [
                              Icon(_result!.status.icon, color: _result!.status.color, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _result!.status.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _result!.status.color,
                                      ),
                                    ),
                                    Text(
                                      'Health Score: ${_result!.healthScorePercent.toStringAsFixed(0)}% • Duration: ${_result!.executionDurationMs}ms',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Verified Record Counts
                        const Text(
                          'Verified Domain Data Counts:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _result!.verifiedCounts.entries.map((e) {
                            return Chip(
                              backgroundColor: AppColors.surface,
                              side: BorderSide(color: Colors.grey.shade300),
                              label: Text(
                                '${e.key.toUpperCase()}: ${e.value}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Passed Verification Steps
                        const Text(
                          'Integrity Checks Passed:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
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
                      onPressed: _isRunningTest || _isRestoring ? null : _executeRestoreTest,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(hasResult ? 'Re-Run Test' : 'Run Restore Test'),
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
                        onPressed: _isRunningTest || _isRestoring ? null : _handleSafeRestore,
                        icon: _isRestoring
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.restore_page_rounded, size: 18),
                        label: Text(_isRestoring ? 'Restoring...' : 'Safe Restore'),
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
