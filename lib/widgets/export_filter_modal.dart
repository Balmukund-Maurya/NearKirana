import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../language_provider.dart';
import '../data_export_backup_models.dart';
import '../data_export_backup_service.dart';

/// Zepto/Blinkit styled modal dialog for configuring and generating custom business data exports.
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
    HapticFeedback.mediumImpact();
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
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('Export failed: $e', 'एक्सपोर्ट विफल हुआ: $e', 'Export failed: $e')),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleShare(String Function(String, String, String) t) async {
    if (_lastResult == null) return;
    HapticFeedback.lightImpact();
    final service = widget.service ?? DataExportBackupService();
    try {
      await service.shareExport(_lastResult!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('Share failed: $e', 'शेयर विफल हुआ: $e', 'Share failed: $e')),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
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

    final domainColor = _selectedDomain.color;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Zepto-style Header (No Truncation)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: domainColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_selectedDomain.icon, color: domainColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('Export Business Records', 'डेटा एक्सपोर्ट करें', 'Export Business Records'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t('Download Excel or PDF reports', 'एक्सेल या पीडीएफ रिपोर्ट डाउनलोड करें', 'Download Excel or PDF reports'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context, _lastResult),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Select Record Domain
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '1',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0C831F)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t('Select Record Category', 'डेटा श्रेणी चुनें', 'Select Category'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                              domainTitle = t('Audit Trail', 'ऑडिट गतिविधि', 'Audit Trail');
                              break;
                          }
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedDomain = d);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? d.color : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? d.color : const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    d.icon,
                                    size: 15,
                                    color: isSelected ? Colors.white : d.color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    domainTitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? Colors.white : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // 2. Choose Format
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '2',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0C831F)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t('Choose Export Format', 'फ़ाइल फॉर्मेट चुनें', 'Choose Format'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormatSelectorCard(
                              format: ExportFormat.csv,
                              title: t('CSV (Excel)', 'CSV (एक्सेल)', 'CSV (Excel)'),
                              subtitle: t('Spreadsheet format', 'स्प्रेडशीट डेटा', 'Spreadsheet'),
                              icon: Icons.table_chart_rounded,
                              isSelected: _selectedFormat == ExportFormat.csv,
                              color: const Color(0xFF0C831F),
                              onTap: () => setState(() => _selectedFormat = ExportFormat.csv),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFormatSelectorCard(
                              format: ExportFormat.pdf,
                              title: t('PDF Document', 'PDF (प्रिंट योग्य)', 'PDF Document'),
                              subtitle: t('Printable report', 'प्रिंट योग्य रिपोर्ट', 'Printable'),
                              icon: Icons.picture_as_pdf_rounded,
                              isSelected: _selectedFormat == ExportFormat.pdf,
                              color: const Color(0xFFDC2626),
                              onTap: () => setState(() => _selectedFormat = ExportFormat.pdf),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 3. Date Presets
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '3',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0C831F)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t('Select Date Range', 'समयावधि चुनें', 'Select Date Range'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
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
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _applyPreset(preset));
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0C831F) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF0C831F) : const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Selected Range Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF0C831F)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${DateFormat('dd MMM yyyy').format(_startDate)}  →  ${DateFormat('dd MMM yyyy').format(_endDate)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Result Summary Card
                      if (_lastResult != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${t('Generated', 'तैयार किया गया', 'Generated')}: ${_lastResult!.fileName}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF166534)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${t('Total Records', 'कुल रिकॉर्ड', 'Total Records')}: ${_lastResult!.recordCount}  •  ${t('Size', 'साइज़', 'Size')}: ${_lastResult!.formattedSize}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleShare(t),
                                  icon: const Icon(Icons.share_rounded, size: 16),
                                  label: Text(t('Share via WhatsApp / Email', 'व्हाट्सएप / ईमेल पर शेयर करें', 'Share via WhatsApp / Email')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
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

              // Action Buttons (Zepto Style Primary Action)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C831F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatSelectorCard({
    required ExportFormat format,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0C831F).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF0C831F) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0C831F).withValues(alpha: 0.15) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: isSelected ? const Color(0xFF0C831F) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: isSelected ? const Color(0xFF0C831F) : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                size: 16,
                color: isSelected ? const Color(0xFF0C831F) : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
