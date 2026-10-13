import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/coupon_model.dart';
import 'package:near_kirana/coupon_service.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';
import 'package:near_kirana/widgets/coupon_widgets.dart';

class AdminDiscountsScreen extends StatefulWidget {
  const AdminDiscountsScreen({super.key});

  @override
  State<AdminDiscountsScreen> createState() => _AdminDiscountsScreenState();
}

class _AdminDiscountsScreenState extends State<AdminDiscountsScreen> {
  String _searchQuery = '';
  String _selectedType = 'All Types';
  String _selectedStatus = 'All Status';
  String _sortBy = 'Sort by: Latest';

  static final List<CouponModel> _demoCoupons = [
    CouponModel(
      id: 'demo_1',
      code: 'WELCOME10',
      description: 'New customer discount',
      type: CouponDiscountType.percentage,
      discountValue: 10,
      minOrderValue: 500,
      maxDiscount: 100,
      startDate: DateTime(2024, 8, 1),
      endDate: DateTime(2027, 8, 31),
      usageLimit: 100,
      usedCount: 45,
      perUserLimit: 1,
      isActive: true,
    ),
    CouponModel(
      id: 'demo_2',
      code: 'FLAT50',
      description: 'Flat discount on orders',
      type: CouponDiscountType.flat,
      discountValue: 50,
      minOrderValue: 299,
      startDate: DateTime(2024, 8, 5),
      endDate: DateTime(2027, 8, 31),
      usageLimit: 200,
      usedCount: 128,
      perUserLimit: 2,
      isActive: true,
    ),
    CouponModel(
      id: 'demo_3',
      code: 'FREESHIP',
      description: 'Free delivery on orders',
      type: CouponDiscountType.freeDelivery,
      discountValue: 0,
      minOrderValue: 499,
      startDate: DateTime(2024, 8, 1),
      endDate: DateTime(2027, 8, 15),
      usageLimit: 150,
      usedCount: 67,
      perUserLimit: 3,
      isActive: true,
    ),
    CouponModel(
      id: 'demo_4',
      code: 'FESTIVE20',
      description: 'Festive season special',
      type: CouponDiscountType.percentage,
      discountValue: 20,
      minOrderValue: 1000,
      maxDiscount: 250,
      startDate: DateTime(2024, 8, 10),
      endDate: DateTime(2027, 8, 20),
      usageLimit: 50,
      usedCount: 23,
      perUserLimit: 1,
      isActive: true,
    ),
    CouponModel(
      id: 'demo_5',
      code: 'FLASH30',
      description: 'Limited time offer',
      type: CouponDiscountType.percentage,
      discountValue: 30,
      minOrderValue: 1500,
      maxDiscount: 300,
      startDate: DateTime(2024, 8, 12),
      endDate: DateTime(2024, 8, 14),
      usageLimit: 100,
      usedCount: 12,
      perUserLimit: 1,
      isActive: false,
    ),
    CouponModel(
      id: 'demo_6',
      code: 'REFER50',
      description: 'Refer & earn discount',
      type: CouponDiscountType.flat,
      discountValue: 50,
      minOrderValue: 299,
      startDate: DateTime(2024, 8, 1),
      endDate: DateTime(2027, 9, 30),
      usageLimit: 300,
      usedCount: 89,
      perUserLimit: 1,
      isActive: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final String? shopId = shopProvider.currentShopId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          const AdminTopHeader(),
          Expanded(
            child: StreamBuilder<List<CouponModel>>(
              stream: CouponService.instance.getAllCouponsStream(shopId: shopId),
              builder: (context, snapshot) {
                // If firestore returns coupons, use them; otherwise fallback to demo coupons
                final liveCoupons = (snapshot.hasData && snapshot.data!.isNotEmpty)
                    ? snapshot.data!
                    : _demoCoupons;

                final filteredCoupons = _filterCoupons(liveCoupons);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPageHeader(shopId),
                      const SizedBox(height: 24),
                      _buildSearchRow(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildMainCard(filteredCoupons, shopId),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildSummaryCard(liveCoupons),
                                const SizedBox(height: 24),
                                _buildRecentActivityCard(),
                                const SizedBox(height: 24),
                                _buildQuickActionsCard(shopId),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<CouponModel> _filterCoupons(List<CouponModel> list) {
    return list.where((c) {
      // Text query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = c.code.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q);
        if (!match) return false;
      }

      // Type filter
      if (_selectedType == 'Percentage' &&
          c.type != CouponDiscountType.percentage) {
        return false;
      }
      if (_selectedType == 'Fixed Amount' &&
          c.type != CouponDiscountType.flat) {
        return false;
      }
      if (_selectedType == 'Free Shipping' &&
          c.type != CouponDiscountType.freeDelivery) {
        return false;
      }

      // Status filter
      final now = DateTime.now();
      if (_selectedStatus == 'Active' && (!c.isActive || c.isExpired())) {
        return false;
      }
      if (_selectedStatus == 'Inactive' && c.isActive) {
        return false;
      }
      if (_selectedStatus == 'Scheduled' && (c.startDate == null || !c.startDate!.isAfter(now))) {
        return false;
      }
      if (_selectedStatus == 'Expired' && !c.isExpired()) {
        return false;
      }

      return true;
    }).toList();
  }

  Widget _buildPageHeader(String? shopId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discounts / Coupons',
              style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(
                fontSize: 28,
                fontFamily: GoogleFonts.inter().fontFamily,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create and manage promotional discounts, offers, and coupon codes',
              style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(
                fontSize: 15,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _openAddEditCouponDialog(shopId: shopId),
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text(
            'Add Coupon',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgTint),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgTint),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _selectedType,
            items: ['All Types', 'Percentage', 'Fixed Amount', 'Free Shipping']
                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v ?? 'All Types'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgTint),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgTint),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            items: ['All Status', 'Active', 'Inactive', 'Scheduled', 'Expired']
                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                .toList(),
            onChanged: (v) => setState(() => _selectedStatus = v ?? 'All Status'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgTint),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgTint),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _sortBy,
            items: ['Sort by: Latest', 'Oldest']
                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                .toList(),
            onChanged: (v) => setState(() => _sortBy = v ?? 'Sort by: Latest'),
            icon: const Icon(Icons.keyboard_arrow_down),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.sort, size: 20, color: AppColors.textMid),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgTint),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgTint),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainCard(List<CouponModel> coupons, String? shopId) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coupons (${coupons.length})',
                      style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your discount coupons and promotional offers',
                      style: AppTextStyles.bodyMedium(color: AppColors.textMid).copyWith(
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _openAddEditCouponDialog(shopId: shopId),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Offer'),
                ),
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
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.bgTint)),
                        ),
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
                            for (int i = 0; i < 8; i++)
                              const Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No coupons found',
                                  style: TextStyle(color: AppColors.textMid),
                                ),
                              ),
                          ],
                        )
                      else
                        for (int i = 0; i < coupons.length; i++)
                          _buildCouponRow(i, coupons[i], shopId),
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
                Text(
                  'Showing ${coupons.isEmpty ? 0 : 1}-${coupons.length} of ${coupons.length} coupons',
                  style: const TextStyle(color: AppColors.textMid, fontSize: 13),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.bgTint),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white,
                      ),
                      child: const Icon(Icons.chevron_left, size: 16, color: AppColors.textMid),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.bgTint),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white,
                      ),
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

  TableRow _buildCouponRow(int index, CouponModel coupon, String? currentShopId) {
    Color typeBg = Colors.green.shade50;
    Color typeText = Colors.green.shade700;
    String typeLabel = 'Percentage';
    IconData icon = Icons.percent;

    if (coupon.type == CouponDiscountType.flat) {
      typeBg = Colors.blue.shade50;
      typeText = Colors.blue.shade700;
      typeLabel = 'Fixed Amount';
      icon = Icons.shopping_bag;
    } else if (coupon.type == CouponDiscountType.freeDelivery) {
      typeBg = Colors.orange.shade50;
      typeText = Colors.orange.shade700;
      typeLabel = 'Free Shipping';
      icon = Icons.local_shipping;
    }

    final dateFormat = DateFormat('dd MMM yyyy');
    final startStr = coupon.startDate != null
        ? dateFormat.format(coupon.startDate!)
        : 'Immediate';
    final endStr = coupon.endDate != null
        ? dateFormat.format(coupon.endDate!)
        : 'Ongoing';

    String status = 'Active';
    if (!coupon.isActive) {
      status = 'Inactive';
    } else if (coupon.isExpired()) {
      status = 'Expired';
    } else if (coupon.startDate != null && coupon.startDate!.isAfter(DateTime.now())) {
      status = 'Scheduled';
    }

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bgTint)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: AppColors.textMid, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: typeText, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupon.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Code: ${coupon.code}',
                      style: const TextStyle(color: AppColors.textMid, fontSize: 11),
                    ),
                    Text(
                      coupon.description,
                      style: const TextStyle(color: AppColors.textMid, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
            decoration: BoxDecoration(
              color: typeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                color: typeText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                coupon.formattedDiscount,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Min. ₹${coupon.minOrderValue.toStringAsFixed(0)}',
                style: const TextStyle(color: AppColors.textMid, fontSize: 12),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            coupon.usageLimit != null
                ? '${coupon.usedCount} / ${coupon.usageLimit}'
                : '${coupon.usedCount} (unlimited)',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
              fontSize: 13,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                startStr,
                style: const TextStyle(color: AppColors.textDark, fontSize: 12),
              ),
              Text(
                endStr,
                style: const TextStyle(color: AppColors.textMid, fontSize: 12),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: InkWell(
            onTap: () => _toggleCouponStatus(coupon),
            child: _buildStatusBadge(status),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Edit Coupon',
                child: InkWell(
                  onTap: () => _openAddEditCouponDialog(
                    coupon: coupon,
                    shopId: currentShopId,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.bgTint),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Duplicate Coupon',
                child: InkWell(
                  onTap: () => _openAddEditCouponDialog(
                    coupon: coupon.copyWith(
                      id: '',
                      code: '${coupon.code}_COPY',
                    ),
                    shopId: currentShopId,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.bgTint),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.copy_outlined,
                      size: 16,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Delete Coupon',
                child: InkWell(
                  onTap: () => _confirmDeleteCoupon(coupon),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade100),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red.shade700,
                    ),
                  ),
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
    if (status == 'Active') {
      bg = Colors.green.shade50;
      text = Colors.green;
    }
    if (status == 'Inactive') {
      bg = Colors.red.shade50;
      text = Colors.red;
    }
    if (status == 'Scheduled') {
      bg = Colors.orange.shade50;
      text = Colors.orange;
    }
    if (status == 'Expired') {
      bg = Colors.grey.shade100;
      text = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: text, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(List<CouponModel> coupons) {
    final total = coupons.length;
    final active = coupons.where((c) => c.isActive && !c.isExpired()).length;
    final inactive = coupons.where((c) => !c.isActive).length;
    final expiredOrScheduled = coupons
        .where((c) =>
            c.isExpired() ||
            (c.startDate != null && c.startDate!.isAfter(DateTime.now())))
        .length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppColors.textDark, size: 20),
              const SizedBox(width: 8),
              Text(
                'Coupon Summary',
                style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                  count: '$total',
                  label: 'Total\nCoupons',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.blue.shade700,
                  bgColor: Colors.blue.shade50,
                  count: '$active',
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
                  count: '$inactive',
                  label: 'Inactive\nCoupons',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryBox(
                  icon: Icons.calendar_month_outlined,
                  iconColor: Colors.purple.shade700,
                  bgColor: Colors.purple.shade50,
                  count: '$expiredOrScheduled',
                  label: 'Exp / Sched\nCoupons',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String count,
    required String label,
  }) {
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
                Text(
                  count,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: iconColor.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
                  Text(
                    'Recent Activity',
                    style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {},
                child: Row(
                  children: [
                    Text(
                      'Live Log',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, color: Colors.green.shade700, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildActivityRow(
            'Coupon Activated',
            'WELCOME10 is active for shoppers',
            'Just now',
            Colors.green,
            Icons.local_offer,
          ),
          const Divider(height: 32, color: AppColors.bgTint),
          _buildActivityRow(
            'Discount Engine Verified',
            'Server-side atomic check active',
            'Live',
            Colors.purple,
            Icons.verified,
          ),
          const Divider(height: 32, color: AppColors.bgTint),
          _buildActivityRow(
            'Free Delivery Promo',
            'FREESHIP active above ₹499',
            'Today',
            Colors.teal,
            Icons.local_shipping,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(
    String title,
    String subtitle,
    String time,
    Color avatarColor,
    IconData icon,
  ) {
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
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
            ],
          ),
        ),
        Text(time, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
      ],
    );
  }

  Widget _buildQuickActionsCard(String? shopId) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.bgTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.textDark, size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: AppTextStyles.heading2(color: AppColors.textDark).copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildQuickActionRow(
            Icons.add_circle_outline,
            AppColors.textDark,
            'Add Coupon',
            'Create a promotional discount offer',
            onTap: () => _openAddEditCouponDialog(shopId: shopId),
          ),
          const SizedBox(height: 16),
          _buildQuickActionRow(
            Icons.percent,
            AppColors.textDark,
            'Percentage Promo',
            'Launch quick percentage discount',
            onTap: () => _openAddEditCouponDialog(
              coupon: CouponModel(
                id: '',
                code: 'FESTIVE15',
                description: 'Special 15% discount offer',
                type: CouponDiscountType.percentage,
                discountValue: 15,
                minOrderValue: 500,
                startDate: DateTime.now(),
                endDate: DateTime.now().add(const Duration(days: 30)),
              ),
              shopId: shopId,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionRow(
            Icons.local_shipping_outlined,
            AppColors.textDark,
            'Free Delivery Campaign',
            'Create zero delivery fee rule',
            onTap: () => _openAddEditCouponDialog(
              coupon: CouponModel(
                id: '',
                code: 'FREEDEL',
                description: 'Free shipping on orders over ₹300',
                type: CouponDiscountType.freeDelivery,
                discountValue: 0,
                minOrderValue: 300,
                startDate: DateTime.now(),
                endDate: DateTime.now().add(const Duration(days: 14)),
              ),
              shopId: shopId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionRow(
    IconData icon,
    Color iconColor,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor == AppColors.textDark
                  ? Colors.grey.shade100
                  : iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(subtitle, style: const TextStyle(color: AppColors.textMid, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: AppColors.textDark, size: 16),
        ],
      ),
    );
  }

  void _openAddEditCouponDialog({CouponModel? coupon, String? shopId}) {
    AdminCouponDialog.show(
      context,
      coupon: coupon,
      shopId: shopId,
    );
  }

  Future<void> _toggleCouponStatus(CouponModel coupon) async {
    try {
      if (coupon.id.startsWith('demo_')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo template: Click "Add Coupon" to save to live database.'),
          ),
        );
        return;
      }
      await CouponService.instance.toggleCouponStatus(coupon.id, !coupon.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Coupon "${coupon.code}" ${coupon.isActive ? "deactivated" : "activated"}',
            ),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating coupon: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteCoupon(CouponModel coupon) async {
    if (coupon.id.startsWith('demo_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo coupon cannot be deleted from cloud.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Coupon'),
        content: Text('Are you sure you want to permanently delete coupon "${coupon.code}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CouponService.instance.deleteCoupon(coupon.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Coupon "${coupon.code}" deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting coupon: $e')),
          );
        }
      }
    }
  }
}
