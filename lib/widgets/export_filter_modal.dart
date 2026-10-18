import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../language_provider.dart';
import '../data_export_backup_models.dart';
import '../data_export_backup_service.dart';

/// Modal dialog for configuring and generating custom business data exports.
class ExportFilterModal extends StatefulWidget {
  final String shopId;
  final ExportDomain initialDomain;
  final DataExportBackupService? service;

  const ExportFilterModal({
    super.key,
    required this.shopId,
    this.initialDomain = ExportDomain.salesReport,
    this.service,
  });

  static Future<ExportResult?> show(
    BuildContext context, {
    required String shopId,
    ExportDomain initialDomain = ExportDomain.salesReport,
    DataExportBackupService? service,
  }) {
    return showDialog<ExportResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExportFilterModal(
        shopId: shopId,
        initialDomain: initialDomain,
        service: service,
      ),
    );
  }

  @override
  State<ExportFilterModal> createState() => _ExportFilterModalState();
}

class _ExportFilterModalState extends State<ExportFilterModal> {
  late ExportDomain _selectedDomain;
  ExportFormat _selectedFormat = ExportFormat.csv;
  DateRangePreset _selectedPreset = DateRangePreset.thisMonth;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isExporting = false;
  ExportResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _selectedDomain = widget.initialDomain;
    _applyPreset(_selectedPreset);
  }

  void _applyPreset(DateRangePreset preset) {
    _selectedPreset = preset;
    final range = preset.getDateRange();
    _startDate = range.start;
    _endDate = range.end;
  }

  Future<void> _handleExport(String Function(String, String, String) t) async {
    setState(() {
      _isExporting = true;
      _lastResult = null;
    });

    try {
      final service = widget.service ?? DataExportBackupService();
      final filter = ExportFilter(
        shopId: widget.shopId,
        domain: _selectedDomain,
        format: _selectedFormat,
        startDate: _startDate,
        endDate: _endDate,
        preset: _selectedPreset,
      );

      final result = await service.generateExport(filter);
      if (mounted) {
        setState(() {
          _isExporting = false;
          _lastResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('Export failed: $e', 'एक्सपोर्ट विफल: $e', 'Export failed: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleShare(String Function(String, String, String) t) async {
    if (_lastResult == null) return;
    final service = widget.service ?? DataExportBackupService();
    try {
      await service.shareExport(_lastResult!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('Share failed: $e', 'शेयर विफल: $e', 'Share failed: $e')),
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
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
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
                            color: _selectedDomain.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_selectedDomain.icon, color: _selectedDomain.color, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t('Export Business Records', 'डेटा निर्यात करें', 'Export Business Records'),
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
                    onPressed: () => Navigator.pop(context, _lastResult),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Domain Selection
                      Text(
                        t('1. Select Record Domain *', '1. डेटा श्रेणी चुनें *', '1. Select Category *'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ExportDomain.values.map((d) {
                          final isSelected = _selectedDomain == d;
                          String domainTitle;
                          switch (d) {
                            case ExportDomain.salesReport:
                              domainTitle = t('Sales Report', 'बिक्री रिपोर्ट', 'Sales Report');
                              break;
                            case ExportDomain.inventoryCatalog:
                              domainTitle = t('Inventory Catalog', 'स्टॉक सूची', 'Inventory Catalog');
                              break;
                            case ExportDomain.khataStatements:
                              domainTitle = t('Khata Ledger', 'खाता बही', 'Khata Ledger');
                              break;
                            case ExportDomain.auditLogs:
                              domainTitle = t('Audit Trail', 'ऑडिट लॉग्स', 'Audit Trail');
                              break;
                          }
                          return ChoiceChip(
                            avatar: Icon(d.icon, size: 16, color: isSelected ? Colors.white : d.color),
                            label: Text(
                              domainTitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : AppColors.textDark,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: d.color,
                            backgroundColor: AppColors.surface,
                            onSelected: (val) {
                              if (val) setState(() => _selectedDomain = d);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Format Selection
                      Text(
                        t('2. Choose Export Format *', '2. फ़ाइल फॉर्मेट चुनें *', '2. Export Format *'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ExportFormat.values.where((f) => f != ExportFormat.json).map((f) {
                          final isSelected = _selectedFormat == f;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => setState(() => _selectedFormat = f),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.15) : AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primaryDark : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(f.icon, size: 18, color: isSelected ? AppColors.primaryDark : AppColors.textLight),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          f == ExportFormat.csv
                                              ? t('CSV (Excel)', 'CSV (एक्सेल)', 'CSV (Excel)')
                                              : t('PDF (Printable)', 'PDF (प्रिंट योग्य)', 'PDF (Printable)'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? AppColors.primaryDark : AppColors.textDark,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Date Presets
                      Text(
                        t('3. Date Range *', '3. समयावधि चुनें *', '3. Date Range *'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          DateRangePreset.thisMonth,
                          DateRangePreset.lastMonth,
                          DateRangePreset.thisWeek,
                          DateRangePreset.today,
                          DateRangePreset.allTime,
                        ].map((preset) {
                          final isSelected = _selectedPreset == preset;
                          String label;
                          switch (preset) {
                            case DateRangePreset.thisMonth:
                              label = t('This Month (CA Special)', 'इस महीने (CA स्पेशल)', 'This Month');
                              break;
                            case DateRangePreset.lastMonth:
                              label = t('Last Month', 'पिछला महीना', 'Last Month');
                              break;
                            case DateRangePreset.thisWeek:
                              label = t('This Week', 'इस हफ्ते', 'This Week');
                              break;
                            case DateRangePreset.today:
                              label = t('Today', 'आज', 'Today');
                              break;
                            case DateRangePreset.allTime:
                              label = t('All Time', 'शुरुआत से अब तक', 'All Time');
                              break;
                            default:
                              label = preset.name;
                          }
                          return ChoiceChip(
                            label: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : AppColors.textDark,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primaryDark,
                            backgroundColor: AppColors.surface,
                            onSelected: (val) {
                              if (val) setState(() => _applyPreset(preset));
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Selected Range Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryDark),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Result Summary Card
                      if (_lastResult != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${t('Generated', 'तैयार किया', 'Generated')} ${_lastResult!.fileName}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${t('Total Records', 'कुल रिकॉर्ड', 'Total Records')}: ${_lastResult!.recordCount} | ${t('Size', 'साइज़', 'Size')}: ${_lastResult!.formattedSize}',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () => _handleShare(t),
                                icon: const Icon(Icons.share_rounded, size: 16),
                                label: Text(t('Share File (WhatsApp, Email)', 'फ़ाइल शेयर करें (व्हाट्सएप/ईमेल)', 'Share File')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons
              ElevatedButton.icon(
                onPressed: _isExporting ? null : () => _handleExport(t),
                icon: _isExporting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  _isExporting
                      ? t('Generating Report...', 'रिपोर्ट तैयार हो रही है...', 'Generating Report...')
                      : '${t('Generate', 'डाउनलोड करें', 'Generate')} ${_selectedFormat.name.toUpperCase()}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedDomain.color,
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
}
