import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_utils.dart';
import 'sound_service.dart';
import 'language_provider.dart';

/// Top-level background message handler invoked by OS when app is terminated or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    'FCM Background message received: ${message.messageId} - ${message.data}',
  );
}

/// Notification permission status enum for UI checks and diagnostics
enum NotificationPermissionStatus {
  authorized,
  provisional,
  denied,
  notSupported,
}

/// Representation of a stored in-app / push notification with multi-language support and Flutter Icons
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String? orderId;
  final String status;
  final String type; // 'order_status', 'new_order', 'general', 'alert'
  final String? recipientPhone;
  final String? recipientUid;
  final String? shopId;
  final DateTime createdAt;
  final bool isRead;
  final String titleEn;
  final String titleHi;
  final String titleHinglish;
  final String bodyEn;
  final String bodyHi;
  final String bodyHinglish;
  final Map<String, dynamic> data;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.orderId,
    this.status = '',
    this.type = 'order_status',
    this.recipientPhone,
    this.recipientUid,
    this.shopId,
    required this.createdAt,
    this.isRead = false,
    this.titleEn = '',
    this.titleHi = '',
    this.titleHinglish = '',
    this.bodyEn = '',
    this.bodyHi = '',
    this.bodyHinglish = '',
    this.data = const {},
  });

  /// Strips unicode emojis from any string
  static String cleanEmoji(String text) {
    if (text.isEmpty) return text;
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E6}-\u{1F1FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F900}-\u{1F9FF}]',
      unicode: true,
    );
    return text.replaceAll(emojiRegex, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Resolves the title dynamically based on active language callback `t(en, hi, hinglish)`
  String getLocalizedTitle(String Function(String, String, String) t) {
    if (titleHi.isNotEmpty || titleHinglish.isNotEmpty || titleEn.isNotEmpty) {
      final en = titleEn.isNotEmpty ? titleEn : (cleanEmoji(title).isNotEmpty ? cleanEmoji(title) : 'Order Update');
      final hi = titleHi.isNotEmpty ? titleHi : (cleanEmoji(title).isNotEmpty ? cleanEmoji(title) : 'ऑर्डर अपडेट');
      final hinglish = titleHinglish.isNotEmpty ? titleHinglish : (cleanEmoji(title).isNotEmpty ? cleanEmoji(title) : 'Order Update');
      return t(en, hi, hinglish);
    }
    // Synthesize from status if direct translations were not persisted
    if (status.isNotEmpty) {
      final syn = NotificationService.getLocalizedStatusStrings(status, orderId: orderId);
      return t(syn['title_en']!, syn['title_hi']!, syn['title_hinglish']!);
    }
    final clean = cleanEmoji(title);
    return clean.isNotEmpty ? clean : 'Order Update';
  }

  /// Resolves the body dynamically based on active language callback `t(en, hi, hinglish)`
  String getLocalizedBody(String Function(String, String, String) t) {
    if (bodyHi.isNotEmpty || bodyHinglish.isNotEmpty || bodyEn.isNotEmpty) {
      final en = bodyEn.isNotEmpty ? bodyEn : cleanEmoji(body);
      final hi = bodyHi.isNotEmpty ? bodyHi : cleanEmoji(body);
      final hinglish = bodyHinglish.isNotEmpty ? bodyHinglish : cleanEmoji(body);
      return t(en, hi, hinglish);
    }
    // Synthesize from status if direct translations were not persisted
    if (status.isNotEmpty) {
      final syn = NotificationService.getLocalizedStatusStrings(status, orderId: orderId);
      return t(syn['body_en']!, syn['body_hi']!, syn['body_hinglish']!);
    }
    return cleanEmoji(body);
  }

  /// Returns localized title according to the active language in [lang]
  String localizedTitle(LanguageProvider lang) {
    return getLocalizedTitle((en, hi, hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    });
  }

  /// Returns localized body according to the active language in [lang]
  String localizedBody(LanguageProvider lang) {
    return getLocalizedBody((en, hi, hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    });
  }

  /// Returns localized title according to language code ('en', 'hi', 'hinglish')
  String getLocalizedTitleForCode(String langCode) {
    return getLocalizedTitle((en, hi, hinglish) {
      if (langCode == 'hi') return hi;
      if (langCode == 'hinglish' || langCode == 'hi_Latn') return hinglish;
      return en;
    });
  }

  /// Returns localized body according to language code ('en', 'hi', 'hinglish')
  String getLocalizedBodyForCode(String langCode) {
    return getLocalizedBody((en, hi, hinglish) {
      if (langCode == 'hi') return hi;
      if (langCode == 'hinglish' || langCode == 'hi_Latn') return hinglish;
      return en;
    });
  }

  /// Official Flutter Material Icon representing the notification type/status
  IconData get icon {
    final s = status.toLowerCase();
    if (s.contains('pending')) return Icons.shopping_bag_outlined;
    if (s.contains('accept')) return Icons.check_circle_outline_rounded;
    if (s.contains('packing') || s.contains('packed')) return Icons.inventory_2_outlined;
    if (s.contains('ready')) return Icons.done_all_rounded;
    if (s.contains('out') || (s.contains('delivery') && !s.contains('fail') && !s.contains('deliver'))) {
      return Icons.two_wheeler_rounded;
    }
    if (s.contains('deliver')) return Icons.verified_rounded;
    if (s.contains('fail')) return Icons.warning_amber_rounded;
    if (s.contains('cancel') || s.contains('reject')) return Icons.cancel_outlined;

    final t = type.toLowerCase();
    if (t.contains('accept')) return Icons.check_circle_outline_rounded;
    if (t.contains('reject') || t.contains('decline')) return Icons.cancel_outlined;
    if (t.contains('substitution') || t.contains('swap')) return Icons.swap_horiz_rounded;
    if (t.contains('order')) return Icons.receipt_long_outlined;
    return Icons.notifications_none_rounded;
  }

  /// Theme-consistent accent color matching the Flutter icon
  Color get iconColor {
    final s = status.toLowerCase();
    if (s.contains('pending')) return const Color(0xFF2563EB); // Royal Blue
    if (s.contains('accept')) return const Color(0xFF16A34A); // Emerald Green
    if (s.contains('packing') || s.contains('packed')) return const Color(0xFFD97706); // Amber
    if (s.contains('ready')) return const Color(0xFF0D9488); // Teal
    if (s.contains('out')) return const Color(0xFFEA580C); // Orange
    if (s.contains('delivered')) return const Color(0xFF059669); // Green
    if (s.contains('fail')) return const Color(0xFFDC2626); // Crimson Red
    if (s.contains('cancel') || s.contains('reject')) return const Color(0xFFE11D48); // Rose Red

    final t = type.toLowerCase();
    if (t.contains('accept')) return const Color(0xFF16A34A);
    if (t.contains('reject')) return const Color(0xFFE11D48);
    if (t.contains('substitution')) return const Color(0xFF7C3AED); // Purple
    return const Color(0xFF4B5563);
  }

  Map<String, dynamic> toMap() => {
    'title': cleanEmoji(title),
    'body': cleanEmoji(body),
    'order_id': orderId,
    'status': status,
    'type': type,
    if (recipientPhone != null) 'recipient_phone': recipientPhone,
    if (recipientUid != null) 'recipient_uid': recipientUid,
    if (shopId != null) 'shop_id': shopId,
    'created_at': Timestamp.fromDate(createdAt),
    'is_read': isRead,
    'title_en': titleEn,
    'title_hi': titleHi,
    'title_hinglish': titleHinglish,
    'body_en': bodyEn,
    'body_hi': bodyHi,
    'body_hinglish': bodyHinglish,
    'data': data,
  };

  factory NotificationItem.fromMap(String id, Map<String, dynamic> map) {
    final rawTime = map['created_at'];
    DateTime date = DateTime.now();
    if (rawTime is Timestamp) {
      date = rawTime.toDate();
    } else if (rawTime is String) {
      date = DateTime.tryParse(rawTime) ?? DateTime.now();
    }

    final dataMap = map['data'] is Map ? Map<String, dynamic>.from(map['data']) : <String, dynamic>{};

    final title = cleanEmoji(map['title']?.toString() ?? '');
    final body = cleanEmoji(map['body']?.toString() ?? '');
    final status = map['status']?.toString() ?? (dataMap['status']?.toString() ?? '');

    final titleEn = cleanEmoji(map['title_en']?.toString() ?? (dataMap['title_en']?.toString() ?? ''));
    final titleHi = cleanEmoji(map['title_hi']?.toString() ?? (dataMap['title_hi']?.toString() ?? ''));
    final titleHinglish = cleanEmoji(map['title_hinglish']?.toString() ?? (dataMap['title_hinglish']?.toString() ?? ''));

    final bodyEn = cleanEmoji(map['body_en']?.toString() ?? (dataMap['body_en']?.toString() ?? ''));
    final bodyHi = cleanEmoji(map['body_hi']?.toString() ?? (dataMap['body_hi']?.toString() ?? ''));
    final bodyHinglish = cleanEmoji(map['body_hinglish']?.toString() ?? (dataMap['body_hinglish']?.toString() ?? ''));

    return NotificationItem(
      id: id,
      title: title,
      body: body,
      orderId: map['order_id']?.toString() ?? dataMap['order_id']?.toString(),
      status: status,
      type: map['type']?.toString() ?? (dataMap['type']?.toString() ?? 'order_status'),
      recipientPhone: map['recipient_phone']?.toString() ?? dataMap['customer_phone']?.toString(),
      recipientUid: map['recipient_uid']?.toString() ?? dataMap['customer_uid']?.toString(),
      shopId: map['shop_id']?.toString() ?? dataMap['shop_id']?.toString(),
      createdAt: date,
      isRead: map['is_read'] == true,
      titleEn: titleEn,
      titleHi: titleHi,
      titleHinglish: titleHinglish,
      bodyEn: bodyEn,
      bodyHi: bodyHi,
      bodyHinglish: bodyHinglish,
      data: dataMap,
    );
  }
}

