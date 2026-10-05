import os
import re

file_path = 'lib/main.dart'

with open(file_path, 'r') as f:
    content = f.read()

# 1. Add _phoneController
controller_insert = """  bool _isLoading = true;
  final TextEditingController _phoneController = TextEditingController();"""

content = content.replace("  bool _isLoading = true;", controller_insert)

# 2. Dispose controller
dispose_insert = """  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }"""
content = re.sub(r'  @override\s+void dispose\(\) \{\s+super\.dispose\(\);\s+\}', dispose_insert, content)

# 3. Replace build method for _LoginScreenState
# We find "class _LoginScreenState extends State<LoginScreen> {"
# and inside it, we find the "  @override\n  Widget build(BuildContext context) {"

state_class_start = content.find("class _LoginScreenState extends State<LoginScreen> {")
build_start = content.find("  @override\n  Widget build(BuildContext context) {", state_class_start)

if build_start == -1:
    print("Could not find build method")
    exit(1)

new_build = """  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);
    final size = MediaQuery.of(context).size;
    final shopName = shopProvider.shopName ?? AppLocalizations.of(context)!.app_name;
    final isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                        width: 70,
                        height: 70,
                        decoration: AppDecorations.primaryGradient(radius: 20),
                        child: const Icon(
                          Icons.shopping_basket_rounded,
                          color: AppColors.white,
                          size: 36,
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(
                        begin: 1.0,
                        end: 1.1,
                        duration: 700.ms,
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(height: 24),
                  ModernLoader(color: AppColors.primaryDark),
                ],
              ),
            )
          : SafeArea(
              child: isDesktop 
                  ? _buildDesktopLayout(context, size, langProvider, shopName) 
                  : _buildMobileLayout(context, size, langProvider, shopName),
            ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, Size size, LanguageProvider langProvider, String shopName) {
    return Row(
      children: [
        // LEFT SIDE: 3D Illustration
        Expanded(
          flex: 5,
          child: Container(
            color: AppColors.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Main Illustration
                Image.asset(
                  'assets/images/kirana_web_hero.jpg',
                  fit: BoxFit.cover,
                ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(1.05, 1.05), end: const Offset(1, 1), duration: 800.ms),
                
                // Overlay for better text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                
                // Feature Cards
                Positioned(
                  left: 40,
                  bottom: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeatureCard(Icons.eco_rounded, 'Fresh Products'),
                      const SizedBox(height: 16),
                      _buildFeatureCard(Icons.local_shipping_rounded, 'Fast Delivery'),
                      const SizedBox(height: 16),
                      _buildFeatureCard(Icons.verified_rounded, 'Trusted Quality'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // RIGHT SIDE: Glassmorphic Auth Card
        Expanded(
          flex: 4,
          child: Container(
            color: AppColors.surface,
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildAuthCard(context, langProvider, shopName, true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, Size size, LanguageProvider langProvider, String shopName) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Illustration Half
          SizedBox(
            height: size.height * 0.35,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/kirana_web_hero.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.surface, Colors.transparent, Colors.black.withOpacity(0.3)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Auth Half
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: _buildAuthCard(context, langProvider, shopName, false),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
          ),
        ],
      ),
    ).animate().slideX(begin: -0.2, end: 0, duration: 600.ms).fadeIn(duration: 600.ms);
  }

  Widget _buildAuthCard(BuildContext context, LanguageProvider langProvider, String shopName, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isDesktop ? 0.9 : 1.0),
        borderRadius: BorderRadius.circular(32),
        border: isDesktop ? Border.all(color: Colors.white.withOpacity(0.5), width: 1.5) : null,
        boxShadow: isDesktop ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Language toggle (top right)
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => _showLanguageBottomSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌐', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      langProvider.currentLanguage == 'hi'
                          ? 'हिं'
                          : langProvider.currentLanguage == 'en'
                              ? 'EN'
                              : 'Hi',
                      style: AppTextStyles.captionMedium(
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: AppColors.textMid,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Logo & Branding
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: AppDecorations.primaryGradient(radius: 16),
                child: const Icon(
                  Icons.shopping_basket_rounded,
                  color: AppColors.white,
                  size: 32,
                ),
              ).animate().scale(begin: const Offset(0,0), end: const Offset(1,1), duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(width: 16),
              Text(
                'NearKirana',
                style: AppTextStyles.display(color: AppColors.primaryDark).copyWith(fontSize: 32),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            'Fresh Groceries\\nAt Your Doorstep',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading2(color: AppColors.textDark),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: 48),
          
          // Input Field
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Enter your mobile number',
              style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
            ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 12),
          
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, size: 20, color: AppColors.textMid),
                      const SizedBox(width: 8),
                      Text('+91', style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
                    ],
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.grey.withOpacity(0.3)),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Enter mobile number',
                      hintStyle: AppTextStyles.bodyMedium(color: AppColors.textMid),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: 24),
          
          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: () {
                if (_phoneController.text.length != 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
                  );
                  return;
                }
                
                // Existing Auth call
                if (kIsWeb) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Phone.email authentication is currently not supported on Web. Please use the mobile app.')),
                  );
                } else {
                  _startCustomPhoneLogin();
                }
              },
              style: AppButtonStyles.primary(radius: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.bgTint, thickness: 1.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(AppLocalizations.of(context)!.or_divider, style: AppTextStyles.caption()),
              ),
              Expanded(child: Divider(color: AppColors.bgTint, thickness: 1.5)),
            ],
          ).animate().fadeIn(delay: 650.ms),
          
          const SizedBox(height: 24),
          
          // Admin/Owner login
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: Text(AppLocalizations.of(context)!.owner_login),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMid),
          ).animate().fadeIn(delay: 700.ms),
          
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Change Shop?'),
                  content: const Text('Do you want to leave this shop and choose another? Your cart will be cleared.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                      child: const Text('Yes, Change Shop'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await Provider.of<ShopProvider>(context, listen: false).clearShop();
                if (context.mounted) {
                  Provider.of<CartProvider>(context, listen: false).clearCart();
                }
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const ShopSelectorScreen()),
                    (route) => false,
                  );
                }
              }
            },
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Change Shop'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
          ).animate().fadeIn(delay: 750.ms),
          
        ],
      ),
    );
  }
}
"""

content = content[:build_start] + new_build

# Also need to import flutter/services.dart for TextInputFormatters
if "import 'package:flutter/services.dart';" not in content:
    content = "import 'package:flutter/services.dart';\n" + content

with open(file_path, 'w') as f:
    f.write(content)
print("done")
