import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'shop_provider.dart';
import 'language_provider.dart';
import 'modern_loader.dart';
import 'animation_helpers.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'receive_payment_screen.dart';
import 'admin_add_edit_customer_screen.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<DocumentSnapshot> _customers = [];
  String _searchQuery = '';
  bool _isLoading = false;
  int _selectedFilter = 0; // 0: All, 1: With Udhaar, 2: Settled

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);

    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      if (shopId == null || shopId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Fetch without composite index requirements to avoid index missing errors
      final querySnapshot = await FirebaseUtils.firestore
          .collection('customers')
          .where('shop_ids', arrayContains: shopId)
          .get();

      final docs = querySnapshot.docs.toList();

      // Sort locally by name
      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aName = (aData['name'] ?? '').toString().toLowerCase();
        final bName = (bData['name'] ?? '').toString().toLowerCase();
        return aName.compareTo(bName);
      });

      _customers.clear();
      _customers.addAll(docs);
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    await _fetchCustomers();
  }

  Future<void> _callCustomer(String phone) async {
    if (phone.isEmpty) return;
    HapticFeedback.lightImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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

    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;

    // Calculate metrics
    final totalCount = _customers.length;
    final udhaarCount = _customers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final balances = data['shop_balances'] as Map<String, dynamic>?;
      double udhaar = 0.0;
      if (balances != null && shopId != null && balances.containsKey(shopId)) {
        udhaar = (balances[shopId] as num?)?.toDouble() ?? 0.0;
      } else {
        udhaar = (data['total_udhaar'] as num?)?.toDouble() ?? 0.0;
      }
      return udhaar > 0;
    }).length;
    final settledCount = totalCount - udhaarCount;

    // Filter customers
    List<DocumentSnapshot> filtered = _customers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final balances = data['shop_balances'] as Map<String, dynamic>?;
      double udhaar = 0.0;
      if (balances != null && shopId != null && balances.containsKey(shopId)) {
        udhaar = (balances[shopId] as num?)?.toDouble() ?? 0.0;
      } else {
        udhaar = (data['total_udhaar'] as num?)?.toDouble() ?? 0.0;
      }

      if (_selectedFilter == 1) return udhaar > 0;
      if (_selectedFilter == 2) return udhaar <= 0;
      return true; // 0 = All
    }).toList();

    // Apply search filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final phone = (data['phone'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

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
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('Customer Directory', 'ग्राहक सूची', 'Customer Directory'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  t('Accounts, bills & credit', 'खाता, उधारी व संपर्क', 'Accounts, bills & credit'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => AdminAddEditCustomerScreen(
                      onBack: () => Navigator.pop(ctx),
                      onSaved: () {
                        Navigator.pop(ctx);
                        _refresh();
                      },
                    ),
                  ),
                ).then((_) => _refresh());
              },
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: Text(
                t('Add', 'जोड़ें', 'Add'),
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
      body: Column(
        children: [
          // Top Controls (Search & Metric Filter Pills)
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
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: t(
                        'Search customer name or mobile...',
                        'ग्राहक का नाम या मोबाइल खोजें...',
                        'Customer name ya mobile se search karein...',
                      ),
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
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

                // 3 Filter Pills: All, With Udhaar, Settled
                Row(
                  children: [
                    _buildMetricFilterPill(
                      title: t('All Customers', 'सभी ग्राहक', 'All Customers'),
                      count: totalCount,
                      color: const Color(0xFF2563EB),
                      isSelected: _selectedFilter == 0,
                      onTap: () => setState(() => _selectedFilter = 0),
                    ),
                    _buildMetricFilterPill(
                      title: t('Pending Udhaar', 'बकाया उधारी', 'Pending Udhaar'),
                      count: udhaarCount,
                      color: const Color(0xFFDC2626),
                      isSelected: _selectedFilter == 1,
                      onTap: () => setState(() => _selectedFilter = 1),
                    ),
                    _buildMetricFilterPill(
                      title: t('Settled (₹0)', 'हिसाब चुकता', 'Settled (₹0)'),
                      count: settledCount,
                      color: const Color(0xFF0C831F),
                      isSelected: _selectedFilter == 2,
                      onTap: () => setState(() => _selectedFilter = 2),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Customer List
          Expanded(
            child: _isLoading
                ? const Center(child: ModernLoader(color: Color(0xFF2563EB)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.people_outline_rounded,
                                size: 54,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? t('No customer matches your search.', 'सर्च से मेल खाता कोई ग्राहक नहीं मिला।', 'Koi customer match nahi mila.')
                                  : t('No customers found in directory.', 'कोई ग्राहक सूची में नहीं है।', 'Directory me koi customer nahi hai.'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 250.ms)
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        color: const Color(0xFF2563EB),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final doc = filtered[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final String name = (data['name'] ?? 'Customer').toString().trim();
                            final String phone = (data['phone'] ?? '').toString().trim();
                            final bool isBanned = data['is_banned'] ?? false;

                            final balances = data['shop_balances'] as Map<String, dynamic>?;
                            double udhaar = 0.0;
                            if (balances != null && shopId != null && balances.containsKey(shopId)) {
                              udhaar = (balances[shopId] as num?)?.toDouble() ?? 0.0;
                            } else {
                              udhaar = (data['total_udhaar'] as num?)?.toDouble() ?? 0.0;
                            }
                            final bool hasUdhaar = udhaar > 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: hasUdhaar
                                      ? const Color(0xFFFCA5A5).withValues(alpha: 0.5)
                                      : const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
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
                                        // Initials Avatar
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Customer Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isBanned) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFEE2E2),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        t('Blocked', 'ब्लॉक', 'Blocked'),
                                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  const Icon(Icons.phone_rounded, size: 13, color: Color(0xFF64748B)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    phone.isNotEmpty ? phone : t('No phone', 'फ़ोन नंबर नहीं', 'No phone'),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Balance Pill
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              t('Udhaar Balance', 'बकाया उधारी', 'Udhaar Balance'),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: hasUdhaar
                                                    ? const Color(0xFFFEF2F2)
                                                    : const Color(0xFFECFDF5),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: hasUdhaar
                                                      ? const Color(0xFFFECACA)
                                                      : const Color(0xFFA7F3D0),
                                                ),
                                              ),
                                              child: Text(
                                                '₹${udhaar.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: hasUdhaar
                                                      ? const Color(0xFFDC2626)
                                                      : const Color(0xFF0C831F),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                                  // Action Buttons
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Call Action
                                        if (phone.isNotEmpty)
                                          InkWell(
                                            onTap: () => _callCustomer(phone),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.call_rounded, size: 16, color: Color(0xFF0C831F)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    t('Call', 'कॉल', 'Call'),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF0C831F),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        else
                                          const SizedBox.shrink(),

                                        Row(
                                          children: [
                                            // Receive Payment button
                                            if (hasUdhaar) ...[
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  HapticFeedback.mediumImpact();
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ReceivePaymentScreen(
                                                        customerId: doc.id,
                                                        customerName: name,
                                                        customerPhone: phone,
                                                      ),
                                                    ),
                                                  ).then((val) {
                                                    if (val == true) _refresh();
                                                  });
                                                },
                                                icon: const Icon(Icons.currency_rupee_rounded, size: 14),
                                                label: Text(
                                                  t('Receive', 'वसूलें', 'Receive'),
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF0C831F),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],

                                            // Edit Customer
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                HapticFeedback.lightImpact();
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (ctx) => AdminAddEditCustomerScreen(
                                                      customer: doc,
                                                      onBack: () => Navigator.pop(ctx),
                                                      onSaved: () {
                                                        Navigator.pop(ctx);
                                                        _refresh();
                                                      },
                                                    ),
                                                  ),
                                                ).then((_) => _refresh());
                                              },
                                              icon: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF475569)),
                                              label: Text(
                                                t('Edit', 'बदलें', 'Edit'),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ),
                                          ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildMetricFilterPill({
    required String title,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                    fontSize: 11,
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
