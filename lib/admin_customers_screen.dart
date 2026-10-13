import 'package:near_kirana/l10n/app_localizations.dart';
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
import 'package:near_kirana/firebase_utils.dart';
import 'receive_payment_screen.dart';
import 'admin_add_edit_customer_screen.dart';

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
  bool _showCustomerForm = false;
  DocumentSnapshot? _customerToEdit;

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
    if (_showCustomerForm) {
      return AdminAddEditCustomerScreen(
        customer: _customerToEdit,
        onBack: () => setState(() => _showCustomerForm = false),
        onSaved: () {
          setState(() => _showCustomerForm = false);
          _refresh();
        },
      );
    }

    final langProvider = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(langProvider.manage_customers),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_admin_customers_screen',
        onPressed: () {
          HapticFeedback.mediumImpact();
          setState(() {
            _showCustomerForm = true;
            _customerToEdit = null;
          });
        },
        backgroundColor: AppColors.primaryDark,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.white),
        label: const Text(
          'Add Customer',
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
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => ReceivePaymentScreen(
                                                        customerId: doc.id,
                                                        customerName: name,
                                                        customerPhone: phone,
                                                      ),
                                                    ),
                                                  ).then((value) {
                                                    if (value == true) {
                                                      _refresh();
                                                    }
                                                  });
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
                                                setState(() {
                                                  _showCustomerForm = true;
                                                  _customerToEdit = doc;
                                                });
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
}
