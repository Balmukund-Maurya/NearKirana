import os

file_path = 'lib/customer_desktop_dashboard.dart'

with open(file_path, 'r') as f:
    content = f.read()

# Fix Cart item design
old_cart_item = """                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${item.quantity} ${item.isLoose ? 'kg' : 'pc'}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),"""

new_cart_item = """                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('${item.quantity} ${item.isLoose ? 'kg' : 'pc'}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(width: 12),
                            Container(
                              height: 28,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  InkWell(onTap: (){}, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('-', style: TextStyle(color: Colors.grey)))),
                                  Text('${item.quantity.toInt()}'),
                                  InkWell(onTap: (){}, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('+', style: TextStyle(color: Colors.grey)))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
                          ],
                        ),
                      ),"""
content = content.replace(old_cart_item, new_cart_item)

# Fix Category items to look exactly like the reference
# The reference has white cards with green icons and text below.
old_category = """  Widget _buildCategoryCard(String name) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
            radius: 24,
            child: name == 'More'
                ? const Icon(Icons.more_horiz_rounded, color: AppColors.primaryDark)
                : const Icon(Icons.category_rounded, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }"""

new_category = """  Widget _buildCategoryCard(String name) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: name == 'More'
                ? const Icon(Icons.more_horiz_rounded, color: AppColors.primaryDark, size: 28)
                : const Icon(Icons.category_rounded, color: AppColors.primaryDark, size: 28), // In real app, we'd use image assets like the reference
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }"""
content = content.replace(old_category, new_category)

with open(file_path, 'w') as f:
    f.write(content)
print("done replacing 2")
