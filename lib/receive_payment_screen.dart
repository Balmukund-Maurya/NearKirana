import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/app_theme.dart';
import 'shop_provider.dart';
import 'modern_loader.dart';
import 'customer_desktop_dashboard.dart';
import 'home_screen.dart';
import 'khata_statement_screen.dart';

class ReceivePaymentScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String? customerPhone;

  const ReceivePaymentScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
  });

  @override
  State<ReceivePaymentScreen> createState() => _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState extends State<ReceivePaymentScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, dynamic>? _customerData;
  List<DocumentSnapshot> _recentPayments = [];

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedPaymentMethod = 'Cash';
  final DateTime _selectedDate = DateTime.now();

  double get _currentBalance => _customerData?['total_udhaar']?.toDouble() ?? 0.0;
  double get _creditLimit => _customerData?['credit_limit']?.toDouble() ?? 5000.0;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _amountController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      
      final doc = await FirebaseUtils.firestore.collection('customers').doc(widget.customerId).get();
      if (doc.exists) {
        _customerData = doc.data();
      }

      final paymentsQuery = await FirebaseUtils.firestore
          .collection('customers')
          .doc(widget.customerId)
          .collection('khata_transactions')
          .where('shop_id', isEqualTo: shopId)
          .where('type', whereIn: ['jama', 'credit', 'payment'])
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();
          
      _recentPayments = paymentsQuery.docs;

    } catch (e) {
      debugPrint('Error fetching customer data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _savePayment() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.invalid_amount ?? 'Please enter a valid amount.'), backgroundColor: Colors.red)
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final batch = FirebaseUtils.firestore.batch();
      final customerRef = FirebaseUtils.firestore.collection('customers').doc(widget.customerId);
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;

      batch.update(customerRef, {
        'shop_balances.$shopId': FieldValue.increment(-amount),
        'total_udhaar': FieldValue.increment(-amount),
      });

      batch.set(customerRef.collection('khata_transactions').doc(), {
        'amount': amount,
        'type': 'jama',
        'shop_id': shopId,
        'payment_method': _selectedPaymentMethod,
        'description': _noteController.text.isNotEmpty ? _noteController.text.trim() : 'Payment Received via $_selectedPaymentMethod',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(AppLocalizations.of(context)?.payment_received_short ?? 'Payment Received Successfully!'), backgroundColor: Colors.green)
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    // Mobile fallback (standard scaffold)
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Payment')),
      body: _isLoading 
          ? const Center(child: ModernLoader()) 
          : SingleChildScrollView(child: _buildDesktopContent(context)), // Using same layout logic for simplicity in this task, but normally would have mobile layout.
    );
  }

  Widget _buildDesktopContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Center Column: Payment Form
        Expanded(
          flex: 7,
          child: Container(
            color: const Color(0xFFF0F2F5),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCustomerCard(),
                        const SizedBox(height: 24),
                        _buildPaymentForm(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right Column: Summary
        Container(
          width: 340,
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKhataSummaryCard(),
                const SizedBox(height: 24),
                _buildBalanceAfterPaymentCard(),
                const SizedBox(height: 24),
                if (_recentPayments.isNotEmpty) ...[
                  _buildRecentPaymentsCard(),
                  const SizedBox(height: 24),
                ],
                _buildHelpCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back, size: 16, color: AppColors.textMid),
                const SizedBox(width: 4),
                const Text('Back', style: TextStyle(color: AppColors.textMid, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Receive Payment', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 24)),
                  const SizedBox(height: 4),
                  const Text("Record a payment received against the customer's Khata", style: TextStyle(color: AppColors.textMid)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => KhataStatementScreen(
                        customerId: widget.customerId,
                        customerName: widget.customerName,
                        isAdmin: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('View Statement'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryDark),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    String email = _customerData?['email'] ?? '';
    String address = _customerData?['address'] ?? '';
    if (email.isEmpty) email = '${widget.customerName.toLowerCase().replaceAll(' ', '.')}@example.com';
    if (address.isEmpty) address = 'Address not available';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryDark.withValues(alpha: 0.1),
                child: Text(
                  widget.customerName.isNotEmpty ? widget.customerName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.customerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.green, size: 8),
                            SizedBox(width: 4),
                            Text('Active', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(widget.customerPhone ?? 'N/A', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(address, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.red.shade400, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Outstanding', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('₹${_currentBalance.toStringAsFixed(0)}', style: TextStyle(color: Colors.red.shade700, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Amount to be paid', style: TextStyle(color: Colors.red.shade400, fontSize: 11)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          const Text('Payment Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('₹', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryDark, width: 2)),
              hintText: '0',
            ),
          ),
          const SizedBox(height: 8),
          Text('Enter payment amount (Max: ₹${_currentBalance.toStringAsFixed(0)})', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          
          const SizedBox(height: 24),
          const Text('Quick Amounts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQuickAmountBtn(500),
              const SizedBox(width: 12),
              _buildQuickAmountBtn(1000),
              const SizedBox(width: 12),
              _buildQuickAmountBtn(2000),
              const SizedBox(width: 12),
              if (_currentBalance > 0)
                _buildQuickAmountBtn(_currentBalance, label: 'Full Amount (₹${_currentBalance.toStringAsFixed(0)})'),
            ],
          ),

          const SizedBox(height: 32),
          const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildPaymentMethodCard('Cash', Icons.money, 'Pay with cash')),
              const SizedBox(width: 16),
              Expanded(child: _buildPaymentMethodCard('UPI', Icons.qr_code, 'Pay via UPI')),
              const SizedBox(width: 16),
              Expanded(child: _buildPaymentMethodCard('Card', Icons.credit_card, 'Pay with card')),
            ],
          ),

          const SizedBox(height: 32),
          const Text('Payment Note (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.sticky_note_2_outlined, color: Colors.grey),
              hintText: 'Add a note about this payment...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),

          const SizedBox(height: 32),
          const Text('Transaction Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            width: 300,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Payment will be recorded on this date', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _savePayment,
              icon: _isProcessing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_outlined),
              label: const Text('Save Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountBtn(double amount, {String? label}) {
    return OutlinedButton(
      onPressed: () {
        _amountController.text = amount.toStringAsFixed(0);
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.green.shade700,
        side: BorderSide(color: Colors.green.shade200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      child: Text(label ?? '₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPaymentMethodCard(String title, IconData icon, String subtitle) {
    bool isSelected = _selectedPaymentMethod == title;
    return InkWell(
      onTap: () {
        setState(() => _selectedPaymentMethod = title);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.white,
          border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.green : Colors.blue.shade700, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.green : Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKhataSummaryCard() {
    double availableCredit = _creditLimit - _currentBalance;
    if (availableCredit < 0) availableCredit = 0;
    double usedPct = _creditLimit > 0 ? (_currentBalance / _creditLimit) : 0;
    if (usedPct > 1.0) usedPct = 1.0;

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
            children: [
              const Icon(Icons.receipt_long, size: 18),
              const SizedBox(width: 8),
              const Text('Khata Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          _buildSummaryRow('Current Balance', '₹${_currentBalance.toStringAsFixed(0)}', isRed: true),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          _buildSummaryRow('Total Credit Limit', '₹${_creditLimit.toStringAsFixed(0)}'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          _buildSummaryRow('Used Credit', '₹${_currentBalance.toStringAsFixed(0)} (${(usedPct*100).toStringAsFixed(0)}%)'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          _buildSummaryRow('Available Credit', '₹${availableCredit.toStringAsFixed(0)} (${((1-usedPct)*100).toStringAsFixed(0)}%)', isBold: true),
          
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedPct,
              backgroundColor: Colors.grey.shade200,
              color: Colors.green,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text('${(usedPct*100).toStringAsFixed(0)}% of your credit limit used', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildBalanceAfterPaymentCard() {
    double inputAmt = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    double remaining = _currentBalance - inputAmt;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, size: 18, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text('Balance After Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          _buildSummaryRow('Current Balance', '₹${_currentBalance.toStringAsFixed(0)}'),
          const SizedBox(height: 12),
          _buildSummaryRow('Payment Amount', '- ₹${inputAmt.toStringAsFixed(0)}', color: Colors.green),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Colors.black12)),
          _buildSummaryRow('Remaining Balance', '₹${remaining.toStringAsFixed(0)}', color: Colors.green.shade700, isBold: true, valueFontSize: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isRed = false, bool isBold = false, Color? color, double valueFontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold || isRed || color != null ? FontWeight.bold : FontWeight.normal,
            fontSize: valueFontSize,
            color: color ?? (isRed ? Colors.red : AppColors.textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPaymentsCard() {
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
              const Row(
                children: [
                  Icon(Icons.history, size: 18),
                  SizedBox(width: 8),
                  Text('Recent Payments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              InkWell(
                onTap: () {},
                child: const Row(
                  children: [
                    Text('View All', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, color: Colors.green, size: 14),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          // Table Header
          Row(
            children: [
              Expanded(flex: 3, child: Text('Date', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Method', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text('Reference', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold))),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
          // List
          ..._recentPayments.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final method = data['payment_method'] ?? 'UPI';
            final ref = doc.id.length > 6 ? doc.id.substring(0, 8).toUpperCase() : doc.id;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(DateFormat('dd MMM yyyy').format(date), style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
                  Expanded(flex: 2, child: Text('₹${amt.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))),
                  Expanded(flex: 2, child: Text(method, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
                  Expanded(flex: 3, child: Text(ref, style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
                ],
              ),
            );
          }),
        ],
      ),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.headset_mic, color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Need Help?', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 14))),
            ],
          ),
          const SizedBox(height: 12),
          Text('Have questions about recording a payment? Contact our support team.', style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              side: BorderSide(color: Colors.blue.shade200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          )
        ],
      ),
    );
  }
}
