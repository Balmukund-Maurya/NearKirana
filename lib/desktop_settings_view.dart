import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:near_kirana/language_provider.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/shop_selector_screen.dart';

class DesktopSettingsView extends StatefulWidget {
  final Function(int) onNavigate;
  const DesktopSettingsView({super.key, required this.onNavigate});

  @override
  State<DesktopSettingsView> createState() => _DesktopSettingsViewState();
}

class _DesktopSettingsViewState extends State<DesktopSettingsView> {

  void _showNotImplemented(String feature) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$feature is not available yet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F9FC),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfileCard(),
                            const SizedBox(height: 32),
                            _buildAppPreferencesCard(),
                            const SizedBox(height: 32),
                            _buildAccountSecurityCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      // RIGHT COLUMN
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDeliveryAddressCard(),
                            const SizedBox(height: 32),
                            _buildLanguageRegionCard(),
                            const SizedBox(height: 32),
                            _buildHelpSupportCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: const Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage your account, preferences and app settings',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final userProvider = Provider.of<UserProvider>(context);
    final String initial = userProvider.customerName.isNotEmpty
        ? userProvider.customerName.trim()[0].toUpperCase()
        : 'G';
    final String name = userProvider.customerName.isEmpty ? 'Guest' : userProvider.customerName;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Update your personal details', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showEditProfileDialog(userProvider),
                icon: const Icon(Icons.edit, size: 14, color: AppColors.primaryDark),
                label: const Text('Edit Profile', style: TextStyle(color: AppColors.primaryDark)),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryDark.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFE8F0FE),
                backgroundImage: userProvider.profileImageUrl != null
                    ? NetworkImage(userProvider.profileImageUrl!)
                    : null,
                child: userProvider.profileImageUrl == null
                    ? Text(
                        initial,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(userProvider.email.isEmpty ? 'No email provided' : userProvider.email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(userProvider.phoneNumber, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildTextField('Full Name', name),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField('Phone Number', userProvider.phoneNumber),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('Email Address', userProvider.email.isEmpty ? 'No email provided' : userProvider.email),
        ],
      ),
    );
  }

  void _showEditProfileDialog(UserProvider userProvider) {
    final nameController = TextEditingController(text: userProvider.customerName);
    final emailController = TextEditingController(text: userProvider.email);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              userProvider.setUser(
                nameController.text.trim(),
                userProvider.phoneNumber,
                address: userProvider.deliveryAddress,
                houseNo: userProvider.customerHouseNo,
                landmark: userProvider.customerLandmark,
              );
              await userProvider.updateEmail(emailController.text.trim());
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ),
      ],
    );
  }

  Widget _buildAccountSecurityCard() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account & Security', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('Manage your account security', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 24),
          _buildSettingsRow(
            icon: Icons.logout_rounded,
            title: 'Logout',
            subtitle: 'Sign out from your account',
            iconColor: Colors.black87,
            onTap: () async {
              await userProvider.logout();
            },
          ),
          const Divider(height: 32, color: Color(0xFFEEEEEE)),
          _buildSettingsRow(
            icon: Icons.delete_forever_rounded,
            title: 'Delete Account',
            subtitle: 'Permanently remove your account and data',
            iconColor: Colors.red,
            titleColor: Colors.red,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                  content: const Text('Are you sure you want to permanently delete your account? This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await userProvider.deleteAccount();
                        // Navigation state will reset to login automatically because user is no longer logged in, handled elsewhere usually (e.g. wrapper).
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Delete'),
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

  Widget _buildAppPreferencesCard() {
    final userProvider = Provider.of<UserProvider>(context);
    final prefs = userProvider.preferences;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('App Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('Manage your notifications and alerts', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 24),
          _buildPreferenceSwitch(
            title: 'Push Notifications',
            subtitle: 'Receive updates about your orders',
            value: prefs['push_notifications'] ?? true,
            onChanged: (val) => userProvider.updatePreference('push_notifications', val),
          ),
          const Divider(height: 32, color: Color(0xFFEEEEEE)),
          _buildPreferenceSwitch(
            title: 'Offers & Discounts',
            subtitle: 'Get notified about the latest deals',
            value: prefs['offers'] ?? true,
            onChanged: (val) => userProvider.updatePreference('offers', val),
          ),
          const Divider(height: 32, color: Color(0xFFEEEEEE)),
          _buildPreferenceSwitch(
            title: 'Promotional Emails',
            subtitle: 'Receive emails about new products',
            value: prefs['promo_emails'] ?? false,
            onChanged: (val) => userProvider.updatePreference('promo_emails', val),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primaryDark,
        ),
      ],
    );
  }

  Widget _buildDeliveryAddressCard() {
    final userProvider = Provider.of<UserProvider>(context);
    final addresses = userProvider.savedAddresses;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivery Addresses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Manage your saved delivery addresses', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showAddAddressDialog(userProvider),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: const Text('Add Address', style: TextStyle(color: Colors.white)),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          if (addresses.isEmpty && (userProvider.deliveryAddress.isNotEmpty || userProvider.customerHouseNo.isNotEmpty))
            _buildAddressItem(
              userProvider: userProvider,
              addressData: {
                'address': userProvider.deliveryAddress,
                'houseNo': userProvider.customerHouseNo,
                'landmark': userProvider.customerLandmark,
                'label': userProvider.addressLabel,
                'lat': userProvider.currentLat,
                'lng': userProvider.currentLng,
              },
              index: -1,
            ),
          if (addresses.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: addresses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildAddressItem(
                  userProvider: userProvider,
                  addressData: addresses[index],
                  index: index,
                );
              },
            ),
          if (addresses.isEmpty && userProvider.deliveryAddress.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No delivery address saved.', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _buildAddressItem({
    required UserProvider userProvider,
    required Map<String, dynamic> addressData,
    required int index,
  }) {
    final bool isDefault = userProvider.deliveryAddress == addressData['address'] && userProvider.customerHouseNo == addressData['houseNo'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDefault ? AppColors.primaryDark.withValues(alpha: 0.05) : Colors.white,
        border: Border.all(color: isDefault ? AppColors.primaryDark : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDefault ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            color: isDefault ? AppColors.primaryDark : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      addressData['label'] ?? 'Home',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    if (isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Default', style: TextStyle(fontSize: 10, color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${addressData['houseNo']} ${addressData['address']}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                if ((addressData['landmark'] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Landmark: ${addressData['landmark']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              if (!isDefault)
                InkWell(
                  onTap: () {
                    userProvider.setDeliveryAddress(
                      addressData['address'] ?? '',
                      addressData['houseNo'] ?? '',
                      addressData['landmark'] ?? '',
                      label: addressData['label'] ?? 'Home',
                    );
                  },
                  child: const Text('Set Default', style: TextStyle(fontSize: 13, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                ),
              if (!isDefault) const SizedBox(width: 16),
              if (index != -1)
                InkWell(
                  onTap: () async {
                    await userProvider.deleteSavedAddress(index);
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline, size: 14, color: Colors.red),
                      SizedBox(width: 4),
                      Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddAddressDialog(UserProvider userProvider) {
    final labelController = TextEditingController();
    final houseNoController = TextEditingController();
    final addressController = TextEditingController();
    final landmarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Address'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label (e.g. Home, Office)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: houseNoController,
                decoration: const InputDecoration(labelText: 'House/Flat No', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Street/Locality', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: landmarkController,
                decoration: const InputDecoration(labelText: 'Landmark (Optional)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (addressController.text.trim().isEmpty || houseNoController.text.trim().isEmpty) {
                return;
              }
              final newAddress = {
                'label': labelController.text.trim().isEmpty ? 'Home' : labelController.text.trim(),
                'houseNo': houseNoController.text.trim(),
                'address': addressController.text.trim(),
                'landmark': landmarkController.text.trim(),
                'lat': userProvider.currentLat ?? 0.0,
                'lng': userProvider.currentLng ?? 0.0,
              };
              await userProvider.addSavedAddress(newAddress);
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageRegionCard() {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Language & Region', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('Set your preferred language and location', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 24),
          
          _buildDropdownRow(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'Choose your preferred language',
            value: langProvider.currentLanguage == 'hi' ? 'Hindi (हिन्दी)' : 'English',
            items: ['English', 'Hindi (हिन्दी)'],
            onChanged: (val) {
              if (val == 'Hindi (हिन्दी)') {
                langProvider.setLanguage('hi');
              } else {
                langProvider.setLanguage('en');
              }
            },
          ),
          const SizedBox(height: 16),
          _buildDropdownRow(
            icon: Icons.location_on_outlined,
            title: 'Location',
            subtitle: 'Your current delivery location',
            value: 'Current Location',
            items: ['Current Location', 'Change Shop'],
            onChanged: (val) {
              if (val == 'Change Shop') {
                _changeShop();
              }
            },
          ),
          const SizedBox(height: 16),
          _buildDropdownRow(
            icon: Icons.currency_rupee,
            title: 'Currency',
            subtitle: 'Prices will be shown in this currency',
            value: 'INR (₹)',
            items: ['INR (₹)'],
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }

  Future<void> _changeShop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Shop?'),
        content: const Text('Do you want to leave this shop and choose another? Your cart will be cleared.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
            child: const Text('Yes, Change Shop'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await Provider.of<ShopProvider>(context, listen: false).clearShop();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ShopSelectorScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildDropdownRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpSupportCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Help & Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('Get help and support', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 24),
          _buildSettingsRow(
            icon: Icons.help_outline_rounded,
            title: 'Help Center',
            subtitle: 'Find answers to common questions',
            onTap: () => _showNotImplemented('Help Center'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(color: Color(0xFFEEEEEE)),
          ),
          _buildSettingsRow(
            icon: Icons.support_agent_rounded,
            title: 'Contact Support',
            subtitle: 'Get in touch with our support team',
            onTap: _contactSupport,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(color: Color(0xFFEEEEEE)),
          ),
          _buildSettingsRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            onTap: () => _showNotImplemented('Privacy Policy'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(color: Color(0xFFEEEEEE)),
          ),
          _buildSettingsRow(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            subtitle: 'Read our terms and conditions',
            onTap: () => _showNotImplemented('Terms & Conditions'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _contactSupport() async {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    String phone = shopProvider.shopSupportPhone?.toString() ?? shopProvider.shopMobile?.toString() ?? '';
    phone = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 10) phone = '91$phone';
    if (phone.isEmpty) {
      _showNotImplemented('Contact Support (No phone number)');
      return;
    }
    
    final Uri launchUri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = Colors.black54,
    Color titleColor = Colors.black87,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: titleColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
