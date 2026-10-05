import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';

class AdminDiscountsScreen extends StatefulWidget {
  const AdminDiscountsScreen({super.key});

  @override
  State<AdminDiscountsScreen> createState() => _AdminDiscountsScreenState();
}

class _AdminDiscountsScreenState extends State<AdminDiscountsScreen> {
  List<Map<String, dynamic>> _coupons = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted) {
      setState(() {
        _coupons = [
          {'id': '1', 'code': 'WELCOME10', 'desc': 'New customer discount', 'type': 'Percentage', 'discount': '10% OFF', 'min_order': 'Min. ₹500', 'usage': '45 / 100', 'start': '01 Aug 2024', 'end': '31 Aug 2024', 'status': 'Active', 'icon': Icons.local_offer},
          {'id': '2', 'code': 'FLAT50', 'desc': 'Flat discount on orders', 'type': 'Fixed Amount', 'discount': '₹50 OFF', 'min_order': 'Min. ₹299', 'usage': '128 / 200', 'start': '05 Aug 2024', 'end': '31 Aug 2024', 'status': 'Active', 'icon': Icons.shopping_cart},
          {'id': '3', 'code': 'FREESHIP', 'desc': 'Free delivery on orders', 'type': 'Free Shipping', 'discount': 'Free Delivery', 'min_order': 'Min. ₹499', 'usage': '67 / 150', 'start': '01 Aug 2024', 'end': '15 Aug 2024', 'status': 'Active', 'icon': Icons.card_giftcard},
          {'id': '4', 'code': 'FESTIVE20', 'desc': 'Festive season special', 'type': 'Percentage', 'discount': '20% OFF', 'min_order': 'Min. ₹1000', 'usage': '23 / 50', 'start': '10 Aug 2024', 'end': '20 Aug 2024', 'status': 'Active', 'icon': Icons.star},
          {'id': '5', 'code': 'FLASH30', 'desc': 'Limited time offer', 'type': 'Percentage', 'discount': '30% OFF', 'min_order': 'Min. ₹1500', 'usage': '12 / 100', 'start': '12 Aug 2024', 'end': '14 Aug 2024', 'status': 'Inactive', 'icon': Icons.bolt},
          {'id': '6', 'code': 'REFER50', 'desc': 'Refer & earn discount', 'type': 'Fixed Amount', 'discount': '₹50 OFF', 'min_order': 'Min. ₹299', 'usage': '89 / 300', 'start': '01 Aug 2024', 'end': '30 Sep 2024', 'status': 'Active', 'icon': Icons.people},
          {'id': '7', 'code': 'DIWALI25', 'desc': 'Diwali special offer', 'type': 'Percentage', 'discount': '25% OFF', 'min_order': 'Min. ₹999', 'usage': '0 / 100', 'start': '01 Oct 2024', 'end': '15 Oct 2024', 'status': 'Scheduled', 'icon': Icons.percent},
          {'id': '8', 'code': 'BULK100', 'desc': 'Bulk purchase discount', 'type': 'Fixed Amount', 'discount': '₹100 OFF', 'min_order': 'Min. ₹1999', 'usage': '56 / 100', 'start': '15 Aug 2024', 'end': '30 Aug 2024', 'status': 'Active', 'icon': Icons.shopping_bag},
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
    final filteredCoupons = _coupons.where((c) {
      final text = '${c['code']} ${c['desc']}'.toLowerCase();
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
                              child: _buildMainCard(filteredCoupons),
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
            Text('Discounts / Coupons', style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28, fontFamily: GoogleFonts.inter().fontFamily, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Create and manage discounts, offers, and coupon codes', style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 15)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _notImplementedMessage('Add Coupon'),
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add Coupon', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
              hintText: 'Search coupons by name or code...',
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
            value: 'All Types',
            items: ['All Types', 'Percentage', 'Fixed Amount', 'Free Shipping'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
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
            value: 'All Status',
            items: ['All Status', 'Active', 'Inactive', 'Scheduled', 'Expired'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
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

  Widget _buildMainCard(List<Map<String, dynamic>> coupons) {
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
                Text('Coupons (${coupons.length})', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Manage your discount coupons and special offers', style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(fontSize: 13)),
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
                      1: FlexColumnWidth(1.8),
                      2: FixedColumnWidth(120),
                      3: FixedColumnWidth(120),
                      4: FixedColumnWidth(100),
                      5: FixedColumnWidth(130),
                      6: FixedColumnWidth(130),
                      7: FixedColumnWidth(135),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.bgTint))),
                        children: [
                          _buildTableHeader('#'),
                          _buildTableHeader('Coupon Details'),
                          _buildTableHeader('Type'),
                          _buildTableHeader('Discount'),
                          _buildTableHeader('Usage'),
                          _buildTableHeader('Validity'),
                          _buildTableHeader('Status'),
                          _buildTableHeader('Actions'),
                        ],
                      ),
                      if (coupons.isEmpty)
                        TableRow(
                          children: [
                            for(int i = 0; i < 8; i++) const SizedBox(height: 100),
                          ],
                        )
                      else
                        for (int i = 0; i < coupons.length; i++)
                          _buildCouponRow(i, coupons[i]),
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
                Text('Showing ${coupons.isEmpty ? 0 : 1}-${coupons.length} of ${coupons.length} coupons', style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
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

  TableRow _buildCouponRow(int index, Map<String, dynamic> data) {
    Color typeBg = Colors.green.shade50;
    Color typeText = Colors.green.shade700;
    if (data['type'] == 'Fixed Amount') {
      typeBg = Colors.blue.shade50;
      typeText = Colors.blue.shade700;
    } else if (data['type'] == 'Free Shipping') {
      typeBg = Colors.orange.shade50;
      typeText = Colors.orange.shade700;
    }
    
    Color avatarColor = Colors.green.shade700;
    Color avatarBg = Colors.green.shade50;
    if (index % 4 == 1) { avatarColor = Colors.purple.shade700; avatarBg = Colors.purple.shade50; }
    if (index % 4 == 2) { avatarColor = Colors.orange.shade700; avatarBg = Colors.orange.shade50; }
    if (index % 4 == 3) { avatarColor = Colors.red.shade700; avatarBg = Colors.red.shade50; }
    if (data['code'] == 'REFER50') { avatarColor = Colors.blue.shade700; avatarBg = Colors.blue.shade50; }
    if (data['code'] == 'DIWALI25') { avatarColor = Colors.pink.shade700; avatarBg = Colors.pink.shade50; }

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
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: avatarBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(data['icon'], color: avatarColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['code'], style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Code: ${data['code']}', style: const TextStyle(color: AppColors.textMid, fontSize: 11)),
                    Text(data['desc'], style: const TextStyle(color: AppColors.textMid, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(4)),
            child: Text(data['type'], style: TextStyle(color: typeText, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['discount'], style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 13)),
              const SizedBox(height: 2),
              Text(data['min_order'], style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(data['usage'], style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textDark, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['start'], style: const TextStyle(color: AppColors.textDark, fontSize: 12)),
              Text(data['end'], style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: _buildStatusBadge(data['status']),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _notImplementedMessage('Edit Coupon'),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textDark),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _notImplementedMessage('Duplicate Coupon'),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.bgTint), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.copy_outlined, size: 16, color: AppColors.textDark),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _notImplementedMessage('Delete Coupon'),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.red.shade50, border: Border.all(color: Colors.red.shade100), borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey.shade50;
    Color text = Colors.grey;
    if (status == 'Active') { bg = Colors.green.shade50; text = Colors.green; }
    if (status == 'Inactive') { bg = Colors.red.shade50; text = Colors.red; }
    if (status == 'Scheduled') { bg = Colors.orange.shade50; text = Colors.orange; }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: text, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

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
              const Icon(Icons.analytics_outlined, color: AppColors.textDark, size: 20),
              const SizedBox(width: 8),
              Text('Coupon Summary', style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.local_offer_outlined,
                  iconColor: Colors.green.shade700,
                  bgColor: Colors.green.shade50,
                  count: '8',
                  label: 'Total\nCoupons',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.blue.shade700,
                  bgColor: Colors.blue.shade50,
                  count: '6',
                  label: 'Active\nCoupons',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.pause_circle_outline,
                  iconColor: Colors.red.shade700,
                  bgColor: Colors.red.shade50,
                  count: '1',
                  label: 'Inactive\nCoupons',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.calendar_month_outlined,
                  iconColor: Colors.purple.shade700,
                  bgColor: Colors.purple.shade50,
                  count: '1',
                  label: 'Scheduled\nCoupons',
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
          _buildActivityRow('Coupon Activated', 'WELCOME10 is now active', '2 hours ago', Colors.green, Icons.local_offer),
          const Divider(height: 32, color: AppColors.bgTint),
          _buildActivityRow('New Coupon Created', 'FESTIVE20 created', '5 hours ago', Colors.purple, Icons.shopping_cart),
          const Divider(height: 32, color: AppColors.bgTint),
          _buildActivityRow('Coupon Deactivated', 'FLASH30 is now inactive', '1 day ago', Colors.red, Icons.pause_circle_outline),
          const Divider(height: 32, color: AppColors.bgTint),
          _buildActivityRow('Coupon Updated', 'FLAT50 updated', '2 days ago', Colors.teal, Icons.shopping_cart),
          const Divider(height: 32, color: AppColors.bgTint),
          _buildActivityRow('New Coupon Created', 'BULK100 created', '3 days ago', Colors.purple, Icons.shopping_bag),
        ],
      ),
    );
  }

  Widget _buildActivityRow(String title, String subtitle, String time, Color avatarColor, IconData icon) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: avatarColor.withValues(alpha: 0.1),
          child: Icon(icon, color: avatarColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
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
          _buildQuickActionRow(Icons.add_circle_outline, AppColors.textDark, 'Add Coupon', 'Create a new discount coupon', onTap: () => _notImplementedMessage('Add Coupon')),
          const SizedBox(height: 16),
          _buildQuickActionRow(Icons.settings_outlined, AppColors.textDark, 'Manage Offers', 'View and manage special offers', onTap: () => _notImplementedMessage('Manage Offers')),
          const SizedBox(height: 16),
          _buildQuickActionRow(Icons.bar_chart, AppColors.textDark, 'View Usage Report', 'See coupon usage analytics', onTap: () => _notImplementedMessage('View Usage Report')),
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
