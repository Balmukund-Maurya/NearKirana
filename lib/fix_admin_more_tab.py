import re

with open('/Users/balmukund/Documents/flutterProject/Aditya_Kirana/lib/admin_more_tab.dart', 'r') as f:
    content = f.read()

# I will find the _buildMenuTile method and replace it cleanly.
method_start = content.find('  Widget _buildMenuTile({')
method_end = content.find('  void _showAddShopBoyDialog(BuildContext context)')

if method_start != -1 and method_end != -1:
    new_method = """  Widget _buildMenuTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
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
      ),
    );
  }

"""
    content = content[:method_start] + new_method + content[method_end:]
    with open('/Users/balmukund/Documents/flutterProject/Aditya_Kirana/lib/admin_more_tab.dart', 'w') as f:
        f.write(content)

