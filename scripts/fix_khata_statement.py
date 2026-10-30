import re

with open('lib/khata_statement_screen.dart', 'r') as f:
    content = f.read()

# Add the FAB and _showAddTransactionDialog to khata_statement_screen.dart

fab_code = """      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddTransactionDialog(context);
        },
        backgroundColor: const Color(0xFF4CAF50),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Transaction',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),"""

dialog_code = """
  void _showAddTransactionDialog(BuildContext context) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String type = widget.isOnlineCustomer ? 'credit' : 'debit'; // Default to Jama if online

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Transaction'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isOnlineCustomer) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ChoiceChip(
                          label: const Text('Udhaar (Given)'),
                          selected: type == 'debit',
                          onSelected: (val) {
                            if (val) setState(() => type = 'debit');
                          },
                          selectedColor: Colors.red.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: type == 'debit' ? Colors.red : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Jama (Received)'),
                          selected: type == 'credit',
                          onSelected: (val) {
                            if (val) setState(() => type = 'credit');
                          },
                          selectedColor: Colors.green.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: type == 'credit' ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount')),
                    );
                    return;
                  }

                  Navigator.pop(dialogCtx);
                  
                  try {
                    final batch = FirebaseFirestore.instance.batch();
                    final customerRef = FirebaseFirestore.instance
                        .collection('customers')
                        .doc(widget.customerId);
                        
                    final txRef = customerRef.collection('khata_transactions').doc();
                    
                    batch.set(txRef, {
                      'amount': amount,
                      'type': type,
                      'description': descController.text.trim(),
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    
                    final balanceChange = type == 'debit' ? amount : -amount;
                    batch.update(customerRef, {
                      'total_udhaar': FieldValue.increment(balanceChange),
                    });
                    
                    await batch.commit();
                    _refresh();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
"""

if 'body: RefreshIndicator' in content:
    content = content.replace('body: RefreshIndicator', fab_code + '\n      body: RefreshIndicator')
    
    # Insert _showAddTransactionDialog before _refresh
    if 'Future<void> _refresh() async {' in content:
        content = content.replace('Future<void> _refresh() async {', dialog_code + '\n  Future<void> _refresh() async {')
    
    with open('lib/khata_statement_screen.dart', 'w') as f:
        f.write(content)
    print("Added FAB and dialog successfully.")
else:
    print("Failed to find anchor.")
