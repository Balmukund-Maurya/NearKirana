import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DesktopOrderDetailsView extends StatefulWidget {
  final QueryDocumentSnapshot order;
  final VoidCallback onBack;
  final VoidCallback onTrackOrder;

  const DesktopOrderDetailsView({
    super.key,
    required this.order,
    required this.onBack,
    required this.onTrackOrder,
  });

  @override
  State<DesktopOrderDetailsView> createState() => _DesktopOrderDetailsViewState();
}

class _DesktopOrderDetailsViewState extends State<DesktopOrderDetailsView> {
  @override
  Widget build(BuildContext context) {
    final data = widget.order.data() as Map<String, dynamic>;
    final String orderId = widget.order.id.substring(0, 8).toUpperCase();
    final String shopName = data['shop_name'] ?? 'NearKirana Store';
    final double totalAmount = double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0.0;
    final String status = data['status'] ?? 'Pending';
    final Timestamp? createdAt = data['created_at'] as Timestamp?;
    final items = data['items'] as List<dynamic>? ?? [];
    
    // Address data
    final addressData = data['delivery_address'] as Map<String, dynamic>? ?? {};
    final String addressType = addressData['type'] ?? 'Home';
    final String fullAddress = addressData['address'] ?? 'No address provided';
    final String city = addressData['city'] ?? 'Bhopal';
    final String pinCode = addressData['pincode']?.toString() ?? '';
    
    // Payment data
    final paymentMethod = data['payment_method'] ?? 'Cash on Delivery';

    // Delivery Partner data
    final String deliveryPartner = data['delivery_boy_name'] ?? 'Not Assigned';
    final String deliveryPhone = data['delivery_boy_phone']?.toString() ?? 'N/A';

    String dateStr = '';
    String timeStr = '';
    if (createdAt != null) {
      final dt = createdAt.toDate();
      dateStr = DateFormat('dd MMM yyyy').format(dt);
      timeStr = DateFormat('hh:mm a').format(dt);
    }
    
    // Status color mapping
    Color statusBgColor;
    Color statusTextColor;
    IconData statusIcon;
    
    if (status == 'Delivered') {
      statusBgColor = const Color(0xFFDCFCE7);
      statusTextColor = const Color(0xFF166534);
      statusIcon = Icons.check_circle;
    } else if (status == 'Cancelled') {
      statusBgColor = const Color(0xFFFEE2E2);
      statusTextColor = const Color(0xFFB91C1C);
      statusIcon = Icons.cancel;
    } else if (status == 'Out for Delivery') {
      statusBgColor = const Color(0xFFDCFCE7);
      statusTextColor = const Color(0xFF166534);
      statusIcon = Icons.local_shipping;
    } else {
      statusBgColor = const Color(0xFFEFF6FF);
      statusTextColor = const Color(0xFF1D4ED8);
      statusIcon = Icons.settings;
    }

    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back, size: 18, color: Colors.black87),
                      label: const Text('Back to Orders', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Order Details', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                        const SizedBox(height: 4),
                        Text('View complete details of your order', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.receipt_long, size: 18, color: Colors.black87),
                      label: const Text('Download Invoice', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: widget.onTrackOrder,
                      icon: const Icon(Icons.local_shipping, size: 18, color: Colors.white),
                      label: const Text('Track Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT COLUMN
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        // Order Header Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 24,
                                runSpacing: 16,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Order #NK$orderId', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                                      const SizedBox(width: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(6)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(statusIcon, size: 14, color: statusTextColor),
                                            const SizedBox(width: 6),
                                            Text(status, style: TextStyle(color: statusTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                                        child: const Icon(Icons.store, color: Color(0xFF2563EB), size: 24),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                                          const SizedBox(height: 4),
                                          const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('View Store', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                                              SizedBox(width: 4),
                                              Icon(Icons.open_in_new, size: 12, color: Color(0xFF6B7280)),
                                            ],
                                          )
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.only(left: 16),
                                    decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade200))),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Total Amount', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Text('₹${totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF111827))),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Placed on $dateStr, $timeStr', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                              
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Divider(height: 1),
                              ),
                              
                              // Horizontal Timeline
                              _buildHorizontalTimeline(status),
                              
                              const SizedBox(height: 24),
                              
                              // Delivery Banner
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFD1FAE5)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                      child: const Icon(Icons.local_shipping, color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Your order is out for delivery!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF065F46))),
                                          const SizedBox(height: 4),
                                          Text('Our delivery partner is on the way to your location.', style: TextStyle(color: Color(0xCC065F46), fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time_filled, color: Color(0xFF10B981), size: 20),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Estimated Delivery Time', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                              const Text('30 - 45 minutes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF065F46))),
                                            ],
                                          )
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
                        
                        // Order Items Table
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text('Order Items (${items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF111827))),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  border: Border.symmetric(horizontal: BorderSide(color: Colors.grey.shade200)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 4, child: Text('Product', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 2, child: Text('Price', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 2, child: Text('Quantity', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600))),
                                  ],
                                ),
                              ),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                                itemBuilder: (context, index) {
                                  final itemData = items[index] as Map<String, dynamic>;
                                  final name = itemData['name'] ?? 'Product';
                                  final unit = itemData['unit'] ?? '1 pc';
                                  final price = double.tryParse(itemData['price']?.toString() ?? '0') ?? 0.0;
                                  final mrp = double.tryParse(itemData['mrp']?.toString() ?? '0') ?? price;
                                  final qty = int.tryParse(itemData['quantity']?.toString() ?? '1') ?? 1;
                                  final lineTotal = price * qty;
                                  final image = itemData['image'];

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey.shade200),
                                                ),
                                                child: image != null && image.toString().isNotEmpty
                                                    ? ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey)))
                                                    : const Icon(Icons.image, color: Colors.grey),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                                                    const SizedBox(height: 4),
                                                    Text(unit, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                  if (mrp > price)
                                                    Text('₹${mrp.toStringAsFixed(0)}', style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade400, fontSize: 12)),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              if (mrp > price)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                                                  child: Text('${(((mrp - price) / mrp) * 100).round()}% OFF', style: const TextStyle(color: Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold)),
                                                )
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(qty.toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text('₹${lineTotal.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Order Timeline Vertically
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Order Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF111827))),
                              const SizedBox(height: 24),
                              _buildVerticalTimeline(status),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // RIGHT COLUMN
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        // Delivery Information
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: Color(0xFF047857), size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(child: Text('Delivery Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                  OutlinedButton(
                                    onPressed: () {},
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      side: const BorderSide(color: Color(0xFF10B981)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Change', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                                      child: const Icon(Icons.home_outlined, color: Color(0xFF374151), size: 20),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(addressType, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                                              const SizedBox(width: 8),
                                              const Text('(Default)', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text('$city${pinCode.isNotEmpty ? ' - $pinCode' : ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(fullAddress, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.4)),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Delivery Partner
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Delivery Partner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: const NetworkImage('https://i.pravatar.cc/150?img=11'),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(deliveryPartner, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                                            const SizedBox(width: 4),
                                            const Text('4.8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            const SizedBox(width: 4),
                                            Text('(320+ deliveries)', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone, color: Color(0xFF10B981), size: 14),
                                            const SizedBox(width: 4),
                                            Text(deliveryPhone, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                          ],
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF10B981)),
                                      label: const Text('Call', style: TextStyle(color: Color(0xFF111827))),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: BorderSide(color: Colors.grey.shade200),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.chat_outlined, size: 16, color: Color(0xFF374151)),
                                      label: const Text('Message', style: TextStyle(color: Color(0xFF111827))),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: BorderSide(color: Colors.grey.shade200),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Order Summary
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Subtotal (${items.length} items)', style: TextStyle(color: Colors.grey.shade600)),
                                  Text('₹${totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text('Delivery Charges', style: TextStyle(color: Colors.grey.shade600)),
                                      const SizedBox(width: 4),
                                      Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
                                    ],
                                  ),
                                  const Text('₹20', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Discount', style: TextStyle(color: Color(0xFF10B981))),
                                  const Text('- ₹32', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF065F46))),
                                    Text('₹${(totalAmount + 20 - 32).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF065F46))),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Payment Information
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.money, color: Color(0xFF10B981), size: 20),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text('Pay when you receive your order', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Selected', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHorizontalTimeline(String currentStatus) {
    // simplified visual timeline matching the reference
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTimelineNode('Order Placed', '12 Aug, 10:30 AM', true, true),
        Expanded(child: Container(height: 2, color: const Color(0xFF10B981))),
        _buildTimelineNode('Confirmed', '12 Aug, 10:35 AM', true, true),
        Expanded(child: Container(height: 2, color: const Color(0xFF10B981))),
        _buildTimelineNode('Preparing', '12 Aug, 11:00 AM', true, true),
        Expanded(child: Container(height: 2, color: const Color(0xFF10B981))),
        _buildTimelineNode('Out for Delivery', '12 Aug, 11:45 AM', true, false, icon: Icons.local_shipping),
        Expanded(child: Container(height: 2, color: Colors.grey.shade200)),
        _buildTimelineNode('Delivered', 'Expected\n12 Aug, 12:30 PM', false, false),
      ],
    );
  }

  Widget _buildTimelineNode(String title, String time, bool isCompleted, bool isCheck, {IconData? icon}) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFF10B981) : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: isCompleted
              ? Icon(isCheck ? Icons.check : icon, color: Colors.white, size: 16)
              : null,
        ),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isCompleted ? const Color(0xFF111827) : Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(time, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildVerticalTimeline(String currentStatus) {
    // Simplified static history mimicking reference
    return Column(
      children: [
        _buildVerticalTimelineNode('Out for Delivery', 'Your order is out for delivery. Amit is on the way.', '12 Aug 2024, 11:45 AM', true, isFirst: true),
        _buildVerticalTimelineNode('Preparing', 'Your order is being prepared at the store.', '12 Aug 2024, 11:00 AM', true),
        _buildVerticalTimelineNode('Order Confirmed', 'Your order has been confirmed by the store.', '12 Aug 2024, 10:35 AM', true),
        _buildVerticalTimelineNode('Order Placed', 'Your order has been placed successfully.', '12 Aug 2024, 10:30 AM', true, isLast: true),
      ],
    );
  }

  Widget _buildVerticalTimelineNode(String title, String desc, String time, bool isCompleted, {bool isFirst = false, bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst) Container(width: 2, height: 16, color: const Color(0xFF10B981)),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFF10B981))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24, top: isFirst ? 2 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 120, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        const SizedBox(width: 16),
                        Expanded(child: Text(desc, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
                      ],
                    ),
                  ),
                  Text(time, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
