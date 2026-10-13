import os
import re

file_path = 'lib/gateway_screen.dart'

with open(file_path, 'r') as f:
    content = f.read()

# 1. Add _phoneController
controller_insert = """  bool _isLoading = true;
  String? _globalPhone;
  final TextEditingController _phoneController = TextEditingController();"""

content = content.replace("  bool _isLoading = true;\n  String? _globalPhone;", controller_insert)

# 2. Add imports if needed
if "import 'package:flutter/services.dart';" not in content:
    content = "import 'package:flutter/services.dart';\n" + content
if "import 'package:flutter/foundation.dart' show kIsWeb;" not in content:
    content = "import 'package:flutter/foundation.dart' show kIsWeb;\n" + content

# 3. Replace build method block
# Find where the block is
start_str = "    if (_globalPhone == null || _globalPhone!.isEmpty) {\n      return Scaffold("
start_idx = content.find(start_str)

if start_idx != -1:
    end_str = "      );\n    }\n\n    return Scaffold("
    end_idx = content.find(end_str, start_idx)
    
    if end_idx != -1:
        end_idx += len("      );\n    }")

        new_block = """    if (_globalPhone == null || _globalPhone!.isEmpty) {
      final size = MediaQuery.of(context).size;
      final isDesktop = size.width >= 900;
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: isDesktop 
              ? _buildDesktopLayout(context, size) 
              : _buildMobileLayout(context, size),
        ),
      );
    }"""
        content = content[:start_idx] + new_block + content[end_idx:]
    else:
        print("Could not find end of block")
else:
    print("Could not find start of block")

# 4. Add the layout methods right before the end of the class
# Find the last closing brace (but we'll just insert before it)
# The class _GatewayScreenState ends at the end of the file or near it.
# Let's find the last '}'
last_brace = content.rfind('}')

layout_methods = """
  Widget _buildDesktopLayout(BuildContext context, Size size) {
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
                      colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent],
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
                    child: _buildAuthCard(context, true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, Size size) {
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
                      colors: [AppColors.surface, Colors.transparent, Colors.black.withValues(alpha: 0.3)],
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
            child: _buildAuthCard(context, false),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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

  Widget _buildAuthCard(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDesktop ? 0.9 : 1.0),
        borderRadius: BorderRadius.circular(32),
        border: isDesktop ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5) : null,
        boxShadow: isDesktop ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
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
                Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3)),
                Expanded(
                  child: TextFormField(
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
                  _forceLogin();
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
        ],
      ),
    );
  }
"""

content = content[:last_brace] + layout_methods + content[last_brace:]

with open(file_path, 'w') as f:
    f.write(content)
print("done")
