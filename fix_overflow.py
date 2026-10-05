import os

filepath = '/Users/macbook/Desktop/Kirana_Store_Builder/lib/admin_product_details_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Fix withOpacity
content = content.replace('withOpacity(', 'withValues(alpha: ')

# Fix _buildStockStatCard
old_card = """  Widget _buildStockStatCard(String label, String value, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bgColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }"""

new_card = """  Widget _buildStockStatCard(String label, String value, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bgColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.1), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }"""

if "Widget _buildStockStatCard" in content:
    # Just in case the old_card replace doesn't match perfectly due to spaces or withValues
    import re
    # We will replace the entire method using regex
    content = re.sub(
        r"Widget _buildStockStatCard.*?return Expanded.*?\}\);\s*\}",
        new_card,
        content,
        flags=re.DOTALL
    )

with open(filepath, 'w') as f:
    f.write(content)
print("Fixed overflow in admin_product_details_screen.dart")
