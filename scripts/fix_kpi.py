import os

file_path = 'lib/admin_desktop_dashboard.dart'

with open(file_path, 'r') as f:
    content = f.read()

old_kpi = """  Widget _buildKPICards(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    if (shopId == null || shopId.isEmpty) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseUtils.firestore.collection('orders').where('shop_id', isEqualTo: shopId).snapshots(),
      builder: (context, snapshot) {
        int todaysOrders = 0;
        double todaysRevenue = 0;
        
        if (snapshot.hasData) {
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);
          
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['created_at'] as Timestamp?;
            if (timestamp != null && timestamp.toDate().isAfter(startOfDay)) {
              todaysOrders++;
              if (['Delivered'].contains(data['status'])) {
                todaysRevenue += double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0;
              }
            }
          }
        }

        return Row(
          children: [
            _buildStatCard("Today's Orders", '$todaysOrders', Icons.shopping_bag_rounded, const Color(0xFF1F9444), const Color(0xFFE8F5E9)),
            const SizedBox(width: 20),
            _buildStatCard("Today's Revenue", '₹${todaysRevenue.toStringAsFixed(0)}', Icons.currency_rupee_rounded, const Color(0xFFFF7B00), const Color(0xFFFFF3E0)),
            const SizedBox(width: 20),
            _buildStatCard('Total Customers', '186', Icons.people_alt_rounded, const Color(0xFF007AFF), const Color(0xFFE3F2FD)),
            const SizedBox(width: 20),
            _buildStatCard('Total Udhaar', '₹42,500', Icons.account_balance_wallet_rounded, const Color(0xFFF04456), const Color(0xFFFFEBEE)),
          ],
        );
      }
    );
  }"""

new_kpi = """  Widget _buildKPICards(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    if (shopId == null || shopId.isEmpty) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseUtils.firestore.collection('orders').where('shop_id', isEqualTo: shopId).snapshots(),
      builder: (context, ordersSnapshot) {
        int todaysOrders = 0;
        double todaysRevenue = 0;
        
        if (ordersSnapshot.hasData) {
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);
          
          for (var doc in ordersSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['created_at'] as Timestamp?;
            if (timestamp != null && timestamp.toDate().isAfter(startOfDay)) {
              todaysOrders++;
              if (['Delivered'].contains(data['status'])) {
                todaysRevenue += double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0;
              }
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseUtils.firestore.collection('customers').where('shop_ids', arrayContains: shopId).snapshots(),
          builder: (context, customersSnapshot) {
            int totalCustomers = 0;
            double totalUdhaar = 0.0;

            if (customersSnapshot.hasData) {
              totalCustomers = customersSnapshot.data!.docs.length;
              for (var doc in customersSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                totalUdhaar += (data['shop_balances']?[shopId] ?? 0).toDouble();
              }
            }

            return Row(
              children: [
                _buildStatCard("Today's Orders", '$todaysOrders', Icons.shopping_bag_rounded, const Color(0xFF1F9444), const Color(0xFFE8F5E9)),
                const SizedBox(width: 20),
                _buildStatCard("Today's Revenue", '₹${todaysRevenue.toStringAsFixed(0)}', Icons.currency_rupee_rounded, const Color(0xFFFF7B00), const Color(0xFFFFF3E0)),
                const SizedBox(width: 20),
                _buildStatCard('Total Customers', '$totalCustomers', Icons.people_alt_rounded, const Color(0xFF007AFF), const Color(0xFFE3F2FD)),
                const SizedBox(width: 20),
                _buildStatCard('Total Udhaar', '₹${totalUdhaar.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded, const Color(0xFFF04456), const Color(0xFFFFEBEE)),
              ],
            );
          }
        );
      }
    );
  }"""

content = content.replace(old_kpi, new_kpi)

with open(file_path, 'w') as f:
    f.write(content)

print("KPI fixed")
