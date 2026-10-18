import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'khata_statement_screen.dart';
import 'admin_whatsapp_reminder_screen.dart';
import 'sound_service.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'language_provider.dart';
import 'package:near_kirana/firebase_utils.dart';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  int _selectedFilter = 0; // 0: All, 1: Pending Dues, 2: Settled

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      debugPrint('Error launching call: $e');
    }
  }

  Future<void> _sendWhatsAppReminder({
    required String phone,
    required String name,
    required double amount,
    required String shopName,
    required String Function(String en, String hi, String hinglish) t,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final fullPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final messageText = t(
      'Hello $name, a friendly reminder from $shopName that your outstanding balance is ₹${amount.toStringAsFixed(0)}. Please clear at your convenience. Thank you!',
      'नमस्ते $name जी, $shopName की ओर से आपका कुल उधार ₹${amount.toStringAsFixed(0)} बाकी है। कृपया समय पर भुगतान करने की कृपा करें। धन्यवाद!',
      'Namaste $name ji, $shopName ki taraf se aapka kul udhaar balance ₹${amount.toStringAsFixed(0)} baki hai. Kripya time par payment karein. Dhanyawad!',
    );
    final uri = Uri.parse('https://wa.me/$fullPhone?text=${Uri.encodeComponent(messageText)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  void _showAddOfflineKhataEntryDialog(BuildContext context) {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController(text: 'Dukan Se Kharid');

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          t('New Khata Entry', 'नया उधार दर्ज करें', 'New Khata Entry'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Phone field
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: t('Customer Phone (10 digits)', 'ग्राहक का मोबाइल नंबर (10 अंक)', 'Customer Phone (10 digits)'),
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        prefixIcon: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF0C831F), size: 20),
                        prefixText: '+91 ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF0C831F), width: 1.8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Name field
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: t('Customer Name', 'ग्राहक का नाम', 'Customer Name'),
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF0C831F), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF0C831F), width: 1.8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Amount field
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                      decoration: InputDecoration(
                        labelText: t('Udhaar Amount (₹)', 'उधार राशि (₹)', 'Udhaar Amount (₹)'),
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFFDC2626), size: 22),
                        filled: true,
                        fillColor: const Color(0xFFFEF2F2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFFECACA)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFFECACA)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick Amount Chips
                    Wrap(
                      spacing: 8,
                      children: [100, 200, 500, 1000, 2000].map((amt) {
                        return ActionChip(
                          label: Text('+₹$amt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            final cur = double.tryParse(amountController.text) ?? 0.0;
                            amountController.text = (cur + amt).toStringAsFixed(0);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Description field
                    TextField(
                      controller: descController,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: t('Description / Items', 'विवरण / सामान की जानकारी', 'Description / Items note'),
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF64748B), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF0C831F), width: 1.8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final phone = phoneController.text.trim();
                              final name = nameController.text.trim();
                              final amount = double.tryParse(amountController.text) ?? 0.0;
                              final desc = descController.text.trim();

                              if (phone.length != 10 || amount <= 0) {
                                HapticFeedback.heavyImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(t('Please enter 10-digit phone and valid amount', 'कृपया 10 अंकों का फोन और सही राशि भरें', 'Please enter 10-digit phone and valid amount')),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }

                              setState(() => isProcessing = true);

                              try {
                                final customerQuery = await FirebaseUtils.firestore
                                    .collection('customers')
                                    .where('mobile', isEqualTo: phone)
                                    .limit(1)
                                    .get();
                                final batch = FirebaseUtils.firestore.batch();
                                if (!context.mounted) return;
                                DocumentReference customerRef;

                                final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
                                if (shopId == null) return;

                                if (customerQuery.docs.isNotEmpty) {
                                  customerRef = customerQuery.docs.first.reference;
                                  batch.update(customerRef, {
                                    'shop_balances.$shopId': FieldValue.increment(amount),
                                    'total_udhaar': FieldValue.increment(amount),
                                    'shop_ids': FieldValue.arrayUnion([shopId]),
                                    if (name.isNotEmpty) 'name': name,
                                  });
                                } else {
                                  if (name.isEmpty) {
                                    setState(() => isProcessing = false);
                                    HapticFeedback.heavyImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(t('Customer name is required for new accounts', 'नए खाते के लिए ग्राहक का नाम अनिवार्य है', 'Customer name required for new khata')),
                                        backgroundColor: const Color(0xFFDC2626),
                                      ),
                                    );
                                    return;
                                  }
                                  customerRef = FirebaseUtils.firestore.collection('customers').doc();
                                  batch.set(customerRef, {
                                    'name': name,
                                    'mobile': phone,
                                    'total_udhaar': amount,
                                    'shop_balances': {shopId: amount},
                                    'shop_ids': [shopId],
                                    'auto_reminder': false,
                                    'created_at': FieldValue.serverTimestamp(),
                                  });
                                }

                                batch.set(
                                  customerRef.collection('khata_transactions').doc(),
                                  {
                                    'amount': amount,
                                    'type': 'debit',
                                    'shop_id': shopId,
                                    'description': desc.isNotEmpty ? desc : 'Offline Udhaar',
                                    'timestamp': FieldValue.serverTimestamp(),
                                  },
                                );

                                await batch.commit();

                                if (context.mounted) {
                                  Navigator.pop(dialogContext);
                                  SoundService().success();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(t('Khata entry recorded successfully', 'उधार खाता सफलतापूर्वक दर्ज हुआ', 'Khata entry added successfully')),
                                      backgroundColor: const Color(0xFF0C831F),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text('Error: $e'),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                }
                              } finally {
                                if (context.mounted) setState(() => isProcessing = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C831F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  t('Save Khata Entry', 'खाते में जोड़ें', 'Save Khata Entry'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleBanStatus(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final isBanned = data['is_banned'] ?? false;
    HapticFeedback.mediumImpact();
    try {
      await doc.reference.update({'is_banned': !isBanned});
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        final msg = isBanned
            ? (lang.isHindi ? 'ग्राहक अनब्लॉक हो गया' : 'Customer unblocked')
            : (lang.isHindi ? 'ग्राहक ब्लॉक हो गया' : 'Customer blocked');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
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

    final shopProvider = Provider.of<ShopProvider>(context);
    final shopId = shopProvider.currentShopId;
    final shopName = shopProvider.currentShopName;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.book_rounded,
                color: Color(0xFF0C831F),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Khata Ledger', 'ग्राहक बहीखाता', 'Khata Ledger'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  t('Digital Udhaar & Balance', 'डिजिटल उधारी व हिसाब-किताब', 'Digital Udhaar & Balance'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicatorPadding: const EdgeInsets.all(3),
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF0C831F),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: t('Offline Khata', 'उधार बहीखाता', 'Offline Khata')),
                  Tab(text: t('App Customers', 'ऑनलाइन ग्राहक', 'App Customers')),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_khata_screen',
        onPressed: () => _showAddOfflineKhataEntryDialog(context),
        backgroundColor: const Color(0xFF0C831F),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          t('Add Khata', 'खाता जोड़ें', 'Add Khata'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
      body: shopId == null || shopId.isEmpty
          ? Center(
              child: Text(
                t('Shop account not loaded', 'दुकान खाता लोड नहीं हुआ', 'Shop account not loaded'),
                style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseUtils.firestore
                  .collection('customers')
                  .where('shop_ids', arrayContains: shopId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFDC2626))),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: ModernLoader(color: Color(0xFF0C831F)));
                }

                final allDocs = List<DocumentSnapshot>.from(snapshot.data!.docs);
                allDocs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  final nameA = (dataA['name'] ?? '').toString().toLowerCase();
                  final nameB = (dataB['name'] ?? '').toString().toLowerCase();
                  return nameA.compareTo(nameB);
                });

          // Filter by search query
          final filteredDocs = allDocs.where((doc) {
            if (_searchQuery.isEmpty) return true;
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final mobile = (data['mobile'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || mobile.contains(query);
          }).toList();

          // Split into Online and Offline
          final onlineCustomers = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data.containsKey('pin');
          }).toList();

          final offlineCustomers = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return !data.containsKey('pin');
          }).toList();

          return Column(
            children: [
              // Search input
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: t('Search by customer name or phone...', 'ग्राहक का नाम या फोन नंबर खोजें...', 'Search customer name or phone...'),
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0C831F), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),

              // TabBar View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOfflineTab(context, offlineCustomers, shopId, shopName, t),
                    _buildOnlineTab(context, onlineCustomers, shopId, shopName, t),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOfflineTab(
    BuildContext context,
    List<DocumentSnapshot> customers,
    String? shopId,
    String shopName,
    String Function(String, String, String) t,
  ) {
    double totalMarketUdhaar = 0.0;
    int pendingDebtorCount = 0;

    for (var doc in customers) {
      final data = doc.data() as Map<String, dynamic>;
      final udhaar = ((data['shop_balances']?[shopId] ?? 0) as num).toDouble();
      if (udhaar > 0) {
        totalMarketUdhaar += udhaar;
        pendingDebtorCount++;
      }
    }

    // Filter by segment
    final displayedCustomers = customers.where((doc) {
      if (_selectedFilter == 0) return true;
      final data = doc.data() as Map<String, dynamic>;
      final udhaar = ((data['shop_balances']?[shopId] ?? 0) as num).toDouble();
      if (_selectedFilter == 1) return udhaar > 0;
      if (_selectedFilter == 2) return udhaar <= 0;
      return true;
    }).toList();

    return Column(
      children: [
        // Zepto/Blinkit Dark Slate/Emerald Analytics Summary Card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF87171), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t('Market Total Udhaar', 'मार्केट में कुल उधारी', 'Market Total Udhaar'),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline_rounded, color: Color(0xFFF87171), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '$pendingDebtorCount ${t('Accounts', 'खाते बाकी', 'Accounts')}',
                          style: const TextStyle(
                            color: Color(0xFFF87171),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹${totalMarketUdhaar.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t('Pending dues', 'वसूली बाकी', 'Pending dues'),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Quick action buttons inside card
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showAddOfflineKhataEntryDialog(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C831F),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              t('New Udhaar', 'नया उधार जोड़ें', 'New Udhaar'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminWhatsappReminderScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 14, color: Color(0xFF60A5FA)),
                            const SizedBox(width: 5),
                            Text(
                              t('Reminders', 'तगादा भेजें', 'Reminders'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),

        // 3 Filter Pills: All, Pending Dues, Settled
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              (0, t('All', 'सभी', 'All'), customers.length),
              (1, t('Pending Dues', 'बाकी रुपये', 'Pending Dues'), pendingDebtorCount),
              (2, t('Settled', 'हिसाब चुकता', 'Settled'), customers.length - pendingDebtorCount),
            ].map((tab) {
              final idx = tab.$1;
              final title = tab.$2;
              final count = tab.$3;
              final isSel = _selectedFilter == idx;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = idx);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF0C831F).withValues(alpha: 0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? const Color(0xFF0C831F) : const Color(0xFFE2E8F0),
                          width: isSel ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                              color: isSel ? const Color(0xFF0C831F) : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '($count)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSel ? const Color(0xFF0C831F) : const Color(0xFF94A3B8),
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
        ),

        // Customer Cards List
        Expanded(
          child: displayedCustomers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_search_rounded, size: 44, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('No customers in this list', 'कोई ग्राहक नहीं मिला', 'No customers in this list'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90, top: 6, left: 14, right: 14),
                  itemCount: displayedCustomers.length,
                  itemBuilder: (context, index) {
                    final doc = displayedCustomers[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String name = (data['name'] ?? 'Customer').toString();
                    final String mobile = (data['mobile'] ?? '').toString();
                    final double udhaar = ((data['shop_balances']?[shopId] ?? 0) as num).toDouble();
                    final bool isBanned = data['is_banned'] ?? false;

                    final bool hasDue = udhaar > 0;
                    final bool isAdvance = udhaar < 0;

                    final Color badgeColor = hasDue
                        ? const Color(0xFFDC2626)
                        : isAdvance
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF16A34A);

                    final String badgeLabel = hasDue
                        ? '${t('Due', 'बाकी', 'Due')}: ₹${udhaar.toStringAsFixed(0)}'
                        : isAdvance
                            ? '${t('Advance', 'जमा', 'Advance')}: ₹${(-udhaar).toStringAsFixed(0)}'
                            : t('Settled', 'चुकता', 'Settled');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasDue ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                          width: hasDue ? 1.4 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => KhataStatementScreen(
                                customerId: doc.id,
                                customerName: name,
                                isAdmin: true,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // Initial Avatar
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Name & Phone
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isBanned) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDC2626),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  t('Blocked', 'ब्लॉक', 'Blocked'),
                                                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          mobile.isNotEmpty ? '+91 $mobile' : t('No phone', 'फोन नंबर नहीं', 'No phone'),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Due Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      badgeLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 8),

                              // Quick Action Buttons Row
                              Row(
                                children: [
                                  // Call
                                  if (mobile.isNotEmpty)
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _makePhoneCall(mobile),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF0C831F)),
                                              const SizedBox(width: 4),
                                              Text(
                                                t('Call', 'कॉल', 'Call'),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0C831F)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (mobile.isNotEmpty && hasDue) ...[
                                    const SizedBox(width: 6),
                                    // WhatsApp Reminder
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _sendWhatsAppReminder(
                                          phone: mobile,
                                          name: name,
                                          amount: udhaar,
                                          shopName: shopName,
                                          t: t,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                                              const SizedBox(width: 4),
                                              Text(
                                                t('Reminder', 'तगादा', 'Reminder'),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  // Statement / Ledger
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => KhataStatementScreen(
                                              customerId: doc.id,
                                              customerName: name,
                                              isAdmin: true,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF475569)),
                                            const SizedBox(width: 4),
                                            Text(
                                              t('Ledger', 'बहीखाता', 'Ledger'),
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // More options (Block/Unblock)
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                                    onSelected: (val) {
                                      if (val == 'ban') _toggleBanStatus(doc);
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'ban',
                                        child: Text(
                                          isBanned
                                              ? t('Unblock Customer', 'ग्राहक अनब्लॉक करें', 'Unblock Customer')
                                              : t('Block Customer', 'ग्राहक ब्लॉक करें', 'Block Customer'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isBanned ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
  }

  Widget _buildOnlineTab(
    BuildContext context,
    List<DocumentSnapshot> customers,
    String? shopId,
    String shopName,
    String Function(String, String, String) t,
  ) {
    if (customers.isEmpty) {
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
              child: const Icon(Icons.devices_rounded, size: 44, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            Text(
              t('No app registered customers yet', 'कोई ऑनलाइन ऐप ग्राहक नहीं मिला', 'No app registered customers yet'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90, top: 12, left: 14, right: 14),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final doc = customers[index];
        final data = doc.data() as Map<String, dynamic>;
        final String name = (data['name'] ?? 'Customer').toString();
        final String mobile = (data['mobile'] ?? '').toString();
        final bool isBanned = data['is_banned'] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF0C831F).withValues(alpha: 0.1),
                  radius: 22,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0C831F)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t('App User', 'ऑनलाइन ग्राहक', 'App User'),
                              style: const TextStyle(fontSize: 9, color: Color(0xFF0C831F), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mobile.isNotEmpty ? '+91 $mobile' : t('No phone', 'फोन नंबर नहीं', 'No phone'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (mobile.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, color: Color(0xFF0C831F), size: 20),
                    tooltip: t('Call', 'कॉल', 'Call'),
                    onPressed: () => _makePhoneCall(mobile),
                  ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onSelected: (val) {
                    if (val == 'ban') _toggleBanStatus(doc);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'ban',
                      child: Text(
                        isBanned
                            ? t('Unblock Customer', 'ग्राहक अनब्लॉक करें', 'Unblock Customer')
                            : t('Block Customer', 'ग्राहक ब्लॉक करें', 'Block Customer'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isBanned ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
