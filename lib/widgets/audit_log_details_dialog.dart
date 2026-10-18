import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../language_provider.dart';
import '../staff_audit_models.dart';

/// Modal dialog showing comprehensive audit log details with visual diff comparison.
class AuditLogDetailsDialog extends StatelessWidget {
  final AuditLogEntry log;

  const AuditLogDetailsDialog({super.key, required this.log});

  static void show(BuildContext context, AuditLogEntry log) {
    showDialog(
      context: context,
      builder: (_) => AuditLogDetailsDialog(log: log),
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

    final dateFormat = DateFormat('dd MMMM yyyy, hh:mm:ss a');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
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
                            color: log.actionType.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(log.actionType.icon, color: log.actionType.color, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            log.actionType.localizedLabel(t),
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

              // Scrollable Details
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Actor Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryDark.withValues(alpha: 0.1),
                              child: const Icon(Icons.person_rounded, color: AppColors.primaryDark),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.actorName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${t('Role', 'पद', 'Role')}: ${log.actorRole.toUpperCase()}${log.actorPhone != null ? ' • +91 ${log.actorPhone}' : ''}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Description
                      Text(
                        t('Action Summary', 'गतिविधि का विवरण', 'Action Summary'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log.description,
                        style: const TextStyle(fontSize: 14, color: AppColors.textDark, height: 1.3),
                      ),
                      const SizedBox(height: 14),

                      // Entity & Target Info
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoTile(
                              t('Target Item', 'संबंधित सामान / खाता', 'Target Item'),
                              log.entityName.isNotEmpty ? log.entityName : log.entityId,
                              Icons.category_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInfoTile(
                              t('Entity Type', 'प्रकार', 'Entity Type'),
                              log.entityType.toUpperCase(),
                              Icons.view_in_ar_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Timestamp & Reason
                      _buildInfoTile(
                        t('Exact Timestamp', 'समय व दिनांक', 'Exact Timestamp'),
                        dateFormat.format(log.timestamp),
                        Icons.access_time_rounded,
                      ),
                      if (log.reason != null && log.reason!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildInfoTile(
                          t('Reported Reason', 'दर्ज कारण', 'Reported Reason'),
                          log.reason!,
                          Icons.help_outline_rounded,
                          highlight: true,
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Before vs After Diff Comparison
                      if (log.oldValue != null || log.newValue != null) ...[
                        Text(
                          t('Before & After Changes', 'बदलाव का तुलनात्मक विवरण', 'Before & After Changes'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Before
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.remove_circle_outline, color: Colors.red.shade700, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          t('OLD VALUE', 'पुराना मान', 'OLD VALUE'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      log.oldValue != null
                                          ? log.oldValue!.entries.map((e) => '${e.key}: ${e.value}').join('\n')
                                          : 'N/A',
                                      style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // After
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          t('NEW VALUE', 'नया मान', 'NEW VALUE'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      log.newValue != null
                                          ? log.newValue!.entries.map((e) => '${e.key}: ${e.value}').join('\n')
                                          : 'N/A',
                                      style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Close Action Button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(t('Close', 'बंद करें', 'Close'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? Colors.amber.shade50 : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? Colors.amber.shade200 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: highlight ? Colors.amber.shade900 : Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: highlight ? Colors.amber.shade900 : AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
