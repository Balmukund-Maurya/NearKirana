import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'language_provider.dart';
import 'admin_settings_screen.dart';
import 'admin_customers_screen.dart';
import 'main.dart';
import 'app_theme.dart';
import 'sound_service.dart';
import 'shop_provider.dart';

class AdminMoreTab extends StatefulWidget {
  const AdminMoreTab({super.key});

  @override
  State<AdminMoreTab> createState() => _AdminMoreTabState();
}

class _AdminMoreTabState extends State<AdminMoreTab> {
  String _ownerName = 'Shop Owner';

  @override
  void initState() {
    super.initState();
    _loadOwnerName();
  }

  Future<void> _loadOwnerName() async {
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    if (shopId == null || shopId.isEmpty) {
      if (mounted) {
        setState(() => _ownerName = 'Shop Owner');
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(shopId).get();
      if (!mounted) return;

      final data = doc.data();
      final ownerName = (data?['owner_name'] ?? data?['shop_name'] ?? '').toString().trim();
      setState(() {
        _ownerName = ownerName.isNotEmpty ? ownerName : 'Shop Owner';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _ownerName = 'Shop Owner');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'More Options',
          style: AppTextStyles.heading2(color: AppColors.textDark),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Admin Profile Card
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
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryLight.withValues(alpha: 0.2),
                      border: Border.all(
                        color: AppColors.primaryLight,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 40,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                        Text(
                          _ownerName,
                          style: AppTextStyles.heading2(
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentPink.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            langProvider.translate('admin_role'),
                            style: AppTextStyles.captionMedium(
                              color: AppColors.accentPink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 32),

            // Menu Items
            _buildMenuSection(
              title: langProvider.translate('store_management'),
              children: [
                _buildMenuTile(
                  icon: Icons.people_alt_rounded,
                  color: Colors.blue,
                  title: langProvider.translate('admin_customers'),
                  subtitle: langProvider.translate('admin_customers_subtitle'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminCustomersScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuTile(
                  icon: Icons.store_rounded,
                  color: Colors.orange,
                  title: langProvider.translate('store_settings'),
                  subtitle: langProvider.translate('store_settings_subtitle'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 24),

            _buildMenuSection(
              title: langProvider.translate('app_settings'),
              children: [
                _buildMenuTile(
                  icon: Icons.language_rounded,
                  color: Colors.teal,
                  title: langProvider.translate('language_setting'),
                  subtitle: langProvider.translate('language_setting_subtitle'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showLanguageDialog(context, langProvider);
                  },
                ),
              ],
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 32),

            // Logout
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
                        langProvider.translate('admin_logout'),
                        style: AppTextStyles.heading2(
                          color: AppColors.textDark,
                        ),
                      ),
                      content: Text(
                        langProvider.translate('admin_logout_confirm'),
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
                            Navigator.pop(dialogContext);
                            SoundService().success();

                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('isAdminLoggedIn');
                            await prefs.remove('customerName');
                            await prefs.remove('customerPhone');

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
                          child: Text(langProvider.translate('admin_logout')),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.logout_rounded, size: 24),
                label: Text(langProvider.translate('admin_logout')),
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
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 32),
            Text(
              langProvider.translate('admin_version'),
              style: AppTextStyles.captionMedium(color: AppColors.textLight),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Text(
            title,
            style: AppTextStyles.heading2(
              color: AppColors.textDark,
            ).copyWith(fontSize: 16),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.bgTint, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children.asMap().entries.map((entry) {
              final isLast = entry.key == children.length - 1;
              return Column(
                children: [
                  entry.value,
                  if (!isLast)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.bgTint,
                      indent: 64,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
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
        size: 16,
        color: AppColors.textLight,
      ),
      onTap: onTap,
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    LanguageProvider langProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.bgTint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                langProvider.translate('select_language'),
                style: AppTextStyles.heading2(color: AppColors.textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildLanguageOption(sheetContext, langProvider, 'hinglish', 'Hinglish', setSheetState),
              const SizedBox(height: 12),
              _buildLanguageOption(sheetContext, langProvider, 'hi', 'हिंदी', setSheetState),
              const SizedBox(height: 12),
              _buildLanguageOption(sheetContext, langProvider, 'en', 'English', setSheetState),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    LanguageProvider langProvider,
    String code,
    String label,
    StateSetter setSheetState,
  ) {
    final isSelected = langProvider.currentLanguage == code;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        langProvider.setLanguage(code);
        // Rebuild the bottom sheet to reflect selection
        setSheetState(() {});
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.bgTint,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySemiBold(
                color: isSelected ? AppColors.primaryDark : AppColors.textDark,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryDark,
              ),
          ],
        ),
      ),
    );
  }
}
