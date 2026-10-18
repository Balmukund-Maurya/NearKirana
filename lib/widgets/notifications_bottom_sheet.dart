import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../language_provider.dart';
import '../notification_service.dart';

/// Shows the notifications center sheet (bottom sheet on mobile, dialog on desktop)
Future<void> showNotificationsSheet(
  BuildContext context, {
  String? shopId,
  String? recipientPhone,
  String? recipientUid,
}) async {
  HapticFeedback.lightImpact();
  final isDesktop = MediaQuery.of(context).size.width > 700;

  if (isDesktop) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NotificationsSheetContent(
                shopId: shopId,
                recipientPhone: recipientPhone,
                recipientUid: recipientUid,
                isDialog: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: NotificationsSheetContent(
          shopId: shopId,
          recipientPhone: recipientPhone,
          recipientUid: recipientUid,
          isDialog: false,
        ),
      ),
    ),
  );
}

class NotificationsSheetContent extends StatelessWidget {
  final String? shopId;
  final String? recipientPhone;
  final String? recipientUid;
  final bool isDialog;

  const NotificationsSheetContent({
    super.key,
    this.shopId,
    this.recipientPhone,
    this.recipientUid,
    this.isDialog = false,
  });

  String _formatRelativeTime(DateTime dateTime, LanguageProvider lang) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inSeconds < 60) {
      if (lang.isHindi) return 'अभी-अभी';
      if (lang.isHinglish) return 'Abhi';
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      if (lang.isHindi) return '$mins मिनट पहले';
      if (lang.isHinglish) return '$mins mins pehle';
      return '${mins}m ago';
    }
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      if (lang.isHindi) return '$hours घंटे पहले';
      if (lang.isHinglish) return '$hours ghante pehle';
      return '${hours}h ago';
    }
    if (diff.inDays == 1) {
      if (lang.isHindi) return 'कल';
      if (lang.isHinglish) return 'Kal';
      return 'Yesterday';
    }
    final days = diff.inDays;
    if (lang.isHindi) return '$days दिन पहले';
    if (lang.isHinglish) return '$days din pehle';
    return '${days}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    return StreamBuilder<List<NotificationItem>>(
      stream: NotificationService.streamNotifications(
        shopId: shopId,
        recipientPhone: recipientPhone,
        recipientUid: recipientUid,
      ),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n.isRead).length;

        return Column(
          children: [
            // Drag handle on mobile
            if (!isDialog)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // Header Row
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100, width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFF0C831F),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              t('Notifications', 'सूचनाएं', 'Notifications'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          t(
                            'Order updates & store announcements',
                            'ऑर्डर अपडेट्स और स्टोर सूचनाएं',
                            'Order updates aur store alerts',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unreadCount > 0)
                    TextButton(
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        await NotificationService.markAllAsRead(
                          shopId: shopId,
                          recipientPhone: recipientPhone,
                          recipientUid: recipientUid,
                        );
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      child: Text(
                        t('Mark all read', 'सभी पढ़े गए', 'Sabhi read mark karein'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C831F),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting &&
                      notifications.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF0C831F),
                      ),
                    )
                  : notifications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications_none_rounded,
                                    size: 42,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  t(
                                    'No Notifications Yet',
                                    'कोई सूचना नहीं है',
                                    'Abhi koi notification nahi hai',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t(
                                    'Order updates and alerts will appear here in your chosen language.',
                                    'ऑर्डर और स्टोर के सभी अपडेट्स यहां आपकी चुनी हुई भाषा में दिखाई देंगे।',
                                    'Order aur store ke updates yahan aapki select ki hui language mein dikhenge.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          itemCount: notifications.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = notifications[index];
                            final title = item.localizedTitle(lang);
                            final body = item.localizedBody(lang);
                            final timeAgo =
                                _formatRelativeTime(item.createdAt, lang);

                            return Dismissible(
                              key: ValueKey(item.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                              onDismissed: (_) {
                                NotificationService.deleteNotification(item.id);
                              },
                              child: InkWell(
                                onTap: () {
                                  if (!item.isRead) {
                                    NotificationService.markAsRead(item.id);
                                  }
                                  if (item.orderId != null &&
                                      item.orderId!.isNotEmpty) {
                                    NotificationService
                                        .onNotificationClicked.value = {
                                      'order_id': item.orderId,
                                      ...item.data,
                                    };
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: item.isRead
                                        ? Colors.white
                                        : const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: item.isRead
                                          ? Colors.grey.shade200
                                          : const Color(0xFF86EFAC),
                                      width: item.isRead ? 1 : 1.4,
                                    ),
                                    boxShadow: item.isRead
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: const Color(0xFF10B981)
                                                  .withValues(alpha: 0.08),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Status icon container
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: item.iconColor
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          item.icon,
                                          color: item.iconColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Text Body
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight: item.isRead
                                                          ? FontWeight.w600
                                                          : FontWeight.w700,
                                                      color:
                                                          const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                                if (!item.isRead) ...[
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 6),
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Color(0xFF10B981),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              body,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                                height: 1.35,
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // Footer: order chip + time
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                if (item.orderId != null &&
                                                    item.orderId!.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2.5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey.shade300,
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .receipt_long_rounded,
                                                          size: 11,
                                                          color:
                                                              Color(0xFF64748B),
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          '#${item.orderId!.length >= 6 ? item.orderId!.substring(0, 6) : item.orderId}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF334155),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                else
                                                  const SizedBox.shrink(),
                                                Text(
                                                  timeAgo,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: Colors.grey.shade500,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}
