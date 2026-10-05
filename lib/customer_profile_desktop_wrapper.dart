import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_provider.dart';
import 'shop_provider.dart';
import 'app_theme.dart';
import 'firebase_utils.dart';
import 'utils/product_image_widget.dart';
import 'khata_statement_screen.dart';
import 'desktop_order_details_view.dart';
import 'desktop_order_tracking_view.dart';

class CustomerProfileDesktopWrapper extends StatefulWidget {
  const CustomerProfileDesktopWrapper({super.key});

  @override
  State<CustomerProfileDesktopWrapper> createState() => _CustomerProfileDesktopWrapperState();
}

class _CustomerProfileDesktopWrapperState extends State<CustomerProfileDesktopWrapper> {
  bool _isLoading = true;
  Map<String, dynamic>? _customerData;
  String? _customerId;
  List<DocumentSnapshot> _orders = [];
  List<DocumentSnapshot> _payments = [];

  // Stats
  double _currentBalance = 0;
  double _totalUdhaar = 0;
  int _totalOrders = 0;
  int _deliveredOrders = 0;
  int _inProgressOrders = 0;
  int _cancelledOrders = 0;
  double _totalSpent = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCustomerData();
    });
  }

  Future<void> _fetchCustomerData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final phone = userProvider.phoneNumber;
      final shopId = shopProvider.currentShopId;

      if (phone.isNotEmpty) {
        // Fetch customer document (Khata)
        final customerQuery = await FirebaseUtils.firestore
            .collection('customers')
            .where('mobile', isEqualTo: phone)
            .limit(1)
            .get();

        if (customerQuery.docs.isNotEmpty) {
          final doc = customerQuery.docs.first;
          _customerId = doc.id;
          _customerData = doc.data();

          if (shopId != null) {
            final balances = _customerData!['shop_balances'] as Map<String, dynamic>?;
            if (balances != null && balances.containsKey(shopId)) {
              _currentBalance = (balances[shopId] as num).toDouble();
            }
            
            // Fetch Payments
            final paymentsQuery = await doc.reference
                .collection('khata_transactions')
                .where('shop_id', isEqualTo: shopId)
                .where('type', isEqualTo: 'credit')
                .orderBy('timestamp', descending: true)
                .limit(10)
                .get();
            _payments = paymentsQuery.docs;
          }
          _totalUdhaar = (_customerData!['total_udhaar'] as num?)?.toDouble() ?? 0;
        }

        // Fetch Orders
        if (shopId != null) {
          final ordersQuery = await FirebaseUtils.firestore
              .collection('orders')
              .where('shop_id', isEqualTo: shopId)
              .where('user_phone', isEqualTo: phone)
              .orderBy('timestamp', descending: true)
              .limit(50)
              .get();

          _orders = ordersQuery.docs;
          _totalOrders = _orders.length;

          for (var doc in _orders) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? '';
            final amount = (data['total_amount'] as num?)?.toDouble() ?? 0;

            if (status.toLowerCase() == 'delivered') {
              _deliveredOrders++;
              _totalSpent += amount;
            } else if (status.toLowerCase() == 'cancelled') {
              _cancelledOrders++;
            } else {
              _inProgressOrders++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching desktop customer details: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToKhataStatement() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (_customerId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KhataStatementScreen(
            customerId: _customerId!,
            customerName: userProvider.customerName.isEmpty ? 'Guest' : userProvider.customerName,
            isAdmin: false,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Khata not found.')));
    }
  }

  void _navigateToEditProfile() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit Customer is not available yet.')),
    );
  }

  Future<void> _openWhatsApp() async {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    String phone = shopProvider.shopSupportPhone?.toString() ?? shopProvider.shopMobile?.toString() ?? '';
    phone = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 10) phone = '91$phone';
    if (phone.isEmpty) return;

    final Uri launchUri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openDialer() async {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    String phone = shopProvider.shopSupportPhone?.toString() ?? shopProvider.shopMobile?.toString() ?? '';
    phone = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 10) phone = '91$phone';
    if (phone.isEmpty) return;

    final Uri launchUri = Uri(scheme: 'tel', path: '+$phone');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final userProvider = Provider.of<UserProvider>(context);

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CENTER COLUMN
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(userProvider),
                  const SizedBox(height: 32),
                  _buildProfileCard(userProvider),
                  const SizedBox(height: 24),
                  _buildCustomerInformation(userProvider),
                  const SizedBox(height: 24),
                  _buildRecentOrders(),
                ],
              ),
            ),
          ),

          // RIGHT COLUMN
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.only(top: 32, right: 32, bottom: 32, left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKhataSummary(),
                  const SizedBox(height: 24),
                  _buildOrderSummary(),
                  const SizedBox(height: 24),
                  _buildPaymentHistory(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(UserProvider user) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back, size: 16),
                    SizedBox(width: 8),
                    Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Customer Details', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text('View customer information, orders and Khata details', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                ],
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionButton(Icons.edit, 'Edit Customer', _navigateToEditProfile, isPrimary: false),
            _buildActionButton(Icons.chat_bubble_outline, 'WhatsApp', _openWhatsApp, color: Colors.green),
            _buildActionButton(Icons.phone_outlined, 'Call', _openDialer, color: Colors.green.shade700),
          ],
        )
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {Color? color, bool isPrimary = true}) {
    final btnColor = color ?? Colors.black87;
    final borderColor = isPrimary ? btnColor.withValues(alpha: 0.3) : Colors.grey.shade300;
    
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: btnColor),
      label: Text(label, style: TextStyle(color: btnColor, fontWeight: FontWeight.w600, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: btnColor,
        side: BorderSide(color: borderColor),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  Widget _buildProfileCard(UserProvider user) {
    final createdRaw = _customerData?['created_at'];
    String createdStr = '';
    if (createdRaw is Timestamp) {
      createdStr = DateFormat('dd MMM yyyy').format(createdRaw.toDate());
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryLight.withValues(alpha: 0.2)),
            child: ClipOval(
              child: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
                  ? ProductImageWidget(imageUrl: user.profileImageUrl, width: 90, height: 90)
                  : const Icon(Icons.person, size: 45, color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.customerName.isEmpty ? 'Guest' : user.customerName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(100)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('Active', style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text(user.phoneNumber, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 16, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text('rahul.kumar@example.com', style: const TextStyle(color: Colors.black87, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text('Customer since ${createdStr.isEmpty ? "15 Jan 2024" : createdStr}', style: const TextStyle(color: Colors.black87, fontSize: 13)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCustomerInformation(UserProvider user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customer Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _navigateToEditProfile,
                icon: const Icon(Icons.edit, size: 14, color: Colors.black87),
                label: const Text('Edit Information', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Full Name', user.customerName.isEmpty ? 'Guest' : user.customerName),
          const SizedBox(height: 16),
          _buildInfoRow('Phone Number', user.phoneNumber),
          const SizedBox(height: 16),
          _buildInfoRow('Email Address', 'N/A'),
          const SizedBox(height: 16),
          _buildInfoRow('Address', user.deliveryAddress.isEmpty ? 'N/A' : user.deliveryAddress),
          const SizedBox(height: 16),
          _buildInfoRow('City', 'N/A'),
          const SizedBox(height: 16),
          _buildInfoRow('State', 'N/A'),
          const SizedBox(height: 16),
          _buildInfoRow('Postal Code', 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Row(
            children: [
              Icon(_getIconForLabel(label), size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        )
      ],
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Full Name': return Icons.person_outline;
      case 'Phone Number': return Icons.phone_outlined;
      case 'Email Address': return Icons.email_outlined;
      case 'Address': return Icons.location_on_outlined;
      case 'City': return Icons.location_city_outlined;
      case 'State': return Icons.map_outlined;
      case 'Postal Code': return Icons.local_post_office_outlined;
      default: return Icons.info_outline;
    }
  }

  Widget _buildRecentOrders() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {},
                child: const Row(
                  children: [
                    Text('View All Orders', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.primaryDark),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Order ID', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Date & Time', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Items', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Amount', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Status', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Action', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
          
          if (_orders.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text("No orders found.")))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _orders.take(5).length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = _orders[index];
                final data = doc.data() as Map<String, dynamic>;
                
                final orderId = doc.id.length > 6 ? doc.id.substring(0,6).toUpperCase() : doc.id;
                final ts = data['timestamp'] as Timestamp?;
                final date = ts != null ? ts.toDate() : DateTime.now();
                final amount = (data['total_amount'] as num?)?.toDouble() ?? 0;
                final status = data['status'] as String? ?? 'Pending';
                
                final items = data['items'] as List<dynamic>? ?? [];
                
                Color statusColor = Colors.orange;
                IconData statusIcon = Icons.access_time;
                if (status.toLowerCase() == 'delivered') { statusColor = Colors.green; statusIcon = Icons.check_circle; }
                else if (status.toLowerCase() == 'cancelled') { statusColor = Colors.red; statusIcon = Icons.cancel; }
                else if (status.toLowerCase() == 'out for delivery') { statusColor = Colors.green.shade700; statusIcon = Icons.local_shipping; }
                else if (status.toLowerCase() == 'preparing') { statusColor = Colors.blue; statusIcon = Icons.settings_suggest; }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('#NK$orderId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd MMM yyyy').format(date), style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(DateFormat('hh:mm a').format(date), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            if (items.isNotEmpty)
                              ...items.take(3).map((it) {
                                final i = it as Map<String, dynamic>;
                                final img = i['image_url'] ?? '';
                                return Container(
                                  width: 24, height: 24, margin: const EdgeInsets.only(right: 2),
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(4)),
                                  child: img.isNotEmpty ? ProductImageWidget(imageUrl: img, width: 24, height: 24) : const Icon(Icons.image, size: 12),
                                );
                              }),
                            if (items.length > 3)
                              Text(' +${items.length - 3}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                if (status.toLowerCase() == 'out for delivery') {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
                                    body: DesktopOrderTrackingView(
                                      order: doc as QueryDocumentSnapshot,
                                      onBack: () => Navigator.pop(context),
                                      onViewDetails: () {},
                                    )
                                  )));
                                } else {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
                                    body: DesktopOrderDetailsView(
                                      order: doc as QueryDocumentSnapshot,
                                      onBack: () => Navigator.pop(context),
                                      onTrackOrder: () {},
                                    )
                                  )));
                                }
                              },
                              icon: const Icon(Icons.remove_red_eye, size: 14, color: Colors.black87),
                              label: Text(status.toLowerCase() == 'out for delivery' ? 'Track Order' : 'View Order', style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKhataSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 20),
                const SizedBox(width: 8),
                const Text('Khata Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniKhataCard(
                        'Current Balance', 'Amount to be paid', '₹${_currentBalance.toStringAsFixed(0)}', Colors.green, Icons.account_balance_wallet_outlined
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMiniKhataCard(
                        'Total Credit Limit', 'Approved limit', '₹5,000', Colors.blue, Icons.monetization_on_outlined
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniKhataCard(
                        'Used Credit', '25% of your limit', '₹1,250', Colors.orange, Icons.shopping_bag_outlined, progress: 0.25
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMiniKhataCard(
                        'Available Credit', '75% remaining', '₹3,750', Colors.purple, Icons.credit_card_outlined, progress: 0.75
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payments not configured on frontend yet.')));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.currency_rupee, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Add Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _navigateToKhataStatement,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          backgroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long, size: 16, color: Colors.black87),
                            const SizedBox(width: 4),
                            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('View Statement', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)))),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMiniKhataCard(String title, String subtitle, String amount, Color color, IconData icon, {double? progress}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(amount, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 20),
                SizedBox(width: 8),
                Text('Order Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildOrderStatCard('Total Orders', _totalOrders.toString(), Colors.green, Icons.shopping_cart_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildOrderStatCard('Delivered', _deliveredOrders.toString(), Colors.blue, Icons.check_circle_outline)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildOrderStatCard('In Progress', _inProgressOrders.toString(), Colors.orange, Icons.access_time)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildOrderStatCard('Cancelled', _cancelledOrders.toString(), Colors.red, Icons.cancel_outlined)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.currency_rupee, color: Colors.green, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Spent', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('₹${_totalSpent.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      const Text('Across all orders', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildOrderStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history, size: 20),
                    SizedBox(width: 8),
                    Text('Payment History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                TextButton(
                  onPressed: _navigateToKhataStatement,
                  child: const Row(
                    children: [
                      Text('View All', style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.bold)),
                      Icon(Icons.arrow_forward, size: 14, color: AppColors.primaryDark),
                    ],
                  ),
                )
              ],
            ),
          ),
          if (_payments.isEmpty)
             const Padding(padding: EdgeInsets.all(24), child: Text("No payments found.", style: TextStyle(color: Colors.grey)))
          else
             Padding(
               padding: const EdgeInsets.all(16),
               child: Column(
                 children: [
                   Row(
                     children: [
                       Expanded(flex: 2, child: Text('Date', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold))),
                       Expanded(flex: 2, child: Text('Method', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold))),
                       Expanded(flex: 2, child: Text('Amount', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold))),
                       Expanded(flex: 3, child: Text('Reference', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold))),
                     ],
                   ),
                   const SizedBox(height: 12),
                   ..._payments.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final ts = data['timestamp'] as Timestamp?;
                      final date = ts != null ? ts.toDate() : DateTime.now();
                      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                      final desc = data['description'] as String? ?? '';
                      // Attempt to guess method from desc, fallback to Unknown
                      String method = 'Cash';
                      if (desc.toLowerCase().contains('upi')) method = 'UPI';
                      else if (desc.toLowerCase().contains('card')) method = 'Card';
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 11))),
                            Expanded(flex: 2, child: Text(method, style: const TextStyle(fontSize: 11))),
                            Expanded(flex: 2, child: Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))),
                            Expanded(flex: 3, child: Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                          ],
                        ),
                      );
                   }),
                 ],
               ),
             )
        ],
      ),
    );
  }
}
