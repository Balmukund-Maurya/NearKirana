import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Domains of business records that can be exported.
enum ExportDomain {
  salesReport,
  inventoryCatalog,
  khataStatements,
  auditLogs;

  String get label {
    switch (this) {
      case ExportDomain.salesReport:
        return 'Sales Report (बिक्री रिपोर्ट - Accountant)';
      case ExportDomain.inventoryCatalog:
        return 'Inventory Catalog (स्टॉक व मूल्य सूची)';
      case ExportDomain.khataStatements:
        return 'Khata Statements (उधार / जमा विवरण)';
      case ExportDomain.auditLogs:
        return 'Audit Trail (ऑडिट व गतिविधि लॉग्स)';
    }
  }

  String get defaultBaseName {
    switch (this) {
      case ExportDomain.salesReport:
        return 'Sales_Report';
      case ExportDomain.inventoryCatalog:
        return 'Inventory_Catalog';
      case ExportDomain.khataStatements:
        return 'Khata_Statements';
      case ExportDomain.auditLogs:
        return 'Audit_Trail';
    }
  }

  IconData get icon {
    switch (this) {
      case ExportDomain.salesReport:
        return Icons.bar_chart_rounded;
      case ExportDomain.inventoryCatalog:
        return Icons.inventory_2_rounded;
      case ExportDomain.khataStatements:
        return Icons.menu_book_rounded;
      case ExportDomain.auditLogs:
        return Icons.verified_user_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ExportDomain.salesReport:
        return Colors.teal;
      case ExportDomain.inventoryCatalog:
        return Colors.indigo;
      case ExportDomain.khataStatements:
        return Colors.deepOrange;
      case ExportDomain.auditLogs:
        return Colors.purple;
    }
  }
}

/// Supported export file formats.
enum ExportFormat {
  csv,
  pdf,
  json;

  String get label {
    switch (this) {
      case ExportFormat.csv:
        return 'CSV Spreadsheet (.csv - Excel, Tally)';
      case ExportFormat.pdf:
        return 'PDF Document (.pdf - Printable)';
      case ExportFormat.json:
        return 'JSON Data (.json - Cloud Archive)';
    }
  }

  String get extension {
    switch (this) {
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.pdf:
        return 'pdf';
      case ExportFormat.json:
        return 'json';
    }
  }

  String get mimeType {
    switch (this) {
      case ExportFormat.csv:
        return 'text/csv';
      case ExportFormat.pdf:
        return 'application/pdf';
      case ExportFormat.json:
        return 'application/json';
    }
  }

  IconData get icon {
    switch (this) {
      case ExportFormat.csv:
        return Icons.table_view_rounded;
      case ExportFormat.pdf:
        return Icons.picture_as_pdf_rounded;
      case ExportFormat.json:
        return Icons.data_object_rounded;
    }
  }
}

/// Quick date presets for financial and reporting workflows.
enum DateRangePreset {
  thisMonth,
  lastMonth,
  thisWeek,
  today,
  allTime,
  custom;

  String get label {
    switch (this) {
      case DateRangePreset.thisMonth:
        return 'This Month (महीने का अंत - Month End)';
      case DateRangePreset.lastMonth:
        return 'Last Month (पिछला महीना)';
      case DateRangePreset.thisWeek:
        return 'This Week (इस सप्ताह)';
      case DateRangePreset.today:
        return 'Today (आज)';
      case DateRangePreset.allTime:
        return 'All Time (सभी रिकॉर्ड्स)';
      case DateRangePreset.custom:
        return 'Custom Range (कस्टम अवधि)';
    }
  }

