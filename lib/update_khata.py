import re

with open('/Users/balmukund/Documents/flutterProject/Aditya_Kirana/lib/khata_statement_screen.dart', 'r') as f:
    content = f.read()

# Add FAB
fab_code = """      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(context),
        backgroundColor: const Color(0xFF4CAF50),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Entry', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
"""
content = content.replace("      body: RefreshIndicator(", fab_code + "      body: RefreshIndicator(")

# Add _showAddTransactionDialog method before the end of the class
dialog_code = """
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
                                  const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
                                );
                                return;
                              }

                              setModalState(() => isProcessing = true);

                              try {
                                final batch = FirebaseFirestore.instance.batch();
                                
                                // 1. Add Transaction
                                final txRef = FirebaseFirestore.instance
                                    .collection('customers')
                                    .doc(widget.customerId)
                                    .collection('khata_transactions')
                                    .doc();
                                
                                batch.set(txRef, {
                                  'amount': amount,
                                  'is_credit': isCredit,
                                  'description': descController.text.trim(),
                                  'timestamp': FieldValue.serverTimestamp(),
                                });

                                // 2. Update Customer Balance
                                final customerRef = FirebaseFirestore.instance
                                    .collection('customers')
                                    .doc(widget.customerId);
                                
                                // Credit (Udhaar Diya) INCREASES balance
                                // Debit (Jama Kiya) DECREASES balance
                                double balanceChange = isCredit ? amount : -amount;
                                
                                batch.update(customerRef, {
                                  'total_udhaar': FieldValue.increment(balanceChange),
                                });

                                await batch.commit();

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(behavior: SnackBarBehavior.floating, content: Text(isCredit ? 'Udhaar Added' : 'Payment Received'), backgroundColor: Colors.green),
                                  );
                                  _refresh();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error: $e'), backgroundColor: Colors.red),
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
"""

content = content.replace("}\n", dialog_code)
# Ensure we only replace the final brace.
# Wait, replacing "}\n" might be tricky if there are multiple.
# We should replace the last instance of "}"
