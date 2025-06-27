import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_legacy/view/shopkeeper/screens/shopkeeper_transcation_screen.dart';
import 'package:provider/provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/models/firebase_customer_shop_relation_model.dart';
import '../../../viewmodel/auth_viewmodel.dart';
import '../../../viewmodel/shop_viewmodel.dart';
import '../../auth/screens/user_type_section_screen.dart';
import 'customer_request_screen.dart';
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
              // ShopkeeperCustomersScreen(),
              EnhancedCustomerRequestsScreen(),
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
                    // QR Code Section - UPDATED VERSION
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

// REPLACE THIS ENTIRE CLASS WITH THE UPDATED VERSION
// Updated _QRCodeSection for shopkeeper_dashboard.dart

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shop QR Code',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  if (shopViewModel.currentShop != null)
                    Text(
                      shopViewModel.currentShop!.shopName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.white.withOpacity(0.9),
                      ),
                    ),
                ],
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

          // QR Code Display with Error Handling
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildQRCodeWidget(),
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

          // Enhanced Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
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
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: shopViewModel.currentShop != null
                      ? () => _copyQRData(context)
                      : null,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    side: const BorderSide(color: AppColors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeWidget() {
    // Show loading if shop is not initialized
    if (shopViewModel.currentShop == null) {
      return Container(
        width: 150,
        height: 150,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
              SizedBox(height: 8),
              Text(
                'Generating QR...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mediumGray,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Generate QR data for the shop
    final qrData = _generateQRData();

    print('Generated QR Data: $qrData');
    print('QR Data Length: ${qrData.length}');

    // Use PrettyQrView.data() to generate QR code
    try {
      return Container(
        width: 150,
        height: 150,
        child: PrettyQrView.data(
          data: qrData,
          decoration: const PrettyQrDecoration(
            shape: PrettyQrSmoothSymbol(),
            image: null,
          ),
        ),
      );
    } catch (e) {
      print('QR Code generation error: $e');

      return Container(
        width: 150,
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_2,
                color: AppColors.error,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'QR Generation\nFailed',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => shopViewModel.refresh(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(fontSize: 10, color: AppColors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Generate clean QR data
  String _generateQRData() {
    if (shopViewModel.currentShop == null) {
      return 'SHOP_NOT_FOUND';
    }

    final shop = shopViewModel.currentShop!;

    // Create simple JSON data for QR
    final qrData = {
      'type': 'local_legacy_shop',
      'shop_id': shop.id,
      'shop_name': shop.shopName,
      'shopkeeper_id': shop.shopkeeperId,
      'version': '1.0',
    };

    return json.encode(qrData);
  }

  void _showQRDialog(BuildContext context) {
    if (shopViewModel.currentShop == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            Text(
              shopViewModel.currentShop!.shopName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              'Payment QR Code',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.mediumGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Container(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 280,
                height: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: _buildLargeQRCode(),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Shop Details',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${shopViewModel.currentShop!.id}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.mediumGray,
                      ),
                    ),
                    if (shopViewModel.currentShop!.address.isNotEmpty)
                      Text(
                        shopViewModel.currentShop!.address,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.mediumGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: AppColors.mediumGray),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareQRCode(context);
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeQRCode() {
    if (shopViewModel.currentShop == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_2,
              size: 100,
              color: AppColors.mediumGray,
            ),
            const SizedBox(height: 16),
            Text(
              'QR Code Not Available',
              style: GoogleFonts.poppins(
                color: AppColors.mediumGray,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final qrData = _generateQRData();

    try {
      return Container(
        width: 248,
        height: 248,
        child: PrettyQrView.data(
          data: qrData,
          decoration: const PrettyQrDecoration(
            shape: PrettyQrSmoothSymbol(),
            image: null,
          ),
        ),
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to display QR code',
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  void _shareQRCode(BuildContext context) {
    if (shopViewModel.currentShop == null) return;

    final qrData = _generateQRData();
    final shareText = '''
🏪 ${shopViewModel.currentShop!.shopName}

📱 Scan this QR code to make payments at our shop!

Shop Details:
📍 ${shopViewModel.currentShop!.address.isNotEmpty ? shopViewModel.currentShop!.address : 'Address not set'}
🆔 Shop ID: ${shopViewModel.currentShop!.id}

💳 Easy credit-based payments
🔒 Secure transactions
⚡ Instant processing

QR Data: $qrData

Powered by Local Legacy
    ''';

    // For demo purposes, show share dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Share QR Code',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share this information with your customers:',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                shareText,
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _copyQRData(context);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Text'),
          ),
        ],
      ),
    );
  }

  void _copyQRData(BuildContext context) {
    if (shopViewModel.currentShop == null) return;

    final qrData = _generateQRData();
    final shareText = '''🏪 ${shopViewModel.currentShop!.shopName}

📱 Scan this QR code to make payments!
📍 ${shopViewModel.currentShop!.address.isNotEmpty ? shopViewModel.currentShop!.address : 'Address not set'}
🆔 ${shopViewModel.currentShop!.id}

QR Data: $qrData

Powered by Local Legacy''';

    Clipboard.setData(ClipboardData(text: shareText));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Shop details copied to clipboard!',
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}



// Keep the rest of your existing widgets as they are
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
  final FirebaseTransactionModel transaction;

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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.timestamp),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.mediumGray,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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