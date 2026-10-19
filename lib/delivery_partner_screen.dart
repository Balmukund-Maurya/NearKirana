import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'delivery_partner_models.dart';
import 'delivery_partner_service.dart';
import 'live_delivery_tracking_service.dart';
import 'customer_live_tracking_screen.dart';
import 'sound_service.dart';

/// Dedicated Delivery Partner Mode dashboard for delivery boys.
/// Handles order acceptance, store pickup confirmation, customer navigation,
/// and delivery completion with cash collection (COD) verification.
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

  // Login/Phone controller when no partner is logged in
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

  Future<void> _handlePartnerLogin() async {
    final phone = _loginPhoneController.text.trim();
    final name = _loginNameController.text.trim();

    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _isLoggingIn = true);
    try {
      var partner = await _service.getPartnerByPhone(phone);
      if (partner == null) {
        // Create new partner
        final newPartner = DeliveryPartner(
          id: '',
          shopId: '', // Can be claimed or associated with shop
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
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
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
          SnackBar(content: Text('Could not launch phone dialer: $phone')),
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
          SnackBar(content: Text('Could not open map navigation for: $address')),
        );
      }
    }
  }

  Future<void> _confirmPickup(DeliveryOrderTask task) async {
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

      // Feature 59: Start Live Location Broadcasting for active delivery
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.blue.shade700,
            content: Text('Pickup Confirmed! Order #${task.orderId.substring(task.orderId.length > 6 ? task.orderId.length - 6 : 0)} is now Out for Delivery.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _acceptTask(DeliveryOrderTask task) async {
    HapticFeedback.mediumImpact();
    try {
      await _service.acceptDeliveryTask(
        orderId: task.orderId,
        partnerId: _currentPartner?.id ?? task.partnerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Order accepted! Proceed to store for pickup.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showDeliveryCompletionDialog(DeliveryOrderTask task) async {
    bool codCollected = task.isCOD;
    final notesCtrl = TextEditingController(text: 'Delivered to customer');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Confirm Delivery',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mark Order as Completed?',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customer: ${task.customerName}\nAddress: ${task.deliveryAddress}',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMid),
                ),
                const SizedBox(height: 16),
                if (task.isCOD) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: codCollected,
                      onChanged: (val) {
                        setDialogState(() => codCollected = val ?? false);
                      },
                      title: Text(
                        'Cash on Delivery Collected: ₹${task.totalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: const Text('Ensure customer handed over exact cash'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Delivery Note (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
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

                    // Feature 59: Stop Live Location Broadcasting upon delivery completion
                    await _trackingService.stopBroadcasting(task.orderId, isDelivered: true);

                    SoundService().orderDelivered();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          content: Text('Delivery Completed Successfully! 🎉'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.error,
                          content: Text('Failed to complete delivery: $e'),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm Delivered'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentPartner == null) {
      return _buildLoginView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Partner Mode',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            Text(
              'डिलीवरी पार्टनर डैशबोर्ड',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMid),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textMid),
            tooltip: 'Switch Partner / Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Partner Profile Card & Duty Switch
          _buildPartnerHeaderCard(),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryDark,
              unselectedLabelColor: AppColors.textMid,
              indicatorColor: AppColors.primaryDark,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(
                  icon: Icon(Icons.electric_moped_rounded, size: 20),
                  text: 'Active Tasks',
                ),
                Tab(
                  icon: Icon(Icons.history_rounded, size: 20),
                  text: 'Delivery History',
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveTasksTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerHeaderCard() {
    final isOnline = _currentPartner?.isOnline ?? true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                child: const Icon(
                  Icons.sports_motorsports_rounded,
                  color: AppColors.primaryDark,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentPartner?.name ?? 'Delivery Partner',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '${_currentPartner?.phone ?? ''} • ${_currentPartner?.vehicleNumber.isNotEmpty == true ? _currentPartner!.vehicleNumber : 'Kirana Express'}',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Switch(
                    value: isOnline,
                    activeThumbColor: Colors.green,
                    onChanged: (val) => _toggleDutyStatus(val),
                  ),
                  Text(
                    isOnline ? 'On Duty' : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.green.shade800 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats Row
          Row(
            children: [
              _buildStatChip(
                icon: Icons.local_shipping_rounded,
                color: Colors.blue,
                label: 'Active',
                value: '${_currentPartner?.activeOrdersCount ?? 0}',
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                icon: Icons.check_circle_rounded,
                color: Colors.green,
                label: 'Delivered',
                value: '${_currentPartner?.totalDeliveredCount ?? 0}',
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                icon: Icons.payments_rounded,
                color: Colors.amber.shade800,
                label: 'COD Cash',
                value: '₹${(_currentPartner?.cashCollected ?? 0.0).toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textLight),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
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

  Widget _buildActiveTasksTab() {
    return StreamBuilder<List<DeliveryOrderTask>>(
      stream: _service.streamPartnerActiveTasks(_currentPartner!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
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
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 56,
                      color: Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Active Deliveries',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All dispatches completed! You will see new orders here as soon as the shopkeeper assigns them to you.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMid),
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
            return _buildTaskCard(tasks[index]);
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<DeliveryOrderTask>>(
      stream: _service.streamPartnerCompletedTasks(_currentPartner!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No delivery history yet',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textDark),
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
            final t = history[index];
            final shortId = t.orderId.length > 6
                ? t.orderId.substring(t.orderId.length - 6)
                : t.orderId;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.green.shade50,
                    child: Icon(Icons.check, color: Colors.green.shade700, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #$shortId • ${t.customerName}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.deliveryAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${t.totalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        t.isCOD ? 'COD Collected' : 'Paid Online',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: t.isCOD ? Colors.amber.shade900 : Colors.green.shade700,
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

  Widget _buildTaskCard(DeliveryOrderTask task) {
    final shortId = task.orderId.length > 6
        ? task.orderId.substring(task.orderId.length - 6)
        : task.orderId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Text(
                  'Order #$shortId',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                _buildTaskStatusBadge(task),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer & Address Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_pin_circle_rounded, color: Colors.deepOrange, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.customerName,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            task.deliveryAddress,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick Contact Buttons: Call & Maps
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: task.customerPhone.isNotEmpty
                            ? () => _launchCall(task.customerPhone)
                            : null,
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                        label: Text('Call (${task.customerPhone.length > 5 ? task.customerPhone.substring(task.customerPhone.length - 4) : '...' })'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchMap(task.deliveryAddress),
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: const Text('Directions'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal.shade700,
                          side: BorderSide(color: Colors.teal.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Items preview & Bill amount
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${task.itemsCount} Items in parcel',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
                          ),
                          if (task.itemsSummary.isNotEmpty)
                            Text(
                              task.itemsSummary.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
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
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            task.isCOD ? 'Collect Cash' : 'Prepaid',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: task.isCOD ? Colors.amber.shade900 : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Dedicated Workflow Action Button
                _buildWorkflowActionButton(task),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatusBadge(DeliveryOrderTask task) {
    Color bg;
    Color fg;
    String label;

    switch (task.deliveryTaskStatus) {
      case DeliveryTaskStatus.assigned:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = 'Assigned (नया)';
        break;
      case DeliveryTaskStatus.accepted:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = 'Accepted (दुकान से पिकअप लें)';
        break;
      case DeliveryTaskStatus.pickedUp:
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        label = 'Out for Delivery (रास्ते में)';
        break;
      case DeliveryTaskStatus.delivered:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Delivered';
        break;
      case DeliveryTaskStatus.cancelled:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildWorkflowActionButton(DeliveryOrderTask task) {
    // 1. If assigned: Accept Task
    if (task.deliveryTaskStatus == DeliveryTaskStatus.assigned) {
      return ElevatedButton.icon(
        onPressed: () => _acceptTask(task),
        icon: const Icon(Icons.thumb_up_alt_rounded),
        label: const Text('Accept Delivery Task (स्वीकार करें)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      );
    }

    // 2. If accepted: Confirm Store Pickup
    if (task.deliveryTaskStatus == DeliveryTaskStatus.accepted) {
      return ElevatedButton.icon(
        onPressed: () => _confirmPickup(task),
        icon: const Icon(Icons.inventory_2_rounded),
        label: const Text('Confirm Store Pickup (दुकान से पार्सल लिया)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      );
    }

    // 3. If picked up: Live location sharing status + Mark Delivered
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'लाइव GPS शेयरिंग चालू है (Live Location Active)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade900,
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
                label: const Text('मैप देखें'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green.shade900,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showDeliveryCompletionDialog(task),
          icon: const Icon(Icons.check_circle_rounded),
          label: Text(
            task.isCOD
                ? 'Collect ₹${task.totalAmount.toStringAsFixed(0)} & Mark Delivered'
                : 'Mark Delivered (सफल डिलीवरी)',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginView() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Delivery Partner Portal',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.two_wheeler_rounded,
                    size: 64,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Delivery Partner Login',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'डिलीवरी पार्टनर मोड में लॉग-इन करें और ऑर्डर्स रिसीव करें',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMid),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _loginPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (फोन नंबर)',
                    prefixIcon: const Icon(Icons.phone_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _loginNameController,
                  decoration: InputDecoration(
                    labelText: 'Partner Name (e.g. Rahul Sharma)',
                    prefixIcon: const Icon(Icons.person_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoggingIn ? null : _handlePartnerLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoggingIn
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Open Delivery Mode',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
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