  /// Calculates the concrete DateTimeRange for this preset.
  DateTimeRange getDateRange({DateTime? now}) {
    final current = now ?? DateTime.now();
    switch (this) {
      case DateRangePreset.today:
        final start = DateTime(current.year, current.month, current.day);
        final end = DateTime(current.year, current.month, current.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case DateRangePreset.thisWeek:
        final start = current.subtract(Duration(days: current.weekday - 1));
        final weekStart = DateTime(start.year, start.month, start.day);
        final end = DateTime(current.year, current.month, current.day, 23, 59, 59);
        return DateTimeRange(start: weekStart, end: end);
      case DateRangePreset.thisMonth:
        final start = DateTime(current.year, current.month, 1);
        final end = DateTime(current.year, current.month, current.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case DateRangePreset.lastMonth:
        final firstDayOfThisMonth = DateTime(current.year, current.month, 1);
        final lastDayOfPrevMonth = firstDayOfThisMonth.subtract(const Duration(days: 1));
        final start = DateTime(lastDayOfPrevMonth.year, lastDayOfPrevMonth.month, 1);
        final end = DateTime(lastDayOfPrevMonth.year, lastDayOfPrevMonth.month, lastDayOfPrevMonth.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case DateRangePreset.allTime:
      case DateRangePreset.custom:
        final start = DateTime(2020, 1, 1);
        final end = DateTime(current.year, current.month, current.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
    }
  }
}

/// Filter criteria for generating business exports.
class ExportFilter {
  final String shopId;
  final ExportDomain domain;
  final ExportFormat format;
  final DateTime startDate;
  final DateTime endDate;
  final DateRangePreset preset;

  const ExportFilter({
    required this.shopId,
    required this.domain,
    required this.format,
    required this.startDate,
    required this.endDate,
    this.preset = DateRangePreset.thisMonth,
  });

  String generateFileName() {
    final dateStr = DateFormat('yyyyMMdd').format(startDate);
    final endStr = DateFormat('yyyyMMdd').format(endDate);
    return '${domain.defaultBaseName}_${dateStr}_to_$endStr.${format.extension}';
  }
}

/// The generated export file payload and high-level summary metrics.
class ExportResult {
  final ExportDomain domain;
  final ExportFormat format;
  final String fileName;
  final String mimeType;
  final int recordCount;
  final int fileSizeBytes;
  final String? csvString;
  final Uint8List? pdfBytes;
  final DateTime generatedAt;
  final Map<String, dynamic> summaryMetrics;

  const ExportResult({
    required this.domain,
    required this.format,
    required this.fileName,
    required this.mimeType,
    required this.recordCount,
    required this.fileSizeBytes,
    this.csvString,
    this.pdfBytes,
    required this.generatedAt,
    this.summaryMetrics = const {},
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Status of a cloud backup snapshot.
enum BackupStatus {
  completed,
  inProgress,
  failed;

  String get label {
    switch (this) {
      case BackupStatus.completed:
        return 'Completed (सफल)';
      case BackupStatus.inProgress:
        return 'In Progress (प्रगति में)';
      case BackupStatus.failed:
        return 'Failed (असफल)';
    }
  }

  Color get color {
    switch (this) {
      case BackupStatus.completed:
        return Colors.green;
      case BackupStatus.inProgress:
        return Colors.orange;
      case BackupStatus.failed:
        return Colors.red;
    }
  }
}

/// Status of an automated or manual restore test.
enum RestoreTestStatus {
  passed,
  passedWithWarnings,
  failed;

  String get label {
    switch (this) {
      case RestoreTestStatus.passed:
        return 'Verified 100% (सत्यापित)';
      case RestoreTestStatus.passedWithWarnings:
        return 'Passed with Warnings (चेतावनी)';
      case RestoreTestStatus.failed:
        return 'Integrity Failed (त्रुटि)';
    }
  }

  Color get color {
    switch (this) {
      case RestoreTestStatus.passed:
        return Colors.green;
      case RestoreTestStatus.passedWithWarnings:
        return Colors.amber.shade800;
      case RestoreTestStatus.failed:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case RestoreTestStatus.passed:
        return Icons.check_circle_rounded;
      case RestoreTestStatus.passedWithWarnings:
        return Icons.warning_amber_rounded;
      case RestoreTestStatus.failed:
        return Icons.cancel_rounded;
    }
  }
}

/// Detailed results of a restore testing operation.
class RestoreTestResult {
  final String id;
  final String backupId;
  final DateTime testedAt;
  final RestoreTestStatus status;
  final double healthScorePercent;
  final String testedBy;
  final List<String> stepsPassed;
  final List<String> warnings;
  final List<String> errors;
  final Map<String, int> verifiedCounts;
  final int executionDurationMs;

  const RestoreTestResult({
    required this.id,
    required this.backupId,
    required this.testedAt,
    required this.status,
    required this.healthScorePercent,
    required this.testedBy,
    required this.stepsPassed,
    this.warnings = const [],
    this.errors = const [],
    required this.verifiedCounts,
    required this.executionDurationMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'backup_id': backupId,
      'tested_at': testedAt.toIso8601String(),
      'status': status.name,
      'health_score_percent': healthScorePercent,
      'tested_by': testedBy,
      'steps_passed': stepsPassed,
      'warnings': warnings,
      'errors': errors,
      'verified_counts': verifiedCounts,
      'execution_duration_ms': executionDurationMs,
    };
  }

  factory RestoreTestResult.fromMap(Map<String, dynamic> map) {
    return RestoreTestResult(
      id: map['id']?.toString() ?? '',
      backupId: map['backup_id']?.toString() ?? '',
      testedAt: map['tested_at'] != null ? DateTime.tryParse(map['tested_at'].toString()) ?? DateTime.now() : DateTime.now(),
      status: RestoreTestStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => RestoreTestStatus.passed,
      ),
      healthScorePercent: (map['health_score_percent'] as num?)?.toDouble() ?? 100.0,
      testedBy: map['tested_by']?.toString() ?? 'System / Admin',
      stepsPassed: List<String>.from(map['steps_passed'] ?? []),
      warnings: List<String>.from(map['warnings'] ?? []),
      errors: List<String>.from(map['errors'] ?? []),
      verifiedCounts: Map<String, int>.from(map['verified_counts'] ?? {}),
      executionDurationMs: (map['execution_duration_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Represents a point-in-time Cloud Backup Snapshot for a store.
class BackupSnapshot {
  final String id;
  final String shopId;
  final DateTime createdAt;
  final BackupStatus status;
  final int retentionDays;
  final int totalRecords;
  final Map<String, int> countsByDomain;
  final String checksumSha256;
  final int sizeBytes;
  final String? backupPayloadJson;
  final String createdBy;
  final DateTime? lastRestoreTestedAt;
  final RestoreTestResult? lastRestoreTestResult;
  final bool isAutoScheduled;

  const BackupSnapshot({
    required this.id,
    required this.shopId,
    required this.createdAt,
    this.status = BackupStatus.completed,
    this.retentionDays = 30,
    required this.totalRecords,
    required this.countsByDomain,
    required this.checksumSha256,
    required this.sizeBytes,
    this.backupPayloadJson,
    required this.createdBy,
    this.lastRestoreTestedAt,
    this.lastRestoreTestResult,
    this.isAutoScheduled = false,
  });

  /// Check whether this backup snapshot has passed its retention lifespan
  bool isExpired({DateTime? now}) {
    final current = now ?? DateTime.now();
    return current.difference(createdAt).inDays > retentionDays;
  }

  /// Human-readable file size
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Relative or formatted creation date
  String get formattedDate {
    return DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);
  }

  /// Short SHA-256 fingerprint for display
  String get shortChecksum {
    if (checksumSha256.length <= 12) return checksumSha256;
    return '${checksumSha256.substring(0, 8)}...${checksumSha256.substring(checksumSha256.length - 4)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'created_at': createdAt.toIso8601String(),
      'status': status.name,
      'retention_days': retentionDays,
      'total_records': totalRecords,
      'counts_by_domain': countsByDomain,
      'checksum_sha256': checksumSha256,
      'size_bytes': sizeBytes,
      'backup_payload_json': backupPayloadJson,
      'created_by': createdBy,
      'last_restore_tested_at': lastRestoreTestedAt?.toIso8601String(),
      'last_restore_test_result': lastRestoreTestResult?.toMap(),
      'is_auto_scheduled': isAutoScheduled,
    };
  }

  factory BackupSnapshot.fromMap(Map<String, dynamic> map, {String? docId}) {
    return BackupSnapshot(
      id: docId ?? map['id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      status: BackupStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => BackupStatus.completed,
      ),
      retentionDays: (map['retention_days'] as num?)?.toInt() ?? 30,
      totalRecords: (map['total_records'] as num?)?.toInt() ?? 0,
      countsByDomain: Map<String, int>.from(map['counts_by_domain'] ?? {}),
      checksumSha256: map['checksum_sha256']?.toString() ?? '',
      sizeBytes: (map['size_bytes'] as num?)?.toInt() ?? 0,
      backupPayloadJson: map['backup_payload_json']?.toString(),
      createdBy: map['created_by']?.toString() ?? 'Shop Owner',
      lastRestoreTestedAt: map['last_restore_tested_at'] != null ? DateTime.tryParse(map['last_restore_tested_at'].toString()) : null,
      lastRestoreTestResult: map['last_restore_test_result'] != null ? RestoreTestResult.fromMap(Map<String, dynamic>.from(map['last_restore_test_result'])) : null,
      isAutoScheduled: map['is_auto_scheduled'] == true,
    );
  }
}

/// High-level metrics for dashboard header
class BackupAnalyticsSummary {
  final int totalBackups;
  final DateTime? lastBackupDate;
  final RestoreTestStatus? lastRestoreTestStatus;
  final double averageHealthScore;
  final int totalProtectedRecords;
  final int activeRetentionDays;

  const BackupAnalyticsSummary({
    required this.totalBackups,
    this.lastBackupDate,
    this.lastRestoreTestStatus,
    required this.averageHealthScore,
    required this.totalProtectedRecords,
    this.activeRetentionDays = 30,
  });

  factory BackupAnalyticsSummary.fromSnapshots(List<BackupSnapshot> snapshots) {
    if (snapshots.isEmpty) {
      return const BackupAnalyticsSummary(
        totalBackups: 0,
        averageHealthScore: 100.0,
        totalProtectedRecords: 0,
      );
    }

    final latest = snapshots.first;
    double scoreSum = 0;
    int testedCount = 0;
    int maxRecords = 0;

    for (final s in snapshots) {
      if (s.totalRecords > maxRecords) maxRecords = s.totalRecords;
      if (s.lastRestoreTestResult != null) {
        scoreSum += s.lastRestoreTestResult!.healthScorePercent;
        testedCount++;
      }
    }

    final avgScore = testedCount > 0 ? (scoreSum / testedCount) : 100.0;

    return BackupAnalyticsSummary(
      totalBackups: snapshots.length,
      lastBackupDate: latest.createdAt,
      lastRestoreTestStatus: latest.lastRestoreTestResult?.status,
      averageHealthScore: avgScore,
      totalProtectedRecords: maxRecords,
      activeRetentionDays: latest.retentionDays,
    );
  }
}
