import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/app_theme.dart';
import 'shop_provider.dart';
import 'modern_loader.dart';
import 'customer_desktop_dashboard.dart';
import 'home_screen.dart';
import 'admin_whatsapp_reminder_screen.dart';

class KhataStatementScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final bool isAdmin;

  const KhataStatementScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.isAdmin = false,
  });

  @override
  State<KhataStatementScreen> createState() => _KhataStatementScreenState();
}

class _KhataStatementScreenState extends State<KhataStatementScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;
  
  Map<String, dynamic>? _customerData;

  @override
  void initState() {
    super.initState();
    _fetchCustomerData();
    _fetchTransactions();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchTransactions();
      }
    });
  }

  Future<void> _fetchCustomerData() async {
    try {
      final doc = await FirebaseUtils.firestore.collection('customers').doc(widget.customerId).get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _customerData = doc.data();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching customer data: $e');
    }
  }

  Future<void> _fetchTransactions() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      Query q = FirebaseUtils.firestore
          .collection('customers')
          .doc(widget.customerId)
          .collection('khata_transactions')
          .where('shop_id', isEqualTo: shopId)
          .orderBy('timestamp', descending: true)
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
        _transactions.addAll(querySnapshot.docs);
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _transactions.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchCustomerData();
    await _fetchTransactions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _deleteTransaction(String txId, double amount, bool isUdhaar) {
    showDialog(
      context: context,
      builder: (deleteCtx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('This will permanently delete this transaction and recalculate the customer\'s total Udhaar balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(deleteCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(deleteCtx);
              try {
                final batch = FirebaseUtils.firestore.batch();
                final txRef = FirebaseUtils.firestore
                    .collection('customers')
                    .doc(widget.customerId)
                    .collection('khata_transactions')
                    .doc(txId);

                final customerRef = FirebaseUtils.firestore
                    .collection('customers')
                    .doc(widget.customerId);

                batch.delete(txRef);

                double balanceChange = isUdhaar ? -amount : amount;

                batch.update(customerRef, {
                  'total_udhaar': FieldValue.increment(balanceChange),
                });

                await batch.commit();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(behavior: SnackBarBehavior.floating, content: Text(AppLocalizations.of(context)!.transaction_deleted),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _refresh();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(behavior: SnackBarBehavior.floating, content: Text(AppLocalizations.of(context)!.error_loading.replaceAll('{error}', e.toString()))),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 800) {
      if (!widget.isAdmin) {
        return DesktopCustomerDashboard(
          selectedIndex: 4, // "My Khata" tab
          onNavTap: (index) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(initialIndex: index),
              ),
              (route) => false,
            );
          },
          child: _buildDesktopContent(context),
        );
      } else {
        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          appBar: AppBar(
            title: Text('${widget.customerName} Statement'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_khata_statement_screen_desktop',
            onPressed: () => _showAddTransactionDialog(context),
            backgroundColor: const Color(0xFF4CAF50),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text('Add Entry', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: _buildDesktopContent(context),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text('${widget.customerName} Statement'),
      ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'fab_khata_statement_screen',
              onPressed: () => _showAddTransactionDialog(context),
              backgroundColor: const Color(0xFF4CAF50),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Add Entry', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF4CAF50),
        child: _transactions.isEmpty && !_isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Text(
                      'No transactions found for this customer.',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _transactions.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _transactions.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: ModernLoader()),
                    );
                  }

                  final tx = _transactions[index].data() as Map<String, dynamic>;
                  final double amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                  final String type = tx['type'] ?? 'debit';
                  final String description = tx['description'] ?? '';
                  final Timestamp? timestamp = tx['timestamp'] as Timestamp?;
                  final String txId = _transactions[index].id;

                  final isUdhaar = type == 'debit' || type == 'udhaar';
                  final color = isUdhaar ? Colors.red : Colors.green;
                  final icon = isUdhaar ? Icons.arrow_upward : Icons.arrow_downward;

                  String dateStr = '';
                  if (timestamp != null) {
                    dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(
                        description.isNotEmpty ? description : (isUdhaar ? 'Udhaar Diya (Given)' : 'Paise Jama Kiye (Paid)'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(dateStr, style: GoogleFonts.poppins(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isUdhaar ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                          ),
                          if (widget.isAdmin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                              onPressed: () => _deleteTransaction(txId, amount, isUdhaar),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // DESKTOP WIDGETS
  Widget _buildDesktopContent(BuildContext context) {
    double currentBalance = _customerData?['total_udhaar']?.toDouble() ?? 0.0;
    double creditLimit = _customerData?['credit_limit']?.toDouble() ?? 5000.0;
    double availableCredit = creditLimit - currentBalance;
    if (availableCredit < 0) availableCredit = 0;

    double totalPurchases = 0;
    double totalPayments = 0;
    for (var doc in _transactions) {
      final tx = doc.data() as Map<String, dynamic>;
      final type = tx['type'] ?? 'debit';
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      if (type == 'debit' || type == 'udhaar') {
        totalPurchases += amount;
      } else {
        totalPayments += amount;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Center Column
        Expanded(
          flex: 7,
          child: Container(
            color: const Color(0xFFF0F2F5),
            child: Column(
              children: [
                _buildDesktopHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDesktopSummaryCards(currentBalance, creditLimit, totalPurchases, totalPayments),
                        const SizedBox(height: 24),
                        _buildDesktopFilterBar(),
                        const SizedBox(height: 24),
                        _buildDesktopTransactionTable(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right Column
        Container(
          width: 320,
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDesktopKhataSummaryCard(currentBalance, creditLimit, availableCredit),
                const SizedBox(height: 24),
                _buildDesktopPaymentOptionsCard(currentBalance),
                const SizedBox(height: 24),
                _buildDesktopHelpCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 16,
            spacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Khata Statement', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 24)),
                  const SizedBox(height: 4),
                  const Text('View your complete credit transactions and payment history', style: TextStyle(color: AppColors.textMid)),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download Statement'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(color: AppColors.primaryDark),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (widget.isAdmin) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        // We fetch the customer document first or just push with customerId
                        FirebaseUtils.firestore.collection('customers').doc(widget.customerId).get().then((doc) {
                          if (doc.exists && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminWhatsappReminderScreen(
                                  initialCustomer: doc,
                                  onBack: () => Navigator.pop(context),
                                ),
                              ),
                            );
                          }
                        });
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('WhatsApp Reminder'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddTransactionDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Entry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSummaryCards(double currentBalance, double creditLimit, double purchases, double payments) {
    return Row(
      children: [
        Expanded(child: _buildSummaryCard('Total Credit Limit', creditLimit, Icons.credit_card, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('Total Purchases', purchases, Icons.shopping_bag_outlined, Colors.purple)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('Total Payments', payments, Icons.account_balance_wallet_outlined, Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('Current Balance', currentBalance, Icons.warning_amber_rounded, Colors.red, isHighlight: true)),
      ],
    );
  }

  Widget _buildSummaryCard(String title, double amount, IconData icon, Color color, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlight ? color.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isHighlight ? color.withValues(alpha: 0.2) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 16),
          Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isHighlight ? color : AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _buildDesktopFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(child: _buildDropdown('Date Range', 'Last 30 Days', Icons.calendar_today)),
          const SizedBox(width: 16),
          Expanded(child: _buildDropdown('Transaction Category', 'All Categories', Icons.category_outlined)),
          const SizedBox(width: 16),
          Expanded(child: _buildDropdown('Transaction Type', 'All Types', Icons.filter_list)),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Filter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
              Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey.shade600),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTransactionTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Date', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 3, child: Text('Description', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('Type', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('Amount', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                const SizedBox(width: 48), // Action
              ],
            ),
          ),
          // Body
          if (_isLoading && _transactions.isEmpty)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: ModernLoader()))
          else if (_transactions.isEmpty)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No transactions found.")))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = _transactions[index];
                final tx = doc.data() as Map<String, dynamic>;
                final double amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                final String type = tx['type'] ?? 'debit';
                final String description = tx['description'] ?? '';
                final Timestamp? timestamp = tx['timestamp'] as Timestamp?;
                final date = timestamp?.toDate() ?? DateTime.now();

                final isUdhaar = type == 'debit' || type == 'udhaar';
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                                color: isUdhaar ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(isUdhaar ? Icons.arrow_upward : Icons.arrow_downward, color: isUdhaar ? Colors.red : Colors.green, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                description.isNotEmpty ? description : (isUdhaar ? 'Udhaar Diya' : 'Jama Kiya'),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Type
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isUdhaar ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isUdhaar ? 'Purchase' : 'Payment',
                              style: TextStyle(color: isUdhaar ? Colors.red : Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      // Amount
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${isUdhaar ? '+' : '-'} ₹${amount.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isUdhaar ? Colors.red : Colors.green, fontSize: 14),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      // Action
                      SizedBox(
                        width: 48,
                        child: widget.isAdmin 
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              onPressed: () => _deleteTransaction(doc.id, amount, isUdhaar),
                            )
                          : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
            ),
          
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: TextButton(
                  onPressed: _fetchTransactions,
                  child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Load More'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopKhataSummaryCard(double currentBalance, double creditLimit, double availableCredit) {
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
          const Text('Khata Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildSummaryRow('Current Balance', '₹${currentBalance.toStringAsFixed(0)}', isRed: true),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          _buildSummaryRow('Total Credit Limit', '₹${creditLimit.toStringAsFixed(0)}'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          _buildSummaryRow('Available Credit', '₹${availableCredit.toStringAsFixed(0)}', isGreen: true),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          _buildSummaryRow('Status', 'Active', isStatus: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isRed = false, bool isGreen = false, bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: const Text('Active', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isRed ? Colors.red : (isGreen ? Colors.green : AppColors.textDark),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopPaymentOptionsCard(double currentBalance) {
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
          const Text('Payment Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Choose how you want to pay', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.qr_code, size: 18),
              label: const Text('Pay via UPI / QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.account_balance, size: 18),
              label: const Text('Bank Transfer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primaryDark),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHelpCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.headset_mic, color: Colors.blue.shade700, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need Help?', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Contact store owner for khata related queries', style: TextStyle(color: Colors.blue.shade700, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    bool isCredit = true; // Default to Udhaar Diya
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add Khata Entry',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => isCredit = true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isCredit ? Colors.red.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                border: Border.all(color: isCredit ? Colors.red : Colors.transparent),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.arrow_upward_rounded, color: isCredit ? Colors.red : Colors.grey),
                                  const SizedBox(height: 4),
                                  Text('Udhaar Diya', style: GoogleFonts.poppins(color: isCredit ? Colors.red : Colors.grey, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => isCredit = false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isCredit ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                border: Border.all(color: !isCredit ? Colors.green : Colors.transparent),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.arrow_downward_rounded, color: !isCredit ? Colors.green : Colors.grey),
                                  const SizedBox(height: 4),
                                  Text('Jama Kiya', style: GoogleFonts.poppins(color: !isCredit ? Colors.green : Colors.grey, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.poppins(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      style: GoogleFonts.poppins(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        prefixIcon: const Icon(Icons.description_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final amount = double.tryParse(amountController.text) ?? 0.0;
                              if (amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(behavior: SnackBarBehavior.floating, content: Text(AppLocalizations.of(context)!.invalid_amount), backgroundColor: Colors.red),
                                );
                                return;
                              }

                              setModalState(() => isProcessing = true);

                              try {
                                final batch = FirebaseUtils.firestore.batch();
                                
                                final txRef = FirebaseUtils.firestore
                                    .collection('customers')
                                    .doc(widget.customerId)
                                    .collection('khata_transactions')
                                    .doc();
                                
                                batch.set(txRef, {
                                  'amount': amount,
                                  'type': isCredit ? 'udhaar' : 'jama',
                                  'description': descController.text.trim(),
                                  'timestamp': FieldValue.serverTimestamp(),
                                });

                                final customerRef = FirebaseUtils.firestore
                                    .collection('customers')
                                    .doc(widget.customerId);
                                
                                double balanceChange = isCredit ? amount : -amount;
                                
                                batch.update(customerRef, {
                                  'total_udhaar': FieldValue.increment(balanceChange),
                                });

                                await batch.commit();

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(behavior: SnackBarBehavior.floating, content: Text(isCredit ? AppLocalizations.of(context)!.udhaar_added : AppLocalizations.of(context)!.payment_received_short), backgroundColor: Colors.green),
                                  );
                                  _refresh();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(behavior: SnackBarBehavior.floating, content: Text(AppLocalizations.of(context)!.error_loading.replaceAll('{error}', e.toString())), backgroundColor: Colors.red),
                                  );
                                  setModalState(() => isProcessing = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isProcessing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Save Transaction', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }
}
