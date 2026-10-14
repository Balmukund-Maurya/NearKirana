import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
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

  Future<void> _handleExport() async {
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
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleShare() async {
    if (_lastResult == null) return;
    final service = widget.service ?? DataExportBackupService();
    try {
      await service.shareExport(_lastResult!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        const Expanded(
                          child: Text(
                            'Export Business Records\n(डेटा निर्यात करें)',
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
                      const Text(
                        '1. Select Record Domain (डेटा श्रेणी) *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ExportDomain.values.map((d) {
                          final isSelected = _selectedDomain == d;
                          return ChoiceChip(
                            avatar: Icon(d.icon, size: 16, color: isSelected ? Colors.white : d.color),
                            label: Text(
                              d.label.split('(').first.trim(),
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
                      const Text(
                        '2. Choose Export Format (फ़ाइल फॉर्मेट) *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                                          f == ExportFormat.csv ? 'CSV (Excel/Tally)' : 'PDF (Printable)',
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
                      const Text(
                        '3. Date Range (अवधि / टाइमफ़्रेम) *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                          return ChoiceChip(
                            label: Text(
                              preset == DateRangePreset.thisMonth ? 'Month-End (CA Special)' : preset.label.split('(').first.trim(),
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
                                      'Generated ${_lastResult!.fileName}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Total Records: ${_lastResult!.recordCount} | Size: ${_lastResult!.formattedSize}',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: _handleShare,
                                icon: const Icon(Icons.share_rounded, size: 16),
                                label: const Text('Share File (WhatsApp, Email, Drive)'),
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
                onPressed: _isExporting ? null : _handleExport,
                icon: _isExporting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  _isExporting ? 'Generating Report...' : 'Generate ${_selectedFormat.name.toUpperCase()} Export',
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
