import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_utils.dart';

/// Structured breadcrumb representing an action or state change leading up to an event
class Breadcrumb {
  final String message;
  final String category;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  Breadcrumb({
    required this.message,
    this.category = 'action',
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Breadcrumb.fromMap(Map<String, dynamic> map) {
    return Breadcrumb(
      message: map['message']?.toString() ?? '',
      category: map['category']?.toString() ?? 'action',
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'message': message,
    'category': category,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] [$category] $message ${data != null ? data.toString() : ""}';
}

/// Actionable, structured crash and error report payload
class ErrorReport {
  final String error;
  final String? stackTrace;
  final String? reason;
  final bool fatal;
  final DateTime timestamp;
  final Map<String, dynamic> userContext;
  final Map<String, dynamic> customKeys;
  final List<Breadcrumb> breadcrumbs;

  ErrorReport({
    required this.error,
    this.stackTrace,
    this.reason,
    required this.fatal,
    DateTime? timestamp,
    required this.userContext,
    required this.customKeys,
    required this.breadcrumbs,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ErrorReport.fromMap(Map<String, dynamic> map) {
    return ErrorReport(
      error: map['error']?.toString() ?? 'Unknown Error',
      stackTrace: map['stackTrace']?.toString(),
      reason: map['reason']?.toString(),
      fatal: map['fatal'] == true,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      userContext: Map<String, dynamic>.from(map['userContext'] ?? {}),
      customKeys: Map<String, dynamic>.from(map['customKeys'] ?? {}),
      breadcrumbs: (map['breadcrumbs'] as List<dynamic>? ?? [])
          .map((b) => Breadcrumb.fromMap(Map<String, dynamic>.from(b)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'error': error,
    'stackTrace': stackTrace,
    'reason': reason,
    'fatal': fatal,
    'timestamp': timestamp.toIso8601String(),
    'userContext': userContext,
    'customKeys': customKeys,
    'breadcrumbs': breadcrumbs.map((b) => b.toMap()).toList(),
  };

  @override
  String toString() {
    return '''
================= ACTIONABLE CRASH REPORT =================
Error: $error
Reason: ${reason ?? 'None provided'}
Fatal: $fatal
Time: ${timestamp.toIso8601String()}
User Context: $userContext
Custom Keys: $customKeys
Recent Breadcrumbs (${breadcrumbs.length}):
${breadcrumbs.map((b) => '  -> $b').join('\n')}
Stack Trace:
$stackTrace
===========================================================
''';
  }
}

/// Production Crash Reporting and Actionable Logging Service.
/// Catches Flutter framework errors and unhandled asynchronous exceptions,
/// appending a rich contextual breadcrumb trail so production bugs can be easily diagnosed.
class CrashReportingService {
  static final CrashReportingService _instance =
      CrashReportingService._internal();
  factory CrashReportingService() => _instance;
  CrashReportingService._internal();

  static const int maxBreadcrumbs = 50;
  static const int maxStoredReports = 20;

  final List<Breadcrumb> _breadcrumbs = [];
  final List<ErrorReport> _storedReports = [];
  final Map<String, dynamic> _userContext = {};
  final Map<String, dynamic> _customKeys = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _enableFirestoreSink = false;
  bool get isFirestoreSinkEnabled => _enableFirestoreSink;
  FirebaseFirestore? _firestore;

  /// Optional remote persistence hook (e.g. Firestore / Crashlytics / API)
  Future<void> Function(ErrorReport report)? onReportRecorded;

  /// Initialize global crash reporting and error boundary hooks
  void init({
    Future<void> Function(ErrorReport report)? onRemoteRecord,
    bool enableFirestoreSink = false,
    FirebaseFirestore? firestore,
  }) {
    if (_isInitialized) return;
    _isInitialized = true;
    _enableFirestoreSink = enableFirestoreSink;
    _firestore = firestore;
    onReportRecorded = onRemoteRecord;

    // 1. Hook Flutter UI & widget errors
    FlutterError.onError = (FlutterErrorDetails details) {
      recordFlutterError(details);
    };

    // 2. Hook PlatformDispatcher asynchronous unhandled errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordError(
        error,
        stack,
        reason: 'Unhandled asynchronous platform error',
        fatal: true,
      );
      return true; // Marked as handled to avoid hard crash if possible
    };

    addBreadcrumb('CrashReportingService initialized', category: 'system');
  }

  /// Record user details for pinpointing affected users in production
  void setUser({
    required String uid,
    String? role,
    String? phone,
    String? shopId,
  }) {
    _userContext['uid'] = uid;
    if (role != null) _userContext['role'] = role;
    if (phone != null) _userContext['phone'] = phone;
    if (shopId != null) _userContext['shop_id'] = shopId;

    addBreadcrumb(
      'User context updated',
      category: 'auth',
      data: {'uid': uid, 'role': role, 'shop_id': shopId},
    );
  }

  /// Clear user details upon logout
  void clearUser() {
    _userContext.clear();
    addBreadcrumb('User logged out', category: 'auth');
  }

  /// Add custom telemetry key/value (e.g. app version, current route)
  void setCustomKey(String key, dynamic value) {
    _customKeys[key] = value;
  }

  /// Log a breadcrumb action in the FIFO ring buffer
  void addBreadcrumb(
    String message, {
    String category = 'action',
    Map<String, dynamic>? data,
  }) {
    if (_breadcrumbs.length >= maxBreadcrumbs) {
      _breadcrumbs.removeAt(0); // Evict oldest
    }
    _breadcrumbs.add(
      Breadcrumb(message: message, category: category, data: data),
    );
  }

  /// Convenience alias for logging a user action breadcrumb
  void recordAction(
    String message, {
    String category = 'action',
    Map<String, dynamic>? data,
  }) {
    addBreadcrumb(message, category: category, data: data);
  }

  /// Record a Flutter UI framework error
  void recordFlutterError(FlutterErrorDetails details, {bool fatal = false}) {
    final report = ErrorReport(
      error: details.exceptionAsString(),
      stackTrace: details.stack?.toString(),
      reason: details.context?.toString() ?? details.summary.toString(),
      fatal: fatal,
      userContext: Map<String, dynamic>.from(_userContext),
      customKeys: Map<String, dynamic>.from(_customKeys),
      breadcrumbs: List<Breadcrumb>.from(_breadcrumbs),
    );

    _handleReport(report);

    // Call standard Flutter dump in debug mode
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  }

  /// Record any non-fatal or fatal error with actionable diagnostic report
  ErrorReport recordError(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? contextData,
  }) {
    final mergedKeys = Map<String, dynamic>.from(_customKeys);
    if (contextData != null) {
      mergedKeys.addAll(contextData);
    }

    final report = ErrorReport(
      error: error.toString(),
      stackTrace: stack?.toString(),
      reason: reason,
      fatal: fatal,
      userContext: Map<String, dynamic>.from(_userContext),
      customKeys: mergedKeys,
      breadcrumbs: List<Breadcrumb>.from(_breadcrumbs),
    );

    _handleReport(report);
    return report;
  }

  void _handleReport(ErrorReport report) {
    if (_storedReports.length >= maxStoredReports) {
      _storedReports.removeAt(0);
    }
    _storedReports.add(report);

    // Print actionable log in debug or test modes
    debugPrint(report.toString());

    // Execute remote webhook / callback if configured
    if (onReportRecorded != null) {
      try {
        onReportRecorded!(report);
      } catch (e) {
        debugPrint('Failed to send error report to remote sink: $e');
      }
    }

    // Persist to Firestore sink if enabled
    if (_enableFirestoreSink) {
      reportCrashToFirestore(report, firestore: _firestore);
    }
  }

  /// Persists a structured error report to Firestore 'crash_reports' collection
  static Future<String?> reportCrashToFirestore(
    ErrorReport report, {
    FirebaseFirestore? firestore,
  }) async {
    try {
      final db = firestore ?? FirebaseUtils.firestore;
      final docRef = await db.collection('crash_reports').add({
        ...report.toMap(),
        'recorded_at': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Failed to persist crash report to Firestore: $e');
      return null;
    }
  }

  /// Fetches recent crash reports for developer/admin monitoring and diagnostics
  static Future<List<Map<String, dynamic>>> fetchRecentCrashReports({
    int limit = 25,
    FirebaseFirestore? firestore,
  }) async {
    try {
      final db = firestore ?? FirebaseUtils.firestore;
      final querySnapshot = await db
          .collection('crash_reports')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch crash reports from Firestore: $e');
      return [];
    }
  }

  /// Get copy of current breadcrumbs
  List<Breadcrumb> getBreadcrumbs() => List.unmodifiable(_breadcrumbs);

  /// Get copy of stored error reports
  List<ErrorReport> getStoredReports() => List.unmodifiable(_storedReports);

  /// Reset in-memory buffer (useful for test isolation)
  void reset() {
    _breadcrumbs.clear();
    _storedReports.clear();
    _userContext.clear();
    _customKeys.clear();
    _isInitialized = false;
    _enableFirestoreSink = false;
    _firestore = null;
    onReportRecorded = null;
  }
}
