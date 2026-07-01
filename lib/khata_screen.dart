import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'khata_statement_screen.dart';
import 'app_theme.dart';
import 'sound_service.dart';
import 'modern_loader.dart';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddOfflineKhataEntryDialog(BuildContext context) {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController(text: 'Walk-in Store Purchase');

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
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppColors.bgTint,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'New Offline Khata',
                      style: AppTextStyles.heading2(color: AppColors.textDark),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: AppTextStyles.bodyMedium(color: AppColors.textDark),
                      decoration: InputDecoration(
                        labelText: 'Customer Phone (10 digits)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.phone_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: AppTextStyles.bodyMedium(color: AppColors.textDark),
                      decoration: InputDecoration(
                        labelText: 'Customer Name (if new)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.heading2(color: AppColors.textDark),
                      decoration: InputDecoration(
                        labelText: 'Udhaar Amount (₹)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(
                          Icons.currency_rupee_rounded,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      style: AppTextStyles.bodyMedium(color: AppColors.textDark),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.description_rounded),
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
                                HapticFeedback.heavyImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Enter valid 10-digit phone and amount > 0'), backgroundColor: AppColors.error),
                                );
                                return;
                              }

                              setState(() => isProcessing = true);

                              try {
                                final customerQuery = await FirebaseFirestore.instance.collection('customers').where('mobile', isEqualTo: phone).limit(1).get();
                                final batch = FirebaseFirestore.instance.batch();
                                DocumentReference customerRef;

                                if (customerQuery.docs.isNotEmpty) {
                                  customerRef = customerQuery.docs.first.reference;
                                  batch.update(customerRef, {
                                    'total_udhaar': FieldValue.increment(amount),
                                  });
                                } else {
                                  if (name.isEmpty) {
                                    setState(() => isProcessing = false);
                                    HapticFeedback.heavyImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Name is required for new customers!'), backgroundColor: AppColors.error),
                                    );
                                    return;
                                  }
                                  customerRef = FirebaseFirestore.instance.collection('customers').doc();
                                  batch.set(customerRef, {
                                    'name': name,
                                    'mobile': phone,
                                    'total_udhaar': amount,
                                    'auto_reminder': false,
                                    'created_at': FieldValue.serverTimestamp(),
                                  });
                                }

                                batch.set(
                                  customerRef.collection('khata_transactions').doc(),
                                  {
                                    'amount': amount,
                                    'type': 'debit',
                                    'description': desc.isNotEmpty ? desc : 'Offline Udhaar',
                                    'timestamp': FieldValue.serverTimestamp(),
                                  },
                                );

                                await batch.commit();

                                if (context.mounted) {
                                  Navigator.pop(dialogContext);
                                  SoundService().success();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Khata Entry Added Successfully!'), backgroundColor: AppColors.primaryDark),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error: $e'), backgroundColor: AppColors.error),
                                  );
                                }
                              } finally {
                                if (context.mounted) setState(() => isProcessing = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                            )
                          : Text('Add Entry', style: AppTextStyles.heading2(color: AppColors.white)),
                    ),
                    const SizedBox(height: 24),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(isBanned ? 'Customer unblocked' : 'Customer blocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Customers & Khata', style: AppTextStyles.heading2(color: AppColors.textDark)),
          backgroundColor: AppColors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primaryDark,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: 'Online'),
              Tab(text: 'Offline (Khata)'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddOfflineKhataEntryDialog(context),
          backgroundColor: AppColors.primaryDark,
          icon: const Icon(Icons.add_rounded, color: AppColors.white),
          label: Text('Add Offline Khata', style: AppTextStyles.bodySemiBold(color: AppColors.white)),
        ),
        body: Column(
          children: [
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  hintStyle: AppTextStyles.bodyMedium(color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textLight),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('customers').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: AppTextStyles.bodyMedium(color: AppColors.error)));
                  }
                  if (!snapshot.hasData) {
                    return Center(child: ModernLoader(color: AppColors.primaryDark));
                  }

                  final allDocs = snapshot.data!.docs;
                  
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

                  return TabBarView(
                    children: [
                      _buildOnlineTab(onlineCustomers),
                      _buildOfflineTab(offlineCustomers),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineTab(List<DocumentSnapshot> customers) {
    if (customers.isEmpty) {
      return Center(
        child: Text('No online customers found', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100, top: 16),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final doc = customers[index];
        final data = doc.data() as Map<String, dynamic>;
        final isBanned = data['is_banned'] ?? false;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
              radius: 24,
              child: Text(
                (data['name'] ?? '?')[0].toUpperCase(),
                style: AppTextStyles.heading2(color: AppColors.primaryDark),
              ),
            ),
            title: Text(data['name'] ?? 'Unknown', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 16)),
            subtitle: Text(data['mobile'] ?? '', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'ban') _toggleBanStatus(doc);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'ban',
                  child: Text(isBanned ? 'Unblock' : 'Block', style: AppTextStyles.bodyMedium(color: isBanned ? AppColors.success : AppColors.error)),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 50 * (index % 10))).slideX(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildOfflineTab(List<DocumentSnapshot> customers) {
    if (customers.isEmpty) {
      return Center(
        child: Text('No offline customers found', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100, top: 16),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final doc = customers[index];
        final data = doc.data() as Map<String, dynamic>;
        final udhaar = (data['total_udhaar'] ?? 0).toDouble();
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.bgTint),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
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
                    customerName: data['name'] ?? 'Unknown',
                    isAdmin: true,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    radius: 24,
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.orange),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['name'] ?? 'Unknown', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(data['mobile'] ?? '', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${udhaar.toStringAsFixed(0)}',
                        style: AppTextStyles.heading1(color: udhaar > 0 ? AppColors.error : AppColors.success).copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text('Balance', style: AppTextStyles.captionMedium(color: AppColors.textLight)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 50 * (index % 10))).slideX(begin: 0.1, end: 0);
      },
    );
  }
}
