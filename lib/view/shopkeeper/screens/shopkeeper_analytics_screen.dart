import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodel/shop_viewmodel.dart';
import '../../../core/models/firebase_customer_shop_relation_model.dart';

class ShopkeeperAnalyticsScreen extends StatefulWidget {
  @override
  State<ShopkeeperAnalyticsScreen> createState() => _ShopkeeperAnalyticsScreenState();
}

class _ShopkeeperAnalyticsScreenState extends State<ShopkeeperAnalyticsScreen> {
  String _selectedPeriod = 'This Month';

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopViewModel>(
      builder: (context, shopViewModel, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.lightGreen, AppColors.white],
            ),
          ),
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => shopViewModel.refresh(),
              color: AppColors.primaryGreen,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Analytics',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGray,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButton<String>(
                            value: _selectedPeriod,
                            underline: const SizedBox(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.darkGray,
                            ),
                            items: ['Today', 'This Week', 'This Month', 'All Time']
                                .map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedPeriod = newValue!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Key Metrics Cards
                    _KeyMetricsSection(shopViewModel: shopViewModel),
                    const SizedBox(height: 24),

                    // Financial Overview
                    _FinancialOverviewSection(shopViewModel: shopViewModel),
                    const SizedBox(height: 24),

                    // Customer Analytics
                    _CustomerAnalyticsSection(shopViewModel: shopViewModel),
                    const SizedBox(height: 24),

                    // Recent Trends
                    _TrendsSection(shopViewModel: shopViewModel),
                    const SizedBox(height: 24),

                    // Performance Indicators
                    _PerformanceIndicatorsSection(shopViewModel: shopViewModel),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KeyMetricsSection extends StatelessWidget {
  final ShopViewModel shopViewModel;

  const _KeyMetricsSection({required this.shopViewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGray,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _MetricCard(
              title: 'Total Revenue',
              value: '₹${shopViewModel.totalMoneyUsed.toStringAsFixed(0)}',
              icon: Icons.attach_money,
              color: AppColors.success,
              trend: '+12%',
              isPositive: true,
            ),
            _MetricCard(
              title: 'Active Customers',
              value: shopViewModel.totalCustomers.toString(),
              icon: Icons.people_alt,
              color: AppColors.accentBlue,
              trend: '+5',
              isPositive: true,
            ),
            _MetricCard(
              title: 'Credit Utilization',
              value: '${_calculateUtilization(shopViewModel).toStringAsFixed(1)}%',
              icon: Icons.trending_up,
              color: AppColors.primaryOrange,
              trend: '+8%',
              isPositive: true,
            ),
            _MetricCard(
              title: 'Overdue Amount',
              value: '₹${_calculateOverdueAmount(shopViewModel).toStringAsFixed(0)}',
              icon: Icons.warning,
              color: AppColors.error,
              trend: '-2%',
              isPositive: false,
            ),
          ],
        ),
      ],
    );
  }

  double _calculateUtilization(ShopViewModel shopViewModel) {
    if (shopViewModel.totalMoneyAllocated == 0) return 0;
    return (shopViewModel.totalMoneyUsed / shopViewModel.totalMoneyAllocated) * 100;
  }

  double _calculateOverdueAmount(ShopViewModel shopViewModel) {
    return shopViewModel.overdueCustomers
        .fold(0.0, (sum, customer) => sum + customer.usedAmount);
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;
  final bool isPositive;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: isPositive ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trend,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialOverviewSection extends StatelessWidget {
  final ShopViewModel shopViewModel;

  const _FinancialOverviewSection({required this.shopViewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Overview',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGray,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryGreen,
                AppColors.accentBlue,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FinancialStat(
                    label: 'Total Allocated',
                    value: '₹${shopViewModel.totalMoneyAllocated.toStringAsFixed(0)}',
                  ),
                  _FinancialStat(
                    label: 'Total Used',
                    value: '₹${shopViewModel.totalMoneyUsed.toStringAsFixed(0)}',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FinancialStat(
                    label: 'Returned',
                    value: '₹${shopViewModel.totalMoneyReturned.toStringAsFixed(0)}',
                  ),
                  _FinancialStat(
                    label: 'Outstanding',
                    value: '₹${(shopViewModel.totalMoneyUsed - shopViewModel.totalMoneyReturned).toStringAsFixed(0)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinancialStat extends StatelessWidget {
  final String label;
  final String value;

  const _FinancialStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}

class _CustomerAnalyticsSection extends StatelessWidget {
  final ShopViewModel shopViewModel;

  const _CustomerAnalyticsSection({required this.shopViewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Analytics',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGray,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _CustomerAnalyticsCard(
                title: 'New Customers',
                value: _getNewCustomersCount(shopViewModel).toString(),
                subtitle: 'This month',
                icon: Icons.person_add,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _CustomerAnalyticsCard(
                title: 'Avg. Credit Usage',
                value: '${_getAverageCreditUsage(shopViewModel).toStringAsFixed(1)}%',
                subtitle: 'Per customer',
                icon: Icons.analytics,
                color: AppColors.primaryOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
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
              Text(
                'Customer Distribution',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGray,
                ),
              ),
              const SizedBox(height: 16),
              _CustomerDistributionItem(
                label: 'Active Customers',
                count: shopViewModel.totalCustomers,
                color: AppColors.success,
                total: shopViewModel.customers.length,
              ),
              _CustomerDistributionItem(
                label: 'Pending Requests',
                count: shopViewModel.pendingRequests,
                color: AppColors.warning,
                total: shopViewModel.customers.length,
              ),
              _CustomerDistributionItem(
                label: 'Overdue Customers',
                count: shopViewModel.overdueCustomers.length,
                color: AppColors.error,
                total: shopViewModel.customers.length,
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _getNewCustomersCount(ShopViewModel shopViewModel) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    return shopViewModel.customers
        .where((c) => c.joinedDate.isAfter(thisMonth))
        .length;
  }

  double _getAverageCreditUsage(ShopViewModel shopViewModel) {
    final activeCustomers = shopViewModel.customers
        .where((c) => c.status == RequestStatus.approved)
        .toList();

    if (activeCustomers.isEmpty) return 0;

    final totalUsagePercentage = activeCustomers.fold(0.0, (sum, customer) {
      if (customer.totalCreditLimit == 0) return sum;
      return sum + (customer.usedAmount / customer.totalCreditLimit * 100);
    });

    return totalUsagePercentage / activeCustomers.length;
  }
}

class _CustomerAnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _CustomerAnalyticsCard({
    required this.title,
    required this.value,
    required this.subtitle,
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
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGray,
            ),
          ),
          Text(
            subtitle,
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

class _CustomerDistributionItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final int total;

  const _CustomerDistributionItem({
    required this.label,
    required this.count,
    required this.color,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.darkGray,
              ),
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${percentage.toStringAsFixed(0)}%)',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendsSection extends StatelessWidget {
  final ShopViewModel shopViewModel;

  const _TrendsSection({required this.shopViewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Trends',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGray,
          ),
        ),
        const SizedBox(height: 16),
        Container(
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
              _TrendItem(
                title: 'Transaction Volume',
                value: '↗ 23% increase',
                subtitle: 'Compared to last month',
                isPositive: true,
              ),
              const Divider(),
              _TrendItem(
                title: 'Average Transaction',
                value: '↗ ₹450',
                subtitle: 'Up from ₹380',
                isPositive: true,
              ),
              const Divider(),
              _TrendItem(
                title: 'Customer Retention',
                value: '↘ 2% decrease',
                subtitle: 'Need attention',
                isPositive: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendItem extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final bool isPositive;

  const _TrendItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isPositive ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceIndicatorsSection extends StatelessWidget {
  final ShopViewModel shopViewModel;

  const _PerformanceIndicatorsSection({required this.shopViewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Indicators',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGray,
          ),
        ),
        const SizedBox(height: 16),
        Container(
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
              _PerformanceIndicator(
                title: 'Credit Utilization Rate',
                percentage: _calculateUtilization(shopViewModel),
                color: AppColors.accentBlue,
              ),
              const SizedBox(height: 16),
              _PerformanceIndicator(
                title: 'On-time Payment Rate',
                percentage: _calculateOnTimePaymentRate(shopViewModel),
                color: AppColors.success,
              ),
              const SizedBox(height: 16),
              _PerformanceIndicator(
                title: 'Customer Satisfaction',
                percentage: 87.5, // Mock data
                color: AppColors.primaryOrange,
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateUtilization(ShopViewModel shopViewModel) {
    if (shopViewModel.totalMoneyAllocated == 0) return 0;
    return (shopViewModel.totalMoneyUsed / shopViewModel.totalMoneyAllocated) * 100;
  }

  double _calculateOnTimePaymentRate(ShopViewModel shopViewModel) {
    final totalCustomers = shopViewModel.totalCustomers;
    final overdueCustomers = shopViewModel.overdueCustomers.length;
    if (totalCustomers == 0) return 100;
    return ((totalCustomers - overdueCustomers) / totalCustomers) * 100;
  }
}

class _PerformanceIndicator extends StatelessWidget {
  final String title;
  final double percentage;
  final Color color;

  const _PerformanceIndicator({
    required this.title,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGray,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }
}