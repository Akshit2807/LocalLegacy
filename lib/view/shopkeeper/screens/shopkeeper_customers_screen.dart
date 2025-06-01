import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodel/shop_viewmodel.dart';
import '../../../core/models/customer_shop_relation_model.dart';

class ShopkeeperCustomersScreen extends StatefulWidget {
  @override
  State<ShopkeeperCustomersScreen> createState() => _ShopkeeperCustomersScreenState();
}

class _ShopkeeperCustomersScreenState extends State<ShopkeeperCustomersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopViewModel>(
      builder: (context, shopViewModel, child) {
        final pendingCustomers = shopViewModel.customers
            .where((c) => c.status == RequestStatus.pending)
            .toList();
        final approvedCustomers = shopViewModel.customers
            .where((c) => c.status == RequestStatus.approved)
            .toList();
        final overdueCustomers = shopViewModel.overdueCustomers;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.lightGreen, AppColors.white],
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
                        'Customer Management',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGray,
                        ),
                      ),
                      const Spacer(),
                      if (pendingCustomers.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pendingCustomers.length}',
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
                      color: AppColors.primaryGreen,
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
                            const Icon(Icons.hourglass_empty, size: 16),
                            const SizedBox(width: 4),
                            Text('Pending (${pendingCustomers.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 16),
                            const SizedBox(width: 4),
                            Text('Active (${approvedCustomers.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.warning, size: 16),
                            const SizedBox(width: 4),
                            Text('Overdue (${overdueCustomers.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Views
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => shopViewModel.refresh(),
                    color: AppColors.primaryGreen,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _PendingCustomersTab(
                          customers: pendingCustomers,
                          shopViewModel: shopViewModel,
                        ),
                        _ActiveCustomersTab(
                          customers: approvedCustomers,
                          shopViewModel: shopViewModel,
                        ),
                        _OverdueCustomersTab(
                          customers: overdueCustomers,
                          shopViewModel: shopViewModel,
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

class _PendingCustomersTab extends StatelessWidget {
  final List<CustomerShopRelation> customers;
  final ShopViewModel shopViewModel;

  const _PendingCustomersTab({
    required this.customers,
    required this.shopViewModel,
  });

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return _EmptyState(
        icon: Icons.hourglass_empty,
        title: 'No Pending Requests',
        subtitle: 'New customer requests will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _PendingCustomerCard(
          customer: customer,
          onAccept: () => _showAcceptDialog(context, customer),
          onReject: () => _showRejectDialog(context, customer),
        );
      },
    );
  }

  void _showAcceptDialog(BuildContext context, CustomerShopRelation customer) {
    final creditController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Accept Customer Request',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: creditController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Credit Limit (₹)',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text('Due Date'),
                subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => selectedDate = date);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final creditLimit = double.tryParse(creditController.text);
                if (creditLimit != null && creditLimit > 0) {
                  Navigator.pop(context);
                  final success = await shopViewModel.acceptCustomerRequest(
                    customer.id,
                    creditLimit,
                    selectedDate,
                  );

                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Customer request accepted!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              child: Text('Accept'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, CustomerShopRelation customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reject Customer Request',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to reject this customer request?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await shopViewModel.rejectCustomerRequest(customer.id);

              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Customer request rejected'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class _ActiveCustomersTab extends StatelessWidget {
  final List<CustomerShopRelation> customers;
  final ShopViewModel shopViewModel;

  const _ActiveCustomersTab({
    required this.customers,
    required this.shopViewModel,
  });

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return _EmptyState(
        icon: Icons.people,
        title: 'No Active Customers',
        subtitle: 'Approved customers will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _ActiveCustomerCard(
          customer: customer,
          onEdit: () => _showEditDialog(context, customer),
          onViewDetails: () => _showCustomerDetails(context, customer),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, CustomerShopRelation customer) {
    final creditController = TextEditingController(
      text: customer.totalCreditLimit.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Credit Limit',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextFormField(
          controller: creditController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Credit Limit (₹)',
            prefixIcon: Icon(Icons.account_balance_wallet),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newLimit = double.tryParse(creditController.text);
              if (newLimit != null && newLimit > 0) {
                Navigator.pop(context);
                final success = await shopViewModel.updateCustomerCredit(
                  customer.id,
                  newLimit,
                );

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Credit limit updated!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetails(BuildContext context, CustomerShopRelation customer) {
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
        builder: (context, scrollController) => Container(
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

              // Customer Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaryGreen,
                    child: Text(
                      'C', // This would be customer's initials
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Name', // This would be actual customer name
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGray,
                          ),
                        ),
                        Text(
                          'Joined ${_formatDate(customer.joinedDate)}',
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
              const SizedBox(height: 32),

              // Credit Details
              _DetailCard(
                title: 'Credit Information',
                children: [
                  _DetailRow(
                    label: 'Total Credit Limit',
                    value: '₹${customer.totalCreditLimit.toStringAsFixed(0)}',
                    valueColor: AppColors.primaryGreen,
                  ),
                  _DetailRow(
                    label: 'Available Credit',
                    value: '₹${customer.availableCredit.toStringAsFixed(0)}',
                    valueColor: AppColors.accentBlue,
                  ),
                  _DetailRow(
                    label: 'Used Amount',
                    value: '₹${customer.usedAmount.toStringAsFixed(0)}',
                    valueColor: AppColors.primaryOrange,
                  ),
                  _DetailRow(
                    label: 'Due Date',
                    value: _formatDate(customer.dueDate),
                    valueColor: customer.isOverdue ? AppColors.error : AppColors.darkGray,
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 3, // This would be actual transaction count
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightGray,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            index % 2 == 0 ? Icons.add : Icons.remove,
                            color: index % 2 == 0 ? AppColors.success : AppColors.primaryOrange,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  index % 2 == 0 ? 'Payment Received' : 'Purchase',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '2 days ago',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${index % 2 == 0 ? '+' : '-'}₹${(index + 1) * 100}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: index % 2 == 0 ? AppColors.success : AppColors.primaryOrange,
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
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _OverdueCustomersTab extends StatelessWidget {
  final List<CustomerShopRelation> customers;
  final ShopViewModel shopViewModel;

  const _OverdueCustomersTab({
    required this.customers,
    required this.shopViewModel,
  });

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return _EmptyState(
        icon: Icons.check_circle,
        title: 'No Overdue Customers',
        subtitle: 'All customers are up to date!',
        iconColor: AppColors.success,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _OverdueCustomerCard(
          customer: customer,
          onContact: () => _contactCustomer(context, customer),
        );
      },
    );
  }

  void _contactCustomer(BuildContext context, CustomerShopRelation customer) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contact feature coming soon!'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }
}

class _PendingCustomerCard extends StatelessWidget {
  final CustomerShopRelation customer;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingCustomerCard({
    required this.customer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.warning.withOpacity(0.1),
                child: Icon(
                  Icons.person,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Customer Request',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGray,
                      ),
                    ),
                    Text(
                      'Requested ${_formatDate(customer.joinedDate)}',
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error),
                  ),
                  child: Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  child: Text('Accept'),
                ),
              ),
            ],
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
      return 'Yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class _ActiveCustomerCard extends StatelessWidget {
  final CustomerShopRelation customer;
  final VoidCallback onEdit;
  final VoidCallback onViewDetails;

  const _ActiveCustomerCard({
    required this.customer,
    required this.onEdit,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryGreen,
                child: Text(
                  'C', // Customer initials
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Name', // Actual customer name
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGray,
                      ),
                    ),
                    Text(
                      'Due in ${customer.daysUntilDue} days',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: customer.daysUntilDue <= 7
                            ? AppColors.error
                            : AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit, color: AppColors.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CreditInfo(
                label: 'Credit Limit',
                value: '₹${customer.totalCreditLimit.toStringAsFixed(0)}',
                color: AppColors.primaryGreen,
              ),
              _CreditInfo(
                label: 'Used',
                value: '₹${customer.usedAmount.toStringAsFixed(0)}',
                color: AppColors.primaryOrange,
              ),
              _CreditInfo(
                label: 'Available',
                value: '₹${customer.availableCredit.toStringAsFixed(0)}',
                color: AppColors.accentBlue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewDetails,
              child: Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverdueCustomerCard extends StatelessWidget {
  final CustomerShopRelation customer;
  final VoidCallback onContact;

  const _OverdueCustomerCard({
    required this.customer,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.error.withOpacity(0.1),
                child: Icon(
                  Icons.warning,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Name', // Actual customer name
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGray,
                      ),
                    ),
                    Text(
                      'Overdue by ${(-customer.daysUntilDue).abs()} days',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${customer.usedAmount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onContact,
              icon: Icon(Icons.phone),
              label: Text('Contact Customer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CreditInfo({
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
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
            color: iconColor ?? AppColors.mediumGray,
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
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.mediumGray,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.darkGray,
            ),
          ),
        ],
      ),
    );
  }
}