import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../language_provider.dart';

/// Full-featured in-app viewer for NearKirana Privacy Policy & Terms of Service.
/// Complies with Google Play & Apple App Store sensitive permission requirements.
class LegalPolicyDialog extends StatelessWidget {
  final int initialTabIndex; // 0: Privacy Policy, 1: Terms of Service
  final String? externalPolicyUrl;

  const LegalPolicyDialog({
    super.key,
    this.initialTabIndex = 0,
    this.externalPolicyUrl = 'https://nearkirana.web.app/privacy-policy',
  });

  static Future<void> showPrivacyPolicy(BuildContext context, {String? url}) {
    return showDialog(
      context: context,
      builder: (ctx) => LegalPolicyDialog(initialTabIndex: 0, externalPolicyUrl: url),
    );
  }

  static Future<void> showTerms(BuildContext context, {String? url}) {
    return showDialog(
      context: context,
      builder: (ctx) => LegalPolicyDialog(initialTabIndex: 1, externalPolicyUrl: url),
    );
  }

  Future<void> _launchExternalUrl(BuildContext context, String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open external link.')),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageProvider.of(context);
    final isHindi = lang.isHindi;
    final isHinglish = lang.isHinglish;

    final titlePrivacy = isHindi
        ? 'गोपनीयता नीति'
        : (isHinglish ? 'Privacy Policy' : 'Privacy Policy');
    final titleTerms = isHindi
        ? 'सेवा की शर्तें'
        : (isHinglish ? 'Terms of Service' : 'Terms of Service');

    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: Column(
            children: [
              // Header with Title and Tabs
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.primaryDark,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NearKirana Legal & Compliance',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                isHindi
                                    ? 'उपयोगकर्ता सुरक्षा व पारदर्शिता'
                                    : 'User Data Protection & Compliance',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TabBar(
                      indicatorColor: AppColors.primaryDark,
                      indicatorWeight: 3,
                      labelColor: AppColors.primaryDark,
                      unselectedLabelColor: const Color(0xFF64748B),
                      labelStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      tabs: [
                        Tab(text: titlePrivacy),
                        Tab(text: titleTerms),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPrivacyPolicyContent(context),
                    _buildTermsOfServiceContent(context),
                  ],
                ),
              ),

              // Footer with External Link & Close Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (externalPolicyUrl != null && externalPolicyUrl!.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          isHindi ? 'वेबसाइट पर देखें' : 'Open in Browser',
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => _launchExternalUrl(context, externalPolicyUrl!),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        isHindi ? 'बंद करें' : 'Close',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicyContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('1. Overview'),
        _buildParagraph(
          'NearKirana ("we", "our", or "the platform") is dedicated to protecting your privacy. This policy explains how information is collected, used, and protected when you access our hyperlocal grocery ordering platform and Kirana store ERP.',
        ),
        _buildSectionHeader('2. Information We Collect'),
        _buildBulletPoint('Phone Number & Account Info: Used for fast OTP authentication and order communications.'),
        _buildBulletPoint('Delivery Addresses & Geolocation: Used strictly to determine delivery feasibility and calculate accurate ETA from local stores.'),
        _buildBulletPoint('Order History & Store Passbooks: Used to maintain your purchase receipts, Khata ledger, and loyalty points.'),
        _buildSectionHeader('3. Device Permissions & Purpose Justification'),
        _buildBulletPoint('Camera: Required solely to scan product barcodes (for inventory and rapid cart addition) and take photos for customer returns/complaint verification.'),
        _buildBulletPoint('Microphone & Speech Recognition: Required to enable voice-based grocery search and ordering in Hindi and English. Audio is processed only during active voice sessions and is never recorded in the background.'),
        _buildBulletPoint('Location (Fine & Coarse): Required during checkout to verify delivery coverage and to provide live order GPS tracking for active deliveries.'),
        _buildBulletPoint('Push Notifications: Used to alert you about real-time order status updates (Accepted, Out for Delivery, Delivered).'),
        _buildSectionHeader('4. Payments & Financial Data'),
        _buildParagraph(
          'We do not store complete credit card or debit card credentials on our servers. All online payments are handled directly by PCI-DSS certified gateways (Razorpay) or direct UPI intent through your installed banking applications (BHIM, Google Pay, PhonePe, Paytm).',
        ),
        _buildSectionHeader('5. Data Protection, Sharing & Deletion'),
        _buildParagraph(
          'We do not sell your personal data to third parties. Data is shared only with the specific local store fulfilling your order and assigned delivery partners. You can request account deletion or data export at any time via Settings or by contacting support.',
        ),
        _buildSectionHeader('6. Contact & Grievance Officer'),
        _buildParagraph(
          'For questions or privacy concerns, please email privacy@nearkirana.in or contact your store owner directly through the in-app support channel.',
        ),
      ],
    );
  }

  Widget _buildTermsOfServiceContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('1. Acceptance of Terms'),
        _buildParagraph(
          'By creating an account, browsing catalog items, or placing orders on NearKirana, you agree to comply with and be bound by these Terms of Service.',
        ),
        _buildSectionHeader('2. Store Ownership & Product Pricing'),
        _buildParagraph(
          'NearKirana enables independent local Kirana store owners to digitize their inventory. Product prices, item availability, and delivery charges are configured directly by the individual merchants. In the event of weight variances on loose items (e.g. fresh produce, grains), prices are computed proportionally by accurate net weight.',
        ),
        _buildSectionHeader('3. Orders & Cancellation Policy'),
        _buildParagraph(
          'Orders can be cancelled free of charge while in "Pending" status before the store begins packing. Once an order is "Out for Delivery", cancellations may be subject to store approval.',
        ),
        _buildSectionHeader('4. Khata Credit & Ledger Policy'),
        _buildParagraph(
          'The digital Khata feature is an agreement between the customer and the local storekeeper. Stores reserve the right to establish or modify credit limits based on payment reliability.',
        ),
        _buildSectionHeader('5. Returns & Complaints'),
        _buildParagraph(
          'If you receive damaged, expired, or incorrect items, you can raise a complaint with attached photos within 24 hours of delivery. Resolving merchants may offer replacements or digital Khata credits.',
        ),
        _buildSectionHeader('6. Governing Law'),
        _buildParagraph(
          'These terms are governed by and construed in accordance with the laws of India. Any disputes are subject to the exclusive jurisdiction of the competent courts in India.',
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12.5,
          height: 1.55,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 6, color: AppColors.primaryDark),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                height: 1.5,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
