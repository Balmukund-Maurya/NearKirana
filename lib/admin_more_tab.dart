import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'admin_settings_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_staff_audit_screen.dart';
import 'admin_data_export_backup_screen.dart';
import 'admin_shop_boys_screen.dart';
import 'admin_loyalty_screen.dart';
import 'shop_qr_screen.dart';
import 'gateway_screen.dart';
import 'sound_service.dart';
import 'shop_provider.dart';
import 'language_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';

class AdminMoreTab extends StatefulWidget {
  const AdminMoreTab({super.key});

  @override
  State<AdminMoreTab> createState() => _AdminMoreTabState();
}

class _AdminMoreTabState extends State<AdminMoreTab> {
  String _ownerName = 'Shop Owner';
  String _shopName = 'NearKirana Store';
  bool _isOpen = true;

  @override
  void initState() {
    super.initState();
    _loadShopProfile();
  }

  Future<void> _loadShopProfile() async {
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    if (shopId == null || shopId.isEmpty) return;

    try {
      final doc = await FirebaseUtils.firestore.collection('shops').doc(shopId).get();
      if (!mounted) return;

      final data = doc.data();
      if (data != null) {
        setState(() {
          _ownerName = (data['owner_name'] ?? data['shop_name'] ?? 'Shop Owner').toString().trim();
          _shopName = (data['shop_name'] ?? 'NearKirana Store').toString().trim();
          _isOpen = data['is_open'] ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleShopOpenStatus() async {
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    if (shopId == null) return;
    HapticFeedback.lightImpact();

    final nextStatus = !_isOpen;
    setState(() => _isOpen = nextStatus);

    try {
      await FirebaseUtils.firestore.collection('shops').doc(shopId).update({
        'is_open': nextStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
      SoundService().success();
    } catch (e) {
      if (mounted) {
        setState(() => _isOpen = !nextStatus);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Color(0xFF0C831F),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Store Hub & More', 'दुकान प्रबंधन व सेवाएं', 'Store Hub & More'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  t('Partner Settings & Tools', 'सेटिंग्स और टूल्स', 'Partner Settings & Tools'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            // Zepto/Blinkit Partner Profile Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Store Avatar
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0C831F).withValues(alpha: 0.12),
                          border: Border.all(
                            color: const Color(0xFF0C831F).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 28,
                          color: Color(0xFF0C831F),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _shopName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF0C831F)),
                                const SizedBox(width: 4),
                                Text(
                                  _ownerName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // QR Code Quick Button
                      IconButton.filledTonal(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ShopQrScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF0C831F), size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF0C831F).withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        tooltip: t('Shop QR Code', 'दुकान का QR कोड', 'Shop QR Code'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // Store Online/Offline Toggle Strip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isOpen
                                ? t('Store is Online (Accepting Orders)', 'दुकान खुली है (ऑर्डर चालू हैं)', 'Store Online (Orders ON)')
                                : t('Store is Closed (Offline)', 'दुकान बंद है (ऑर्डर बंद)', 'Store Closed (Offline)'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _isOpen,
                          activeThumbColor: const Color(0xFF0C831F),
                          onChanged: (_) => _toggleShopOpenStatus(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 20),

            // Section 1: Store Operations (दुकान संचालन)
            _buildModernSection(
              title: t('Store Operations', 'दुकान संचालन व ग्राहक', 'Store Operations'),
              icon: Icons.store_rounded,
              children: [
                _buildModernTile(
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF2563EB),
                  title: t('Customer Directory', 'ग्राहक सूची', 'Customer Directory'),
                  subtitle: t('Customer accounts, orders & history', 'सभी ग्राहकों की लिस्ट व खरीदारी विवरण', 'Customers list and orders history'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminCustomersScreen()),
                    );
                  },
                ),
                _buildModernTile(
                  icon: Icons.two_wheeler_rounded,
                  color: const Color(0xFFEA580C),
                  title: t('Delivery Partners & Dispatch', 'डिलीवरी स्टाफ व डिस्पैच', 'Delivery Partners & Dispatch'),
                  subtitle: t('Manage delivery boys, active dispatches & routes', 'डिलीवरी बॉय जोड़ें व ऑर्डर डिलीवरी ट्रैक करें', 'Manage delivery boys and dispatches'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminShopBoysScreen()),
                    );
                  },
                ),
                _buildModernTile(
                  icon: Icons.assignment_return_rounded,
                  color: const Color(0xFF7C3AED),
                  title: t('Complaints & Returns', 'शिकायतें व सामान वापसी', 'Complaints & Returns'),
                  subtitle: t('Manage customer issues, item returns & refunds', 'खराब सामान, रीप्लेसमेंट व रिफंड समाधान', 'Damaged items, returns and refunds'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminComplaintsScreen()),
                    );
                  },
                ),
              ],
            ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 16),

            // Section 2: Finances & Reports (मुनाफा, थोक खरीद व रिपोर्ट)
            _buildModernSection(
              title: t('Finances & Analytics', 'फाइनेंस, मुनाफा व रिपोर्ट', 'Finances & Analytics'),
              icon: Icons.currency_rupee_rounded,
              children: [
                _buildModernTile(
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF0C831F),
                  title: t('Sales & Profit Analytics', 'बिक्री व मुनाफा विश्लेषण', 'Sales & Profit Analytics'),
                  subtitle: t('Gross profit, revenue trends, COGS & margins', 'दैनिक कमाई, नेट प्रॉफिट व खर्चों की रिपोर्ट', 'Gross profit, revenue and margin insights'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()),
                    );
                  },
                ),
                _buildModernTile(
                  icon: Icons.card_giftcard_rounded,
                  color: const Color(0xFFD97706),
                  title: t('Loyalty & Referrals', 'लॉयल्टी व रेफरल प्रोग्राम', 'Loyalty & Referrals'),
                  subtitle: t('Cashback coins, coupons & rewards setup', 'ग्राहकों के पॉइंट्स, कूपन व रिवॉर्ड नियम', 'Points passbook, cashback & customer rewards'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminLoyaltyScreen()),
                    );
                  },
                ),
                _buildModernTile(
                  icon: Icons.cloud_download_rounded,
                  color: const Color(0xFF0D9488),
                  title: t('Data Export & Backup', 'डेटा बैकअप व रिपोर्ट एक्सपोर्ट', 'Data Export & Backup'),
                  subtitle: t('Download Excel/PDF reports for accounting', 'CA/अकाउंटेंट के लिए एक्सेल व पीडीएफ फाइल', 'Download CSV/PDF reports & cloud backups'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminDataExportBackupScreen()),
                    );
                  },
                ),
              ],
            ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 16),

            // Section 3: Store Settings & System
            _buildModernSection(
              title: t('Settings & Preferences', 'सेटिंग्स व भाषा', 'Settings & Preferences'),
              icon: Icons.tune_rounded,
              children: [
                _buildModernTile(
                  icon: Icons.settings_rounded,
                  color: const Color(0xFF475569),
                  title: t('Store Settings', 'दुकान की सेटिंग्स', 'Store Settings'),
                  subtitle: t('Shop name, delivery radius, timings & UPI', 'दुकान का नाम, डिलीवरी दूरी व यूपीआई आईडी', 'Shop profile, delivery radius and UPI setup'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminSettingsScreen()),
                    );
                  },
                ),
                _buildModernTile(
                  icon: Icons.badge_rounded,
                  color: const Color(0xFF4338CA),
                  title: t('Staff Accounts & Audit', 'स्टाफ खाते व ऑडिट लॉग', 'Staff Accounts & Audit'),
                  subtitle: t('Employee roles, login PINs & activity audit', 'कर्मचारी के अधिकार, पिन व एक्टिविटी लॉग', 'Staff permissions, PINs and audit trail'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminStaffAuditScreen()),
                    );
                  },
                ),
                _buildModernTile(
                  icon: Icons.language_rounded,
                  color: const Color(0xFF0C831F),
                  title: t('App Language', 'ऐप की भाषा', 'App Language'),
                  subtitle: lang.isHindi
                      ? 'हिंदी (Hindi) चुना गया है'
                      : lang.isHinglish
                          ? 'Hinglish (रोमन हिंदी) चुना गया है'
                          : 'English is active',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showLanguageModal(context);
                  },
                ),
              ],
            ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, t),
                icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFDC2626)),
                label: Text(
                  t('Logout from Store', 'दुकान से लॉगआउट करें', 'Logout from Store'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF2F2),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 18),
            Text(
              'NearKirana Partner • v2.6.4 (Zepto Architecture)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      color: Color(0xFFF1F5F9),
                      indent: 54,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageModal(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.translate_rounded, color: Color(0xFF0C831F), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t('Select App Language', 'ऐप की भाषा चुनें', 'App Language Select Karein'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildLangOptionTile(context, lang, 'en', 'English', 'Default standard English', setSheetState),
              const SizedBox(height: 10),
              _buildLangOptionTile(context, lang, 'hi', 'हिंदी (Hindi)', 'दुकानदार व ग्राहकों के लिए सरल हिंदी', setSheetState),
              const SizedBox(height: 10),
              _buildLangOptionTile(context, lang, 'hinglish', 'Hinglish (Roman Hindi)', 'Easy English script Hindi', setSheetState),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangOptionTile(
    BuildContext context,
    LanguageProvider langProvider,
    String code,
    String label,
    String sublabel,
    StateSetter setSheetState,
  ) {
    final isSelected = langProvider.currentLanguage == code;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        langProvider.setLanguage(code);
        setSheetState(() {});
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0C831F).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0C831F) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF0C831F) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF0C831F),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, String Function(String, String, String) t) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              t('Logout Store?', 'लॉगआउट करना चाहते हैं?', 'Logout Store?'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Text(
          t('Are you sure you want to log out from this store?', 'क्या आप इस दुकान से लॉगआउट करना चाहते हैं?', 'Kya aap is dukan se logout karna chahte hain?'),
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              t('Cancel', 'रद्द करें', 'Cancel'),
              style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
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
              await prefs.remove('global_phone');
              await prefs.remove('app_role');

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const GatewayScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              t('Logout', 'लॉगआउट', 'Logout'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
