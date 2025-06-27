import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodel/shop_viewmodel.dart';
import '../../../core/models/firebase_customer_shop_relation_model.dart';

class EnhancedCustomerRequestsScreen extends StatefulWidget {
  @override
  State<EnhancedCustomerRequestsScreen> createState() => _EnhancedCustomerRequestsScreenState();
}

class _EnhancedCustomerRequestsScreenState extends State<EnhancedCustomerRequestsScreen>
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
        final pendingRequests = shopViewModel.pendingCustomerRequests;
        final approvedCustomers = shopViewModel.approvedCustomers;
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
                      if (pendingRequests.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            '${pendingRequests.length} new',
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
                            Icon(Icons.pending_actions, size: 16),
                            const SizedBox(width: 4),
                            Text('Pending (${pendingRequests.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 16),
                            const SizedBox(width: 4),
                            Text('Active (${approvedCustomers.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning, size: 16),
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
                        _PendingRequestsTab(
                          requests: pendingRequests,
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

class _PendingRequestsTab extends StatelessWidget {
  final List<CustomerRequestWithDetails> requests;
  final ShopViewModel shopViewModel;

  const _PendingRequestsTab({
    required this.requests,
    required this.shopViewModel,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return _EmptyState(
        icon: Icons.pending_actions,
        title: 'No Pending Requests',
        subtitle: 'New customer requests will appear here when they scan your QR code',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _PendingRequestCard(
          request: request,
          onAccept: () => _showAcceptDialog(context, request),
          onReject: () => _showRejectDialog(context, request),
        );
      },
    );
  }

  void _showAcceptDialog(BuildContext context, CustomerRequestWithDetails request) {
    final creditController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                child: Text(
                  request.displayName.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Accept ${request.displayName}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer details summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _CustomerDetailRow(
                        icon: Icons.person,
                        label: 'Name',
                        value: request.displayName,
                      ),
                      _CustomerDetailRow(
                        icon: Icons.email,
                        label: 'Email',
                        value: request.displayEmail,
                      ),
                      if (request.customerPhone != null)
                        _CustomerDetailRow(
                          icon: Icons.phone,
                          label: 'Phone',
                          value: request.displayPhone,
                        ),
                      _CustomerDetailRow(
                        icon: Icons.schedule,
                        label: 'Requested',
                        value: request.formattedRequestDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Credit limit input
                TextFormField(
                  controller: creditController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Credit Limit (₹)',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                    hintText: 'Enter credit limit',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Due date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today, color: AppColors.primaryGreen),
                  title: Text('Due Date'),
                  subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                  trailing: Icon(Icons.edit, color: AppColors.primaryGreen),
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
                const SizedBox(height: 16),

                // Quick credit options
                Text(
                  'Quick Options',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [1000, 2500, 5000, 10000]
                      .map((amount) => GestureDetector(
                    onTap: () => creditController.text = amount.toString(),
                    child: Chip(
                      label: Text('₹$amount'),
                      backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                      labelStyle: GoogleFonts.poppins(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            Consumer<ShopViewModel>(
              builder: (context, viewModel, child) {
                return ElevatedButton(
                  onPressed: viewModel.isLoading
                      ? null
                      : () async {
                    final creditLimit = double.tryParse(creditController.text);
                    if (creditLimit != null && creditLimit > 0) {
                      Navigator.pop(context);
                      final success = await viewModel.acceptCustomerRequest(
                        request.relationId,
                        creditLimit,
                        selectedDate,
                        requestDetails: request,
                      );

                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${request.displayName} approved with ₹${creditLimit.toStringAsFixed(0)} credit!',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter a valid credit limit'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  child: viewModel.isLoading
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text('Accept'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, CustomerRequestWithDetails request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.error.withOpacity(0.1),
              child: Icon(
                Icons.person_remove,
                color: AppColors.error,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Reject Request',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to reject the request from ${request.displayName}?',
          style: GoogleFonts.poppins(),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          Consumer<ShopViewModel>(
            builder: (context, viewModel, child) {
              return ElevatedButton(
                onPressed: viewModel.isLoading
                    ? null
                    : () async {
                  Navigator.pop(context);
                  final success = await viewModel.rejectCustomerRequest(request.relationId);

                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Request from ${request.displayName} rejected'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: viewModel.isLoading
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text('Reject'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  final CustomerRequestWithDetails request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingRequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

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
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.primaryOrange.withOpacity(0.1),
                child: Text(
                  request.displayName.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.displayEmail,
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
                        'Requested ${request.formattedRequestDate}',
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
              Icon(
                Icons.new_releases,
                color: AppColors.warning,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: Icon(Icons.close, size: 16),
                  label: Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: Icon(Icons.check, size: 16),
                  label: Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveCustomersTab extends StatelessWidget {
  final List<FirebaseCustomerShopRelation> customers;
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
          onLendMore: () => _showLendMoreDialog(context, customer),
          onPaidUp: () => _showPaidUpDialog(context, customer),
          onViewDetails: () => _showCustomerDetails(context, customer),
        );
      },
    );
  }

  void _showLendMoreDialog(BuildContext context, FirebaseCustomerShopRelation customer) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController(text: 'Additional credit requested by customer');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              Icons.trending_up,
              color: AppColors.primaryGreen,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Lend More',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Current Credit Limit',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.mediumGray),
                  ),
                  Text(
                    '₹${customer.totalCreditLimit.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'New Credit Limit (₹)',
                prefixIcon: Icon(Icons.account_balance_wallet),
                hintText: 'Enter new credit limit',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason (Optional)',
                prefixIcon: Icon(Icons.note),
                hintText: 'Reason for credit increase',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          Consumer<ShopViewModel>(
            builder: (context, viewModel, child) {
              return ElevatedButton(
                onPressed: viewModel.isLoading
                    ? null
                    : () async {
                  final newLimit = double.tryParse(amountController.text);
                  if (newLimit != null && newLimit > customer.totalCreditLimit) {
                    Navigator.pop(context);
                    final success = await viewModel.updateCustomerCredit(
                      customer.id,
                      newLimit,
                      reason: reasonController.text,
                    );

                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Credit limit updated successfully!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid amount greater than current limit'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                child: viewModel.isLoading
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text('Update'),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPaidUpDialog(BuildContext context, FirebaseCustomerShopRelation customer) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController(text: 'Cash payment received');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              Icons.payment,
              color: AppColors.success,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Paid Up',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Outstanding Amount',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.mediumGray),
                  ),
                  Text(
                    '₹${customer.usedAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Payment Amount (₹)',
                prefixIcon: Icon(Icons.money),
                hintText: 'Enter payment amount',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Payment Description',
                prefixIcon: Icon(Icons.description),
                hintText: 'Payment method or note',
              ),
            ),
            const SizedBox(height: 12),
            // Quick amount buttons
            if (customer.usedAmount > 0) ...[
              Wrap(
                spacing: 8,
                children: [
                  _QuickPaymentButton(
                    amount: customer.usedAmount,
                    label: 'Full Amount',
                    onTap: () => amountController.text = customer.usedAmount.toStringAsFixed(0),
                  ),
                  if (customer.usedAmount >= 200)
                    _QuickPaymentButton(
                      amount: customer.usedAmount / 2,
                      label: 'Half',
                      onTap: () => amountController.text = (customer.usedAmount / 2).toStringAsFixed(0),
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          Consumer<ShopViewModel>(
            builder: (context, viewModel, child) {
              return ElevatedButton(
                onPressed: viewModel.isLoading
                    ? null
                    : () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount != null && amount > 0 && amount <= customer.usedAmount) {
                    Navigator.pop(context);
                    final success = await viewModel.processPaidUpPayment(
                      customer.customerId,
                      amount,
                      descriptionController.text,
                    );

                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Payment recorded successfully!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid payment amount'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: viewModel.isLoading
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text('Record Payment'),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCustomerDetails(BuildContext context, FirebaseCustomerShopRelation customer) {
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
              // Handle bar
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

              // Customer header
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaryGreen,
                    child: Text(
                      'C', // Customer initials
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
                          'Customer Name',
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
              const SizedBox(height: 24),

              // Credit summary
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
                      'Credit Summary',
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
                          label: 'Credit Limit',
                          value: '₹${customer.totalCreditLimit.toStringAsFixed(0)}',
                          color: AppColors.primaryGreen,
                        ),
                        _DetailItem(
                          label: 'Used Amount',
                          value: '₹${customer.usedAmount.toStringAsFixed(0)}',
                          color: AppColors.primaryOrange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DetailItem(
                          label: 'Available',
                          value: '₹${customer.availableCredit.toStringAsFixed(0)}',
                          color: AppColors.accentBlue,
                        ),
                        _DetailItem(
                          label: 'Due Date',
                          value: _formatDate(customer.dueDate),
                          color: customer.isOverdue ? AppColors.error : AppColors.darkGray,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recent transactions
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
                child: Consumer<ShopViewModel>(
                  builder: (context, shopViewModel, child) {
                    final transactions = shopViewModel.getCustomerTransactions(customer.customerId);

                    if (transactions.isEmpty) {
                      return Center(
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
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
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

class _ActiveCustomerCard extends StatelessWidget {
  final FirebaseCustomerShopRelation customer;
  final VoidCallback onLendMore;
  final VoidCallback onPaidUp;
  final VoidCallback onViewDetails;

  const _ActiveCustomerCard({
    required this.customer,
    required this.onLendMore,
    required this.onPaidUp,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final hasOutstanding = customer.usedAmount > 0;
    final isNearDue = customer.daysUntilDue <= 7 && hasOutstanding;
    final isOverdue = customer.isOverdue && hasOutstanding;

    return Container(
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
                radius: 25,
                backgroundColor: AppColors.primaryGreen,
                child: Text(
                  'C', // Customer initials
                  style: GoogleFonts.poppins(
                    fontSize: 18,
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
                    if (hasOutstanding) ...[
                      Text(
                        isOverdue
                            ? 'Overdue by ${(-customer.daysUntilDue).abs()} days'
                            : 'Due in ${customer.daysUntilDue} days',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isOverdue ? AppColors.error : AppColors.mediumGray,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'No outstanding amount',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.success,
                        ),
                      ),
                    ],
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CreditInfoColumn(
                  label: 'Credit Limit',
                  value: '₹${customer.totalCreditLimit.toStringAsFixed(0)}',
                  color: AppColors.primaryGreen,
                ),
                _CreditInfoColumn(
                  label: 'Used',
                  value: '₹${customer.usedAmount.toStringAsFixed(0)}',
                  color: AppColors.primaryOrange,
                ),
                _CreditInfoColumn(
                  label: 'Available',
                  value: '₹${customer.availableCredit.toStringAsFixed(0)}',
                  color: AppColors.accentBlue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onLendMore,
                  icon: Icon(Icons.trending_up, size: 16),
                  label: Text('Lend More'),
                ),
              ),
              const SizedBox(width: 12),
              if (hasOutstanding) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPaidUp,
                    icon: Icon(Icons.payment, size: 16),
                    label: Text('Paid Up'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: Icon(Icons.visibility, size: 16),
                    label: Text('View Details'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OverdueCustomersTab extends StatelessWidget {
  final List<FirebaseCustomerShopRelation> customers;
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
          onPaidUp: () => _showPaidUpDialog(context, customer),
        );
      },
    );
  }

  void _contactCustomer(BuildContext context, FirebaseCustomerShopRelation customer) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contact feature coming soon!'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  void _showPaidUpDialog(BuildContext context, FirebaseCustomerShopRelation customer) {
    // Reuse the paid up dialog from ActiveCustomersTab
    final activeTab = _ActiveCustomersTab(customers: [], shopViewModel: shopViewModel);
    activeTab._showPaidUpDialog(context, customer);
  }
}

class _OverdueCustomerCard extends StatelessWidget {
  final FirebaseCustomerShopRelation customer;
  final VoidCallback onContact;
  final VoidCallback onPaidUp;

  const _OverdueCustomerCard({
    required this.customer,
    required this.onContact,
    required this.onPaidUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
                radius: 25,
                backgroundColor: AppColors.error.withOpacity(0.1),
                child: Icon(
                  Icons.warning,
                  color: AppColors.error,
                  size: 24,
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onContact,
                  icon: Icon(Icons.phone, size: 16),
                  label: Text('Contact'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentBlue,
                    side: BorderSide(color: AppColors.accentBlue),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPaidUp,
                  icon: Icon(Icons.payment, size: 16),
                  label: Text('Paid Up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper Widgets
class _CustomerDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CustomerDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.mediumGray),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.mediumGray,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditInfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CreditInfoColumn({
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

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailItem({
    required this.label,
    required this.value,
    required this.color,
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
            color: color,
          ),
        ),
      ],
    );
  }
}

class _QuickPaymentButton extends StatelessWidget {
  final double amount;
  final String label;
  final VoidCallback onTap;

  const _QuickPaymentButton({
    required this.amount,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text('$label (₹${amount.toStringAsFixed(0)})'),
        backgroundColor: AppColors.success.withOpacity(0.1),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: AppColors.success,
          fontWeight: FontWeight.w600,
        ),
      ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.mediumGray,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}