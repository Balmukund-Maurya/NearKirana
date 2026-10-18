import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'language_provider.dart';
import 'delivery_partner_models.dart';
import 'delivery_partner_service.dart';
import 'live_delivery_tracking_service.dart';
import 'customer_live_tracking_screen.dart';
import 'sound_service.dart';

/// Zepto & Blinkit inspired Rider Dashboard for Delivery Partners.
/// Handles real-time order dispatch, store pickup confirmation, live GPS broadcasting,
/// turn-by-turn navigation, and cash-on-delivery (COD) handoffs in Hindi, English, and Hinglish.
class DeliveryPartnerScreen extends StatefulWidget {
  final String? initialPartnerId;
  final String? initialPhone;
  final DeliveryPartnerService? service;
  final LiveDeliveryTrackingService? trackingService;

  const DeliveryPartnerScreen({
    super.key,
    this.initialPartnerId,
    this.initialPhone,
    this.service,
    this.trackingService,
  });

  @override
  State<DeliveryPartnerScreen> createState() => _DeliveryPartnerScreenState();
}

class _DeliveryPartnerScreenState extends State<DeliveryPartnerScreen>
    with SingleTickerProviderStateMixin {
  late final DeliveryPartnerService _service;
  late final LiveDeliveryTrackingService _trackingService;
  late TabController _tabController;

  DeliveryPartner? _currentPartner;
  bool _isLoading = true;

  // Login controllers
  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _loginNameController = TextEditingController();
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DeliveryPartnerService();
    _trackingService = widget.trackingService ??
        LiveDeliveryTrackingService(firestore: _service.firestore);
    _tabController = TabController(length: 2, vsync: this);
    _initializePartner();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginPhoneController.dispose();
    _loginNameController.dispose();
    super.dispose();
  }

  Future<void> _initializePartner() async {
    setState(() => _isLoading = true);

    String? partnerId = widget.initialPartnerId;
    String? phone = widget.initialPhone;

    if (partnerId == null || partnerId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      partnerId = prefs.getString('current_delivery_partner_id');
      phone ??= prefs.getString('current_delivery_partner_phone');
    }

    if (partnerId != null && partnerId.isNotEmpty) {
      final partner = await _service.getPartner(partnerId);
      if (partner != null) {
        if (mounted) {
          setState(() {
            _currentPartner = partner;
            _isLoading = false;
          });
          return;
        }
      }
    }

    if (phone != null && phone.isNotEmpty) {
      final partner = await _service.getPartnerByPhone(phone);
      if (partner != null) {
        if (mounted) {
          setState(() {
            _currentPartner = partner;
            _isLoading = false;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_delivery_partner_id', partner.id);
          await prefs.setString('current_delivery_partner_phone', partner.phone);
          return;
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePartnerLogin(
    String Function(String, String, String) t,
  ) async {
    final phone = _loginPhoneController.text.trim();
    final name = _loginNameController.text.trim();

    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
          content: Text(
            t(
              'Please enter a valid 10-digit mobile number',
              'कृपया 10 अंकों का मान्य मोबाइल नंबर दर्ज करें',
              'Kripya 10 ankon ka valid phone number darj karein',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoggingIn = true);
    try {
      var partner = await _service.getPartnerByPhone(phone);
      if (partner == null) {
        final newPartner = DeliveryPartner(
          id: '',
          shopId: '',
          name: name.isNotEmpty ? name : 'Delivery Partner',
          phone: phone,
          status: DeliveryPartnerStatus.available,
          createdAt: DateTime.now(),
        );
        partner = await _service.registerOrUpdatePartner(newPartner);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_delivery_partner_id', partner.id);
      await prefs.setString('current_delivery_partner_phone', partner.phone);

      if (mounted) {
        setState(() {
          _currentPartner = partner;
          _isLoggingIn = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
            content: Text(
              t(
                'Login failed: $e',
                'लॉगिन असफल रहा: $e',
                'Login fail ho gaya: $e',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(String Function(String, String, String) t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 10),
            Text(
              t('Logout Partner', 'लॉगआउट करें', 'Logout Karein'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          t(
            'Are you sure you want to sign out from delivery mode?',
            'क्या आप डिलीवरी मोड से लॉगआउट करना चाहते हैं?',
            'Kya aap delivery mode se logout karna chahte hain?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Cancel', 'रद्द करें', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(t('Logout', 'लॉगआउट', 'Logout')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_delivery_partner_id');
    await prefs.remove('current_delivery_partner_phone');

    if (mounted) {
      setState(() {
        _currentPartner = null;
      });
    }
  }

  Future<void> _toggleDutyStatus(bool isOnline) async {
    if (_currentPartner == null) return;
    final newStatus = isOnline
        ? DeliveryPartnerStatus.available
        : DeliveryPartnerStatus.offline;

    HapticFeedback.lightImpact();
    await _service.updatePartnerStatus(_currentPartner!.id, newStatus);
    setState(() {
      _currentPartner = _currentPartner!.copyWith(status: newStatus);
    });
  }

  Future<void> _launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not launch dialer: $phone'),
          ),
        );
      }
    }
  }

  Future<void> _launchMap(String address) async {
    final query = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not open map navigation for: $address'),
          ),
        );
      }
    }
  }

  Future<void> _confirmPickup(
    DeliveryOrderTask task,
    String Function(String, String, String) t,
  ) async {
    HapticFeedback.mediumImpact();
    try {
      await _service.confirmStorePickup(
        orderId: task.orderId,
        partnerId: _currentPartner?.id ?? task.partnerId,
        shopId: task.shopId,
        customerPhone: task.customerPhone,
        orderTotal: task.totalAmount,
        partnerName: _currentPartner?.name ?? task.partnerName,
      );

      await _trackingService.startBroadcasting(
        orderId: task.orderId,
        partnerId: _currentPartner?.id ?? task.partnerId,
        partnerName: _currentPartner?.name ?? task.partnerName,
        partnerPhone: _currentPartner?.phone ?? '',
        partnerVehicle: _currentPartner?.vehicleNumber,
        shopId: task.shopId,
        customerPhone: task.customerPhone,
        customerName: task.customerName,
        customerAddress: task.deliveryAddress,
        customerLat: task.customerLat,
        customerLng: task.customerLng,
      );

      SoundService().orderDispatched();

      if (mounted) {
        final shortId = task.orderId.length > 6
            ? task.orderId.substring(task.orderId.length - 6)
            : task.orderId;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0C831F),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(
                      'Pickup Confirmed! Order #$shortId is Out for Delivery.',
                      'पिकअप कन्फर्म! ऑर्डर #$shortId डिलीवरी के लिए निकल गया है।',
                      'Pickup Confirm! Order #$shortId Out for Delivery hai.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Error: $e'),
          ),
        );
      }
    }
  }

  Future<void> _acceptTask(
    DeliveryOrderTask task,
    String Function(String, String, String) t,
  ) async {
    HapticFeedback.mediumImpact();
    try {
      await _service.acceptDeliveryTask(
        orderId: task.orderId,
        partnerId: _currentPartner?.id ?? task.partnerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0C831F),
            content: Row(
              children: [
                const Icon(Icons.thumb_up_alt_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(
                      'Order accepted! Proceed to store for pickup.',
                      'ऑर्डर स्वीकार कर लिया! दुकान से पार्सल पिकअप करें।',
                      'Order accept ho gaya! Store se parcel pickup karein.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Error: $e'),
          ),
        );
      }
    }
  }

  Future<void> _showDeliveryCompletionDialog(
    DeliveryOrderTask task,
    String Function(String, String, String) t,
  ) async {
    bool codCollected = task.isCOD;
    final notesCtrl = TextEditingController(
      text: t('Delivered to customer', 'ग्राहक को डिलीवर किया गया', 'Customer ko deliver kiya gaya'),
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final shortId = task.orderId.length > 6
              ? task.orderId.substring(task.orderId.length - 6)
              : task.orderId;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: Color(0xFF0C831F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Confirm Delivery', 'डिलीवरी पूर्ण करें', 'Delivery Confirm Karein'),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${t('Order', 'ऑर्डर', 'Order')} #$shortId',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer mini preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        Text(
                          '₹${task.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF0C831F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (task.isCOD)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.payments_rounded,
                                color: Color(0xFFD97706),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                t(
                                  'Cash on Delivery (COD)',
                                  'कैश ऑन डिलीवरी (नकद भुगतान)',
                                  'Cash on Delivery (COD)',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${t('Collect Cash Amount', 'ग्राहक से नकद राशि लें', 'Customer se cash lein')}: ₹${task.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: codCollected,
                                activeColor: const Color(0xFF0C831F),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  setDialogState(() => codCollected = val ?? false);
                                },
                              ),
                              Expanded(
                                child: Text(
                                  t(
                                    'Cash received from customer',
                                    'ग्राहक से नकद प्राप्त हो गया है',
                                    'Customer se cash receive ho gaya hai',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF78350F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF0C831F), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t(
                                'Order is Prepaid Online. No cash collection required.',
                                'ऑर्डर का ऑनलाइन भुगतान हो चुका है। कोई नकद राशि नहीं लेनी है।',
                                'Order prepaid hai. Customer se cash nahi lena hai.',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 14),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: t('Delivery Notes (Optional)', 'डिलीवरी रिमार्क (वैकल्पिक)', 'Delivery Notes (Optional)'),
                      prefixIcon: const Icon(Icons.note_alt_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  t('Cancel', 'रद्द करें', 'Cancel'),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (task.isCOD && !codCollected) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFFDC2626),
                        content: Text(
                          t(
                            'Please verify cash collection before completing delivery',
                            'कृपया डिलीवरी पूरी करने से पहले नकद प्राप्ति की पुष्टि करें',
                            'Kripya delivery complete karne se pehle cash confirm karein',
                          ),
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.of(ctx).pop();
                  HapticFeedback.heavyImpact();

                  try {
                    await _service.completeDelivery(
                      orderId: task.orderId,
                      partnerId: _currentPartner?.id ?? task.partnerId,
                      shopId: task.shopId,
                      codCollected: codCollected,
                      codAmount: codCollected ? task.totalAmount : 0.0,
                      completionNotes: notesCtrl.text.trim(),
                      customerPhone: task.customerPhone,
                      orderTotal: task.totalAmount,
                      partnerName: _currentPartner?.name ?? task.partnerName,
                    );

                    await _trackingService.stopBroadcasting(task.orderId, isDelivered: true);
                    SoundService().orderDelivered();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF0C831F),
                          behavior: SnackBarBehavior.floating,
                          content: Row(
                            children: [
                              const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t(
                                    'Delivery Completed Successfully!',
                                    'डिलीवरी सफलतापूर्वक संपन्न हुई!',
                                    'Delivery successfully complete ho gayi!',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFFDC2626),
                          behavior: SnackBarBehavior.floating,
                          content: Text('Failed to complete delivery: $e'),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C831F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  t('Confirm Delivered', 'सफल डिलीवरी दर्ज करें', 'Confirm Delivered'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF0C831F)),
              const SizedBox(height: 16),
              Text(
                t('Loading Partner Profile...', 'प्रोफ़ाइल लोड हो रही है...', 'Profile load ho rahi hai...'),
                style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentPartner == null) {
      return _buildLoginView(t);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.two_wheeler_rounded,
                color: Color(0xFF0C831F),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('Delivery Partner Mode', 'डिलीवरी पार्टनर मोड', 'Delivery Partner Mode'),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  t('Zepto & Blinkit Express Fleet', 'एक्सप्रेस डिलीवरी फ्लीट', 'Express Delivery Fleet'),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            tooltip: t('Switch Partner / Logout', 'लॉगआउट करें', 'Logout Karein'),
            onPressed: () => _handleLogout(t),
          ),
        ],
      ),
      body: Column(
        children: [
          // Rider Header & Duty Strip
          _buildPartnerHeaderCard(t),

          // Zepto/Blinkit Style Segmented Tab Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF0C831F),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.electric_moped_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(t('Active Tasks', 'सक्रिय कार्य', 'Active Tasks')),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(t('Delivery History', 'डिलीवरी इतिहास', 'Delivery History')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveTasksTab(t),
                _buildHistoryTab(t),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerHeaderCard(String Function(String, String, String) t) {
    final isOnline = _currentPartner?.isOnline ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0C831F), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    Icons.sports_motorsports_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Partner Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentPartner?.name ?? 'Delivery Partner',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currentPartner?.phone ?? ''} • ${_currentPartner?.vehicleNumber.isNotEmpty == true ? _currentPartner!.vehicleNumber : 'Kirana Express'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Duty Status Pill & Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline
                          ? t('On Duty', 'ड्यूटी पर', 'On Duty')
                          : t('Offline', 'ऑफलाइन', 'Offline'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isOnline ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: isOnline,
                        activeThumbColor: const Color(0xFF0C831F),
                        activeTrackColor: const Color(0xFFA7F3D0),
                        inactiveThumbColor: const Color(0xFF94A3B8),
                        inactiveTrackColor: const Color(0xFFE2E8F0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) => _toggleDutyStatus(val),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Zepto/Blinkit Rider Stats Bar
          Row(
            children: [
              _buildStatCard(
                icon: Icons.local_shipping_rounded,
                color: const Color(0xFF2563EB),
                label: t('Active', 'चालू कार्य', 'Active'),
                value: '${_currentPartner?.activeOrdersCount ?? 0}',
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF0C831F),
                label: t('Delivered', 'सफल डिलीवरी', 'Delivered'),
                value: '${_currentPartner?.totalDeliveredCount ?? 0}',
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFFD97706),
                label: t('COD Cash', 'नकद कैश', 'COD Cash'),
                value: '₹${(_currentPartner?.cashCollected ?? 0.0).toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTasksTab(String Function(String, String, String) t) {
    return StreamBuilder<List<DeliveryOrderTask>>(
      stream: _service.streamPartnerActiveTasks(_currentPartner!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0C831F)));
        }

        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      size: 42,
                      color: Color(0xFF0C831F),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t('No Active Deliveries', 'कोई सक्रिय डिलीवरी नहीं है', 'No Active Deliveries'),
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'All dispatches completed! You will see new orders here as soon as the shopkeeper assigns them to you.',
                      'सभी डिलीवरी पूरी हो चुकी हैं! जैसे ही दुकानदार आपको नया ऑर्डर असाइन करेगा, वह यहां दिखेगा।',
                      'Sabhi orders complete ho gaye! Naya order assign hote hi yahan dikhega.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            return _buildZeptoTaskCard(tasks[index], t);
          },
        );
      },
    );
  }

  Widget _buildHistoryTab(String Function(String, String, String) t) {
    return StreamBuilder<List<DeliveryOrderTask>>(
      stream: _service.streamPartnerCompletedTasks(_currentPartner!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0C831F)));
        }

        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_toggle_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 14),
                Text(
                  t('No delivery history yet', 'अभी तक कोई डिलीवरी इतिहास नहीं', 'Abhi tak koi delivery history nahi hai'),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = history[index];
            final shortId = item.orderId.length > 6
                ? item.orderId.substring(item.orderId.length - 6)
                : item.orderId;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF0C831F), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t('Order', 'ऑर्डर', 'Order')} #$shortId • ${item.customerName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.deliveryAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${item.totalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.isCOD ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.isCOD
                              ? t('COD Collected', 'नकद प्राप्त', 'COD Cash')
                              : t('Prepaid', 'ऑनलाइन पेड', 'Prepaid'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: item.isCOD ? const Color(0xFFB45309) : const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildZeptoTaskCard(
    DeliveryOrderTask task,
    String Function(String, String, String) t,
  ) {
    final shortId = task.orderId.length > 6
        ? task.orderId.substring(task.orderId.length - 6)
        : task.orderId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$shortId',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0C831F),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  t('Express Parcel', 'एक्सप्रेस पार्सल', 'Express Parcel'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(task, t),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route Nodes (Pickup Store -> Customer Drop)
                _buildRouteNodes(task, t),

                const SizedBox(height: 14),

                // Contact & Navigation Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: task.customerPhone.isNotEmpty
                            ? () => _launchCall(task.customerPhone)
                            : null,
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 17),
                        label: Text(
                          t('Call Customer', 'ग्राहक को कॉल करें', 'Call Customer'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchMap(task.deliveryAddress),
                        icon: const Icon(Icons.near_me_rounded, size: 17),
                        label: Text(
                          t('Directions', 'मैप नेविगेशन', 'Directions'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(color: Color(0xFF99F6E4)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Parcel Bill Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                '${task.itemsCount} ${t('items in parcel', 'सामान पार्सल में', 'items parcel mein')}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (task.itemsSummary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              task.itemsSummary.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${task.totalAmount.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: task.isCOD ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.isCOD
                                  ? t('Collect Cash', 'नकद लें', 'Collect Cash')
                                  : t('Prepaid Online', 'ऑनलाइन पेड', 'Prepaid Online'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: task.isCOD ? const Color(0xFFB45309) : const Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Zepto One-Tap Workflow Button
                _buildWorkflowButton(task, t),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteNodes(
    DeliveryOrderTask task,
    String Function(String, String, String) t,
  ) {
    return Column(
      children: [
        // Drop Node (Customer destination)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.location_on_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.customerName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.deliveryAddress,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(
    DeliveryOrderTask task,
    String Function(String, String, String) t,
  ) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (task.deliveryTaskStatus) {
      case DeliveryTaskStatus.assigned:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        label = t('Assigned', 'नया असाइन', 'Assigned');
        icon = Icons.assignment_ind_rounded;
        break;
      case DeliveryTaskStatus.accepted:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        label = t('Accepted (Store Pickup)', 'स्वीकार किया (दुकान से लें)', 'Accepted (Store Pickup)');
        icon = Icons.storefront_rounded;
        break;
      case DeliveryTaskStatus.pickedUp:
        bg = const Color(0xFFFAF5FF);
        fg = const Color(0xFF7E22CE);
        label = t('Out for Delivery', 'रास्ते में है', 'Out for Delivery');
        icon = Icons.two_wheeler_rounded;
        break;
      case DeliveryTaskStatus.delivered:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        label = t('Delivered', 'डिलीवर हुआ', 'Delivered');
        icon = Icons.check_circle_rounded;
        break;
      case DeliveryTaskStatus.cancelled:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        label = t('Cancelled', 'रद्द', 'Cancelled');
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowButton(
    DeliveryOrderTask task,
    String Function(String, String, String) t,
  ) {
    // 1. Stage: Assigned -> Accept Task
    if (task.deliveryTaskStatus == DeliveryTaskStatus.assigned) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => _acceptTask(task, t),
          icon: const Icon(Icons.thumb_up_alt_rounded, size: 18),
          label: Text(
            t('Accept Delivery Task', 'ऑर्डर स्वीकार करें', 'Accept Delivery Task'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );
    }

    // 2. Stage: Accepted -> Confirm Store Pickup
    if (task.deliveryTaskStatus == DeliveryTaskStatus.accepted) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => _confirmPickup(task, t),
          icon: const Icon(Icons.inventory_2_rounded, size: 18),
          label: Text(
            t('Confirm Store Pickup', 'दुकान से पार्सल लिया', 'Confirm Store Pickup'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0C831F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );
    }

    // 3. Stage: Picked up -> Live GPS Active + Mark Delivered
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t(
                    'Live GPS Broadcast Active',
                    'लाइव GPS शेयरिंग चालू है',
                    'Live GPS Broadcast Active',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  CustomerLiveTrackingScreen.open(
                    context,
                    orderId: task.orderId,
                  );
                },
                icon: const Icon(Icons.map_rounded, size: 16),
                label: Text(
                  t('View Map', 'मैप देखें', 'View Map'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0C831F),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _showDeliveryCompletionDialog(task, t),
            icon: const Icon(Icons.task_alt_rounded, size: 20),
            label: Text(
              task.isCOD
                  ? '${t('Collect', 'कैश लें', 'Collect')} ₹${task.totalAmount.toStringAsFixed(0)} & ${t('Mark Delivered', 'डिलीवरी पूरी करें', 'Mark Delivered')}'
                  : t('Mark Delivered (Prepaid)', 'डिलीवरी पूर्ण करें', 'Mark Delivered (Prepaid)'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
    );
  }

  Widget _buildLoginView(String Function(String, String, String) t) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          t('Delivery Partner Portal', 'डिलीवरी पार्टनर पोर्टल', 'Delivery Partner Portal'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.two_wheeler_rounded,
                      size: 64,
                      color: Color(0xFF0C831F),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  t('Zepto & Blinkit Express Fleet', 'एक्सप्रेस डिलीवरी पार्टनर', 'Express Delivery Fleet'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'Login to accept delivery tasks, route navigation & instant payouts',
                    'ऑर्डर डिलीवरी स्वीकार करने और नेविगेट करने के लिए लॉगिन करें',
                    'Delivery tasks accept karne aur navigate karne ke liye login karein',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _loginPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: t('Mobile Number', 'मोबाइल नंबर', 'Mobile Number'),
                    hintText: '9876543210',
                    prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF0C831F)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF0C831F), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _loginNameController,
                  decoration: InputDecoration(
                    labelText: t('Rider Full Name', 'डिलीवरी बॉय का पूरा नाम', 'Rider Full Name'),
                    hintText: 'e.g. Rahul Sharma',
                    prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF0C831F)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF0C831F), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoggingIn ? null : () => _handlePartnerLogin(t),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C831F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoggingIn
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            t('Start Delivering Now', 'ड्यूटी शुरू करें', 'Duty Shuru Karein'),
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
