import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'user_provider.dart';
import 'shop_provider.dart';
import 'app_theme.dart';
import 'firebase_utils.dart';

class DesktopKhataView extends StatefulWidget {
  const DesktopKhataView({super.key});

  @override
  State<DesktopKhataView> createState() => _DesktopKhataViewState();
}

class _DesktopKhataViewState extends State<DesktopKhataView> {
  bool _isLoading = false;
  Map<String, dynamic>? _customerData;
  List<DocumentSnapshot> _transactions = [];
  String? _customerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchKhataData();
    });
  }

  Future<void> _fetchKhataData() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final phone = userProvider.phoneNumber;
      final shopId = shopProvider.currentShopId;

      if (phone.isEmpty || shopId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final customerQuery = await FirebaseUtils.firestore
          .collection('customers')
          .where('mobile', isEqualTo: phone)
          .limit(1)
          .get();

      if (customerQuery.docs.isNotEmpty) {
        final doc = customerQuery.docs.first;
        _customerId = doc.id;
        _customerData = doc.data();

        final txQuery = await doc.reference
            .collection('khata_transactions')
            .where('shop_id', isEqualTo: shopId)
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();

        _transactions = txQuery.docs;
      }
    } catch (e) {
      debugPrint('Error fetching Khata data: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final shopProvider = Provider.of<ShopProvider>(context);
    final shopId = shopProvider.currentShopId;
    
    // Fallback data if no khata exists
    double currentBalance = 0;
    double totalBalance = 0;
    int activeShops = 0;
    
    if (_customerData != null && shopId != null) {
      final balances = _customerData!['shop_balances'] as Map<String, dynamic>?;
      if (balances != null && balances.containsKey(shopId)) {
        currentBalance = (balances[shopId] as num).toDouble();
      }
      totalBalance = (_customerData!['total_udhaar'] as num?)?.toDouble() ?? 0;
      final shopIds = _customerData!['shop_ids'] as List<dynamic>?;
      activeShops = shopIds?.length ?? 0;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CENTER COLUMN
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeader(),
                const SizedBox(height: 32),
                _buildSummaryCards(currentBalance, totalBalance, activeShops),
                const SizedBox(height: 32),
                _buildRecentTransactions(),
                const SizedBox(height: 32),
                _buildKhataBenefits(),
              ],
            ),
          ),
        ),
        
        // RIGHT COLUMN
        Container(
          width: 320,
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMakePaymentCard(currentBalance),
                const SizedBox(height: 24),
                _buildCreditInfoCard(currentBalance, totalBalance, activeShops),
                const SizedBox(height: 24),
                _buildHelpCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long, color: AppColors.primaryDark, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Khata', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28)),
                const SizedBox(height: 4),
                Text('Manage your credit account and payment history', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
              ],
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.info_outline, color: AppColors.primaryDark, size: 18),
          label: const Text('How it works?', style: TextStyle(color: AppColors.primaryDark)),
          style: TextButton.styleFrom(
            backgroundColor: AppColors.primaryLight.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(double currentBalance, double totalBalance, int activeShops) {
    return Row(
      children: [
        Expanded(child: _buildCard('Current Balance', 'Amount you need to pay', currentBalance, AppColors.success, Icons.account_balance_wallet)),
        const SizedBox(width: 16),
        Expanded(child: _buildCard('Total Udhaar', 'Across all shops', totalBalance, Colors.blue, Icons.monetization_on)),
        const SizedBox(width: 16),
        Expanded(child: _buildCard('Active Shops', 'Connected stores', activeShops.toDouble(), Colors.orange, Icons.storefront, isCurrency: false)),
        const SizedBox(width: 16),
        Expanded(child: _buildCard('Transactions', 'Recent activities', _transactions.length.toDouble(), Colors.purple, Icons.history, isCurrency: false)),
      ],
    );
  }

  Widget _buildCard(String title, String subtitle, double amount, Color color, IconData icon, {bool isCurrency = true}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Text(isCurrency ? '₹${amount.toStringAsFixed(0)}' : amount.toInt().toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
          const SizedBox(height: 12),
          Container(
            height: 6,
            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
            alignment: Alignment.centerLeft,
            child: Container(
              width: 40,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text('Your credit purchases and payments', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Row(
                  children: [
                    Text('View All Transactions', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.primaryDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Table Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Date', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text('Description', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('Type', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('Amount', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                const SizedBox(width: 48), // space for actions
              ],
            ),
          ),
          const Divider(height: 1),
          
          if (_transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text("No transactions found.")),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final data = _transactions[index].data() as Map<String, dynamic>;
                final type = data['type'] as String? ?? 'debit';
                final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final desc = data['description'] as String? ?? '';
                final ts = data['timestamp'] as Timestamp?;
                final date = ts != null ? ts.toDate() : DateTime.now();
                
                final isPayment = type == 'credit';
                final typeColor = isPayment ? Colors.green : Colors.red;
                final typeBg = isPayment ? Colors.green.shade50 : Colors.red.shade50;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Row(
                    children: [
                      // Date
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(DateFormat('hh:mm a').format(date), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          ],
                        ),
                      ),
                      
                      // Description
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: typeBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(isPayment ? Icons.currency_rupee : Icons.shopping_bag_outlined, color: typeColor, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isPayment ? 'Payment Received' : 'Order/Purchase', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(desc, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Type
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isPayment ? 'Payment' : 'Purchase',
                            style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      
                      // Amount
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${isPayment ? '-' : '+'} ₹${amount.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: typeColor),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      
                      // Actions
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onPressed: () {},
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

  Widget _buildMakePaymentCard(double currentBalance) {
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
          const Text('Make a Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Clear your khata balance easily', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${currentBalance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit, size: 14, color: AppColors.primaryDark),
                label: const Text('Change Amount', style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // Should integrate with existing payment flow if one exists
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Online payments not fully configured yet.')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Pay Now', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          const Text('Quick Payment Options', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildQuickPayBtn('₹500')),
              const SizedBox(width: 8),
              Expanded(child: _buildQuickPayBtn('₹1,000')),
              const SizedBox(width: 8),
              Expanded(child: _buildQuickPayBtn('₹2,000')),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: _buildQuickPayBtn('Full Amount')),
        ],
      ),
    );
  }

  Widget _buildQuickPayBtn(String label) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryDark, side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCreditInfoCard(double currentBalance, double totalBalance, int activeShops) {
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
          const Text('Credit Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          _buildInfoRow(Icons.account_balance_wallet, Colors.green, 'Current Shop Balance', '₹${currentBalance.toStringAsFixed(0)}'),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.store, Colors.orange, 'Active Shops', activeShops.toString()),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.monetization_on, Colors.blue, 'Total Udhaar', '₹${totalBalance.toStringAsFixed(0)}'),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.history, Colors.purple, 'Last Transaction', _transactions.isNotEmpty ? DateFormat('dd MMM yyyy').format((_transactions.first['timestamp'] as Timestamp).toDate()) : 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.headset_mic, color: Colors.blue.shade700, size: 24),
          ),
          const SizedBox(height: 16),
          Text('Need Help?', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Have questions about your khata or payments? Contact our support team.', style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildKhataBenefits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Khata Benefits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildBenefitCard(Icons.shopping_cart, 'Buy Now, Pay Later', 'Shop your daily needs on credit', Colors.green)),
            const SizedBox(width: 16),
            Expanded(child: _buildBenefitCard(Icons.calendar_month, 'Flexible Payments', 'Pay at your convenience', Colors.blue)),
            const SizedBox(width: 16),
            Expanded(child: _buildBenefitCard(Icons.percent, 'No Extra Charges', 'Zero interest on khata', Colors.orange)),
            const SizedBox(width: 16),
            Expanded(child: _buildBenefitCard(Icons.history, 'Track History', 'View all transactions in one place', Colors.purple)),
          ],
        )
      ],
    );
  }

  Widget _buildBenefitCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
