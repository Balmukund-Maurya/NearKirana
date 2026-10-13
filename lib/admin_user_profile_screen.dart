import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';
import 'package:near_kirana/utils/product_image_widget.dart';

class AdminUserProfileScreen extends StatefulWidget {
  const AdminUserProfileScreen({super.key});

  @override
  State<AdminUserProfileScreen> createState() => _AdminUserProfileScreenState();
}

class _AdminUserProfileScreenState extends State<AdminUserProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  bool _isUploading = false;
  bool _isUpdating = false;

  int _totalOrders = 0;
  int _totalCustomers = 0;
  int _totalProducts = 0;

  @override
  void initState() {
    super.initState();
    _initData();
    _fetchStats();
  }

  void _initData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    
    _nameCtrl.text = userProvider.customerName.isNotEmpty ? userProvider.customerName : 'Admin User';
    _phoneCtrl.text = userProvider.phoneNumber.isNotEmpty ? userProvider.phoneNumber : (shopProvider.shopMobile ?? '');
    _locationCtrl.text = shopProvider.shopAddress ?? userProvider.deliveryAddress;
  }

  Future<void> _fetchStats() async {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final shopId = shopProvider.currentShopId;
    if (shopId == null) return;

    try {
      final ordersSnap = await FirebaseUtils.firestore
          .collection('orders')
          .where('shop_id', isEqualTo: shopId)
          .count()
          .get();
          
      final customersSnap = await FirebaseUtils.firestore
          .collection('customers')
          .where('shop_ids', arrayContains: shopId)
          .count()
          .get();
          
      final productsSnap = await FirebaseUtils.firestore
          .collection('products')
          .where('shop_id', isEqualTo: shopId)
          .count()
          .get();

      if (mounted) {
        setState(() {
          _totalOrders = ordersSnap.count ?? 0;
          _totalCustomers = customersSnap.count ?? 0;
          _totalProducts = productsSnap.count ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
  }

  Future<void> _pickImage() async {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        final finalImageUrl = 'data:image/jpeg;base64,$base64String';
        await shopProvider.updateShopProfilePic(finalImageUrl);
      } catch (e) {
        debugPrint('Error uploading image: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isUpdating = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // We update the local UserProvider
      userProvider.setUser(
        _nameCtrl.text.trim(),
        _phoneCtrl.text.trim(),
        address: _locationCtrl.text.trim(),
      );

      // Attempt to update customer document if it exists by phone number
      final customerQuery = await FirebaseUtils.firestore
          .collection('customers')
          .where('mobile', isEqualTo: _phoneCtrl.text.trim())
          .limit(1)
          .get();

      if (customerQuery.docs.isNotEmpty) {
        await customerQuery.docs.first.reference.update({
          'name': _nameCtrl.text.trim(),
          'address': _locationCtrl.text.trim(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          const AdminTopHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User Profile', style: AppTextStyles.heading1(color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text('Manage your profile information and account settings', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                  const SizedBox(height: 32),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildLeftColumn()),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _buildRightColumn()),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLeftColumn(),
                        const SizedBox(height: 24),
                        _buildRightColumn(),
                      ],
                    ),
                ],
              ),
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
        _buildProfileOverview(),
        const SizedBox(height: 32),
        _buildTabs(),
        const SizedBox(height: 24),
        _buildPersonalInformationForm(),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAccountStatistics(),
        const SizedBox(height: 24),
        _buildQuickActions(),
        const SizedBox(height: 24),
        _buildAccountActivity(),
      ],
    );
  }

  Widget _buildProfileOverview() {
    return Consumer2<UserProvider, ShopProvider>(
      builder: (context, userProv, shopProv, child) {
        final name = userProv.customerName.isNotEmpty ? userProv.customerName : 'Admin User';
        final phone = userProv.phoneNumber.isNotEmpty ? userProv.phoneNumber : (shopProv.shopMobile ?? 'N/A');
        final location = shopProv.shopAddress ?? userProv.deliveryAddress;
        
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8F5E9)),
                      child: ClipOval(
                        child: _isUploading
                            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
                            : (shopProv.shopProfilePic != null && shopProv.shopProfilePic!.isNotEmpty)
                                ? ProductImageWidget(imageUrl: shopProv.shopProfilePic, width: 100, height: 100)
                                : const Icon(Icons.person, size: 50, color: AppColors.primaryDark),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                      child: const Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.heading2(color: AppColors.textDark)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.admin_panel_settings, color: AppColors.primaryDark, size: 16),
                              const SizedBox(width: 4),
                              Text('Administrator', style: AppTextStyles.captionMedium(color: AppColors.primaryDark)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text('Active', style: AppTextStyles.captionMedium(color: AppColors.textDark)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Contact Info
              Container(
                width: 1,
                height: 80,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 24),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContactRow(Icons.phone_outlined, phone),
                    const SizedBox(height: 12),
                    _buildContactRow(Icons.email_outlined, 'admin@nearkirana.com'),
                    const SizedBox(height: 12),
                    if (location.isNotEmpty) _buildContactRow(Icons.location_on_outlined, location),
                    const SizedBox(height: 12),
                    _buildContactRow(Icons.calendar_today_outlined, 'Joined 12 Aug 2024'),
                    const SizedBox(height: 12),
                    _buildContactRow(Icons.access_time_outlined, 'Last login 2 hours ago'),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMid),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppTextStyles.bodyMedium(color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _buildTabItem(Icons.person_outline, 'Personal Information', true),
          const SizedBox(width: 32),
          _buildTabItem(Icons.security_outlined, 'Security', false),
          const SizedBox(width: 32),
          _buildTabItem(Icons.settings_outlined, 'Preferences', false),
          const SizedBox(width: 32),
          _buildTabItem(Icons.notifications_outlined, 'Notifications', false),
        ],
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, right: 24),
      decoration: isActive
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.primaryDark, width: 2),
              ),
            )
          : null,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isActive ? AppColors.primaryDark : AppColors.textMid),
          const SizedBox(width: 8),
          Text(
            label,
            style: isActive
                ? AppTextStyles.bodySemiBold(color: AppColors.primaryDark)
                : AppTextStyles.bodyMedium(color: AppColors.textMid),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInformationForm() {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assignment_ind_outlined, color: AppColors.primaryDark, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personal Information', style: AppTextStyles.title(color: AppColors.textDark)),
                  Text('Update your personal information and contact details', style: AppTextStyles.captionMedium(color: AppColors.textMid)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildTextField('Full Name *', _nameCtrl)),
              const SizedBox(width: 24),
              Expanded(child: _buildTextField('Email Address *', TextEditingController(text: 'admin@nearkirana.com'), isEnabled: true)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildTextField('Phone Number', _phoneCtrl, isEnabled: true)),
              const SizedBox(width: 24),
              Expanded(child: _buildTextField('Location', _locationCtrl)),
            ],
          ),
          const SizedBox(height: 24),
          _buildTextField('Profile Bio (Optional)', TextEditingController(text: 'Manage your personal information, security settings, and preferences for your NearKirana admin account.'), maxLines: 3),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('82/500', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : _updateProfile,
              icon: _isUpdating 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.person_outline, size: 18),
              label: const Text('Update Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isEnabled = true, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySemiBold(color: AppColors.textDark).copyWith(
            color: label.contains('*') ? AppColors.textDark : AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: isEnabled,
          maxLines: maxLines,
          style: AppTextStyles.bodyMedium(color: AppColors.textDark),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: isEnabled ? Colors.white : Colors.grey.shade50,
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
              borderSide: const BorderSide(color: AppColors.primaryDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountStatistics() {
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
              const Icon(Icons.bar_chart, color: AppColors.primaryDark, size: 24),
              const SizedBox(width: 8),
              Text('Account Statistics', style: AppTextStyles.title(color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStatCard(Icons.shopping_cart_outlined, const Color(0xFFE8F5E9), AppColors.primaryDark, '1,245', 'Total Orders\nManaged')),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(Icons.people_outline, const Color(0xFFE3F2FD), Colors.blue.shade700, '856', 'Customers\nManaged')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard(Icons.inventory_2_outlined, const Color(0xFFF3E5F5), Colors.purple.shade700, '324', 'Products\nManaged')),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(Icons.storefront_outlined, const Color(0xFFFFF3E0), Colors.orange.shade700, '8', 'Shops\nManaged')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, Color bgColor, Color iconColor, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withAlpha((0.5 * 255).toInt()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const Spacer(),
              Text(value, style: AppTextStyles.heading2(color: iconColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.captionMedium(color: AppColors.textMid)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
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
              const Icon(Icons.bolt, color: AppColors.textDark, size: 22),
              const SizedBox(width: 8),
              Text('Quick Actions', style: AppTextStyles.title(color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 20),
          _buildQuickActionRow(Icons.lock_outline, 'Change Password', 'Update your account password'),
          _divider(),
          _buildQuickActionRow(Icons.notifications_outlined, 'Manage Notifications', 'Configure notification preferences'),
          _divider(),
          _buildQuickActionRow(Icons.security_outlined, 'Two-Factor Authentication', 'Add an extra layer of security'),
          _divider(),
          _buildQuickActionRow(Icons.computer_outlined, 'Session Management', 'View and manage active sessions'),
        ],
      ),
    );
  }

  Widget _buildQuickActionRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.textDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium(color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.captionMedium(color: AppColors.textMid)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, size: 18, color: AppColors.textMid),
        ],
      ),
    );
  }

  Widget _divider() => Divider(color: Colors.grey.shade100, height: 1);

  Widget _buildAccountActivity() {
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
              const Icon(Icons.history, color: AppColors.textDark, size: 22),
              const SizedBox(width: 8),
              Text('Account Activity', style: AppTextStyles.title(color: AppColors.textDark)),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text('View All →', style: TextStyle(color: AppColors.primaryDark, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActivityRow(
            Icons.login_rounded,
            const Color(0xFFE3F2FD),
            Colors.blue.shade600,
            'Logged in from Chrome (Windows)',
            '2 hours ago',
          ),
          const SizedBox(height: 16),
          _buildActivityRow(
            Icons.person_outline,
            const Color(0xFFE8F5E9),
            AppColors.primaryDark,
            'Updated profile information',
            '1 day ago',
          ),
          const SizedBox(height: 16),
          _buildActivityRow(
            Icons.lock_outline,
            const Color(0xFFFFF3E0),
            Colors.orange.shade700,
            'Changed password',
            '3 days ago',
          ),
          const SizedBox(height: 16),
          _buildActivityRow(
            Icons.verified_user_outlined,
            const Color(0xFFE8F5E9),
            AppColors.primaryDark,
            'Enabled two-factor authentication',
            '1 week ago',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(IconData icon, Color bgColor, Color iconColor, String title, String time) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: AppTextStyles.bodyMedium(color: AppColors.textDark)),
        ),
        Text(time, style: AppTextStyles.captionMedium(color: AppColors.textMid)),
      ],
    );
  }
}

