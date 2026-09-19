import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'user_provider.dart';
import 'cart_provider.dart';
import 'main.dart';
import 'language_provider.dart';
import 'app_theme.dart';
import 'sound_service.dart';
import 'my_orders_screen.dart'; // FIX-11: Import MyOrdersScreen
import 'khata_statement_screen.dart';
import 'shop_provider.dart';
import 'shop_selector_screen.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'utils/product_image_widget.dart';
import 'modern_loader.dart';

class CustomerProfileTab extends StatelessWidget {
  const CustomerProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(langProvider.translate('my_profile')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.bgTint, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _ProfileAvatar(userProvider: userProvider).animate().scale(
                    duration: 400.ms,
                    curve: Curves.easeOutBack,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userProvider.customerName.isEmpty
                        ? langProvider.translate('guest')
                        : userProvider.customerName,
                    style: AppTextStyles.heading1(color: AppColors.textDark),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgTint,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      userProvider.phoneNumber,
                      style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats / Info Row
            Row(
              children: [
                Expanded(
                  child: _buildMiniStatCard(
                    icon: Icons.shopping_bag_rounded,
                    title: langProvider.translate('my_orders'),
                    value: langProvider.translate('view_history'),
                    color: AppColors.accentPink,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // FIX-11: Navigate to Orders screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyOrdersScreen(),
                        ),
                      );
                    },
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMiniStatCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: langProvider.translate('khata'),
                    value: langProvider.translate('view_ledger'),
                    color: AppColors.primaryDark,
                    onTap: () async {
                      HapticFeedback.lightImpact();

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(color: AppColors.primaryDark),
                        ),
                      );

                      try {
                        final phone = userProvider.phoneNumber;
                        final query = await FirebaseFirestore.instance
                            .collection('customers')
                            .where('mobile', isEqualTo: phone)
                            .limit(1)
                            .get();

                        if (context.mounted) Navigator.pop(context); // dismiss loader

                        if (query.docs.isNotEmpty) {
                          final customerId = query.docs.first.id;
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => KhataStatementScreen(
                                  customerId: customerId,
                                  customerName: userProvider.customerName.isEmpty
                                      ? 'Guest'
                                      : userProvider.customerName,
                                  isAdmin: false,
                                ),
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Khata not found for this number.'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) Navigator.pop(context);
                        debugPrint('Error fetching customer for Khata: $e');
                      }
                    },
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Options
            _buildInfoCard(
              title: langProvider.translate('delivery_address'),
              icon: Icons.location_on_rounded,
              color: const Color(0xFF4CAF50),
              content: _buildAddressContent(
                context,
                userProvider,
                langProvider,
              ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 20),
            _buildInfoCard(
              title: langProvider.translate('app_language'),
              icon: Icons.language_rounded,
              color: Colors.blue,
              content: _buildLanguageContent(context, langProvider),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 20),
            _buildInfoCard(
              title: langProvider.translate('help_support'),
              icon: Icons.support_agent_rounded,
              color: Colors.orange,
              content: _buildSupportContent(context, langProvider),
            ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.blue),
              ),
              title: const Text(
                'Dukan Badlein (Change Shop)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Doosri dukan search ya scan karein'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Dukan Badlein?'),
                    content: const Text(
                      'Kya aap is dukan se bahar aakar doosri dukan chunna chahte hain? Aapka Cart clear ho jayega.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text('Haan, Badlein'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await Provider.of<ShopProvider>(context, listen: false).clearShop();

                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const ShopSelectorScreen()),
                      (route) => false,
                    );
                  }
                }
              },
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text(
                        langProvider.translate('logout'),
                        style: AppTextStyles.heading2(
                          color: AppColors.textDark,
                        ),
                      ),
                      content: Text(
                        langProvider.translate('logout_confirm'),
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textMid,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(
                            langProvider.translate('cancel'),
                            style: AppTextStyles.bodySemiBold(
                              color: AppColors.textMid,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(dialogContext); // Close dialog
                            SoundService().success();

                            final cartProvider = Provider.of<CartProvider>(
                              context,
                              listen: false,
                            );

                            await userProvider.logout();
                            cartProvider.clearCart();

                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const LoginScreen(fromLogout: true),
                                ),
                                (route) => false,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(langProvider.translate('logout')),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.logout_rounded, size: 24),
                label: Text(langProvider.translate('logout')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  foregroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: AppTextStyles.button(),
                  elevation: 0,
                ),
              ),
            ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 24),
            Text(
              'Shop App - Version 1.0.0',
              style: AppTextStyles.captionMedium(color: AppColors.textLight),
            ).animate().fadeIn(delay: 900.ms),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgTint, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.captionMedium(color: AppColors.textMid),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.bodySemiBold(
                color: AppColors.textDark,
              ).copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageContent(
    BuildContext context,
    LanguageProvider langProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLanguageOption(context, langProvider, 'hi', 'हिंदी'),
          _buildLanguageOption(context, langProvider, 'en', 'English'),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    LanguageProvider langProvider,
    String code,
    String label,
  ) {
    final isSelected = langProvider.currentLanguage == code;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        langProvider.setLanguage(code);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : AppColors.bgTint,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style:
              AppTextStyles.bodyMedium(
                color: isSelected ? Colors.blue : AppColors.textMid,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ),
    );
  }

  Widget _buildSupportContent(BuildContext context, LanguageProvider langProvider) {
    return Column(
      children: [
        _buildSupportTile(
          icon: Icons.call_rounded,
          color: Colors.orange,
          title: langProvider.translate('call_shop'),
          subtitle: 'Store Helpdesk',
          onTap: () async {
            HapticFeedback.lightImpact();
            try {
              final shopProvider = Provider.of<ShopProvider>(context, listen: false);
              String phone = shopProvider.shopSupportPhone?.toString() ?? shopProvider.shopMobile?.toString() ?? '';
              phone = phone.replaceAll(RegExp(r'\D'), '');
              if (phone.length == 10) phone = '91$phone';
              if (phone.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Is dukan ka contact number available nahi hai.')),
                  );
                }
                return;
              }
              
              final Uri launchUri = Uri(scheme: 'tel', path: '+$phone');
              await launchUrl(launchUri);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open dialer.')),
                );
              }
            }
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, thickness: 1, color: AppColors.bgTint),
        ),
        _buildSupportTile(
          icon: Icons.chat_rounded,
          color: Colors.green,
          title: langProvider.translate('whatsapp_support'),
          subtitle: langProvider.translate('chat_with_us'),
          onTap: () async {
            HapticFeedback.lightImpact();
            try {
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              final shopProvider = Provider.of<ShopProvider>(context, listen: false);
              final String userName = userProvider.customerName.isNotEmpty ? userProvider.customerName : 'Customer';
              final String userPhone = userProvider.phoneNumber.isNotEmpty ? userProvider.phoneNumber : '';
              
              String template = shopProvider.shopWhatsAppTemplate?.toString() ??
                  "नमस्ते {shopName}, मेरा नाम {name} है और मेरा मोबाइल नंबर {phone} है। मुझे अपने ऑर्डर / अकाउंट के बारे में कुछ मदद चाहिए।";
              template = template.replaceAll('{shopName}', shopProvider.shopName ?? 'My Shop');
              
              String message = template
                  .replaceAll('{name}', userName)
                  .replaceAll('{phone}', userPhone.isNotEmpty ? '($userPhone)' : '');
              
              final String encodedMessage = Uri.encodeComponent(message);

              String phone = shopProvider.shopSupportPhone?.toString() ?? shopProvider.shopMobile?.toString() ?? '';
              phone = phone.replaceAll(RegExp(r'\D'), '');
              if (phone.length == 10) phone = '91$phone';
              if (phone.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Is dukan ka WhatsApp number available nahi hai.')),
                  );
                }
                return;
              }
              
              final Uri launchUri = Uri.parse('https://wa.me/$phone?text=$encodedMessage');
              await launchUrl(launchUri, mode: LaunchMode.externalApplication);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open WhatsApp.')),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildSupportTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.captionMedium(color: AppColors.textMid),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: AppColors.textLight,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAddressContent(
    BuildContext context,
    UserProvider userProvider,
    LanguageProvider langProvider,
  ) {
    if (userProvider.deliveryAddress.isEmpty &&
        userProvider.customerHouseNo.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          langProvider.translate('no_address'),
          style: AppTextStyles.bodyMedium(color: AppColors.textMid),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.home_work_rounded,
                color: AppColors.textMid,
                size: 20,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${langProvider.translate('house_no')} ${userProvider.customerHouseNo}',
                    style: AppTextStyles.bodySemiBold(
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: Text(
                      userProvider.deliveryAddress,
                      style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (userProvider.customerLandmark.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.near_me_rounded,
                  color: AppColors.textLight,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  '${langProvider.translate('landmark_txt')} ${userProvider.customerLandmark}',
                  style: AppTextStyles.captionMedium(color: AppColors.textMid),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.bgTint, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppTextStyles.heading2(
                    color: AppColors.textDark,
                  ).copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.bgTint),
          content,
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatefulWidget {
  final UserProvider userProvider;
  const _ProfileAvatar({required this.userProvider});
  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        final finalImageUrl = 'data:image/jpeg;base64,$base64String';
        await widget.userProvider.updateProfileImage(finalImageUrl);
      } catch (e) {
        debugPrint('Error uploading profile pic: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight.withValues(alpha: 0.2),
              border: Border.all(
                color: AppColors.primaryLight,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: _isUploading
                  ? const Center(child: ModernLoader(color: AppColors.primaryDark))
                  : (widget.userProvider.profileImageUrl != null && widget.userProvider.profileImageUrl!.isNotEmpty)
                      ? ProductImageWidget(imageUrl: widget.userProvider.profileImageUrl, width: 100, height: 100)
                      : const Icon(
                          Icons.person_rounded,
                          size: 50,
                          color: AppColors.primaryDark,
                        ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }
}
