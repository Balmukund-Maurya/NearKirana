import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_theme.dart';
import 'shop_provider.dart';
import 'sound_service.dart';
import 'modern_loader.dart';
import 'animation_helpers.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'package:near_kirana/firebase_utils.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<DocumentSnapshot> _customers = [];
  String _searchQuery = '';
  Timer? _debounce;
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchCustomers();
      }
    });
  }

  Future<void> _fetchCustomers() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      Query q = FirebaseUtils.firestore.collection('customers').where('shop_ids', arrayContains: shopId);

      if (_searchQuery.isNotEmpty) {
        q = q
            .where('name', isGreaterThanOrEqualTo: _searchQuery)
            .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
      } else {
        q = q.orderBy('name');
      }

      q = q.limit(_limit);

      if (_lastDocument != null) {
        q = q.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await q.get();

      if (querySnapshot.docs.length < _limit) {
        _hasMore = false;
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _customers.addAll(querySnapshot.docs);
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    setState(() {
      _customers.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchCustomers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(langProvider.translate('manage_customers')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_admin_customers_screen',
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showAddOfflineKhataEntryDialog(context);
        },
        backgroundColor: AppColors.primaryDark,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text(
          'Add Offline Khata',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
      ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    setState(() {
                      _searchQuery = val.trim();
                      if (_searchQuery.isNotEmpty) {
                        _searchQuery =
                            _searchQuery[0].toUpperCase() +
                            _searchQuery.substring(1);
                      }
                    });
                    _refresh();
                  }
                });
              },
              style: AppTextStyles.bodyMedium(color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Search by Name...',
                hintStyle: AppTextStyles.bodyMedium(color: AppColors.textMid),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primaryDark,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textMid,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _searchController.clear();
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          setState(() => _searchQuery = '');
                          _refresh();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),

          Expanded(
            child: _customers.isEmpty && _isLoading
                ? const Center(
                    child: ModernLoader(color: AppColors.primaryDark,
                    ),
                  )
                : _customers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 80,
                          color: AppColors.bgTint,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No customers found.',
                          style: AppTextStyles.bodySemiBold(
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.primaryDark,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(
                        top: 16,
                        left: 16,
                        right: 16,
                        bottom: 100,
                      ),
                      itemCount: _customers.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _customers.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: ModernLoader(color: AppColors.primaryDark,
                              ),
                            ),
                          );
                        }

                        final doc = _customers[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final String name = data['name'] ?? 'Unknown';
                        final String phone =
                            data['mobile'] ?? data['phone'] ?? 'Unknown';
                        final bool isBanned = data['is_banned'] ?? false;
                        final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
                        final double udhaar =
                            (data['shop_balances']?[shopId] as num?)?.toDouble() ?? 0.0;
                        final int nameChangeCount =
                            (data['name_change_count'] as num?)?.toInt() ?? 0;
                        final bool hasUdhaar = udhaar > 0;

                        return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: hasUdhaar
                                      ? AppColors.error.withValues(alpha: 0.2)
                                      : AppColors.bgTint,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryLight
                                                      .withValues(alpha: 0.2),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    name.isNotEmpty
                                                        ? name[0].toUpperCase()
                                                        : '?',
                                                    style:
                                                        AppTextStyles.heading1(
                                                          color: AppColors
                                                              .primaryDark,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            name,
                                                            style:
                                                                AppTextStyles.heading2(
                                                                  color: AppColors
                                                                      .textDark,
                                                                ).copyWith(
                                                                  fontSize: 18,
                                                                ),
                                                            overflow:
                                                                TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (nameChangeCount > 0) ...[
                                                          const SizedBox(width: 8),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: Colors.orange.withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                                                            ),
                                                            child: const Text(
                                                              'Edited',
                                                              style: TextStyle(
                                                                color: Colors.orange,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.phone_rounded,
                                                          size: 14,
                                                          color:
                                                              AppColors.textMid,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          phone,
                                                          style:
                                                              AppTextStyles.captionMedium(
                                                                color: AppColors
                                                                    .textMid,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Balance (Udhaar)',
                                              style:
                                                  AppTextStyles.captionMedium(
                                                    color: AppColors.textMid,
                                                  ),
                                            ),
                                            Text(
                                              '₹${udhaar.toStringAsFixed(0)}',
                                              style: AppTextStyles.heading2(
                                                color: hasUdhaar
                                                    ? AppColors.error
                                                    : AppColors.primaryDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.bgTint,
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Switch(
                                              value: isBanned,
                                              activeThumbColor: AppColors.error,
                                              inactiveTrackColor:
                                                  AppColors.bgTint,
                                              onChanged: (val) async {
                                                HapticFeedback.lightImpact();
                                                await FirebaseUtils.firestore
                                                    .collection('customers')
                                                    .doc(doc.id)
                                                    .update({'is_banned': val});
                                                SoundService().play(
                                                  'switch.mp3',
                                                );
                                                _refresh();
                                              },
                                            ),
                                            Text(
                                              isBanned ? 'Banned' : 'Active',
                                              style: AppTextStyles.bodySemiBold(
                                                color: isBanned
                                                    ? AppColors.error
                                                    : AppColors.primaryDark,
                                              ).copyWith(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            if (hasUdhaar)
                                              InkWell(
                                                onTap: () {
                                                  HapticFeedback.mediumImpact();
                                                  _showSettlePaymentDialog(
                                                    context,
                                                    doc.id,
                                                    name,
                                                    udhaar,
                                                  );
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                        horizontal: 8,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .currency_rupee_rounded,
                                                        size: 16,
                                                        color: AppColors
                                                            .primaryDark,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Receive',
                                                        style:
                                                            AppTextStyles.bodySemiBold(
                                                              color: AppColors
                                                                  .primaryDark,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 4),
                                            InkWell(
                                              onTap: () {
                                                HapticFeedback.lightImpact();
                                                _showEditCustomerDialog(
                                                  context,
                                                  doc.id,
                                                  name,
                                                  phone,
                                                );
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                      horizontal: 8,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.edit_rounded,
                                                      size: 16,
                                                      color: Colors.blue,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Edit',
                                                      style:
                                                          AppTextStyles.bodySemiBold(
                                                            color: Colors.blue,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .fadeSlideUp(delay: 30 * (index % 10));
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddOfflineKhataEntryDialog(BuildContext context) {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final descController = TextEditingController(
      text: 'Walk-in Store Purchase',
    );
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppColors.bgTint,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'New Offline Khata',
                      style: AppTextStyles.heading2(color: AppColors.textDark),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textDark,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Customer Phone (10 digits)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.phone_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textDark,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Customer Name (if new)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.heading2(color: AppColors.textDark),
                      decoration: InputDecoration(
                        labelText: 'Udhaar Amount (₹)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(
                          Icons.currency_rupee_rounded,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textDark,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.description_rounded),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final phone = phoneController.text.trim();
                              final name = nameController.text.trim();
                              final amount =
                                  double.tryParse(amountController.text) ?? 0.0;
                              final desc = descController.text.trim();

                              if (phone.length != 10 || amount <= 0) {
                                HapticFeedback.heavyImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                      'Enter valid 10-digit phone and amount > 0',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              setState(() => isProcessing = true);

                              try {
                                final customerQuery = await FirebaseFirestore
                                    .instance
                                    .collection('customers')
                                    .where('mobile', isEqualTo: phone)
                                    .limit(1)
                                    .get();

                                if (!context.mounted) return;
                                final batch = FirebaseUtils.firestore
                                    .batch();
                                DocumentReference customerRef;

                                if (customerQuery.docs.isNotEmpty) {
                                  customerRef =
                                      customerQuery.docs.first.reference;
                                  batch.update(customerRef, {
                                    'shop_balances.$shopId': FieldValue.increment(amount),
                                    'total_udhaar': FieldValue.increment(amount),
                                    'shop_ids': FieldValue.arrayUnion([shopId]),
                                  });
                                } else {
                                  if (name.isEmpty) {
                                    setState(() => isProcessing = false);
                                    HapticFeedback.heavyImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                          'Name is required for new customers!',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }
                                  customerRef = FirebaseUtils.firestore
                                      .collection('customers')
                                      .doc();
                                  batch.set(customerRef, {
                                    'name': name,
                                    'mobile': phone,
                                    'shop_balances.$shopId': amount,
                                    'total_udhaar': amount,
                                    'shop_ids': FieldValue.arrayUnion([shopId]),
                                    'auto_reminder': false,
                                    'created_at': FieldValue.serverTimestamp(),
                                  });
                                }

                                batch.set(
                                  customerRef
                                      .collection('khata_transactions')
                                      .doc(),
                                  {
                                    'amount': amount,
                                    'type': 'debit',
                                    'shop_id': shopId,
                                    'description': desc.isNotEmpty
                                        ? desc
                                        : 'Offline Udhaar',
                                    'timestamp': FieldValue.serverTimestamp(),
                                  },
                                );

                                await batch.commit();

                                if (context.mounted) {
                                  Navigator.pop(dialogContext);
                                  SoundService().success();
                                  _refresh();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                        'Khata Entry Added Successfully!',
                                      ),
                                      backgroundColor: AppColors.primaryDark,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setState(() => isProcessing = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: ModernLoader(),
                            )
                          : const Text(
                              'Add Entry',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSettlePaymentDialog(
    BuildContext context,
    String docId,
    String customerName,
    double currentUdhaar,
  ) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Settle Payment',
            style: AppTextStyles.heading2(color: AppColors.textDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'From $customerName',
                style: AppTextStyles.bodyMedium(color: AppColors.textMid),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Balance',
                      style: AppTextStyles.bodySemiBold(color: AppColors.error),
                    ),
                    Text(
                      '₹$currentUdhaar',
                      style: AppTextStyles.heading2(color: AppColors.error),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppTextStyles.heading2(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: 'Amount Received (₹)',
                  labelStyle: AppTextStyles.bodyMedium(
                    color: AppColors.textMid,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(
                    Icons.currency_rupee_rounded,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodySemiBold(color: AppColors.textMid),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final amountText = amountController.text.trim();
                final amount = double.tryParse(amountText);

                if (amount == null || amount <= 0) {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(behavior: SnackBarBehavior.floating, content: Text(langProvider.translate('invalid_amount')),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (amount > currentUdhaar) {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(behavior: SnackBarBehavior.floating, content: Text(langProvider.translate('cannot_collect_more').replaceAll('{amount}', currentUdhaar.toStringAsFixed(2))),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext);

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(
                    child: ModernLoader(color: AppColors.primaryDark,
                    ),
                  ),
                );

                try {
                  final batch = FirebaseUtils.firestore.batch();
                  final customerRef = FirebaseUtils.firestore
                      .collection('customers')
                      .doc(docId);

                  final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
                  batch.update(customerRef, {
                    'shop_balances.$shopId': FieldValue.increment(-amount),
                    'total_udhaar': FieldValue.increment(-amount),
                  });

                  batch
                      .set(customerRef.collection('khata_transactions').doc(), {
                        'amount': amount,
                        'type': 'credit',
                        'description': 'Cash Received (Settlement)',
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                  await batch.commit();

                  if (context.mounted) {
                    Navigator.pop(context); // close loader
                    SoundService().play('save.mp3');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(behavior: SnackBarBehavior.floating, content: Text(langProvider.translate('payment_received').replaceAll('{amount}', amount.toStringAsFixed(2)).replaceAll('{customer}', customerName)),
                        backgroundColor: AppColors.primaryDark,
                      ),
                    );
                    _refresh();
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // close loader
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(langProvider.translate('record_payment')),
            ),
          ],
        );
      },
    );
  }

  void _showEditCustomerDialog(
    BuildContext context,
    String docId,
    String currentName,
    String currentPhone,
  ) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final TextEditingController nameController =
        TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Edit Customer',
          style: AppTextStyles.heading2(color: AppColors.textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: AppTextStyles.bodyMedium(color: AppColors.textDark),
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: AppTextStyles.bodyMedium(color: AppColors.textDark),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodySemiBold(color: AppColors.textMid),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                Navigator.pop(dialogCtx);
                try {
                  await FirebaseUtils.firestore
                      .collection('customers')
                      .doc(docId)
                      .update({
                        'name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        // Update mobile field as well since that's what's used in khata_screen
                        'mobile': phoneController.text.trim(),
                      });
                  if (context.mounted) {
                    SoundService().success();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(behavior: SnackBarBehavior.floating, content: Text(langProvider.translate('profile_updated')),
                        backgroundColor: AppColors.primaryDark,
                      ),
                    );
                    _refresh();
                  }
                } catch (e) {
                  debugPrint('Error updating profile: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(langProvider.translate('save_btn')),
          ),
        ],
      ),
    );
  }
}
