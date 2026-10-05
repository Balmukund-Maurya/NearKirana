import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';
import 'package:provider/provider.dart';

class AdminShopBoysScreen extends StatefulWidget {
  const AdminShopBoysScreen({super.key});

  @override
  State<AdminShopBoysScreen> createState() => _AdminShopBoysScreenState();
}

class _AdminShopBoysScreenState extends State<AdminShopBoysScreen> {
  List<Map<String, dynamic>> _shopBoys = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Injecting exact mock data from the reference image for visual matching
    if (mounted) {
      setState(() {
        _shopBoys = [
          {'id': 'SB001', 'name': 'Ramesh Kumar', 'phone': '+91 98765 43210', 'assigned_shop': 'Main Store', 'assigned_shop_location': 'Shivaji Nagar', 'total_orders': 124, 'status': 'Active'},
          {'id': 'SB002', 'name': 'Suresh Patel', 'phone': '+91 98765 43211', 'assigned_shop': 'Main Store', 'assigned_shop_location': 'Shivaji Nagar', 'total_orders': 98, 'status': 'Active'},
          {'id': 'SB003', 'name': 'Amit Yadav', 'phone': '+91 98765 43212', 'assigned_shop': 'Branch Store', 'assigned_shop_location': 'MP Nagar', 'total_orders': 76, 'status': 'Active'},
          {'id': 'SB004', 'name': 'Vikash Singh', 'phone': '+91 98765 43213', 'assigned_shop': 'Main Store', 'assigned_shop_location': 'Shivaji Nagar', 'total_orders': 65, 'status': 'Active'},
          {'id': 'SB005', 'name': 'Imran Khan', 'phone': '+91 98765 43214', 'assigned_shop': 'Branch Store', 'assigned_shop_location': 'MP Nagar', 'total_orders': 52, 'status': 'Active'},
          {'id': 'SB006', 'name': 'Rohit Sharma', 'phone': '+91 98765 43215', 'assigned_shop': 'Sector Store', 'assigned_shop_location': 'New Market', 'total_orders': 48, 'status': 'Inactive'},
          {'id': 'SB007', 'name': 'Manoj Gupta', 'phone': '+91 98765 43216', 'assigned_shop': 'Main Store', 'assigned_shop_location': 'Shivaji Nagar', 'total_orders': 41, 'status': 'Active'},
          {'id': 'SB008', 'name': 'Deepak Verma', 'phone': '+91 98765 43217', 'assigned_shop': 'Branch Store', 'assigned_shop_location': 'MP Nagar', 'total_orders': 36, 'status': 'Active'},
        ];
        _isLoading = false;
      });
    }
  }

  void _notImplementedMessage(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature flow is not present in the current project.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredBoys = _shopBoys.where((b) {
      final text = '${b['name']} ${b['phone']} ${b['id']}'.toLowerCase();
      return text.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          const AdminTopHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPageHeader(),
                        const SizedBox(height: 24),
                        _buildSearchRow(),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _buildMainCard(filteredBoys),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  _buildSummaryCard(),
                                  const SizedBox(height: 24),
                                  _buildRecentActivityCard(),
                                  const SizedBox(height: 24),
                                  _buildQuickActionsCard(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shop Boys / Delivery Partners', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28, fontFamily: GoogleFonts.inter().fontFamily, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Manage your delivery partners and track their performance', style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 15)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _notImplementedMessage('Add Shop Boy'),
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add Shop Boy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by name, phone number, or ID...',
              hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMid),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: 'All Status',
            items: ['All Status', 'Active', 'Inactive'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
            onChanged: (v) {},
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: 'All Shops',
            items: ['All Shops'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
            onChanged: (v) {},
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: 'Sort by: Latest',
            items: ['Sort by: Latest', 'Oldest'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
            onChanged: (v) {},
            icon: const Icon(Icons.keyboard_arrow_down),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.sort, size: 20, color: AppColors.textMid),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bgTint)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainCard(List<Map<String, dynamic>> boys) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shop Boys (${boys.length})', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Manage delivery partners and assign orders', style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.bgTint),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth > 950 ? constraints.maxWidth : 950,
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(50),
                      1: FlexColumnWidth(2),
                      2: FixedColumnWidth(170),
                      3: FixedColumnWidth(150),
                      4: FixedColumnWidth(100),
                      5: FixedColumnWidth(110),
                      6: FixedColumnWidth(160),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.bgTint))),
                        children: [
                          _buildTableHeader('#'),
                          _buildTableHeader('Partner'),
                          _buildTableHeader('Contact'),
                          _buildTableHeader('Assigned Shop'),
                          _buildTableHeader('Total Orders'),
                          _buildTableHeader('Status'),
                          _buildTableHeader('Actions'),
                        ],
                      ),
                      if (boys.isEmpty)
                        TableRow(
                          children: [
                            const SizedBox(),
                            const SizedBox(),
                            const SizedBox(),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 48),
                              child: Center(child: Text('No delivery partners found', style: TextStyle(color: Colors.grey))),
                            ),
                            const SizedBox(),
                            const SizedBox(),
                            const SizedBox(),
                          ],
                        )
                      else
                        for (int i = 0; i < boys.length; i++)
                          _buildBoyRow(i, boys[i]),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Showing ${boys.isEmpty ? 0 : 1}-${boys.length} of ${boys.length} shop boys', style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6), color: Colors.white),
                      child: const Icon(Icons.chevron_left, size: 16, color: AppColors.textMid),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(6)),
                      child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6), color: Colors.white),
                      child: const Icon(Icons.chevron_right, size: 16, color: AppColors.textMid),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildBoyRow(int index, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unknown';
    final idStr = data['id'].toString().substring(0, min(5, data['id'].toString().length));
    final phone = data['phone'] ?? 'N/A';
    final shop = data['assigned_shop'] ?? 'Unassigned';
    final shopSub = data['assigned_shop_location'] ?? '';
    final totalOrders = data['total_orders'] ?? 0;
    final isActive = data['status'] != 'Inactive';

    return TableRow(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.bgTint))),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text('${index + 1}', style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.shade50,
                child: const Icon(Icons.person, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('ID: $idStr', style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMid),
              const SizedBox(width: 4),
              Expanded(child: Text(phone, style: const TextStyle(color: AppColors.textDark, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shop, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w500)),
              if (shopSub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(shopSub, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
              ]
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text('$totalOrders', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: isActive ? Colors.green : Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(isActive ? 'Active' : 'Inactive', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _notImplementedMessage('Edit Partner'),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textDark),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _notImplementedMessage('View Performance'),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.bar_chart_outlined, size: 16, color: AppColors.textDark),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _notImplementedMessage('More Options'),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.more_vert, size: 16, color: AppColors.textDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  int min(int a, int b) => a < b ? a : b;

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(text, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, color: AppColors.textDark, size: 20),
              const SizedBox(width: 8),
              Text('Partner Summary', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.person_outline,
                  iconColor: Colors.green.shade700,
                  bgColor: Colors.green.shade50,
                  count: '${_shopBoys.length}',
                  label: 'Total\nShop Boys',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.blue.shade700,
                  bgColor: Colors.blue.shade50,
                  count: '${_shopBoys.where((b) => b['status'] != 'Inactive').length}',
                  label: 'Active\nPartners',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.person_off_outlined,
                  iconColor: Colors.red.shade700,
                  bgColor: Colors.red.shade50,
                  count: '${_shopBoys.where((b) => b['status'] == 'Inactive').length}',
                  label: 'Inactive\nPartners',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.inventory_2_outlined,
                  iconColor: Colors.purple.shade700,
                  bgColor: Colors.purple.shade50,
                  count: '${_shopBoys.fold<int>(0, (sum, item) => sum + ((item['total_orders'] as int?) ?? 0))}',
                  label: 'Total Orders\nDelivered',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({required IconData icon, required Color iconColor, required Color bgColor, required String count, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count, style: TextStyle(color: iconColor, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: iconColor.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500, height: 1.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, color: AppColors.textDark, size: 20),
                  const SizedBox(width: 8),
                  Text('Recent Activity', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              InkWell(
                onTap: () => _notImplementedMessage('View All Activity'),
                child: Row(
                  children: [
                    Text('View All', style: TextStyle(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, color: Colors.green.shade700, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildActivityRow('Ramesh Kumar', 'delivered order #NKO0124', '2 hours ago', Colors.green),
          const Divider(height: 32, color: AppColors.bgTint),
          _buildActivityRow('Suresh Patel', 'picked up order #NKO0123', '4 hours ago', Colors.blue),
          const Divider(height: 32, color: AppColors.bgTint),
          _buildActivityRow('Amit Yadav', 'delivered order #NKO0122', '6 hours ago', Colors.red),
          const Divider(height: 32, color: AppColors.bgTint),
          _buildActivityRow('Vikash Singh', 'picked up order #NKO0121', '8 hours ago', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildActivityRow(String name, String action, String time, Color avatarColor) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: avatarColor.withValues(alpha: 0.1),
          child: Icon(Icons.person, color: avatarColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 13)),
              const SizedBox(height: 2),
              Text(action, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
            ],
          ),
        ),
        Text(time, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.textDark, size: 20),
              const SizedBox(width: 8),
              Text('Quick Actions', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 24),
          _buildQuickActionRow(Icons.person_add_alt_1, Colors.green.shade700, 'Add Shop Boy', 'Register a new delivery partner', onTap: () => _notImplementedMessage('Add Shop Boy')),
          const SizedBox(height: 16),
          _buildQuickActionRow(Icons.assignment_outlined, AppColors.textDark, 'Assign Orders', 'Assign orders to shop boys', onTap: () => _notImplementedMessage('Assign Orders')),
          const SizedBox(height: 16),
          _buildQuickActionRow(Icons.bar_chart, AppColors.textDark, 'View Performance', 'See detailed performance report', onTap: () => _notImplementedMessage('View Performance')),
        ],
      ),
    );
  }

  Widget _buildQuickActionRow(IconData icon, Color iconColor, String title, String subtitle, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor == AppColors.textDark ? Colors.grey.shade100 : iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(subtitle, style: const TextStyle(color: AppColors.textMid, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: AppColors.textDark, size: 16),
        ],
      ),
    );
  }
}
