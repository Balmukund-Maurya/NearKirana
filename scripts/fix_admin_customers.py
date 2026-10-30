import re

with open('lib/admin_customers_screen.dart', 'r') as f:
    content = f.read()

# I will write a completely new build method for AdminCustomersScreen
# It currently returns a Scaffold with an AppBar and body.
# I will wrap the Scaffold in a DefaultTabController.

new_build = """  @override
  Widget build(BuildContext context) {
    final onlineCustomers = _customers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data.containsKey('pin') && data['pin'] != null && data['pin'].toString().isNotEmpty;
    }).toList();

    final offlineCustomers = _customers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return !data.containsKey('pin') || data['pin'] == null || data['pin'].toString().isEmpty;
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textDark,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Khata Register',
            style: AppTextStyles.heading2(color: AppColors.textDark),
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.textMid,
            indicatorColor: AppColors.primaryDark,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Offline (Udhaar)'),
              Tab(text: 'Online'),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                if (tabController.index == 0) {
                  return FloatingActionButton.extended(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _showAddOfflineKhataEntryDialog(context);
                    },
                    backgroundColor: AppColors.primaryDark,
                    icon: const Icon(Icons.add_rounded, color: AppColors.white),
                    label: const Text(
                      'Add Offline Customer',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack);
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
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
                decoration: InputDecoration(
                  hintText: 'Search customers...',
                  hintStyle: AppTextStyles.bodyMedium(color: AppColors.textMid),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textMid,
                  ),
                  filled: true,
                  fillColor: AppColors.bgTint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCustomerList(offlineCustomers, isOnlineTab: false),
                  _buildCustomerList(onlineCustomers, isOnlineTab: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerList(List<DocumentSnapshot> list, {required bool isOnlineTab}) {
    if (_isLoading && _customers.isEmpty) {
      return Center(child: ModernLoader());
    }

    if (list.isEmpty && !_isLoading) {
      return _buildEmptyState(isOnlineTab);
    }

    return RefreshIndicator(
      color: AppColors.primaryDark,
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 100, // Space for FAB
        ),
        itemCount: list.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == list.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ModernLoader(size: 24),
              ),
            );
          }

          final doc = list[index];
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'Unknown';
          final mobile = data['mobile'] ?? 'N/A';
          final udhaar = (data['total_udhaar'] as num?)?.toDouble() ?? 0.0;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.bgTint),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (isOnlineTab && udhaar == 0) {
                  // No udhaar action for online customer with 0 balance
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KhataStatementScreen(
                      customerId: doc.id,
                      customerName: name,
                      customerPhone: mobile,
                      isOnlineCustomer: isOnlineTab,
                    ),
                  ),
                ).then((_) => _refresh());
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: AppTextStyles.heading2(
                            color: AppColors.primaryDark,
                          ).copyWith(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTextStyles.bodySemiBold(
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mobile,
                            style: AppTextStyles.captionMedium(
                              color: AppColors.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isOnlineTab || udhaar != 0) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Udhaar',
                            style: AppTextStyles.captionMedium(
                              color: AppColors.textMid,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${udhaar.toStringAsFixed(0)}',
                            style: AppTextStyles.bodySemiBold(
                              color: udhaar > 0
                                  ? AppColors.error
                                  : (udhaar < 0
                                      ? AppColors.success
                                      : AppColors.textDark),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.primaryDark,
                      )
                    ],
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms).slideX(
            begin: 0.2,
            duration: 300.ms,
            curve: Curves.easeOut,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isOnlineTab) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOnlineTab ? Icons.group_off_rounded : Icons.person_off_rounded,
            size: 64,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            isOnlineTab ? 'No online customers found' : 'No offline customers found',
            style: AppTextStyles.heading3(color: AppColors.textMid),
          ),
          if (!isOnlineTab && _searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Click + to add a new offline customer',
              style: AppTextStyles.captionMedium(color: AppColors.textLight),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

"""

# We need to replace the `build` method and its sub-methods.
# Find `  @override\n  Widget build(BuildContext context) {`
build_start = content.find("  @override\n  Widget build(BuildContext context) {")
# Find `  void _showAddOfflineKhataEntryDialog(BuildContext context) {`
dialog_start = content.find("  void _showAddOfflineKhataEntryDialog(BuildContext context) {")

if build_start != -1 and dialog_start != -1:
    new_content = content[:build_start] + new_build + "\n" + content[dialog_start:]
    with open('lib/admin_customers_screen.dart', 'w') as f:
        f.write(new_content)
    print("Replaced build method successfully.")
else:
    print("Could not find start or end bounds.")
