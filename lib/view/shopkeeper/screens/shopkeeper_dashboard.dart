import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_legacy/view/shopkeeper/screens/shopkeeper_transcation_screen.dart';
import 'package:provider/provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/models/customer_shop_relation_model.dart';
import '../../../viewmodel/auth_viewmodel.dart';
import '../../../viewmodel/shop_viewmodel.dart';
import '../../auth/screens/user_type_section_screen.dart';
import 'shopkeeper_customers_screen.dart';
import 'shopkeeper_analytics_screen.dart';

class ShopkeeperDashboard extends StatefulWidget {
  const ShopkeeperDashboard({super.key});

  @override
  State<ShopkeeperDashboard> createState() => _ShopkeeperDashboardState();
}

class _ShopkeeperDashboardState extends State<ShopkeeperDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final shopViewModel = Provider.of<ShopViewModel>(context, listen: false);
      if (authViewModel.user != null) {
        shopViewModel.initializeShop(authViewModel.user!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthViewModel, ShopViewModel>(
      builder: (context, authViewModel, shopViewModel, child) {
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _DashboardTab(shopViewModel: shopViewModel, authViewModel: authViewModel),
              ShopkeeperCustomersScreen(),
              ShopkeeperTransactionsScreen(),
              ShopkeeperAnalyticsScreen(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: AppColors.primaryGreen,
            unselectedItemColor: AppColors.mediumGray,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Customers',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long),
                label: 'Transactions',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics),
                label: 'Analytics',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final ShopViewModel shopViewModel;
  final AuthViewModel authViewModel;

  const _DashboardTab({
    required this.shopViewModel,
    required this.authViewModel,
  });

  @override
  Widget build(BuildContext context) {
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
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: AppColors.primaryGreen,
                              child: Text(
                                authViewModel.user?.initials ?? 'S',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
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
                                    'Welcome back,',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: AppColors.mediumGray,
                                    ),
                                  ),
                                  Text(
                                    shopViewModel.currentShop?.shopName ??
                                        authViewModel.user?.displayName ?? 'Shopkeeper',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showLogoutDialog(context),
                              icon: const Icon(
                                Icons.logout,
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Dashboard Content
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // QR Code Section
                    _QRCodeSection(shopViewModel: shopViewModel),
                    const SizedBox(height: 24),

                    // Quick Stats
                    _QuickStatsSection(shopViewModel: shopViewModel),
                    const SizedBox(height: 24),

                    // Pending Requests Alert
                    if (shopViewModel.pendingRequests > 0)
                      _PendingRequestsAlert(shopViewModel: shopViewModel),

                    // Recent Activity
                    _RecentActivitySection(shopViewModel: shopViewModel),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Logout',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: AppColors.mediumGray),
              ),
            ),
            TextButton(
              onPressed: () async {
                await authViewModel.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const UserTypeSelectionScreen()),
                        (route) => false,
                  );
                }
              },
              child: Text(
                'Logout',
                style: GoogleFonts.poppins(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QRCodeSection extends StatelessWidget {
  final ShopViewModel shopViewModel;

  const _QRCodeSection({required this.shopViewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        borderRadius: BorderRadius.circular(20),
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
              Text(
                'Shop QR Code',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              IconButton(
                onPressed: () => _showQRDialog(context),
                icon: const Icon(
                  Icons.fullscreen,
                  color: AppColors.white,
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
            ),
            child: shopViewModel.currentShop != null
                ? PrettyQr(
              data: shopViewModel.currentShop!.qrCode,
              size: 150,
              roundEdges: true,
              elementColor: AppColors.darkGray,
            )
                : const CircularProgressIndicator(),
          ),
          const SizedBox(height: 16),
          Text(
            'Customers can scan this QR to make payments',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: shopViewModel.currentShop != null
                ? () => _shareQRCode(context)
                : null,
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share QR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQRDialog(BuildContext context) {
    if (shopViewModel.currentShop == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Shop QR Code',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Container(
          width: 300,
          height: 300,
          child: PrettyQr(
            data: shopViewModel.currentShop!.qrCode,
            size: 280,
            roundEdges: true,
            elementColor: AppColors.darkGray,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: AppColors.primaryGreen),
            ),
          ),
          ElevatedButton(
            onPressed: () => _shareQRCode(context),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _shareQRCode(BuildContext context) {
    // Implementation for sharing QR code
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'QR Code sharing feature coming soon!',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }
}

class _QuickStatsSection extends StatelessWidget {
  final ShopViewModel shopViewModel;

  const _QuickStatsSection({required this.shopViewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Overview',
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
              child: _StatCard(
                title: 'Total Customers',
                value: shopViewModel.totalCustomers.toString(),
                icon: Icons.people,
                color: AppColors.accentBlue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Money Allocated',
                value: '₹${shopViewModel.totalMoneyAllocated.toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Money Used',
                value: '₹${shopViewModel.totalMoneyUsed.toStringAsFixed(0)}',
                icon: Icons.trending_down,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Overdue',
                value: shopViewModel.overdueCustomers.length.toString(),
                icon: Icons.warning,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
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

class _PendingRequestsAlert extends StatelessWidget {
  final ShopViewModel shopViewModel;

  const _PendingRequestsAlert({required this.shopViewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notification_important,
            color: AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Requests',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                Text(
                  '${shopViewModel.pendingRequests} customers waiting for approval',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Navigate to customers tab
              // This would be handled by the parent widget
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Review',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  final ShopViewModel shopViewModel;

  const _RecentActivitySection({required this.shopViewModel});

  @override
  Widget build(BuildContext context) {
    final recentTransactions = shopViewModel.transactions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to transactions tab
              },
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (recentTransactions.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 48,
                  color: AppColors.mediumGray,
                ),
                const SizedBox(height: 12),
                Text(
                  'No recent transactions',
                  style: GoogleFonts.poppins(
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTransactions.length,
            itemBuilder: (context, index) {
              final transaction = recentTransactions[index];
              return _TransactionTile(transaction: transaction);
            },
          ),
      ],
    );
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
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.timestamp),
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
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}