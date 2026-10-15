import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_provider.dart';
import 'shop_provider.dart';
import 'app_theme.dart';
import 'firebase_utils.dart';
import 'payment_service.dart';

class DesktopKhataView extends StatefulWidget {
  const DesktopKhataView({super.key});

  @override
  State<DesktopKhataView> createState() => _DesktopKhataViewState();
}

class _DesktopKhataViewState extends State<DesktopKhataView> {
  bool _isLoading = false;
  Map<String, dynamic>? _customerData;
  String? _customerDocId;
  List<DocumentSnapshot> _transactions = [];
  double? _selectedPayAmount;

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
        _customerDocId = doc.id;
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
                color: AppColors.primaryLight.withValues(alpha: 0.2),
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
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.1),
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
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)),
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
    final double amountToDisplay = _selectedPayAmount != null && _selectedPayAmount! > 0
        ? _selectedPayAmount!
        : currentBalance;

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
              Text('₹${amountToDisplay.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => _showChangeAmountDialog(currentBalance),
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
                if (currentBalance <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Aapka outstanding balance zero hai. Koi payment baaki nahi hai.')),
                  );
                  return;
                }
                _showPaymentDialog(amountToDisplay, currentBalance);
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
              Expanded(child: _buildQuickPayBtn('₹500', 500, currentBalance)),
              const SizedBox(width: 8),
              Expanded(child: _buildQuickPayBtn('₹1,000', 1000, currentBalance)),
              const SizedBox(width: 8),
              Expanded(child: _buildQuickPayBtn('₹2,000', 2000, currentBalance)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: _buildQuickPayBtn('Full Amount', currentBalance, currentBalance)),
        ],
      ),
    );
  }

  Widget _buildQuickPayBtn(String label, double amount, double currentBalance) {
    final isSelected = _selectedPayAmount == amount;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedPayAmount = amount > 0 ? amount : currentBalance;
        });
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : AppColors.primaryDark,
        backgroundColor: isSelected ? AppColors.primaryDark : null,
        side: BorderSide(color: isSelected ? AppColors.primaryDark : Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  void _showChangeAmountDialog(double currentBalance) {
    final controller = TextEditingController(
      text: (_selectedPayAmount ?? currentBalance).toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Payment Amount'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Amount (₹)',
            prefixText: '₹ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                setState(() => _selectedPayAmount = val);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
            child: const Text('Set Amount', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(double amount, double currentBalance) {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final shopUpiId = shopProvider.shopUpiId ?? '';
    final shopName = shopProvider.currentShopName;
    final shopId = shopProvider.currentShopId ?? '';
    final utrController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final upiUrl = shopUpiId.isNotEmpty
              ? PaymentService().generateUpiPaymentUrl(
                  upiId: shopUpiId,
                  payeeName: shopName,
                  amount: amount,
                  orderId: 'KHATA_${DateTime.now().millisecondsSinceEpoch}',
                  note: 'Khata Payment $shopName',
                )
              : null;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pay Khata Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        children: [
                          const Text('Total Amount to Pay', style: TextStyle(fontSize: 13, color: Color(0xFF166534))),
                          const SizedBox(height: 4),
                          Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                          Text('Remaining Udhaar after payment: ₹${(currentBalance - amount).clamp(0, double.infinity).toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (shopUpiId.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Store UPI ID is not set yet. Please pay in cash at the counter.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Shop UPI ID', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(shopUpiId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18, color: Color(0xFF15803D)),
                            tooltip: 'Copy UPI ID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: shopUpiId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('UPI ID copied to clipboard'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: QrImageView(
                                data: upiUrl ?? '',
                                version: QrVersions.auto,
                                size: 140,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Scan with GPay, PhonePe, Paytm', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (upiUrl != null) {
                            final uri = Uri.parse(upiUrl);
                            try {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (_) {}
                          }
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open UPI App to Pay'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: utrController,
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
                        LengthLimitingTextInputFormatter(35),
                      ],
                      decoration: const InputDecoration(
                        labelText: '12-digit UTR / Payment Ref Number',
                        hintText: 'Enter UTR after paying',
                        prefixIcon: Icon(Icons.receipt_long, size: 18),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final utr = utrController.text.trim();
                              if (!PaymentService().isValidUtr(utr)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Kripya sahi 12-digit UPI Reference / UTR Number enter karein.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (_customerDocId == null || _customerDocId!.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Customer record not found.'), backgroundColor: Colors.red),
                                );
                                return;
                              }

                              setDialogState(() => isSubmitting = true);
                              try {
                                final batch = FirebaseUtils.firestore.batch();
                                final customerRef = FirebaseUtils.firestore.collection('customers').doc(_customerDocId);

                                final Map<String, dynamic> updateData = {
                                  'total_udhaar': FieldValue.increment(-amount),
                                };
                                if (shopId.isNotEmpty) {
                                  updateData['shop_balances.$shopId'] = FieldValue.increment(-amount);
                                }
                                batch.update(customerRef, updateData);

                                final txRef = customerRef.collection('khata_transactions').doc();
                                batch.set(txRef, {
                                  'amount': amount,
                                  'type': 'jama',
                                  'shop_id': shopId,
                                  'payment_method': 'UPI',
                                  'utr': utr,
                                  'description': 'Khata Payment via UPI (UTR: $utr)',
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'status': 'completed',
                                });

                                final pTxnId = 'KHATA_PAY_${DateTime.now().millisecondsSinceEpoch}';
                                batch.set(FirebaseUtils.firestore.collection('payment_transactions').doc(pTxnId), {
                                  'transaction_id': pTxnId,
                                  'customer_id': _customerDocId,
                                  'shop_id': shopId,
                                  'amount': amount,
                                  'payment_method': 'UPI',
                                  'gateway_reference': utr,
                                  'status': 'completed',
                                  'verified_by': 'Customer Self Payment',
                                  'created_at': FieldValue.serverTimestamp(),
                                });

                                await batch.commit();

                                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('₹${amount.toStringAsFixed(0)} payment successfully recorded! Khata balance updated.'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                await _fetchKhataData();
                              } catch (e) {
                                setDialogState(() => isSubmitting = false);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Payment error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Verify & Submit Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
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
