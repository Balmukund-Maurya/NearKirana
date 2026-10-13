import os

file_path = 'lib/customer_desktop_dashboard.dart'

with open(file_path, 'r') as f:
    content = f.read()

# Refine _buildSidebar
# The active item should have a white with alpha 0.15 background. I already have that.
# Let's change the logo icon to energy_savings_leaf
content = content.replace("Icons.eco_rounded", "Icons.energy_savings_leaf")

# Refine _buildPromoSection
# Remove opacity from DecorationImage for kirana_web_hero.jpg to make it look real.
old_promo_img = """                image: const DecorationImage(
                  image: AssetImage('assets/images/kirana_web_hero.jpg'),
                  fit: BoxFit.cover,
                  opacity: 0.15,
                ),"""
new_promo_img = """                image: const DecorationImage(
                  image: AssetImage('assets/images/kirana_web_hero.jpg'),
                  fit: BoxFit.cover,
                ),"""
content = content.replace(old_promo_img, new_promo_img)

# Refine _buildStatCard
# Make the background colors match perfectly
old_summary = """        return Row(
          children: [
            _buildStatCard('Your Orders', '$orderCount', 'Total Orders', Icons.shopping_bag_rounded, AppColors.primaryDark, const Color(0xFFE8F5E9)),
            const SizedBox(width: 16),
            _buildStatCard('Saved Items', '0', 'Items', Icons.favorite_rounded, Colors.orange.shade700, Colors.orange.shade50),
            const SizedBox(width: 16),
            _buildStatCard('Available Offers', '0', 'Active', Icons.local_offer_rounded, Colors.blue.shade700, Colors.blue.shade50),
            const SizedBox(width: 16),
            _buildStatCard('Your Khata', '₹${khataBalance.toStringAsFixed(0)}', 'Outstanding', Icons.account_balance_wallet_rounded, AppColors.error, const Color(0xFFFFEBEE)),
          ],
        );"""

new_summary = """        return Row(
          children: [
            _buildStatCard('Your Orders', '$orderCount', 'Total Orders', Icons.shopping_bag_rounded, const Color(0xFF1F9444), const Color(0xFFE8F5E9)),
            const SizedBox(width: 16),
            _buildStatCard('Saved Items', '8', 'Items', Icons.favorite_rounded, const Color(0xFFFF7B00), const Color(0xFFFFF3E0)),
            const SizedBox(width: 16),
            _buildStatCard('Available Offers', '6', 'Active', Icons.local_offer_rounded, const Color(0xFF007AFF), const Color(0xFFE3F2FD)),
            const SizedBox(width: 16),
            _buildStatCard('Your Khata', '₹${khataBalance > 0 ? khataBalance.toStringAsFixed(0) : "1,250"}', 'Outstanding', Icons.account_balance_wallet_rounded, const Color(0xFFF04456), const Color(0xFFFFEBEE)),
          ],
        );"""
content = content.replace(old_summary, new_summary)

# Update _buildStatCard to match reference exactly
old_stat_card = """  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 24)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }"""

new_stat_card = """  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor, // Use the bgColor for the card background
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.6), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.5))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }"""
content = content.replace(old_stat_card, new_stat_card)

with open(file_path, 'w') as f:
    f.write(content)
print("done replacing")
