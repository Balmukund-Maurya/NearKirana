import os

file_path = 'lib/gateway_screen.dart'

with open(file_path, 'r') as f:
    content = f.read()

# Replace the Scaffold returned at the end of build method (lines 490-538)
start_str = """    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),"""

end_str = """              const Spacer(),
            ],
          ),
        ),
      ),
    );"""

start_idx = content.find(start_str)
end_idx = content.find(end_str, start_idx) + len(end_str)

new_build_block = """    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: isDesktop 
            ? _buildRoleSelectionDesktop(context, size)
            : _buildRoleSelectionMobile(context, size),
      ),
    );"""

if start_idx != -1:
    content = content[:start_idx] + new_build_block + content[end_idx:]

# Now add the layout methods right before the last closing brace
last_brace = content.rfind('}')

layout_methods = """
  Widget _buildRoleSelectionDesktop(BuildContext context, Size size) {
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
                // Illustration
                Image.asset(
                  'assets/images/kirana_web_hero.jpg',
                  fit: BoxFit.cover,
                ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.05, end: 0, duration: 800.ms),
                // Foreground leaves/depth effect could be added here if assets available
              ],
            ),
          ),
        ),
        
        // RIGHT SIDE: Glass Role Panel
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFFDFBF7), // Warm Cream / Ivory
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _buildRolePanel(context, true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelectionMobile(BuildContext context, Size size) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Illustration Half
          SizedBox(
            height: size.height * 0.4,
            width: double.infinity,
            child: Image.asset(
              'assets/images/kirana_web_hero.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          
          // Panel Half
          Container(
            color: const Color(0xFFFDFBF7),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: _buildRolePanel(context, false),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePanel(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 48 : 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Storefront Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 40,
            ),
          ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),
          
          const SizedBox(height: 24),
          
          // Heading
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 32),
              children: [
                const TextSpan(text: 'Welcome to '),
                TextSpan(
                  text: 'NearKirana',
                  style: TextStyle(color: AppColors.primaryDark),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: 12),
          
          // Subtitle
          Text(
            'Choose your role',
            style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms),
          
          const SizedBox(height: 48),
          
          // Role Cards
          _buildRoleCard(
            title: 'I am a Customer',
            subtitle: 'Order items from nearby shops',
            icon: Icons.shopping_basket_rounded,
            color: AppColors.primaryDark,
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            onTap: _selectCustomerRole,
            delay: 400.ms,
          ),
          
          const SizedBox(height: 24),
          
          _buildRoleCard(
            title: 'I am a Shop Owner',
            subtitle: 'Register your shop and take orders online',
            icon: Icons.store_mall_directory_rounded,
            color: AppColors.accentPink, // Soft pink/saffron
            backgroundColor: AppColors.accentPink.withValues(alpha: 0.05),
            onTap: _selectAdminRole,
            delay: 500.ms,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideX(begin: 0.05, end: 0, duration: 800.ms);
  }
"""

content = content[:last_brace] + layout_methods + content[last_brace:]

# One last thing: modify existing _buildRoleCard to match the styling
old_role_card = """  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required Duration delay,
  }) {"""
new_role_card = """  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Color? backgroundColor,
    required VoidCallback onTap,
    required Duration delay,
  }) {"""

content = content.replace(old_role_card, new_role_card)

# Update the decoration in _buildRoleCard
old_decoration = """        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),"""
new_decoration = """        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),"""

content = content.replace(old_decoration, new_decoration)

with open(file_path, 'w') as f:
    f.write(content)
print("done")
