import re

with open('lib/admin_customers_screen.dart', 'r') as f:
    lines = f.readlines()

# Find _showEditCustomerDialog
start_idx = 0
for i, line in enumerate(lines):
    if 'void _showEditCustomerDialog' in line:
        start_idx = i
        break

dialogs_code = "".join(lines[start_idx:])

header_and_body = '''import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<DocumentSnapshot> _customers = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _fetchCustomers();
      }
    });
  }

  Future<void> _fetchCustomers() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      Query q = FirebaseFirestore.instance.collection('customers');
      
      if (_searchQuery.isNotEmpty) {
        q = q.where('name', isGreaterThanOrEqualTo: _searchQuery)
             .where('name', isLessThanOrEqualTo: '$_searchQuery\\uf8ff');
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _customers.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchCustomers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          'Manage Customers',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                  if (_searchQuery.isNotEmpty) {
                    _searchQuery = _searchQuery[0].toUpperCase() + _searchQuery.substring(1);
                  }
                });
                _refresh();
              },
              decoration: InputDecoration(
                hintText: 'Search by Name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _customers.isEmpty && !_isLoading
                  ? Center(
                      child: Text(
                        'No customers found.',
                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _customers.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _customers.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        
                        final doc = _customers[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final String name = data['name'] ?? 'Unknown';
                        final String phone = data['phone'] ?? 'Unknown';
                        final bool isBanned = data['is_banned'] ?? false;
                        final double udhaar = (data['total_udhaar'] as num?)?.toDouble() ?? 0.0;

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            phone,
                                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Khata (Udhaar)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                                        Text('₹$udhaar', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                                      ],
                                    )
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Switch(
                                          value: isBanned,
                                          activeColor: Colors.red,
                                          onChanged: (val) async {
                                            await FirebaseFirestore.instance.collection('customers').doc(doc.id).update({
                                              'is_banned': val,
                                            });
                                            _refresh();
                                          },
                                        ),
                                        Text(
                                          isBanned ? 'Banned' : 'Active',
                                          style: GoogleFonts.poppins(
                                            color: isBanned ? Colors.red : Colors.green,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _showEditCustomerDialog(context, doc.id, name, phone),
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Edit Profile'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

'''

with open('lib/admin_customers_screen.dart', 'w') as f:
    f.write(header_and_body + dialogs_code)
