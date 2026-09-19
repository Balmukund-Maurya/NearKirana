# Read the bottom part of the file (dialogs)
with open('lib/khata_screen.dart', 'r') as f:
    lines = f.readlines()

# find _showReceivePaymentDialog
start_idx = 0
for i, line in enumerate(lines):
    if 'void _showReceivePaymentDialog' in line:
        start_idx = i
        break

dialogs_code = "".join(lines[start_idx:])

header_and_body = '''import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'khata_statement_screen.dart';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
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
          'Grahak Ka Khata',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50), // Leaf Green
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerForm(context),
        backgroundColor: const Color(0xFFFF8C00), // Saffron Orange
        child: const Icon(Icons.add, color: Colors.white),
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
                        'Koi grahak nahi hai.',
                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _customers.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _customers.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        
                        final customer = _customers[index];
                        final data = customer.data() as Map<String, dynamic>;
                        
                        final String name = data['name'] ?? 'Unknown';
                        final String mobile = data['mobile'] ?? '';
                        final double udhaar = double.tryParse(data['total_udhaar']?.toString() ?? '0') ?? 0.0;
                        final bool autoReminder = data['auto_reminder'] ?? false;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 2,
                          color: Colors.white,
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
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            mobile,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Total Udhaar',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '₹$udhaar',
                                          style: GoogleFonts.poppins(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        final message = 'Namaste $name, Aditya Kirana se aapka pichla baaki bill ₹$udhaar hai. Kripya samay par jama karein.';
                                        String phone = mobile.replaceAll(RegExp(r'[^0-9]'), '');
                                        if (phone.length == 10) phone = '91$phone';
                                        
                                        final Uri url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
                                        
                                        try {
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Could not open WhatsApp.')),
                                            );
                                          }
                                        }
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.chat, color: Color(0xFF25D366), size: 24),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Reminder',
                                            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF25D366), fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showReceivePaymentDialog(context, customer.id, name, udhaar),
                                      icon: const Icon(Icons.currency_rupee, size: 16),
                                      label: const Text('Bhugtaan'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4CAF50),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                        minimumSize: const Size(0, 32),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => KhataStatementScreen(
                                              customerId: customer.id,
                                              customerName: name,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.receipt_long, size: 16),
                                      label: const Text('Statement'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF1976D2),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        minimumSize: const Size(0, 32),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Auto',
                                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                                        ),
                                        Switch(
                                          value: autoReminder,
                                          activeThumbColor: const Color(0xFF4CAF50),
                                          onChanged: (bool val) async {
                                            await FirebaseFirestore.instance
                                                .collection('customers')
                                                .doc(customer.id)
                                                .update({'auto_reminder': val});
                                            _refresh();
                                          },
                                        ),
                                      ],
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

with open('lib/khata_screen.dart', 'w') as f:
    f.write(header_and_body + dialogs_code)
