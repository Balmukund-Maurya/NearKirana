import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'shop_provider.dart';
import 'firebase_utils.dart';
import 'app_theme.dart';
import 'modern_loader.dart';
import 'widgets/admin_top_header.dart';
import 'receive_payment_screen.dart';
import 'admin_add_edit_customer_screen.dart';

class AdminCustomersDesktopView extends StatefulWidget {
  const AdminCustomersDesktopView({super.key});

  @override
  State<AdminCustomersDesktopView> createState() => _AdminCustomersDesktopViewState();
}

class _AdminCustomersDesktopViewState extends State<AdminCustomersDesktopView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<DocumentSnapshot> _customers = [];
  String _searchQuery = '';
  Timer? _debounce;
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;
  
  int _totalCustomers = 0;
  int _totalActive = 0;
  int _totalInactive = 0;
  double _totalUdhaar = 0.0;
  bool _isLoadingSummary = false;
  
  bool _showCustomerForm = false;
  DocumentSnapshot? _customerToEdit;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
    _fetchCustomers();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _fetchCustomers();
      }
    });
  }

  Future<void> _fetchSummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      final snapshot = await FirebaseUtils.firestore
          .collection('customers')
          .where('shop_ids', arrayContains: shopId)
          .get();
          
      int active = 0;
      int inactive = 0;
      double udhaar = 0.0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final isBanned = data['is_banned'] ?? false;
        if (isBanned) {
          inactive++;
        } else {
          active++;
        }
        udhaar += (data['shop_balances']?[shopId] as num?)?.toDouble() ?? 0.0;
      }
      
      if (mounted) {
        setState(() {
          _totalCustomers = snapshot.docs.length;
          _totalActive = active;
          _totalInactive = inactive;
          _totalUdhaar = udhaar;
        });
      }
    } catch (e) {
      debugPrint('Error fetching customer summary: $e');
    }
    if (mounted) {
      setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _fetchCustomers() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      Query q = FirebaseUtils.firestore.collection('customers').where('shop_ids', arrayContains: shopId);

      if (_searchQuery.isNotEmpty) {
        q = q
            .where('name', isGreaterThanOrEqualTo: _searchQuery)
            .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
      } else {
        q = q.orderBy('name');
      }

      q = q.limit(_limit);
      if (_lastDocument != null) {
        q = q.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await q.get();

      if (querySnapshot.docs.length < _limit) {
        _hasMore = false;
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _customers.addAll(querySnapshot.docs);
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _customers.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    _fetchSummary();
    await _fetchCustomers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showCustomerForm) {
      return AdminAddEditCustomerScreen(
        customer: _customerToEdit,
        onBack: () => setState(() => _showCustomerForm = false),
        onSaved: () {
          setState(() => _showCustomerForm = false);
          _refresh();
        },
      );
    }

    return Column(
      children: [
        const AdminTopHeader(),
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _buildMainContent(),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 3,
                    child: _buildRightPanel(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Manage Customers', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text('View and manage your customers', style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showCustomerForm = true;
                  _customerToEdit = null;
                });
              },
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
              label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10703B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Filter Row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildTextField('Search by name or phone...', Icons.search),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: _buildDropdown('All Status'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildCustomersTable(),
      ],
    );
  }

  Widget _buildTextField(String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          if (_debounce?.isActive ?? false) _debounce!.cancel();
          _debounce = Timer(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _searchQuery = val.trim();
                if (_searchQuery.isNotEmpty) {
                  _searchQuery = _searchQuery[0].toUpperCase() + _searchQuery.substring(1);
                }
              });
              _refresh();
            }
          });
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    setState(() => _searchQuery = '');
                    _refresh();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdown(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          ),
          Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600, size: 18),
        ],
      ),
    );
  }

  Widget _buildCustomersTable() {
    if (_customers.isEmpty && _isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(48), child: ModernLoader(color: AppColors.primaryDark)));
    }

    if (_customers.isEmpty && !_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 80),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_alt_rounded, size: 64, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No customers found.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customers (${_customers.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text('Your customer list and their account status', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          ),
          
          // Table Header
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
          
          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _customers.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
            itemBuilder: (context, index) {
              return _buildTableRow(_customers[index], index + 1);
            },
          ),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: ModernLoader(color: AppColors.primaryDark)),
            ),

          if (!_hasMore && _customers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Showing 1-${_customers.length} of ${_customers.length} customers', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  Row(
                    children: [
                      _buildPageButton(Icons.chevron_left, false),
                      const SizedBox(width: 8),
                      _buildPageButton('1', true),
                      const SizedBox(width: 8),
                      _buildPageButton(Icons.chevron_right, false),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageButton(dynamic content, bool isActive) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF10703B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? const Color(0xFF10703B) : Colors.grey.shade300),
      ),
      child: Center(
        child: content is String
            ? Text(content, style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w600))
            : Icon(content as IconData, color: Colors.grey.shade600, size: 20),
      ),
    );
  }

  Widget _buildTableRow(DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final String name = data['name'] ?? 'Unknown';
    final String initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
    final String phone = data['mobile'] ?? data['phone'] ?? 'Unknown';
    final bool isBanned = data['is_banned'] ?? false;
    final int nameChangeCount = (data['name_change_count'] as num?)?.toInt() ?? 0;
    
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    final double udhaar = (data['shop_balances']?[shopId] as num?)?.toDouble() ?? 0.0;
    final bool hasUdhaar = udhaar > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('$index', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          ),
          
          Expanded(
            flex: 4,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE8F5E9),
                  child: Text(initials, style: const TextStyle(color: Color(0xFF10703B), fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                          ),
                          if (nameChangeCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Edited', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('ID: ${doc.id.substring(0, 7).toUpperCase()}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.currency_rupee, size: 12, color: Color(0xFF10703B)),
                          const SizedBox(width: 4),
                          const Text('Receive', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF10703B))),
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
                    setState(() {
                      _showCustomerForm = true;
                      _customerToEdit = doc;
                    });
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
  }

  Widget _buildRightPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer Summary Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: Color(0xFF10703B)),
                  SizedBox(width: 8),
                  Text('Customer Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoadingSummary)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF10703B))))
              else
                Column(
                  children: [
                    Row(
                      children: [
                        _buildSummaryStatCard('Total\nCustomers', '$_totalCustomers', Icons.people_outline, const Color(0xFF10703B), const Color(0xFFE8F5E9)),
                        const SizedBox(width: 12),
                        _buildSummaryStatCard('Active\nCustomers', '$_totalActive', Icons.person_outline, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildSummaryStatCard('Inactive\nCustomers', '$_totalInactive', Icons.person_off_outlined, const Color(0xFFF97316), const Color(0xFFFFF7ED)),
                        const SizedBox(width: 12),
                        _buildSummaryStatCard('Total Udhaar\nBalance', '₹${_totalUdhaar.toStringAsFixed(0)}', Icons.account_balance_wallet_outlined, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Quick Actions Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: Color(0xFF1E293B), size: 22),
                  SizedBox(width: 8),
                  Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                ],
              ),
              const SizedBox(height: 20),
              _buildQuickAction(Icons.person_add_alt_1_outlined, 'Add New Customer', 'Create a new customer account', onTap: () {
                setState(() {
                  _showCustomerForm = true;
                  _customerToEdit = null;
                });
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String title, String subtitle, {bool isLast = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1E293B), size: 24),
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
}
