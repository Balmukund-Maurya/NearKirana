import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/receive_payment_screen.dart';
import 'package:near_kirana/khata_statement_screen.dart';

class AdminKhataDesktopView extends StatefulWidget {
  const AdminKhataDesktopView({super.key});

  @override
  State<AdminKhataDesktopView> createState() => _AdminKhataDesktopViewState();
}

class _AdminKhataDesktopViewState extends State<AdminKhataDesktopView> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;

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

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _showAddOfflineKhataEntryDialog() {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController(text: 'Walk-in Store Purchase');

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('New Offline Khata', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogContext)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Customer Phone (10 digits)',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Customer Name (if new)',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Udhaar Amount (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee, color: Colors.red),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final phone = phoneController.text.trim();
                              final name = nameController.text.trim();
                              final amount = double.tryParse(amountController.text) ?? 0.0;
                              final desc = descController.text.trim();

                              if (phone.length != 10 || amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid input'), backgroundColor: Colors.red));
                                return;
                              }

                              setDialogState(() => isProcessing = true);

                              try {
                                final customerQuery = await FirebaseUtils.firestore.collection('customers').where('mobile', isEqualTo: phone).limit(1).get();
                                final batch = FirebaseUtils.firestore.batch();
                                DocumentReference customerRef;

                                final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
                                if (shopId == null) return;

                                if (customerQuery.docs.isNotEmpty) {
                                  customerRef = customerQuery.docs.first.reference;
                                  batch.update(customerRef, {
                                    'shop_balances.$shopId': FieldValue.increment(amount),
                                    'total_udhaar': FieldValue.increment(amount),
                                    'shop_ids': FieldValue.arrayUnion([shopId]),
                                  });
                                } else {
                                  if (name.isEmpty) {
                                    setDialogState(() => isProcessing = false);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name required for new customer'), backgroundColor: Colors.red));
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

                                if (mounted) {
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Khata entry added successfully'), backgroundColor: Color(0xFF10703B)));
                                  _refresh();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                }
                              } finally {
                                if (mounted) setDialogState(() => isProcessing = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10703B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    if (shopId == null) return const Center(child: Text('Loading shop...'));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light warm/gray background
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseUtils.firestore.collection('customers').where('shop_ids', arrayContains: shopId).orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allDocs = snapshot.data?.docs ?? [];
          final filteredDocs = allDocs.where((doc) {
            if (_searchQuery.isEmpty) return true;
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final mobile = (data['mobile'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || mobile.contains(query);
          }).toList();

          final onlineCustomers = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data.containsKey('pin');
          }).toList();

          final offlineCustomers = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return !data.containsKey('pin');
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: Main Content
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer Ledger',
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Track and manage customer credit (khata)',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _showAddOfflineKhataEntryDialog,
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Add Offline Khata', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10703B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Tabs
                      Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 2)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: const Color(0xFF10703B),
                          unselectedLabelColor: Colors.grey.shade600,
                          indicatorColor: const Color(0xFF10703B),
                          indicatorWeight: 3,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          tabs: const [
                            Tab(text: 'Online'),
                            Tab(text: 'Offline (Khata)'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Search Toolbar
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                decoration: InputDecoration(
                                  hintText: 'Search by name or phone...',
                                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Text('All Status', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                                const SizedBox(width: 24),
                                Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500, size: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Main Table Container
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Table Header
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Customers (${filteredDocs.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                    const SizedBox(height: 4),
                                    Text('Manage customer khata accounts and credit balances', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.symmetric(horizontal: BorderSide(color: Colors.grey.shade100)),
                                  color: const Color(0xFFF8FAFC),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: 30, child: Text('#', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 4, child: Text('Customer Details', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 3, child: Text('Contact', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 3, child: Text('Status', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 3, child: Text('Balance (Udhaar)', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 3, child: Text('Actions', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                                  ],
                                ),
                              ),

                              // Table Body inside TabBarView
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _buildCustomerList(onlineCustomers, shopId),
                                    _buildCustomerList(offlineCustomers, shopId),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // Right Panel: Summary & Actions
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Khata Summary Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bar_chart, color: Color(0xFF10703B)),
                                  const SizedBox(width: 8),
                                  const Text('Khata Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              Builder(builder: (context) {
                                int totalActive = 0;
                                int totalInactive = 0;
                                double totalUdhaar = 0;

                                for (var doc in filteredDocs) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final isBanned = data['is_banned'] ?? false;
                                  if (isBanned) {
                                    totalInactive++;
                                  } else {
                                    totalActive++;
                                  }
                                  final udhaar = (data['shop_balances']?[shopId] ?? 0).toDouble();
                                  totalUdhaar += udhaar;
                                }

                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        _buildSummaryStatCard('Total\nCustomers', '${filteredDocs.length}', Icons.people_outline, const Color(0xFF10703B), const Color(0xFFE8F5E9)),
                                        const SizedBox(width: 12),
                                        _buildSummaryStatCard('Active\nKhata', '$totalActive', Icons.account_balance_wallet_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _buildSummaryStatCard('Inactive\nKhata', '$totalInactive', Icons.person_off_outlined, const Color(0xFFF97316), const Color(0xFFFFF7ED)),
                                        const SizedBox(width: 12),
                                        _buildSummaryStatCard('Total Udhaar\nBalance', '₹${totalUdhaar.toStringAsFixed(0)}', Icons.currency_rupee_rounded, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Quick Actions
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bolt, color: Color(0xFF1E293B)),
                                  const SizedBox(width: 8),
                                  const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildQuickAction(
                                icon: Icons.person_add_outlined,
                                title: 'Add Offline Khata',
                                subtitle: 'Create a new customer khata account',
                                onTap: _showAddOfflineKhataEntryDialog,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomerList(List<DocumentSnapshot> customers, String shopId) {
    if (customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No customers found', style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: customers.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        final doc = customers[index];
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'Unknown';
        final phone = data['mobile'] ?? '';
        final isBanned = data['is_banned'] ?? false;
        final udhaar = (data['shop_balances']?[shopId] ?? 0).toDouble();
        final hasUdhaar = udhaar > 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text('${index + 1}', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              ),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFE8F5E9),
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF10703B), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('ID: ${doc.id.substring(0, 6).toUpperCase()}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Flexible(child: Text(phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Switch(
                        value: !isBanned,
                        activeColor: const Color(0xFF10703B),
                        onChanged: (val) async {
                          await FirebaseUtils.firestore.collection('customers').doc(doc.id).update({'is_banned': !val});
                          _refresh();
                        },
                      ),
                      Text(!isBanned ? 'Active' : 'Inactive', style: TextStyle(color: !isBanned ? const Color(0xFF10703B) : Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text('₹${udhaar.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: hasUdhaar ? Colors.red : const Color(0xFF10703B))),
                    if (hasUdhaar)
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReceivePaymentScreen(
                                customerId: doc.id,
                                customerName: name,
                                customerPhone: phone,
                              ),
                            ),
                          ).then((value) {
                            if (value == true) _refresh();
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.currency_rupee, size: 12, color: Color(0xFF10703B)),
                              SizedBox(width: 4),
                              Text('Receive', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF10703B))),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => KhataStatementScreen(
                              customerId: doc.id,
                              customerName: name,
                              isAdmin: true,
                            ),
                          ),
                        ).then((_) => _refresh());
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text('Edit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF2563EB))),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryStatCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                  Text(title, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700, height: 1.1), maxLines: 2, overflow: TextOverflow.visible),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.grey.shade700, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: Colors.grey.shade400, size: 16),
          ],
        ),
      ),
    );
  }
}
