import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shop_provider.dart';
import 'notifications_bottom_sheet.dart';

class AdminTopHeader extends StatelessWidget {
  const AdminTopHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Search Bar
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.search, color: Colors.grey),
                    ),
                    const Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search products, customers, orders...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Text('Ctrl + K', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          // Actions
          _buildHeaderIcon(
            Icons.notifications_none_rounded,
            showBadge: true,
            onTap: () => showNotificationsSheet(context, shopId: shopId),
          ),
          const SizedBox(width: 16),
          _buildHeaderIcon(Icons.chat_bubble_outline_rounded),
          const SizedBox(width: 16),
          _buildHeaderIcon(Icons.settings_outlined),
          const SizedBox(width: 24),
          // Profile
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.person, color: Color(0xFF136633)),
              ),
              const SizedBox(width: 12),
              const Text('Admin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, {bool showBadge = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: Colors.grey.shade700, size: 20),
            if (showBadge)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
