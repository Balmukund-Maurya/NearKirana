import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'shop_provider.dart';
import 'language_provider.dart';
import 'delivery_partner_models.dart';
import 'delivery_partner_service.dart';
import 'sound_service.dart';
import 'modern_loader.dart';
import 'animation_helpers.dart';

class AdminShopBoysScreen extends StatefulWidget {
  const AdminShopBoysScreen({super.key});

  @override
  State<AdminShopBoysScreen> createState() => _AdminShopBoysScreenState();
}

class _AdminShopBoysScreenState extends State<AdminShopBoysScreen> {
  final DeliveryPartnerService _service = DeliveryPartnerService();
  final FocusNode _searchFocusNode = FocusNode();
  Stream<List<DeliveryPartner>>? _partnersStream;
  String? _lastShopId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shopId = Provider.of<ShopProvider>(context).currentShopId ?? '';
    if (_lastShopId != shopId || _partnersStream == null) {
      _lastShopId = shopId;
      _partnersStream = _service.streamShopPartners(shopId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _callPartner(String phone) async {
    if (phone.isEmpty) return;
    HapticFeedback.lightImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _togglePartnerStatus(DeliveryPartner partner) async {
    HapticFeedback.selectionClick();
    final nextStatus = partner.isOnline
        ? DeliveryPartnerStatus.offline
        : DeliveryPartnerStatus.available;

    final updated = partner.copyWith(status: nextStatus);
    await _service.registerOrUpdatePartner(updated);
    SoundService().play('switch.mp3');
  }

  Future<void> _showAddPartnerDialog(BuildContext context, String Function(String, String, String) t) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFEA580C), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t('Add Delivery Partner', 'नया डिलीवरी बॉय जोड़ें', 'Add Delivery Partner'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: t('Full Name', 'पूरा नाम', 'Full Name'),
                  hintText: 'e.g. Rahul Verma',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: t('Mobile Number (10 Digits)', 'मोबाइल नंबर (10 अंक)', 'Mobile Number (10 Digits)'),
                  hintText: '9876543210',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vehicleCtrl,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: t('Vehicle Number / Model', 'गाड़ी का नंबर / मॉडल', 'Vehicle Number / Model'),
                  hintText: 'e.g. MP04 AB 1234 / Honda Activa',
                  prefixIcon: const Icon(Icons.motorcycle_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    if (name.isEmpty || phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t('Please enter name and mobile number', 'कृपया नाम और मोबाइल नंबर दर्ज करें', 'Please enter name and phone')),
                          backgroundColor: const Color(0xFFDC2626),
                        ),
                      );
                      return;
                    }

                    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId ?? '';
                    final partner = DeliveryPartner(
                      id: '',
                      shopId: shopId,
                      name: name,
                      phone: phone,
                      vehicleNumber: vehicleCtrl.text.trim(),
                      status: DeliveryPartnerStatus.available,
                      createdAt: DateTime.now(),
                    );

                    await _service.registerOrUpdatePartner(partner);
                    SoundService().success();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    t('Save Partner', 'पार्टनर सेव करें', 'Save Partner'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C831F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    final shopId = Provider.of<ShopProvider>(context).currentShopId ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.two_wheeler_rounded,
                color: Color(0xFFEA580C),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t('Delivery Fleet & Dispatch', 'डिलीवरी स्टाफ व डिस्पैच', 'Delivery Fleet & Dispatch'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    t('Manage riders & orders dispatch', 'डिलीवरी बॉय प्रबंधन व रूट', 'Manage riders & dispatch'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showAddPartnerDialog(context, t),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: Text(
                t('Add Rider', 'राइडर जोड़ें', 'Add Rider'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C831F),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<DeliveryPartner>>(
        stream: _partnersStream ?? _service.streamShopPartners(shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: ModernLoader(color: Color(0xFFEA580C)));
          }

          final allPartners = snapshot.data ?? [];

          // Counts for metric cards
          final totalFleet = allPartners.length;
          final availableCount = allPartners.where((p) => p.status == DeliveryPartnerStatus.available).length;
          final onDeliveryCount = allPartners.where((p) => p.status == DeliveryPartnerStatus.onDelivery).length;
          final offlineCount = allPartners.where((p) => p.status == DeliveryPartnerStatus.offline).length;

          // Filter by status pill
          List<DeliveryPartner> filtered = allPartners.where((p) {
            if (_selectedFilter == 1) return p.status == DeliveryPartnerStatus.available;
            if (_selectedFilter == 2) return p.status == DeliveryPartnerStatus.onDelivery;
            if (_selectedFilter == 3) return p.status == DeliveryPartnerStatus.offline;
            return true; // 0 = All
          }).toList();

          // Filter by search query
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.trim().toLowerCase();
            filtered = filtered.where((p) {
              return p.name.toLowerCase().contains(q) ||
                  p.phone.toLowerCase().contains(q) ||
                  p.vehicleNumber.toLowerCase().contains(q);
            }).toList();
          }

          return Column(
            children: [
              // Top Controls: Search Bar & Metric Cards
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: t(
                            'Search rider name, phone or vehicle...',
                            'राइडर का नाम, फ़ोन या गाड़ी नंबर खोजें...',
                            'Rider name, phone ya vehicle se search karein...',
                          ),
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFEA580C), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 4 Filter Metric Cards
                    Row(
                      children: [
                        _buildFilterPill(
                          title: t('All Fleet', 'सभी स्टाफ', 'All Fleet'),
                          count: totalFleet,
                          color: const Color(0xFF0C831F),
                          isSelected: _selectedFilter == 0,
                          onTap: () => setState(() => _selectedFilter = 0),
                        ),
                        _buildFilterPill(
                          title: t('Available', 'ड्यूटी पर', 'Available'),
                          count: availableCount,
                          color: const Color(0xFF16A34A),
                          isSelected: _selectedFilter == 1,
                          onTap: () => setState(() => _selectedFilter = 1),
                        ),
                        _buildFilterPill(
                          title: t('On Delivery', 'डिलीवरी पर', 'On Route'),
                          count: onDeliveryCount,
                          color: const Color(0xFF2563EB),
                          isSelected: _selectedFilter == 2,
                          onTap: () => setState(() => _selectedFilter = 2),
                        ),
                        _buildFilterPill(
                          title: t('Offline', 'ऑफलाइन', 'Offline'),
                          count: offlineCount,
                          color: const Color(0xFF64748B),
                          isSelected: _selectedFilter == 3,
                          onTap: () => setState(() => _selectedFilter = 3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Fleet List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.two_wheeler_rounded, size: 54, color: Color(0xFFEA580C)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? t('No delivery partner matches search.', 'सर्च से मेल खाता कोई डिलीवरी बॉय नहीं मिला।', 'No partner matches search.')
                                  : t('No delivery partners added yet.', 'अभी कोई डिलीवरी बॉय नहीं जोड़ा गया है।', 'No delivery boys added yet.'),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showAddPartnerDialog(context, t),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(t('Add Delivery Partner', 'डिलीवरी बॉय जोड़ें', 'Add Delivery Partner')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0C831F),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 250.ms)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final partner = filtered[index];
                          final isOnline = partner.isOnline;
                          final statusColor = partner.status == DeliveryPartnerStatus.available
                              ? const Color(0xFF16A34A)
                              : partner.status == DeliveryPartnerStatus.onDelivery
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF64748B);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Rider Avatar
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.two_wheeler_rounded,
                                            color: isOnline ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Rider Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    partner.name,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                                  ),
                                                  child: Text(
                                                    lang.isHindi
                                                        ? partner.status.hindiLabel
                                                        : partner.status.label.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              partner.vehicleNumber.isNotEmpty
                                                  ? '${partner.phone} • ${partner.vehicleNumber}'
                                                  : partner.phone,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Duty Switch
                                      Transform.scale(
                                        scale: 0.8,
                                        child: Switch(
                                          value: isOnline,
                                          activeThumbColor: const Color(0xFF0C831F),
                                          onChanged: (_) => _togglePartnerStatus(partner),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                                // Stats & Actions Footer
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Total Deliveries Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF0C831F)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${partner.totalDeliveredCount} ${t('Delivered', 'डिलीवरी', 'Delivered')}',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Call Rider Button
                                      OutlinedButton.icon(
                                        onPressed: () => _callPartner(partner.phone),
                                        icon: const Icon(Icons.call_rounded, size: 14, color: Color(0xFF0C831F)),
                                        label: Text(
                                          t('Call Rider', 'कॉल करें', 'Call Rider'),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0C831F)),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                                          backgroundColor: const Color(0xFFECFDF5),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).fadeSlideUp(delay: 20 * (index % 10));
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterPill({
    required String title,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : const Color(0xFFE2E8F0),
                width: isSelected ? 1.6 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? color : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
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