/// Comprehensive, production-ready Push Notification & Device Token service.
/// Enforces:
/// 1. Reliable FCM push notification delivery across Foreground, Background, and Terminated states.
/// 2. Device token lifecycle management (retrieval, registration, rotation/token refresh, and cleanup).
/// 3. Notification permission requests and status diagnostics.
/// 4. Event-driven order status notification dispatching (e.g. Packed -> Out for Delivery).
/// 5. Failed-delivery retry queue with error logging and backoff mechanisms.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static FirebaseMessaging? _messaging;
  static bool _isInitialized = false;
  static String? _cachedFcmToken;

  /// Global notifier when a notification is clicked by user (for deep-linking into order)
  static final ValueNotifier<Map<String, dynamic>?> onNotificationClicked =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// Channel ID and details for high-priority order alerts
  static const String orderChannelId = 'kirana_order_channel';
  static const String orderChannelName = 'Order Updates & Delivery Alerts';
  static const String orderChannelDescription =
      'High-priority notifications for new orders, delivery dispatch, and status updates';

  /// Initializes local notifications and FCM listeners safely across all platforms.
  static Future<void> initialize({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Flutter Local Notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final data = json.decode(response.payload!);
              onNotificationClicked.value = Map<String, dynamic>.from(data);
            } catch (_) {}
          }
        },
      );

      // Create Android Notification Channel with maximum priority
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          orderChannelId,
          orderChannelName,
          description: orderChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidImplementation.createNotificationChannel(channel);
      }

      // 2. Setup Firebase Messaging if available
      _messaging = messaging ?? FirebaseMessaging.instance;

      if (_messaging != null) {
        // Request Notification Permission
        await requestNotificationPermissions();

        // Foreground notification display options
        await _messaging!.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Background handler registration
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        // Foreground Message Listener
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _handleForegroundMessage(message);
        });

        // App opened from background via notification tap
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleNotificationTap(message);
        });

        // App opened from terminated state via notification tap
        final initialMessage = await _messaging!.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        // Automatic Token Rotation / Refresh Listener
        _messaging!.onTokenRefresh.listen((newToken) {
          _handleTokenRefresh(newToken, firestore: firestore);
        });

        // Fetch and cache initial token
        try {
          _cachedFcmToken = await _messaging!.getToken();
          if (_cachedFcmToken != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('fcm_device_token', _cachedFcmToken!);
          }
        } catch (e) {
          debugPrint('FCM getToken warning: $e');
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialization warning: $e');
      _isInitialized = true; // Still mark initialized to prevent crash loops
    }
  }

  /// Request notification permission on device
  static Future<NotificationPermissionStatus>
  requestNotificationPermissions() async {
    try {
      if (_messaging == null) return NotificationPermissionStatus.notSupported;

      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          return NotificationPermissionStatus.authorized;
        case AuthorizationStatus.provisional:
          return NotificationPermissionStatus.provisional;
        case AuthorizationStatus.denied:
        case AuthorizationStatus.notDetermined:
        default:
          return NotificationPermissionStatus.denied;
      }
    } catch (e) {
      debugPrint('requestNotificationPermissions error: $e');
      return NotificationPermissionStatus.notSupported;
    }
  }

  /// Returns current device FCM token
  static Future<String?> getDeviceToken() async {
    if (_cachedFcmToken != null) return _cachedFcmToken;
    try {
      if (_messaging != null) {
        _cachedFcmToken = await _messaging!.getToken();
        return _cachedFcmToken;
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('fcm_device_token');
    } catch (e) {
      debugPrint('getDeviceToken error: $e');
      return null;
    }
  }

  /// Syncs device FCM token with Firestore user records
  static Future<void> syncDeviceToken({
    required String uid,
    String? token,
    String? phone,
    String? role,
    String? shopId,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    final activeToken = token ?? await getDeviceToken();
    if (activeToken == null || activeToken.isEmpty) return;

    try {
      final sanitizedTokenDocId = activeToken.length > 50
          ? activeToken.substring(activeToken.length - 40)
          : activeToken;

      final tokenData = {
        'token': activeToken,
        'uid': uid,
        'phone': phone ?? '',
        'role': role ?? 'customer',
        'shop_id': shopId ?? '',
        'platform': defaultTargetPlatform.name,
        'is_active': true,
        'updated_at': FieldValue.serverTimestamp(),
      };

      // 1. Save in global device_tokens registry
      await db
          .collection('device_tokens')
          .doc(sanitizedTokenDocId)
          .set(tokenData, SetOptions(merge: true));

      // 2. Save in user's profile subcollection
      await db
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens')
          .doc(sanitizedTokenDocId)
          .set(tokenData, SetOptions(merge: true));

      // 3. If shop owner, register under shop topics
      if (shopId != null && shopId.isNotEmpty) {
        await subscribeToTopic('shop_${shopId}_orders');
      }
    } catch (e) {
      debugPrint('syncDeviceToken error: $e');
    }
  }

  /// Removes or deactivates device token upon user logout
  static Future<void> removeDeviceToken({
    required String uid,
    String? token,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    final activeToken = token ?? await getDeviceToken();
    if (activeToken == null || activeToken.isEmpty) return;

    try {
      final sanitizedTokenDocId = activeToken.length > 50
          ? activeToken.substring(activeToken.length - 40)
          : activeToken;

      await db.collection('device_tokens').doc(sanitizedTokenDocId).update({
        'is_active': false,
        'logged_out_at': FieldValue.serverTimestamp(),
      });

      await db
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens')
          .doc(sanitizedTokenDocId)
          .update({
            'is_active': false,
            'logged_out_at': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('removeDeviceToken error: $e');
    }
  }

  /// Handles FCM token rotation / refresh
  static Future<void> handleTokenRefresh(
    String newToken, {
    FirebaseFirestore? firestore,
  }) async {
    await _handleTokenRefresh(newToken, firestore: firestore);
  }

  static Future<void> _handleTokenRefresh(
    String newToken, {
    FirebaseFirestore? firestore,
  }) async {
    _cachedFcmToken = newToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_device_token', newToken);

    final uid = prefs.getString('current_user_uid');
    final phone = prefs.getString('customerPhone');
    final role = prefs.getString('selectedRole');
    final shopId = prefs.getString('current_shop_id');

    if (uid != null && uid.isNotEmpty) {
      await syncDeviceToken(
        uid: uid,
        token: newToken,
        phone: phone,
        role: role,
        shopId: shopId,
        firestore: firestore,
      );
    }
  }

  /// Subscribe to specific FCM Topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      final sanitized = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]+'), '_');
      await _messaging?.subscribeToTopic(sanitized);
    } catch (e) {
      debugPrint('subscribeToTopic warning: $e');
    }
  }

  /// Unsubscribe from specific FCM Topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      final sanitized = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]+'), '_');
      await _messaging?.unsubscribeFromTopic(sanitized);
    } catch (e) {
      debugPrint('unsubscribeFromTopic warning: $e');
    }
  }

  /// Generates full 3-language localized dictionaries for any order status
  static Map<String, String> getLocalizedStatusStrings(
    String status, {
    String? orderId,
    double? orderTotal,
    String? deliveryBoyName,
    String? failureReason,
  }) {
    final cleanStatus = status.trim();
    final shortOrderId = (orderId != null && orderId.length >= 6)
        ? orderId.substring(0, 6)
        : (orderId ?? '');
    final orderPrefix = shortOrderId.isNotEmpty ? ' #$shortOrderId' : '';
    final totalFormatted = orderTotal != null && orderTotal > 0
        ? ' (₹${orderTotal.toStringAsFixed(0)})'
        : '';

    final s = cleanStatus.toLowerCase();

    if (s.contains('pending')) {
      return {
        'title_en': 'New Order Placed$orderPrefix',
        'title_hi': 'नया ऑर्डर प्राप्त हुआ$orderPrefix!',
        'title_hinglish': 'Naya Order Place Hua$orderPrefix!',
        'body_en': 'Order$orderPrefix$totalFormatted received. Awaiting store confirmation.',
        'body_hi': 'ऑर्डर$orderPrefix$totalFormatted प्राप्त हुआ है। दुकान द्वारा पुष्टि की प्रतीक्षा है।',
        'body_hinglish': 'Order$orderPrefix$totalFormatted receive ho gaya hai. Dukan dwara confirm hone ki pratiksha hai.',
      };
    } else if (s.contains('accept')) {
      return {
        'title_en': 'Order Accepted$orderPrefix',
        'title_hi': 'ऑर्डर स्वीकार किया गया$orderPrefix!',
        'title_hinglish': 'Order Accept Ho Gaya$orderPrefix!',
        'body_en': 'The store has accepted your order$orderPrefix.',
        'body_hi': 'दुकानदार ने आपका ऑर्डर$orderPrefix स्वीकार कर लिया है।',
        'body_hinglish': 'Dukandar ne aapka order$orderPrefix accept kar liya hai.',
      };
    } else if (s == 'packing' || s.contains('packing')) {
      return {
        'title_en': 'Order Packing in Progress$orderPrefix',
        'title_hi': 'ऑर्डर पैक हो रहा है$orderPrefix!',
        'title_hinglish': 'Order Pack Ho Raha Hai$orderPrefix!',
        'body_en': 'Your items are being packed at the store.',
        'body_hi': 'आपका सामान दुकान पर पैक किया जा रहा है।',
        'body_hinglish': 'Aapka saman dukan par pack ho raha hai.',
      };
    } else if (s == 'packed' || s.contains('packed')) {
      return {
        'title_en': 'Order Packed$orderPrefix',
        'title_hi': 'ऑर्डर पैक हो चुका है$orderPrefix!',
        'title_hinglish': 'Order Pack Ho Chuka Hai$orderPrefix!',
        'body_en': 'Your order$orderPrefix is packed and ready for dispatch.',
        'body_hi': 'आपका ऑर्डर$orderPrefix पैक हो चुका है और भेजने के लिए तैयार है।',
        'body_hinglish': 'Aapka order$orderPrefix pack ho chuka hai aur dispatch ke liye taiyar hai.',
      };
    } else if (s.contains('ready')) {
      return {
        'title_en': 'Order Ready$orderPrefix',
        'title_hi': 'ऑर्डर तैयार है$orderPrefix!',
        'title_hinglish': 'Order Taiyar Hai$orderPrefix!',
        'body_en': 'Your order$orderPrefix is ready for pickup or dispatch.',
        'body_hi': 'आपका ऑर्डर$orderPrefix पिकअप या डिलीवरी के लिए तैयार है।',
        'body_hinglish': 'Aapka order$orderPrefix pickup ya delivery ke liye taiyar hai.',
      };
    } else if (s.contains('out') || s.contains('dispatch')) {
      final rider = (deliveryBoyName != null && deliveryBoyName.isNotEmpty)
          ? deliveryBoyName
          : null;
      return {
        'title_en': 'Order Out for Delivery$orderPrefix',
        'title_hi': 'ऑर्डर डिलीवरी के लिए निकल चुका है$orderPrefix!',
        'title_hinglish': 'Order Raste Mein Hai (Out for Delivery)$orderPrefix!',
        'body_en': rider != null
            ? 'Order$orderPrefix is out for delivery with $rider.'
            : 'Order$orderPrefix is out for delivery and will reach you shortly.',
        'body_hi': rider != null
            ? 'ऑर्डर$orderPrefix निकल चुका है! डिलीवरी पार्टनर: $rider।'
            : 'ऑर्डर$orderPrefix निकल चुका है और जल्द ही आप तक पहुंचेगा।',
        'body_hinglish': rider != null
            ? 'Order$orderPrefix delivery partner $rider ke sath nikal chuka hai.'
            : 'Order$orderPrefix nikal chuka hai aur jald aap tak pahunchega.',
      };
    } else if (s.contains('deliver') && !s.contains('fail')) {
      return {
        'title_en': 'Order Delivered Successfully$orderPrefix',
        'title_hi': 'ऑर्डर सफलतापूर्वक डिलीवर हो गया$orderPrefix!',
        'title_hinglish': 'Order Safaltapoorvak Deliver Ho Gaya$orderPrefix!',
        'body_en': 'Order$orderPrefix has been delivered. Thank you for shopping with NearKirana!',
        'body_hi': 'ऑर्डर$orderPrefix डिलीवर हो चुका है। NearKirana से खरीदारी करने के लिए धन्यवाद!',
        'body_hinglish': 'Order$orderPrefix deliver ho chuka hai. NearKirana se shopping ke liye dhanyawad!',
      };
    } else if (s.contains('fail')) {
      final reason = (failureReason != null && failureReason.isNotEmpty)
          ? failureReason
          : null;
      return {
        'title_en': 'Delivery Unsuccessful$orderPrefix',
        'title_hi': 'डिलीवरी असफल रही$orderPrefix',
        'title_hinglish': 'Delivery Asafal Rahi$orderPrefix',
        'body_en': reason != null
            ? 'Order$orderPrefix could not be delivered: $reason. Please contact the store.'
            : 'Order$orderPrefix could not be delivered. Delivery partner will retry soon.',
        'body_hi': reason != null
            ? 'ऑर्डर$orderPrefix डिलीवर नहीं हो सका: $reason। कृपया दुकान से संपर्क करें।'
            : 'ऑर्डर$orderPrefix डिलीवर नहीं हो सका। डिलीवरी पार्टनर दोबारा प्रयास करेगा।',
        'body_hinglish': reason != null
            ? 'Order$orderPrefix deliver nahi ho saka: $reason. Kripya dukan se sampark karein.'
            : 'Order$orderPrefix deliver nahi ho saka. Delivery partner dobara koshish karega.',
      };
    } else if (s.contains('cancel') || s.contains('reject')) {
      final isRejected = s.contains('reject') || cleanStatus == 'Rejected';
      final reason = (failureReason != null && failureReason.isNotEmpty)
          ? failureReason
          : null;
      return {
        'title_en': isRejected ? 'Order Declined$orderPrefix' : 'Order Cancelled$orderPrefix',
        'title_hi': isRejected ? 'ऑर्डर अस्वीकार किया गया$orderPrefix' : 'ऑर्डर रद्द हुआ$orderPrefix',
        'title_hinglish': isRejected ? 'Order Decline Hua$orderPrefix' : 'Order Cancel Hua$orderPrefix',
        'body_en': reason != null
            ? 'Order$orderPrefix was ${isRejected ? 'declined' : 'cancelled'}. Reason: $reason.'
            : 'Order$orderPrefix has been ${isRejected ? 'declined' : 'cancelled'}.',
        'body_hi': reason != null
            ? 'ऑर्डर$orderPrefix ${isRejected ? 'अस्वीकार' : 'रद्द'} कर दिया गया है। कारण: $reason।'
            : 'ऑर्डर$orderPrefix ${isRejected ? 'अस्वीकार' : 'रद्द'} कर दिया गया है।',
        'body_hinglish': reason != null
            ? 'Order$orderPrefix ${isRejected ? 'decline' : 'cancel'} kar diya gaya hai. Karan: $reason.'
            : 'Order$orderPrefix ${isRejected ? 'decline' : 'cancel'} ho gaya hai.',
      };
    }

    return {
      'title_en': 'Order Update$orderPrefix',
      'title_hi': 'ऑर्डर अपडेट$orderPrefix',
      'title_hinglish': 'Order Update$orderPrefix',
      'body_en': 'Your order$orderPrefix status is $cleanStatus.',
      'body_hi': 'आपके ऑर्डर$orderPrefix का स्टेटस $cleanStatus है।',
      'body_hinglish': 'Aapke order$orderPrefix ka status $cleanStatus hai.',
    };
  }

  /// Shows instant local high-priority heads-up notification in the user's selected language
  static Future<void> showOrderNotification(
    String title,
    String body, {
    String? orderId,
    Map<String, dynamic>? payload,
    String? titleEn,
    String? titleHi,
    String? titleHinglish,
    String? bodyEn,
    String? bodyHi,
    String? bodyHinglish,
    String? language,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          orderChannelId,
          orderChannelName,
          channelDescription: orderChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          showWhen: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      100000,
    );

    // Resolve target language from parameters or SharedPreferences
    final selectedLang = language ?? await getSelectedLanguage();

    String? tEn = titleEn ?? payload?['title_en']?.toString();
    String? tHi = titleHi ?? payload?['title_hi']?.toString();
    String? tHinglish = titleHinglish ?? payload?['title_hinglish']?.toString();

    String? bEn = bodyEn ?? payload?['body_en']?.toString();
    String? bHi = bodyHi ?? payload?['body_hi']?.toString();
    String? bHinglish = bodyHinglish ?? payload?['body_hinglish']?.toString();

    // Synthesize from status if direct translations were not supplied
    final status = payload?['status']?.toString();
    if ((tHi == null || tHi.isEmpty) && status != null && status.isNotEmpty) {
      final syn = getLocalizedStatusStrings(
        status,
        orderId: orderId ?? payload?['order_id']?.toString(),
        orderTotal: (payload?['total_amount'] as num?)?.toDouble(),
        deliveryBoyName: payload?['delivery_boy']?.toString(),
        failureReason: payload?['failure_reason']?.toString(),
      );
      tEn ??= syn['title_en'];
      tHi = syn['title_hi'];
      tHinglish = syn['title_hinglish'];
      bEn ??= syn['body_en'];
      bHi = syn['body_hi'];
      bHinglish = syn['body_hinglish'];
    }

    String displayTitle = title;
    String displayBody = body;

    if (selectedLang == 'hi') {
      if (tHi != null && tHi.isNotEmpty) displayTitle = tHi;
      if (bHi != null && bHi.isNotEmpty) displayBody = bHi;
    } else if (selectedLang == 'hinglish' || selectedLang == 'hi_Latn') {
      if (tHinglish != null && tHinglish.isNotEmpty) displayTitle = tHinglish;
      if (bHinglish != null && bHinglish.isNotEmpty) displayBody = bHinglish;
    } else {
      if (tEn != null && tEn.isNotEmpty) displayTitle = tEn;
      if (bEn != null && bEn.isNotEmpty) displayBody = bEn;
    }

    final String jsonPayload = json.encode({
      'order_id': ?orderId,
      'title_en': ?tEn,
      'title_hi': ?tHi,
      'title_hinglish': ?tHinglish,
      'body_en': ?bEn,
      'body_hi': ?bHi,
      'body_hinglish': ?bHinglish,
      ...?payload,
    });

    try {
      final cleanTitle = NotificationItem.cleanEmoji(displayTitle);
      final cleanBody = NotificationItem.cleanEmoji(displayBody);
      await _notificationsPlugin.show(
        id: notificationId,
        title: cleanTitle,
        body: cleanBody,
        notificationDetails: platformDetails,
        payload: jsonPayload,
      );
    } catch (e) {
      debugPrint('Local notification show warning: $e');
    }
  }

  /// Resolves the user's saved language preference ('en', 'hi', or 'hinglish')
  static Future<String> getSelectedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('app_language');
      if (lang != null && ['en', 'hi', 'hinglish', 'hi_Latn'].contains(lang)) {
        return (lang == 'hi_Latn') ? 'hinglish' : lang;
      }
    } catch (_) {}
    return 'en';
  }

  /// Dispatches an order status change notification across backend queue, user notifications, and local alerts.
  /// Formatted cleanly without emojis with full dynamic multi-language (en, hi, hinglish) support.
  static Future<Map<String, dynamic>> dispatchOrderStatusNotification({
    required String orderId,
    required String newStatus,
    required String customerPhone,
    String? customerUid,
    required String shopId,
    double? orderTotal,
    String? deliveryBoyName,
    String? failureReason,
    String? language,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    final selectedLang = language ?? await getSelectedLanguage();

    final syn = getLocalizedStatusStrings(
      newStatus,
      orderId: orderId,
      orderTotal: orderTotal,
      deliveryBoyName: deliveryBoyName,
      failureReason: failureReason,
    );

    final String titleEn = syn['title_en']!;
    final String titleHi = syn['title_hi']!;
    final String titleHinglish = syn['title_hinglish']!;

    final String bodyEn = syn['body_en']!;
    final String bodyHi = syn['body_hi']!;
    final String bodyHinglish = syn['body_hinglish']!;

    String activeTitle = titleEn;
    String activeBody = bodyEn;
    if (selectedLang == 'hi') {
      activeTitle = titleHi;
      activeBody = bodyHi;
    } else if (selectedLang == 'hinglish' || selectedLang == 'hi_Latn') {
      activeTitle = titleHinglish;
      activeBody = bodyHinglish;
    }

    final payloadData = {
      'order_id': orderId,
      'status': newStatus,
      'shop_id': shopId,
      'customer_phone': customerPhone,
      'delivery_boy': ?deliveryBoyName,
      'failure_reason': ?failureReason,
      'total_amount': ?orderTotal,
      'timestamp': DateTime.now().toIso8601String(),
      'title_en': titleEn,
      'title_hi': titleHi,
      'title_hinglish': titleHinglish,
      'body_en': bodyEn,
      'body_hi': bodyHi,
      'body_hinglish': bodyHinglish,
    };

    // Check if the currently active device belongs to this customer!
    final prefs = await SharedPreferences.getInstance();
    final currentCustomerPhone = prefs.getString('customerPhone') ?? '';
    final cleanCurrent = currentCustomerPhone.replaceAll(RegExp(r'\D'), '');
    final cleanRecipient = customerPhone.replaceAll(RegExp(r'\D'), '');

    final bool isCurrentDeviceTheRecipient = cleanRecipient.isNotEmpty &&
        cleanCurrent.isNotEmpty &&
        (cleanCurrent == cleanRecipient ||
            (cleanCurrent.length >= 10 &&
                cleanRecipient.length >= 10 &&
                cleanCurrent.substring(cleanCurrent.length - 10) ==
                    cleanRecipient.substring(cleanRecipient.length - 10)));

    // 1. Show instant local notification on active device ONLY IF the active device belongs to the recipient customer!
    // This prevents shop owner from receiving local popup alerts on their own phone when accepting/packing/dispatching orders.
    if (isCurrentDeviceTheRecipient) {
      await showOrderNotification(
        activeTitle,
        activeBody,
        orderId: orderId,
        titleEn: titleEn,
        titleHi: titleHi,
        titleHinglish: titleHinglish,
        bodyEn: bodyEn,
        bodyHi: bodyHi,
        bodyHinglish: bodyHinglish,
        language: selectedLang,
        payload: payloadData,
      );

      // 2. Play contextual sound alert only on customer device
      final s = newStatus.toLowerCase();
      if (s.contains('out') || s.contains('dispatch')) {
        SoundService().orderDispatched();
      } else if (s.contains('deliver') && !s.contains('fail')) {
        SoundService().orderDelivered();
      } else if (s.contains('cancel') || s.contains('reject')) {
        SoundService().orderCancelled();
      } else {
        SoundService().statusUpdated();
      }
    }

    // Phone variants for reliable customer in-app notification queries
    final last10 = cleanRecipient.length >= 10
        ? cleanRecipient.substring(cleanRecipient.length - 10)
        : cleanRecipient;
    final List<String> phoneVariants = {
      customerPhone,
      cleanRecipient,
      last10,
      if (last10.isNotEmpty) '+91$last10',
      if (last10.isNotEmpty) '91$last10',
    }.where((e) => e.isNotEmpty).toList();

    // 3. Persist to customer's in-app notification center
    final notificationRef = db.collection('notifications').doc();
    final notificationDoc = {
      'title': activeTitle,
      'body': activeBody,
      'title_en': titleEn,
      'title_hi': titleHi,
      'title_hinglish': titleHinglish,
      'body_en': bodyEn,
      'body_hi': bodyHi,
      'body_hinglish': bodyHinglish,
      'order_id': orderId,
      'status': newStatus,
      'type': 'order_status',
      'target_role': 'customer',
      'recipient_role': 'customer',
      'recipient_phone': customerPhone,
      'recipient_phone_clean': last10,
      'recipient_phones': phoneVariants,
      'recipient_uid': ?customerUid,
      'shop_id': shopId,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      'data': payloadData,
    };
    await notificationRef.set(notificationDoc);

    // 4. Enqueue in reliable notification_queue for Cloud Function / backend FCM delivery
    final queueRef = db.collection('notification_queue').doc();
    final queueDoc = {
      'notification_id': notificationRef.id,
      'title': activeTitle,
      'body': activeBody,
      'title_en': titleEn,
      'title_hi': titleHi,
      'title_hinglish': titleHinglish,
      'body_en': bodyEn,
      'body_hi': bodyHi,
      'body_hinglish': bodyHinglish,
      'target_phone': customerPhone,
      'target_uid': ?customerUid,
      'target_topic': 'order_$orderId',
      'shop_id': shopId,
      'order_id': orderId,
      'status': 'queued', // 'queued' -> 'sent' / 'failed'
      'retry_count': 0,
      'max_retries': 3,
      'priority': 'high',
      'created_at': FieldValue.serverTimestamp(),
      'payload': payloadData,
    };
    await queueRef.set(queueDoc);

    return {
      'notification_id': notificationRef.id,
      'queue_id': queueRef.id,
      'title': activeTitle,
      'body': activeBody,
      'status': 'queued',
    };
  }

  /// Dispatches notifications for product substitution proposals, approvals, and rejections
  static Future<Map<String, dynamic>> dispatchSubstitutionNotification({
    required String orderId,
    required String type, // 'proposed', 'accepted', 'rejected'
    required String message,
    String? customerPhone,
    String? customerUid,
    required String shopId,
    String? language,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    final selectedLang = language ?? await getSelectedLanguage();
    final shortOrderId =
        orderId.length >= 6 ? orderId.substring(0, 6) : orderId;
    final cleanMsg = NotificationItem.cleanEmoji(message);

    String titleEn = 'Alternative Item Proposed (#$shortOrderId)';
    String titleHi = 'वैकल्पिक सामान प्रस्तावित (#$shortOrderId)';
    String titleHinglish = 'Alternative Item Proposed (#$shortOrderId)';

    String bodyEn = 'Alternative item proposed for order #$shortOrderId ($cleanMsg). Please review and approve.';
    String bodyHi = 'ऑर्डर #$shortOrderId के लिए सामान का विकल्प प्रस्तावित किया गया है: $cleanMsg। कृपया चेक करें।';
    String bodyHinglish = 'Order #$shortOrderId ke liye alternative item suggest kiya gaya hai: $cleanMsg. Kripya check karein.';

    if (type == 'accepted') {
      titleEn = 'Alternative Item Approved (#$shortOrderId)';
      titleHi = 'वैकल्पिक सामान स्वीकृत (#$shortOrderId)';
      titleHinglish = 'Alternative Item Accept Hua (#$shortOrderId)';

      bodyEn = 'Alternative item was approved for order #$shortOrderId ($cleanMsg).';
      bodyHi = 'ऑर्डर #$shortOrderId के लिए वैकल्पिक सामान स्वीकार कर लिया गया: $cleanMsg।';
      bodyHinglish = 'Order #$shortOrderId ke liye alternative item accept kar liya gaya: $cleanMsg.';
    } else if (type == 'rejected') {
      titleEn = 'Alternative Item Declined (#$shortOrderId)';
      titleHi = 'वैकल्पिक सामान अस्वीकृत (#$shortOrderId)';
      titleHinglish = 'Alternative Item Decline Hua (#$shortOrderId)';

      bodyEn = 'Alternative item was declined for order #$shortOrderId ($cleanMsg).';
      bodyHi = 'ऑर्डर #$shortOrderId के लिए वैकल्पिक सामान अस्वीकार कर दिया गया: $cleanMsg।';
      bodyHinglish = 'Order #$shortOrderId ke liye alternative item decline ho gaya: $cleanMsg.';
    }

    String activeTitle = titleEn;
    String activeBody = bodyEn;
    if (selectedLang == 'hi') {
      activeTitle = titleHi;
      activeBody = bodyHi;
    } else if (selectedLang == 'hinglish' || selectedLang == 'hi_Latn') {
      activeTitle = titleHinglish;
      activeBody = bodyHinglish;
    }

    final notificationRef = db.collection('notifications').doc();
    final now = FieldValue.serverTimestamp();

    final notificationDoc = {
      'id': notificationRef.id,
      'order_id': orderId,
      'type': 'substitution_$type',
      'status': type,
      'title': activeTitle,
      'body': activeBody,
      'title_en': titleEn,
      'title_hi': titleHi,
      'title_hinglish': titleHinglish,
      'body_en': bodyEn,
      'body_hi': bodyHi,
      'body_hinglish': bodyHinglish,
      'customer_phone': customerPhone ?? '',
      'customer_uid': ?customerUid,
      'shop_id': shopId,
      'created_at': now,
      'is_read': false,
      'data': {
        'order_id': orderId,
        'type': 'substitution_$type',
        'status': type,
        'title_en': titleEn,
        'title_hi': titleHi,
        'title_hinglish': titleHinglish,
        'body_en': bodyEn,
        'body_hi': bodyHi,
        'body_hinglish': bodyHinglish,
      },
    };

    try {
      await notificationRef.set(notificationDoc);
    } catch (e) {
      debugPrint('Failed to dispatch substitution notification: $e');
    }

    await showOrderNotification(
      activeTitle,
      activeBody,
      orderId: orderId,
      titleEn: titleEn,
      titleHi: titleHi,
      titleHinglish: titleHinglish,
      bodyEn: bodyEn,
      bodyHi: bodyHi,
      bodyHinglish: bodyHinglish,
      language: selectedLang,
      payload: notificationDoc,
    );

    return notificationDoc;
  }

  /// Streams notifications for a given user or shop
  static Stream<List<NotificationItem>> streamNotifications({
    String? shopId,
    String? recipientPhone,
    String? recipientUid,
    int limit = 50,
    FirebaseFirestore? firestore,
  }) {
    final db = firestore ?? FirebaseUtils.firestore;
    Query query = db.collection('notifications');

    if (shopId != null && shopId.isNotEmpty) {
      query = query.where('shop_id', isEqualTo: shopId);
    } else if (recipientPhone != null && recipientPhone.isNotEmpty) {
      final clean = recipientPhone.replaceAll(RegExp(r'\D'), '');
      final last10 = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;
      final phoneVariants = {
        recipientPhone,
        clean,
        last10,
        if (last10.isNotEmpty) '+91$last10',
        if (last10.isNotEmpty) '91$last10',
      }.where((e) => e.isNotEmpty).toList();

      query = query.where('recipient_phone', whereIn: phoneVariants.take(10).toList());
    } else if (recipientUid != null && recipientUid.isNotEmpty) {
      query = query.where('recipient_uid', isEqualTo: recipientUid);
    }

    return query
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (shopId != null && shopId.isNotEmpty) {
              // Shop owner only wants notifications meant for the store/admin.
              // Exclude customer order status notifications!
              final targetRole = data['target_role'] ?? data['recipient_role'];
              if (targetRole == 'customer') return false;
              final type = (data['type'] ?? '').toString();
              if (type == 'order_status') return false;
            }
            return true;
          })
          .map((doc) => NotificationItem.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Real-time stream of unread notifications count
  static Stream<int> unreadCountStream({
    String? shopId,
    String? recipientPhone,
    String? recipientUid,
    FirebaseFirestore? firestore,
  }) {
    final db = firestore ?? FirebaseUtils.firestore;
    Query query = db.collection('notifications');

    if (shopId != null && shopId.isNotEmpty) {
      query = query.where('shop_id', isEqualTo: shopId);
    } else if (recipientPhone != null && recipientPhone.isNotEmpty) {
      final clean = recipientPhone.replaceAll(RegExp(r'\D'), '');
      final last10 = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;
      final phoneVariants = {
        recipientPhone,
        clean,
        last10,
        if (last10.isNotEmpty) '+91$last10',
        if (last10.isNotEmpty) '91$last10',
      }.where((e) => e.isNotEmpty).toList();

      query = query.where('recipient_phone', whereIn: phoneVariants.take(10).toList());
    } else if (recipientUid != null && recipientUid.isNotEmpty) {
      query = query.where('recipient_uid', isEqualTo: recipientUid);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          if (shopId != null && shopId.isNotEmpty) {
            // Exclude customer order status notifications from shop owner's unread counter
            final targetRole = data['target_role'] ?? data['recipient_role'];
            if (targetRole == 'customer') return false;
            final type = (data['type'] ?? '').toString();
            if (type == 'order_status') return false;
          }
          return data['is_read'] != true;
        }).length);
  }

  /// Marks a specific notification as read
  static Future<void> markAsRead(String notificationId, {FirebaseFirestore? firestore}) async {
    try {
      final db = firestore ?? FirebaseUtils.firestore;
      await db.collection('notifications').doc(notificationId).update({'is_read': true});
    } catch (e) {
      debugPrint('markAsRead warning: $e');
    }
  }

  /// Marks all notifications for a shop or user as read
  static Future<void> markAllAsRead({
    String? shopId,
    String? recipientPhone,
    String? recipientUid,
    FirebaseFirestore? firestore,
  }) async {
    try {
      final db = firestore ?? FirebaseUtils.firestore;
      Query query = db.collection('notifications').where('is_read', isEqualTo: false);
      if (shopId != null && shopId.isNotEmpty) {
        query = query.where('shop_id', isEqualTo: shopId);
      } else if (recipientPhone != null && recipientPhone.isNotEmpty) {
        query = query.where('recipient_phone', isEqualTo: recipientPhone);
      }
      final snapshot = await query.limit(50).get();
      final batch = db.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'is_read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('markAllAsRead warning: $e');
    }
  }

  /// Deletes a notification from Firestore
  static Future<void> deleteNotification(String notificationId, {FirebaseFirestore? firestore}) async {
    try {
      final db = firestore ?? FirebaseUtils.firestore;
      await db.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('deleteNotification warning: $e');
    }
  }

  /// Failed-delivery retry processor: Inspects failed items in notification_queue and retries
  static Future<int> retryFailedNotifications({
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    int retriedCount = 0;

    try {
      final failedDocs = await db
          .collection('notification_queue')
          .where('status', isEqualTo: 'failed')
          .limit(20)
          .get();

      for (var doc in failedDocs.docs) {
        final data = doc.data();
        final int currentRetries = (data['retry_count'] as num?)?.toInt() ?? 0;
        final int maxRetries = (data['max_retries'] as num?)?.toInt() ?? 3;

        if (currentRetries < maxRetries) {
          // Re-attempt delivery
          await doc.reference.update({
            'status': 'queued',
            'retry_count': currentRetries + 1,
            'last_retry_at': FieldValue.serverTimestamp(),
          });
          retriedCount++;
        } else {
          // Mark as permanently dead-letter
          await doc.reference.update({
            'status': 'dead_letter',
            'exhausted_at': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('retryFailedNotifications error: $e');
    }

    return retriedCount;
  }

  /// Internal handler for messages received while app is open
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final selectedLang = await getSelectedLanguage();

    final title =
        notification?.title ??
        data['title'] ??
        'NearKirana Notification';
    final body = notification?.body ?? data['body'] ?? '';

    await showOrderNotification(
      title,
      body,
      orderId: data['order_id']?.toString(),
      payload: data,
      titleEn: data['title_en']?.toString(),
      titleHi: data['title_hi']?.toString(),
      titleHinglish: data['title_hinglish']?.toString(),
      bodyEn: data['body_en']?.toString(),
      bodyHi: data['body_hi']?.toString(),
      bodyHinglish: data['body_hinglish']?.toString(),
      language: selectedLang,
    );
  }

  /// Internal handler when notification is tapped
  static void _handleNotificationTap(RemoteMessage message) {
    onNotificationClicked.value = message.data;
  }
}
