import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodel/auth_viewmodel.dart';
import '../../../viewmodel/customer_viewmodel.dart';
import '../../../core/models/customer_shop_relation_model.dart';

class CustomerShopsScreen extends StatefulWidget {
  @override
  State<CustomerShopsScreen> createState() => _CustomerShopsScreenState();
}

class _CustomerShopsScreenState extends State<CustomerShopsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerViewModel>(
      builder: (context, customerViewModel, child) {
        final approvedShops = customerViewModel.registeredShops
            .where((s) => s.status == RequestStatus.approved)
            .toList();
        final pendingShops = customerViewModel.registeredShops
            .where((s) => s.status == RequestStatus.pending)
            .toList();

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.lightOrange, AppColors.white],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Text(
                        'My Shops',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGray,
                        ),
                      ),
                      const Spacer(),
                      if (pendingShops.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pendingShops.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: AppColors.white,
                    unselectedLabelColor: AppColors.mediumGray,
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.store, size: 16),
                            const SizedBox(width: 4),
                            Text('Active (${approvedShops.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.hourglass_empty, size: 16),
                            const SizedBox(width: 4),
                            Text('Pending (${pendingShops.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Views
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => customerViewModel.refresh(
                      Provider.of<AuthViewModel>(context, listen: false).user!.id,
                    ),
                    color: AppColors.primaryOrange,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _ActiveShopsTab(
                          shops: approvedShops,
                          customerViewModel: customerViewModel,
                        ),
                        _PendingShopsTab(
                          shops: pendingShops,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActiveShopsTab extends StatelessWidget {
  final List<CustomerShopRelation> shops;
  final CustomerViewModel customerViewModel;

  const _ActiveShopsTab({
    required this.shops,
    required this.customerViewModel,
  });

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) {
      return _EmptyState(
        icon: Icons.store,
        title: 'No Active Shops',
        subtitle: 'Scan a shop QR code to get started',
        actionText: 'Scan QR Code',
        onAction: () {
          // This would trigger the QR scanner
          DefaultTabController.of(context)?.animateTo(3); // Navigate to QR tab
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: shops.length,
      itemBuilder: (context, index) {
        final shop = shops[index];
        return _ActiveShopCard(
          shop: shop,
          onTap: () => _showShopDetails(context, shop, customerViewModel),
        );
      },
    );
  }

  void _showShopDetails(BuildContext context, CustomerShopRelation shop, CustomerViewModel customerViewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => _ShopDetailsSheet(
          shop: shop,
          customerViewModel: customerViewModel,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _PendingShopsTab extends StatelessWidget {
  final List<CustomerShopRelation> shops;

  const _PendingShopsTab({required this.shops});

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) {
      return _EmptyState(
        icon: Icons.hourglass_empty,
        title: 'No Pending Requests',
        subtitle: 'All your shop requests have been processed',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: shops.length,
      itemBuilder: (context, index) {
        final shop = shops[index];
        return _PendingShopCard(shop: shop);
      },
    );
  }
}

class _ActiveShopCard extends StatelessWidget {
  final CustomerShopRelation shop;
  final VoidCallback onTap;

  const _ActiveShopCard({
    required this.shop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNearDue = shop.daysUntilDue <= 7 && shop.usedAmount > 0;
    final isOverdue = shop.isOverdue && shop.usedAmount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: isOverdue
              ? Border.all(color: AppColors.error, width: 2)
              : isNearDue
              ? Border.all(color: AppColors.warning, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Shop Header
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryOrange,
                        AppColors.warmYellow,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.store,
                    color: AppColors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shop Name', // This would be actual shop name
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGray,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Member since ${_formatDate(shop.joinedDate)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'OVERDUE',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  )
                else if (isNearDue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'DUE SOON',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Credit Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CreditInfoItem(
                        label: 'Available',
                        value: '₹${shop.availableCredit.toStringAsFixed(0)}',
                        color: AppColors.success,
                      ),
                      _CreditInfoItem(
                        label: 'Used',
                        value: '₹${shop.usedAmount.toStringAsFixed(0)}',
                        color: AppColors.primaryOrange,
                      ),
                      _CreditInfoItem(
                        label: 'Total Limit',
                        value: '₹${shop.totalCreditLimit.toStringAsFixed(0)}',
                        color: AppColors.accentBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Credit Usage Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Credit Usage',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                          ),
                          Text(
                            '${((shop.usedAmount / shop.totalCreditLimit) * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGray,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: shop.usedAmount / shop.totalCreditLimit,
                        backgroundColor: AppColors.mediumGray.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          shop.usedAmount / shop.totalCreditLimit > 0.8
                              ? AppColors.error
                              : shop.usedAmount / shop.totalCreditLimit > 0.6
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                        minHeight: 6,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Due Date Info
            if (shop.usedAmount > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? AppColors.error.withOpacity(0.1)
                      : isNearDue
                      ? AppColors.warning.withOpacity(0.1)
                      : AppColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOverdue ? Icons.error : Icons.schedule,
                      color: isOverdue
                          ? AppColors.error
                          : isNearDue
                          ? AppColors.warning
                          : AppColors.accentBlue,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOverdue
                            ? 'Payment overdue by ${(-shop.daysUntilDue).abs()} days'
                            : 'Payment due in ${shop.daysUntilDue} days',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOverdue
                              ? AppColors.error
                              : isNearDue
                              ? AppColors.warning
                              : AppColors.accentBlue,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(shop.dueDate),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _PendingShopCard extends StatelessWidget {
  final CustomerShopRelation shop;

  const _PendingShopCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.hourglass_empty,
              color: AppColors.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shop Name', // This would be actual shop name
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Request sent ${_formatDate(shop.joinedDate)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.mediumGray,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Awaiting approval',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class _CreditInfoItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CreditInfoItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppColors.mediumGray,
          ),
        ),
      ],
    );
  }
}

class _ShopDetailsSheet extends StatelessWidget {
  final CustomerShopRelation shop;
  final CustomerViewModel customerViewModel;
  final ScrollController scrollController;

  const _ShopDetailsSheet({
    required this.shop,
    required this.customerViewModel,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final shopTransactions = customerViewModel.getShopTransactions(shop.shopId);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mediumGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Shop Header
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryOrange,
                      AppColors.warmYellow,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.store,
                  color: AppColors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shop Name', // This would be actual shop name
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    Text(
                      'Member since ${_formatDate(shop.joinedDate)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Credit Details
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credit Information',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _DetailItem(
                      label: 'Total Credit Limit',
                      value: '₹${shop.totalCreditLimit.toStringAsFixed(0)}',
                    ),
                    _DetailItem(
                      label: 'Used Amount',
                      value: '₹${shop.usedAmount.toStringAsFixed(0)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _DetailItem(
                      label: 'Available Credit',
                      value: '₹${shop.availableCredit.toStringAsFixed(0)}',
                    ),
                    _DetailItem(
                      label: 'Due Date',
                      value: _formatDate(shop.dueDate),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recent Transactions
          Text(
            'Recent Transactions',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: shopTransactions.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 48,
                    color: AppColors.mediumGray,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions yet',
                    style: GoogleFonts.poppins(
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: scrollController,
              itemCount: shopTransactions.length,
              itemBuilder: (context, index) {
                final transaction = shopTransactions[index];
                final isCredit = transaction.type == TransactionType.credit;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCredit
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isCredit ? Icons.add : Icons.remove,
                          color: isCredit ? AppColors.success : AppColors.primaryOrange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.description,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _formatDateTime(transaction.timestamp),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCredit ? AppColors.success : AppColors.primaryOrange,
                        ),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return 'Today at $hour:$minute';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.mediumGray,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGray,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.mediumGray,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}