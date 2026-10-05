import 'dart:io';
import 'package:flutter/material.dart';

script = """import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:near_kirana/user_provider.dart';

class DesktopOrderTrackingView extends StatelessWidget {
  final QueryDocumentSnapshot order;
  final VoidCallback onBack;

  const DesktopOrderTrackingView({
    super.key,
    required this.order,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final data = order.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'Pending';
    final double total = double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0.0;
    final double subtotal = double.tryParse(data['subtotal']?.toString() ?? total.toString()) ?? total;
    final double deliveryFee = double.tryParse(data['delivery_fee']?.toString() ?? '0') ?? 0.0;
    final double discount = double.tryParse(data['discount']?.toString() ?? '0') ?? 0.0;
    
    final Timestamp? createdAt = data['created_at'] as Timestamp?;
    // Format: 12 Aug 2024, 10:30 AM (Mock for now, using simpler logic)
    final dateStr = createdAt != null 
        ? '\\${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
        : 'Unknown Date';
        
    final String orderIdStr = order.id.substring(0, 8).toUpperCase();
    final items = data['items'] as List<dynamic>? ?? [];
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String deliveryAddress = data['delivery_address'] ?? userProvider.deliveryAddress;
    final String deliveryPartner = data['delivery_boy_name'] ?? 'Amit Sharma';
    final String deliveryPhone = data['delivery_boy_phone']?.toString() ?? '+91 98765 43210';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Area
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 16, color: Color(0xFF374151)),
                label: const Text('Back to Orders', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Tracking', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  Text('Track your order in real-time and get latest updates', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.headset_mic_outlined, color: Color(0xFF047857), size: 18),
                label: const Text('Need Help?', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  side: const BorderSide(color: Color(0xFF047857)),
                  backgroundColor: const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT COLUMN
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    // ORDER HEADER CARD
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('Order #$orderIdStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF111827))),
                                      const SizedBox(width: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          status,
                                          style: const TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Placed on $dateStr', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                                ],
                              ),
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Total Amount', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                                      Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF111827))),
                                    ],
                                  ),
                                  const SizedBox(width: 24),
                                  OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.receipt_long, color: Color(0xFF374151), size: 18),
                                    label: const Text('View Invoice', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      side: BorderSide(color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                          
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Divider(height: 1),
                          ),
                          
                          // TIMELINE
                          _buildHorizontalTimeline(status),
                          
                          const SizedBox(height: 32),
                          
                          // CURRENT STATUS BANNER
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(color: Color(0xFF047857), shape: BoxShape.circle),
                                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Your order is ${status.toLowerCase()}!', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF111827))),
                                      const SizedBox(height: 4),
                                      Text('Our delivery partner is on the way to your location.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time_filled, color: Color(0xFF047857), size: 20),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Estimated Delivery Time', style: TextStyle(color: Color(0xFF166534), fontSize: 11)),
                                          const Text('30 - 45 minutes', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 14)),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // DELIVERY PARTNER
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Delivery Partner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Container(
                                      width: 64, height: 64,
                                      decoration: const BoxDecoration(color: Color(0xFF047857), shape: BoxShape.circle),
                                      child: const Icon(Icons.person, color: Colors.white, size: 32),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(deliveryPartner, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.orange, size: 14),
                                            const SizedBox(width: 4),
                                            const Text('4.8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            Text(' (320+ deliveries)', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone, color: Color(0xFF047857), size: 12),
                                            const SizedBox(width: 4),
                                            Text(deliveryPhone, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(Icons.call_outlined, color: Color(0xFF047857), size: 18),
                                        label: const Text('Call', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFF0FDF4),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF374151), size: 18),
                                        label: const Text('Message', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          side: BorderSide(color: Colors.grey.shade300),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 24),
                        
                        // LIVE TRACKING
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 250,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Live Tracking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
                                          const SizedBox(height: 8),
                                          Text('Map tracking unavailable in this region', style: TextStyle(color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // ORDER UPDATES TIMELINE
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Order Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                              TextButton(
                                onPressed: () {},
                                child: const Text('View All Updates →', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildVerticalTimelineUpdate('Out for Delivery', 'Your order is out for delivery. Amit is on the way.', '12 Aug 2024, 11:45 AM', true, false),
                          _buildVerticalTimelineUpdate('Preparing', 'Your order is being prepared at the store.', '12 Aug 2024, 11:00 AM', true, false),
                          _buildVerticalTimelineUpdate('Order Confirmed', 'Your order has been confirmed by the store.', '12 Aug 2024, 10:35 AM', true, false),
                          _buildVerticalTimelineUpdate('Order Placed', 'Your order has been placed successfully.', '12 Aug 2024, 10:30 AM', true, true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 32),
              
              // RIGHT COLUMN
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    // DELIVERY ADDRESS
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: Color(0xFF047857), size: 20),
                                  const SizedBox(width: 8),
                                  const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                                ],
                              ),
                              Text('Change', style: TextStyle(color: const Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.home_outlined, color: Color(0xFF374151), size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('Home', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                                        const SizedBox(width: 8),
                                        Text('(Default)', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(deliveryAddress, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
                                  ],
                                ),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // ORDER SUMMARY
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order Summary (${items.length} items)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                          const SizedBox(height: 24),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (ctx, i) => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(height: 1),
                            ),
                            itemBuilder: (ctx, i) {
                              final itemData = items[i] as Map<String, dynamic>;
                              final itemName = itemData['name'] ?? 'Product';
                              final double itemPrice = double.tryParse(itemData['price']?.toString() ?? '0') ?? 0.0;
                              final int qty = int.tryParse(itemData['quantity']?.toString() ?? '1') ?? 1;
                              
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                                    child: const Icon(Icons.image, color: Colors.grey, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
                                        const SizedBox(height: 4),
                                        Text('Qty: $qty', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Text('₹${itemPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // PRICE DETAILS
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Price Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal (${items.length} items)', style: TextStyle(color: Colors.grey.shade600)),
                              Text('₹${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text('Delivery Charges ', style: TextStyle(color: Colors.grey.shade600)),
                                  Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
                                ],
                              ),
                              Text('₹${deliveryFee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Discount', style: TextStyle(color: Colors.grey.shade600)),
                              Text('- ₹${discount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                                Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF111827))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalTimeline(String currentStatus) {
    // 0: Placed, 1: Confirmed, 2: Preparing, 3: Out for Delivery, 4: Delivered
    final statuses = ['Pending', 'Confirmed', 'Preparing', 'Out for Delivery', 'Delivered'];
    int currentIndex = statuses.indexOf(currentStatus);
    if (currentIndex == -1) currentIndex = 0; // Default to first if unknown (like Cancelled)
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTimelineNode('Order Placed', '12 Aug, 10:30 AM', true, currentIndex >= 0),
        _buildTimelineLine(currentIndex >= 1),
        _buildTimelineNode('Confirmed', '12 Aug, 10:35 AM', true, currentIndex >= 1),
        _buildTimelineLine(currentIndex >= 2),
        _buildTimelineNode('Preparing', '12 Aug, 11:00 AM', true, currentIndex >= 2),
        _buildTimelineLine(currentIndex >= 3),
        _buildTimelineNode('Out for Delivery', '12 Aug, 11:45 AM', currentIndex >= 3, currentIndex >= 3),
        _buildTimelineLine(currentIndex >= 4),
        _buildTimelineNode('Delivered', 'Expected\\n12 Aug, 12:30 PM', false, currentIndex >= 4),
      ],
    );
  }

  Widget _buildTimelineLine(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? const Color(0xFF047857) : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildTimelineNode(String title, String subtitle, bool isCompleted, bool isCurrent) {
    return Column(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFF047857) : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            title == 'Out for Delivery' ? Icons.local_shipping : Icons.check,
            color: isCompleted ? Colors.white : Colors.transparent,
            size: 16,
          ),
        ),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isCompleted || isCurrent ? const Color(0xFF111827) : Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
      ],
    );
  }

  Widget _buildVerticalTimelineUpdate(String title, String desc, String time, bool isCompleted, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: const Color(0xFF047857), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
            if (!isLast)
              Container(width: 2, height: 40, color: const Color(0xFF047857)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                  Text(time, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              if (!isLast) const SizedBox(height: 24),
            ],
          ),
        )
      ],
    );
  }
}
"""

with open('lib/desktop_order_tracking_view.dart', 'w') as f:
    f.write(script)
print("done")
