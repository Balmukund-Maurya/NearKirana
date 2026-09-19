import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'shop_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'modern_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchTransactions();
      }
    });
  }

  Future<void> _fetchTransactions() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      Query q = FirebaseFirestore.instance
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
    await _fetchTransactions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
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
                      child: Center(
                        child: ModernLoader(),
                      ),
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
                    dateStr = DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(timestamp.toDate());
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(
                        description.isNotEmpty
                            ? description
                            : (isUdhaar ? 'Udhaar Diya (Given)' : 'Paise Jama Kiye (Paid)'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        dateStr,
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isUdhaar ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: color,
                            ),
                          ),
                          if (widget.isAdmin)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (deleteCtx) => AlertDialog(
                                    title: const Text('Delete Transaction?'),
                                    content: const Text(
                                      'This will permanently delete this transaction and recalculate the customer\'s total Udhaar balance.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(deleteCtx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(deleteCtx);
                                          try {
                                            final batch = FirebaseFirestore.instance.batch();
                                            final txRef = FirebaseFirestore.instance
                                                .collection('customers')
                                                .doc(widget.customerId)
                                                .collection('khata_transactions')
                                                .doc(txId);

                                            final customerRef = FirebaseFirestore.instance
                                                .collection('customers')
                                                .doc(widget.customerId);

                                            batch.delete(txRef);

                                            double balanceChange = isUdhaar ? -amount : amount;

                                            batch.update(customerRef, {
                                              'total_udhaar': FieldValue.increment(balanceChange),
                                            });

                                            await batch.commit();

                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('transaction_deleted')),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              // FIX-34: Refresh after delete
                                              _refresh();
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('generic_error').replaceAll('{error}', e.toString()))),
                                              );
                                            }
                                          }
                                        },
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
                                color: isCredit ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
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
                                color: !isCredit ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
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
                                  SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('invalid_amount')), backgroundColor: Colors.red),
                                );
                                return;
                              }

                              setModalState(() => isProcessing = true);

                              try {
                                final batch = FirebaseFirestore.instance.batch();
                                
                                final txRef = FirebaseFirestore.instance
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

                                final customerRef = FirebaseFirestore.instance
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
                                    SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate(isCredit ? 'udhaar_added' : 'payment_received_short')), backgroundColor: Colors.green),
                                  );
                                  _refresh();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(behavior: SnackBarBehavior.floating, content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('generic_error').replaceAll('{error}', e.toString())), backgroundColor: Colors.red),
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
