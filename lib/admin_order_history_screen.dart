import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'modern_loader.dart';
import 'package:near_kirana/firebase_utils.dart';

class AdminOrderHistoryScreen extends StatefulWidget {
  const AdminOrderHistoryScreen({super.key});

  @override
  State<AdminOrderHistoryScreen> createState() =>
      _AdminOrderHistoryScreenState();
}

class _AdminOrderHistoryScreenState extends State<AdminOrderHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<DocumentSnapshot> _orders = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 50;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchOrders();
      }
    });
  }

  Future<void> _fetchOrders() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query q = FirebaseUtils.firestore
          .collection('orders')
          .where('status', whereIn: ['Delivered', 'Cancelled'])
          .orderBy('created_at', descending: true)
          .limit(_limit);

      if (_lastDocument != null) {
        q = q.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await q.get();

      if (querySnapshot.docs.length < _limit) {
        _hasMore = false;
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _orders.addAll(querySnapshot.docs);
      }

      // FIX-16: Auto-fetch more if search yields too few results
      if (_searchQuery.isNotEmpty && _hasMore) {
        final filteredCount = _orders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['customer_name'] ?? '').toString().toLowerCase();
          final phone = (data['phone_number'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || phone.contains(_searchQuery);
        }).length;

        if (filteredCount < 5) {
          _isLoading = false; // Reset lock
          return await _fetchOrders(); // Recursively fetch next page
        }
      }
    } catch (e) {
      debugPrint('Error fetching order history: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _orders.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchOrders();
  }

  Color _getStatusColor(String status) {
    if (status == 'Delivered') return Colors.green;
    if (status == 'Cancelled') return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Order History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
                _refresh(); // FIX-16: Auto-trigger search on typing
              },
              decoration: InputDecoration(
                hintText: 'Search by Name or Phone...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _refresh(); // FIX-16: Refresh list on clear
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                ),
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final filteredOrders = _orders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['customer_name'] ?? '')
                      .toString()
                      .toLowerCase();
                  final phone = (data['phone_number'] ?? '')
                      .toString()
                      .toLowerCase();
                  return name.contains(_searchQuery) ||
                      phone.contains(_searchQuery);
                }).toList();

                if (filteredOrders.isEmpty && _isLoading) {
                  return const Center(child: ModernLoader());
                } else if (filteredOrders.isEmpty) {
                  return Center(
                    child: Text(
                      'Koi order nahi mila.',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == filteredOrders.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: ModernLoader()),
                        );
                      }

                      final doc = filteredOrders[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final createdAt = data['created_at'] as Timestamp?;
                      final dateString = createdAt != null
                          ? DateFormat(
                              'dd MMM yyyy, hh:mm a',
                            ).format(createdAt.toDate())
                          : 'Unknown Date';

                      final status = data['status'] ?? 'Unknown';
                      final customerName = data['customer_name'] ?? 'Unknown';
                      final phone = data['phone_number'] ?? 'Unknown';
                      final totalAmount = data['total_amount'] ?? 0.0;
                      final deliveryType = data['delivery_type'] ?? 'Pickup';
                      final String? deliveryAddress = data['delivery_address'];
                      final double? customerLat = (data['customer_lat'] as num?)
                          ?.toDouble();
                      final double? customerLng = (data['customer_lng'] as num?)
                          ?.toDouble();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      customerName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        status,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                    child: Text(
                                      status,
                                      style: GoogleFonts.poppins(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Phone: $phone',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Date: $dateString',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Type: $deliveryType',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                              if (data.containsKey('delivery_boy_name')) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Delivery By: ${data['delivery_boy_name']}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.blue.shade700,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],

                              if (deliveryType == 'Delivery' &&
                                  (deliveryAddress != null ||
                                      customerLat != null)) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Colors.blue,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          deliveryAddress ??
                                              'Location provided via GPS',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () async {
                                          Uri url;
                                          if (customerLat != null &&
                                              customerLng != null) {
                                            url = Uri.parse(
                                              'https://www.google.com/maps/dir/?api=1&destination=$customerLat,$customerLng',
                                            );
                                          } else if (deliveryAddress != null) {
                                            url = Uri.parse(
                                              'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(deliveryAddress)}',
                                            );
                                          } else {
                                            return;
                                          }
                                          try {
                                            await launchUrl(
                                              url,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                                    'Could not open Maps.',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons.map,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Divider(height: 24),
                              Text(
                                'Total: ₹$totalAmount',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
