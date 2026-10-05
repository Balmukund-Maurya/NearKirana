import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:near_kirana/admin_desktop_dashboard.dart';


class AdminWhatsappReminderScreen extends StatefulWidget {
  final DocumentSnapshot? initialCustomer;
  final VoidCallback? onBack;

  const AdminWhatsappReminderScreen({
    super.key,
    this.initialCustomer,
    this.onBack,
  });

  @override
  State<AdminWhatsappReminderScreen> createState() => _AdminWhatsappReminderScreenState();
}

class _AdminWhatsappReminderScreenState extends State<AdminWhatsappReminderScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  List<DocumentSnapshot> _customers = [];
  DocumentSnapshot? _selectedCustomer;
  bool _isLoading = false;
  String _searchQuery = '';
  
  String _reminderType = 'Payment Reminder'; // Payment Reminder, Overdue Payment, Custom Message
  
  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.initialCustomer;
    _fetchCustomers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _updateMessageTemplate();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }
  
  void _updateMessageTemplate() {
    if (_selectedCustomer == null) {
      _messageController.text = '';
      return;
    }
    
    final data = _selectedCustomer!.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Customer';
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    final balances = data['shop_balances'] as Map<String, dynamic>? ?? {};
    final balance = (balances[shopId] ?? 0.0).toDouble();
    
    if (_reminderType == 'Payment Reminder') {
      _messageController.text = 'Namaste $name,\n\nAapka NearKirana par ₹${balance.toStringAsFixed(0)} ka outstanding balance hai.\nKripya convenient time par payment kar dein.\n\nThank you,\nNearKirana';
    } else if (_reminderType == 'Overdue Payment') {
      _messageController.text = 'URGENT: Namaste $name,\n\nAapka ₹${balance.toStringAsFixed(0)} ka payment overdue hai.\nKripya jald se jald payment clear karein.\n\nThank you,\nNearKirana';
    } else {
      // Custom message stays as is unless empty
      if (_messageController.text.isEmpty) {
        _messageController.text = 'Namaste $name,\n\n';
      }
    }
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      final q = FirebaseUtils.firestore.collection('customers')
          .where('shop_ids', arrayContains: shopId)
          .limit(100);
      final snapshot = await q.get();
      setState(() {
        _customers = snapshot.docs;
        if (_selectedCustomer == null && _customers.isNotEmpty) {
          _selectedCustomer = _customers.first;
          _updateMessageTemplate();
        }
      });
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendReminder() async {
    if (_selectedCustomer == null) return;
    
    final data = _selectedCustomer!.data() as Map<String, dynamic>;
    String phone = data['mobile']?.toString() ?? data['phone']?.toString() ?? '';
    phone = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 10) phone = '91$phone';
    
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid WhatsApp number found.')),
      );
      return;
    }
    
    final message = Uri.encodeComponent(_messageController.text);
    final Uri launchUri = Uri.parse('https://wa.me/$phone?text=$message');
    
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      
      // Optionally save to history if collection exists. But prompt says "ONLY use statuses supported by existing system".
      // We'll skip writing to DB if no history system exists, or just show success.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening WhatsApp...'), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        
        if (isDesktop) {
          return AdminDesktopDashboard(
            selectedIndex: 4, // Customers index
            onNavTap: (index) {
              Navigator.pop(context); // Go back
            },
            child: Scaffold(
              backgroundColor: const Color(0xFFF8F9FA),
              appBar: _buildAppBar(),
              body: _buildDesktopLayout(),
            ),
          );
        }
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: _buildAppBar(),
          body: _buildMobileLayout(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: widget.onBack != null ? IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
        onPressed: widget.onBack,
      ) : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WhatsApp Reminder', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 20)),
          Text('Send payment reminders to customers with outstanding Khata balance', style: TextStyle(color: AppColors.textMid, fontSize: 13)),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.history, color: AppColors.textMid),
          label: const Text('View Reminder History', style: TextStyle(color: AppColors.textMid)),
        ),
        const SizedBox(width: 16),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.grey.withValues(alpha: 0.2), height: 1),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Customers List
          Expanded(
            flex: 3,
            child: _buildCustomerSelection(),
          ),
          const SizedBox(width: 24),
          
          // Middle & Right: Scrollable together
          Expanded(
            flex: 8,
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildMiddleSection(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: _buildRightSection(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCustomerSelection(),
          const SizedBox(height: 24),
          _buildMiddleSection(),
          const SizedBox(height: 24),
          _buildRightSection(),
        ],
      ),
    );
  }

  // ---- SECTIONS ----

  Widget _buildCustomerSelection() {
    final filteredCustomers = _customers.where((doc) {
      if (_searchQuery.isEmpty) return true;
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final phone = (data['mobile'] ?? data['phone'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || phone.contains(_searchQuery);
    }).toList();

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Select Customer', style: AppTextStyles.heading2()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customer by name or phone number...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: filteredCustomers.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = filteredCustomers[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isSelected = _selectedCustomer?.id == doc.id;
                      
                      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
                      final balances = data['shop_balances'] as Map<String, dynamic>? ?? {};
                      final balance = (balances[shopId] ?? 0.0).toDouble();

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCustomer = doc;
                            _updateMessageTemplate();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          color: isSelected ? AppColors.primaryDark.withValues(alpha: 0.05) : Colors.transparent,
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isSelected ? AppColors.primaryDark : Colors.grey.shade200,
                                child: Text(
                                  (data['name'] ?? 'U')[0].toUpperCase(),
                                  style: TextStyle(color: isSelected ? Colors.white : AppColors.textDark),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data['name'] ?? 'Unknown', style: AppTextStyles.bodySemiBold()),
                                    const SizedBox(height: 4),
                                    Text('+91 ${data['mobile'] ?? data['phone'] ?? 'N/A'}', style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Outstanding', style: TextStyle(color: AppColors.textMid, fontSize: 11)),
                                  Text('₹${balance.toStringAsFixed(0)}', style: TextStyle(color: balance > 0 ? Colors.red : AppColors.textDark, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: isSelected ? AppColors.primaryDark : Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSelectedCustomerCard(),
        const SizedBox(height: 24),
        _buildReminderTypeCard(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildMessageTemplateCard()),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _buildMessagePreviewCard()),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _sendReminder,
                icon: const Icon(Icons.chat_bubble, color: Colors.white),
                label: const Text('Send WhatsApp Reminder', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.schedule),
                label: const Text('Schedule Reminder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildKhataSummaryCard(),
        const SizedBox(height: 24),
        _buildReminderSummaryCard(),
        const SizedBox(height: 24),
        _buildRecentRemindersCard(),
        const SizedBox(height: 24),
        _buildHelpCard(),
      ],
    );
  }

  // ---- MIDDLE WIDGETS ----

  Widget _buildSelectedCustomerCard() {
    if (_selectedCustomer == null) {
      return Container(
        height: 150,
        decoration: _cardDecoration(),
        alignment: Alignment.center,
        child: const Text('No customer selected'),
      );
    }
    
    final data = _selectedCustomer!.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final phone = data['mobile'] ?? data['phone'] ?? 'N/A';
    final email = data['email'] ?? 'N/A';
    final address = data['address'] ?? 'N/A';
    
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    final balances = data['shop_balances'] as Map<String, dynamic>? ?? {};
    final balance = (balances[shopId] ?? 0.0).toDouble();

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Selected Customer', style: AppTextStyles.heading2()),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryDark.withValues(alpha: 0.1),
                child: const Icon(Icons.person, size: 40, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.circle, color: Colors.green, size: 10),
                              SizedBox(width: 4),
                              Text('Active', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildIconText(Icons.phone, '+91 $phone'),
                    const SizedBox(height: 4),
                    _buildIconText(Icons.email_outlined, email),
                    const SizedBox(height: 4),
                    _buildIconText(Icons.location_on_outlined, address),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.receipt_long, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(child: Text('Outstanding Balance', style: TextStyle(color: Colors.red, fontSize: 13))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('₹${balance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month, color: AppColors.textMid, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Last Payment', style: TextStyle(color: AppColors.textMid, fontSize: 13))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('No recent payment', style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.chat_bubble, color: Colors.green, size: 32),
                      SizedBox(height: 8),
                      Text('WhatsApp Available', textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Can send reminder', textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildReminderTypeCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reminder Type', style: AppTextStyles.heading2()),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildTypeOption('Payment Reminder', 'Standard reminder', Icons.chat_bubble_outline),
              _buildTypeOption('Overdue Payment', 'For overdue balances', Icons.access_time),
              _buildTypeOption('Custom Message', 'Write your own message', Icons.edit_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(String title, String subtitle, IconData icon) {
    final isSelected = _reminderType == title;
    return InkWell(
      onTap: () {
        setState(() {
          _reminderType = title;
          _updateMessageTemplate();
        });
      },
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade200, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.green : AppColors.textMid),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.green : AppColors.textDark)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textMid)),
                ],
              ),
            ),
            Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Colors.green : Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTemplateCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Text('WhatsApp Message', style: AppTextStyles.heading2()),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.code, size: 16),
                label: const Text('Use Variables', style: TextStyle(fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 16),
          const Text('Message Template', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('$_reminderType (Default)', overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 8,
            onChanged: (v) => setState(() {}),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${_messageController.text.length}/1000', style: TextStyle(color: AppColors.textMid, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMessagePreviewCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Message Preview', style: AppTextStyles.heading2()),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEAE2), // WhatsApp background color
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble, color: Colors.green, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedCustomer?.get('name') ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                          Text('+91 ${_selectedCustomer?.get('mobile') ?? _selectedCustomer?.get('phone') ?? '9876543210'}', style: TextStyle(color: Colors.grey.shade700, fontSize: 11), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF8C6), // WhatsApp bubble color
                    borderRadius: BorderRadius.circular(12).copyWith(topLeft: const Radius.circular(0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _messageController.text.isEmpty ? 'Type a message...' : _messageController.text,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(DateFormat('hh:mm a').format(DateTime.now()), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.done_all, size: 14, color: Colors.blue),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ---- RIGHT WIDGETS ----

  Widget _buildKhataSummaryCard() {
    double outstanding = 0;
    double creditLimit = 5000;
    
    if (_selectedCustomer != null) {
      final data = _selectedCustomer!.data() as Map<String, dynamic>;
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      final balances = data['shop_balances'] as Map<String, dynamic>? ?? {};
      outstanding = (balances[shopId] ?? 0.0).toDouble();
      creditLimit = (data['credit_limit'] ?? 5000.0).toDouble();
    }
    
    final available = (creditLimit - outstanding).clamp(0.0, creditLimit);
    final percent = creditLimit > 0 ? (outstanding / creditLimit).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Khata Summary', style: AppTextStyles.heading2()),
          const SizedBox(height: 16),
          _buildSummaryRow('Current Outstanding', '₹${outstanding.toStringAsFixed(0)}', isRed: true),
          _buildSummaryRow('Total Credit Limit', '₹${creditLimit.toStringAsFixed(0)}'),
          _buildSummaryRow('Used Credit', '₹${outstanding.toStringAsFixed(0)} (${(percent * 100).toStringAsFixed(0)}%)'),
          _buildSummaryRow('Available Credit', '₹${available.toStringAsFixed(0)} (${((1 - percent) * 100).toStringAsFixed(0)}%)', isBold: true),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey.shade200,
              color: Colors.orange,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text('${(percent * 100).toStringAsFixed(0)}% of credit limit used', style: TextStyle(fontSize: 12, color: AppColors.textMid)),
        ],
      ),
    );
  }

  Widget _buildReminderSummaryCard() {
    double outstanding = 0;
    if (_selectedCustomer != null) {
      final data = _selectedCustomer!.data() as Map<String, dynamic>;
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      final balances = data['shop_balances'] as Map<String, dynamic>? ?? {};
      outstanding = (balances[shopId] ?? 0.0).toDouble();
    }
    
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 20),
              const SizedBox(width: 8),
              Text('Reminder Summary', style: AppTextStyles.heading2()),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Selected Customer', _selectedCustomer?.get('name') ?? '-'),
          _buildSummaryRow('WhatsApp Number', '+91 ${_selectedCustomer?.get('mobile') ?? _selectedCustomer?.get('phone') ?? '-'}'),
          _buildSummaryRow('Outstanding Amount', '₹${outstanding.toStringAsFixed(0)}'),
          _buildSummaryRow('Message Type', _reminderType),
          _buildSummaryRow('Template', 'Default Template'),
        ],
      ),
    );
  }

  Widget _buildRecentRemindersCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, size: 20),
                  const SizedBox(width: 8),
                  Text('Recent Reminders', style: AppTextStyles.heading2()),
                ],
              ),
              TextButton(onPressed: () {}, child: const Text('View All', style: TextStyle(color: Colors.green))),
            ],
          ),
          const SizedBox(height: 16),
          // Placeholder since reminder history is not in the system yet.
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('No recent reminders sent', style: TextStyle(color: AppColors.textMid)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Icon(Icons.headset_mic, color: Colors.blue.shade700, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need Help?', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Having issues sending WhatsApp reminders? Contact our support team.', style: TextStyle(color: Colors.blue.shade800, fontSize: 11)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue.shade300),
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Contact Support \u2192', style: TextStyle(fontSize: 12)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildIconText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMid),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: AppColors.textMid, fontSize: 13)),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isRed = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMid, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: isRed ? Colors.red : AppColors.textDark,
              fontWeight: (isRed || isBold) ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    );
  }
}
