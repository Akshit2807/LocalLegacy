import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodel/customer_viewmodel.dart';
import '../../../viewmodel/auth_viewmodel.dart';
import '../../../core/models/customer_shop_relation_model.dart';

class CustomerTransactionsScreen extends StatefulWidget {
  @override
  State<CustomerTransactionsScreen> createState() => _CustomerTransactionsScreenState();
}

class _CustomerTransactionsScreenState extends State<CustomerTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';

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
    return Consumer2<CustomerViewModel, AuthViewModel>(
      builder: (context, customerViewModel, authViewModel, child) {
        final allTransactions = customerViewModel.transactions;
        final creditTransactions = allTransactions
            .where((t) => t.type == TransactionType.credit)
            .toList();
        final debitTransactions = allTransactions
            .where((t) => t.type == TransactionType.debit)
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
                // Header with Summary
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction History',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGray,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: 'Total Spent',
                              value: '₹${_getTotalAmount(debitTransactions).toStringAsFixed(0)}',
                              icon: Icons.shopping_cart,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _SummaryCard(
                              title: 'This Month',
                              value: '₹${_getMonthlyAmount(allTransactions).toStringAsFixed(0)}',
                              icon: Icons.calendar_today,
                              color: AppColors.accentBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Filter Tabs
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
                            const Icon(Icons.all_inclusive, size: 16),
                            const SizedBox(width: 4),
                            Text('All (${allTransactions.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_cart, size: 16),
                            const SizedBox(width: 4),
                            Text('Purchases (${debitTransactions.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.payment, size: 16),
                            const SizedBox(width: 4),
                            Text('Payments (${creditTransactions.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Transactions List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => customerViewModel.refresh(authViewModel.user!.id),
                    color: AppColors.primaryOrange,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _TransactionsList(
                          transactions: allTransactions,
                          emptyMessage: 'No transactions yet',
                          emptySubtitle: 'Your transactions will appear here',
                        ),
                        _TransactionsList(
                          transactions: debitTransactions,
                          emptyMessage: 'No purchases yet',
                          emptySubtitle: 'Scan a shop QR to make your first purchase',
                        ),
                        _TransactionsList(
                          transactions: creditTransactions,
                          emptyMessage: 'No payments yet',
                          emptySubtitle: 'Payment transactions will appear here',
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

  double _getTotalAmount(List<TransactionModel> transactions) {
    return transactions.fold(0.0, (sum, t) => sum + t.amount);
  }

  double _getMonthlyAmount(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    return transactions
        .where((t) => t.timestamp.isAfter(thisMonth))
        .fold(0.0, (sum, t) => sum + t.amount);
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: AppColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsList extends StatelessWidget {
  final List<TransactionModel> transactions;
  final String emptyMessage;
  final String emptySubtitle;

  const _TransactionsList({
    required this.transactions,
    required this.emptyMessage,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: AppColors.mediumGray,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
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

    // Group transactions by date
    final groupedTransactions = _groupTransactionsByDate(transactions);

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: groupedTransactions.length,
      itemBuilder: (context, index) {
        final dateGroup = groupedTransactions[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Text(
                    dateGroup['date'],
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.lightGray,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₹${dateGroup['total'].toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Transactions for this date
            ...dateGroup['transactions'].map<Widget>((transaction) =>
                _TransactionTile(transaction: transaction),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _groupTransactionsByDate(List<TransactionModel> transactions) {
    final grouped = <String, List<TransactionModel>>{};

    for (final transaction in transactions) {
      final dateKey = _formatDateGroup(transaction.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(transaction);
    }

    return grouped.entries.map((entry) {
      final total = entry.value.fold(0.0, (sum, t) => sum + t.amount);
      return {
        'date': entry.key,
        'transactions': entry.value,
        'total': total,
      };
    }).toList();
  }

  String _formatDateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(transactionDate).inDays < 7) {
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == TransactionType.credit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            width: 4,
            color: isCredit ? AppColors.success : AppColors.primaryOrange,
          ),
        ),
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
          // Transaction Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCredit
                    ? [AppColors.success, AppColors.success.withOpacity(0.8)]
                    : [AppColors.primaryOrange, AppColors.warmYellow],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              isCredit ? Icons.add_circle : Icons.shopping_bag,
              color: AppColors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shop Name', // This would be fetched from shop data
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.mediumGray,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.mediumGray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(transaction.timestamp),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.mediumGray,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCredit
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCredit ? 'PAYMENT' : 'PURCHASE',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isCredit ? AppColors.success : AppColors.primaryOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? AppColors.success : AppColors.primaryOrange,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ID: ${transaction.id.substring(0, 6)}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: AppColors.mediumGray,
                    // fontFamily: 'monospace', // Not supported in GoogleFonts.poppins
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}