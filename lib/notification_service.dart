import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_utils.dart';
import 'sound_service.dart';

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

/// Representation of a stored in-app / push notification
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String? orderId;
  final String type; // 'order_status', 'new_order', 'general', 'alert'
  final String? recipientPhone;
  final String? recipientUid;
  final String? shopId;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> data;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.orderId,
    this.type = 'order_status',
    this.recipientPhone,
    this.recipientUid,
    this.shopId,
    required this.createdAt,
    this.isRead = false,
    this.data = const {},
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'body': body,
    'order_id': orderId,
    'type': type,
    if (recipientPhone != null) 'recipient_phone': recipientPhone,
    if (recipientUid != null) 'recipient_uid': recipientUid,
    if (shopId != null) 'shop_id': shopId,
    'created_at': Timestamp.fromDate(createdAt),
    'is_read': isRead,
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

    return NotificationItem(
      id: id,
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      orderId: map['order_id']?.toString(),
      type: map['type']?.toString() ?? 'order_status',
      recipientPhone: map['recipient_phone']?.toString(),
      recipientUid: map['recipient_uid']?.toString(),
      shopId: map['shop_id']?.toString(),
      createdAt: date,
      isRead: map['is_read'] == true,
      data: map['data'] is Map ? Map<String, dynamic>.from(map['data']) : {},
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

  /// Shows instant local high-priority heads-up notification (Backwards compatible)
  static Future<void> showOrderNotification(
    String title,
    String body, {
    String? orderId,
    Map<String, dynamic>? payload,
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

    final String jsonPayload = json.encode({
      'order_id': ?orderId,
      ...?payload,
    });

    try {
      await _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: jsonPayload,
      );
    } catch (e) {
      debugPrint('Local notification show warning: $e');
    }
  }

  /// Dispatches an order status change notification across backend queue, user notifications, and local alerts.
  /// Example: Packed -> Out for Delivery triggers instant notification to customer.
  static Future<Map<String, dynamic>> dispatchOrderStatusNotification({
    required String orderId,
    required String newStatus,
    required String customerPhone,
    String? customerUid,
    required String shopId,
    double? orderTotal,
    String? deliveryBoyName,
    String? failureReason,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;

    final shortOrderId = orderId.length >= 6
        ? orderId.substring(0, 6)
        : orderId;

    // Generate localized and contextual notification content
    String title = 'Order Update';
    String body =
        'Your order #$shortOrderId status has been updated to $newStatus.';

    switch (newStatus) {
      case 'Pending':
        title = '🛍️ Naya Order Place Hua!';
        body =
            'Order #$shortOrderId (₹${(orderTotal ?? 0).toStringAsFixed(0)}) prapt hua hai. Dukan dwara confirm hone ki pratiksha hai.';
        break;
      case 'Accepted':
        title = '✅ Order Sweekar Kiya Gaya!';
        body = 'Dukandar ne aapka order #$shortOrderId accept kar liya hai.';
        break;
      case 'Packing':
      case 'Packed':
        title = '📦 Order Pack Ho Raha Hai!';
        body = 'Aapka saman dukan par pack kiya ja raha hai.';
        break;
      case 'Ready':
        title = '🎉 Order Taiyar Hai!';
        body =
            'Aapka order #$shortOrderId pack ho chuka hai aur dispatch ke liye taiyar hai.';
        break;
      case 'Out for Delivery':
        title = '🛵 Order Raste Mein Hai (Out for Delivery)!';
        body = deliveryBoyName != null && deliveryBoyName.isNotEmpty
            ? 'Order #$shortOrderId nikal chuka hai! Delivery Partner: $deliveryBoyName.'
            : 'Order #$shortOrderId nikal chuka hai aur jald aap tak pahunchega.';
        break;
      case 'Delivered':
        title = '🌟 Order Safaltapoorvak Deliver Ho Gaya!';
        body =
            'Order #$shortOrderId deliver ho chuka hai. NearKirana se shopping karne ke liye dhanyawad!';
        break;
      case 'Delivery_Failed':
        title = '⚠️ Delivery Asafal Rahi';
        body = failureReason != null && failureReason.isNotEmpty
            ? 'Order deliver nahi ho saka: $failureReason. Kripya dukan par sampark karein.'
            : 'Order deliver nahi ho saka. Delivery partner dobara koshish karega.';
        break;
      case 'Cancelled':
      case 'Rejected':
        title = '❌ Order Cancel Hua';
        body = failureReason != null && failureReason.isNotEmpty
            ? 'Order #$shortOrderId cancel kar diya gaya hai. Karan: $failureReason.'
            : 'Order #$shortOrderId cancel kar diya gaya hai.';
        break;
    }

    final payloadData = {
      'order_id': orderId,
      'status': newStatus,
      'shop_id': shopId,
      'customer_phone': customerPhone,
      'delivery_boy': ?deliveryBoyName,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 1. Show instant local notification on active device
    await showOrderNotification(
      title,
      body,
      orderId: orderId,
      payload: payloadData,
    );

    // 2. Play contextual sound alert
    if (newStatus == 'Out for Delivery') {
      SoundService().orderDispatched();
    } else if (newStatus == 'Delivered') {
      SoundService().orderDelivered();
    } else if (newStatus == 'Cancelled' || newStatus == 'Rejected') {
      SoundService().orderCancelled();
    } else {
      SoundService().statusUpdated();
    }

    // 3. Persist to customer's in-app notification center
    final notificationRef = db.collection('notifications').doc();
    final notificationDoc = {
      'title': title,
      'body': body,
      'order_id': orderId,
      'status': newStatus,
      'recipient_phone': customerPhone,
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
      'title': title,
      'body': body,
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
      'title': title,
      'body': body,
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
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    final shortOrderId =
        orderId.length >= 6 ? orderId.substring(0, 6) : orderId;
    String title = '🔄 Alternative Item Proposed (#$shortOrderId)';
    if (type == 'accepted') {
      title = '✅ Alternative Item Approved (#$shortOrderId)';
    } else if (type == 'rejected') {
      title = '❌ Alternative Item Declined (#$shortOrderId)';
    }

    final notificationRef = db.collection('notifications').doc();
    final now = FieldValue.serverTimestamp();

    final notificationDoc = {
      'id': notificationRef.id,
      'order_id': orderId,
      'type': 'substitution_$type',
      'title': title,
      'body': message,
      'customer_phone': customerPhone ?? '',
      'customer_uid': ?customerUid,
      'shop_id': shopId,
      'created_at': now,
      'is_read': false,
    };

    try {
      await notificationRef.set(notificationDoc);
    } catch (e) {
      debugPrint('Failed to dispatch substitution notification: $e');
    }

    return notificationDoc;
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
  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title'] ??
        'NearKirana Notification';
    final body = notification?.body ?? message.data['body'] ?? '';

    showOrderNotification(
      title,
      body,
      orderId: message.data['order_id'],
      payload: message.data,
    );
  }

  /// Internal handler when notification is tapped
  static void _handleNotificationTap(RemoteMessage message) {
    onNotificationClicked.value = message.data;
  }
}
