import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'shop_provider.dart';
import 'firebase_utils.dart';
import 'sound_service.dart';

class AdminAddEditCustomerScreen extends StatefulWidget {
  final DocumentSnapshot? customer;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  const AdminAddEditCustomerScreen({
    super.key,
    this.customer,
    required this.onBack,
    required this.onSaved,
  });

  @override
  State<AdminAddEditCustomerScreen> createState() => _AdminAddEditCustomerScreenState();
}

class _AdminAddEditCustomerScreenState extends State<AdminAddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  late TextEditingController _addrLine1Controller;
  late TextEditingController _addrLine2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;

  late TextEditingController _creditLimitController;

  bool _isBanned = false;

  @override
  void initState() {
    super.initState();
    final data = widget.customer?.data() as Map<String, dynamic>? ?? {};

    _nameController = TextEditingController(text: data['name'] ?? '');
    _phoneController = TextEditingController(text: data['mobile'] ?? data['phone'] ?? '');
    _emailController = TextEditingController(text: data['email'] ?? '');
    
    final delAddr = data['delivery_address'] as Map<String, dynamic>?;
    if (delAddr != null) {
      _addrLine1Controller = TextEditingController(text: delAddr['line1'] ?? '');
      _addrLine2Controller = TextEditingController(text: delAddr['line2'] ?? '');
      _cityController = TextEditingController(text: delAddr['city'] ?? '');
      _stateController = TextEditingController(text: delAddr['state'] ?? '');
      _zipController = TextEditingController(text: delAddr['pincode']?.toString() ?? '');
    } else {
      _addrLine1Controller = TextEditingController(text: data['address'] ?? '');
      _addrLine2Controller = TextEditingController();
      _cityController = TextEditingController();
      _stateController = TextEditingController();
      _zipController = TextEditingController();
    }
    
    // Attempt to get credit limit
    double currentLimit = 5000.0;
    if (data.containsKey('credit_limit')) {
      currentLimit = (data['credit_limit'] as num).toDouble();
    }
    _creditLimitController = TextEditingController(text: currentLimit.toStringAsFixed(0));
    _isBanned = data['is_banned'] ?? false;

    // Listen to changes to update preview
    _nameController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _addrLine1Controller.addListener(() => setState(() {}));
    _creditLimitController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addrLine1Controller.dispose();
    _addrLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      
      final line1 = _addrLine1Controller.text.trim();
      final line2 = _addrLine2Controller.text.trim();
      final city = _cityController.text.trim();
      final state = _stateController.text.trim();
      final zip = _zipController.text.trim();
      
      String addressStr = line1;
      if (line2.isNotEmpty) addressStr += ', $line2';
      if (city.isNotEmpty) addressStr += ', $city';
      if (state.isNotEmpty) addressStr += ', $state';
      if (zip.isNotEmpty) addressStr += ' - $zip';
      
      final deliveryAddress = {
        'type': 'Home',
        'line1': line1,
        'line2': line2,
        'city': city,
        'state': state,
        'pincode': zip,
        'address': addressStr,
      };

      final creditLimit = double.tryParse(_creditLimitController.text.trim()) ?? 5000.0;

      if (widget.customer != null) {
        // Edit Mode
        await FirebaseUtils.firestore.collection('customers').doc(widget.customer!.id).update({
          'name': name,
          'phone': phone,
          'mobile': phone,
          'email': email,
          'address': addressStr,
          'delivery_address': deliveryAddress,
          'credit_limit': creditLimit,
        });
        SoundService().success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Customer updated successfully!'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      } else {
        // Create Mode - Try to find existing by phone first
        final customerQuery = await FirebaseUtils.firestore
            .collection('customers')
            .where('mobile', isEqualTo: phone)
            .limit(1)
            .get();

        if (customerQuery.docs.isNotEmpty) {
          // Exists
          final existingId = customerQuery.docs.first.id;
          await FirebaseUtils.firestore.collection('customers').doc(existingId).update({
            'name': name,
            'email': email,
            'address': addressStr,
            'delivery_address': deliveryAddress,
            'credit_limit': creditLimit,
            'shop_ids': FieldValue.arrayUnion([shopId]),
          });
        } else {
          // Create new
          await FirebaseUtils.firestore.collection('customers').add({
            'name': name,
            'mobile': phone,
            'email': email,
            'address': addressStr,
            'delivery_address': deliveryAddress,
            'credit_limit': creditLimit,
            'shop_balances.$shopId': 0.0,
            'total_udhaar': 0.0,
            'shop_ids': [shopId],
            'auto_reminder': false,
            'is_banned': false,
            'created_at': FieldValue.serverTimestamp(),
          });
        }
        SoundService().success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Customer added successfully!'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }

      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.transparent, // Background provided by parent
      body: Column(
        children: [
          // Header
          _buildHeader(isEdit),
          
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: isDesktop 
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildLeftColumn()),
                          const SizedBox(width: 24),
                          Expanded(flex: 3, child: _buildRightColumn()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLeftColumn(),
                          const SizedBox(height: 24),
                          _buildRightColumn(),
                        ],
                      ),
              ),
            ),
          ),
          
          // Bottom Actions
          _buildBottomActions(isEdit),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isEdit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.bgTint)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back, size: 16, color: AppColors.textDark),
                  SizedBox(width: 6),
                  Text('Back', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Customer' : 'Add Customer',
                  style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 24),
                ),
                Text(
                  'Create a new customer or update existing customer information',
                  style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                ),
              ],
            ),
          ),
          if (isEdit)
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               decoration: BoxDecoration(
                 color: Colors.white,
                 border: Border.all(color: Colors.grey.shade300),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: const Row(
                 children: [
                   Icon(Icons.edit_outlined, size: 16, color: AppColors.textDark),
                   SizedBox(width: 8),
                   Text('Edit Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                 ],
               ),
             )
          else
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               decoration: BoxDecoration(
                 color: const Color(0xFFE8F5E9),
                 border: Border.all(color: const Color(0xFFA5D6A7)),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: const Row(
                 children: [
                   Icon(Icons.person_add_alt_1_outlined, size: 16, color: AppColors.primaryDark),
                   SizedBox(width: 8),
                   Text('Add Customer', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                 ],
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Information
        _buildSectionCard(
          title: 'Basic Information',
          subtitle: 'Enter the customer\'s basic details',
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Upload Visual
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryDark.withOpacity(0.3), width: 1.5, style: BorderStyle.solid),
                  color: const Color(0xFFF0FDF4), // very light green
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, color: AppColors.primaryDark, size: 28),
                    SizedBox(height: 4),
                    Text('Add Photo', style: TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _nameController,
                            label: 'Full Name *',
                            icon: Icons.person_outline,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _phoneController,
                            label: 'Phone Number *',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            prefix: const Text('+91  ', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            hint: 'customer@example.com',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: TextEditingController(),
                            label: 'Date of Birth (Optional)',
                            icon: Icons.calendar_today_outlined,
                            hint: 'Select date',
                            enabled: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Address Information
        _buildSectionCard(
          title: 'Address Information',
          subtitle: 'Enter the customer\'s delivery address',
          content: Column(
            children: [
              _buildTextField(
                controller: _addrLine1Controller,
                label: 'Address Line 1 *',
                icon: Icons.location_on_outlined,
                hint: 'House/Flat No., Building Name',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _addrLine2Controller,
                label: 'Address Line 2 (Optional)',
                icon: Icons.location_on_outlined,
                hint: 'Street, Sector, Area',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _cityController,
                      label: 'City *',
                      icon: Icons.location_city_outlined,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _stateController,
                      label: 'State *',
                      icon: Icons.map_outlined,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _zipController,
                      label: 'Postal Code *',
                      icon: Icons.pin_drop_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Khata / Credit Information
        _buildSectionCard(
          title: 'Khata / Credit Information',
          subtitle: 'Set credit limit and khata preferences for this customer',
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _creditLimitController,
                  label: 'Credit Limit (₹)',
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: TextEditingController(text: '30'),
                  label: 'Payment Due Days',
                  icon: Icons.calendar_month_outlined,
                  enabled: false,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Switch(
                        value: true, // Fixed visually to true for now since it's default
                        onChanged: (v) {},
                        activeColor: Colors.white,
                        activeTrackColor: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Allow Khata (Credit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Enable credit purchases for this customer', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Additional Information
        _buildSectionCard(
          title: 'Additional Information',
          subtitle: 'Add any extra notes about this customer',
          content: _buildTextField(
            controller: TextEditingController(),
            label: 'Customer Notes (Optional)',
            icon: Icons.notes,
            hint: 'E.g., Regular customer. Prefers UPI payments.',
            enabled: false,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Customer Preview
        _buildCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Customer Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isBanned ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: _isBanned ? Colors.red : AppColors.primaryDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isBanned ? 'Banned' : 'Active',
                          style: TextStyle(
                            color: _isBanned ? Colors.red : AppColors.primaryDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE8F5E9),
                    ),
                    child: const Center(child: Icon(Icons.person, color: AppColors.primaryDark, size: 36)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.isEmpty ? 'New Customer' : _nameController.text,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 8),
                        _buildPreviewRow(Icons.phone_outlined, _phoneController.text.isEmpty ? 'N/A' : '+91 ${_phoneController.text}'),
                        const SizedBox(height: 4),
                        _buildPreviewRow(Icons.email_outlined, _emailController.text.isEmpty ? 'N/A' : _emailController.text),
                        const SizedBox(height: 4),
                        _buildPreviewRow(Icons.location_on_outlined, _addrLine1Controller.text.isEmpty ? 'N/A' : _addrLine1Controller.text),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Khata Summary
        _buildCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Khata Summary (Preview)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 20),
              _buildSummaryRow('Credit Limit', '₹${_creditLimitController.text.isEmpty ? '0' : _creditLimitController.text}', isBold: true),
              const SizedBox(height: 12),
              
              // Get actual used credit if available
              Builder(builder: (context) {
                final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
                double usedCredit = 0.0;
                if (widget.customer != null) {
                  final data = widget.customer!.data() as Map<String, dynamic>?;
                  if (data != null && data['shop_balances'] != null) {
                     usedCredit = (data['shop_balances'][shopId] as num?)?.toDouble() ?? 0.0;
                  }
                }
                double limit = double.tryParse(_creditLimitController.text) ?? 5000.0;
                double available = limit - usedCredit;
                if (available < 0) available = 0;
                
                double pct = 0;
                if (limit > 0) {
                  pct = usedCredit / limit;
                  if (pct > 1.0) pct = 1.0;
                }

                return Column(
                  children: [
                    _buildSummaryRow('Used Credit', '₹${usedCredit.toStringAsFixed(0)} (${(pct*100).toStringAsFixed(0)}%)'),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Available Credit', '₹${available.toStringAsFixed(0)} (${((1-pct)*100).toStringAsFixed(0)}%)', isBold: true),
                    const SizedBox(height: 16),
                    // Progress Bar
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pct,
                        child: Container(
                          decoration: BoxDecoration(
                            color: pct > 0.9 ? Colors.red : AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${(pct*100).toStringAsFixed(0)}% of credit limit used', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                );
              }),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Customer Benefits
        _buildCard(
          padding: const EdgeInsets.all(20),
          color: const Color(0xFFF0F7FF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(Icons.card_giftcard, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  const Text('Customer Benefits', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              _buildBenefitRow('Can place orders on credit (khata)'),
              _buildBenefitRow('Flexible payment options'),
              _buildBenefitRow('Track order history'),
              _buildBenefitRow('View and manage payments'),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Important Notes
        _buildCard(
          padding: const EdgeInsets.all(20),
          color: const Color(0xFFFFF9E6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: const Icon(Icons.priority_high, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  const Text('Important Notes', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              _buildNoteRow('Customer will be able to place orders after creation'),
              _buildNoteRow('Credit limit can be updated later'),
              _buildNoteRow('All information can be edited anytime'),
              _buildNoteRow('Customer will receive notifications (if enabled)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(bool isEdit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          TextButton(
            onPressed: widget.onBack,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _saveCustomer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isProcessing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                isEdit ? 'Update Customer' : 'Save Customer',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required String subtitle, required Widget content}) {
    return _buildCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 18)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding, Color color = Colors.white}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? prefix,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: enabled,
          validator: validator,
          style: TextStyle(color: enabled ? AppColors.textDark : Colors.grey.shade600, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade500, size: 20) : null,
            prefix: prefix,
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isBold ? AppColors.textDark : Colors.grey.shade700, fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textDark, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildNoteRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•', style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textDark, fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }
}
