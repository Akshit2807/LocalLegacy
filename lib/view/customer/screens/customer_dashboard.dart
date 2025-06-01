import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/models/customer_shop_relation_model.dart';
import '../../../viewmodel/auth_viewmodel.dart';
import '../../../viewmodel/customer_viewmodel.dart';
import '../../auth/screens/user_type_section_screen.dart';
import 'customer_payment_screen.dart';
import 'customer_shops_screen.dart';
import 'customer_transcation_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final customerViewModel = Provider.of<CustomerViewModel>(context, listen: false);
      if (authViewModel.user != null) {
        customerViewModel.initializeCustomer(authViewModel.user!.id);
        _checkSecurityPin(customerViewModel, authViewModel.user!.id);
      }
    });
  }

  void _checkSecurityPin(CustomerViewModel customerViewModel, String customerId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (customerViewModel.securityPin == null) {
        _showSetPinDialog(customerViewModel, customerId);
      }
    });
  }

  void _showSetPinDialog(CustomerViewModel customerViewModel, String customerId) {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Set Security PIN',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please set a 4-digit PIN for secure transactions',
              style: GoogleFonts.poppins(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Enter PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (pinController.text.length == 4 &&
                  pinController.text == confirmPinController.text) {
                final success = await customerViewModel.setSecurityPin(
                  customerId,
                  pinController.text,
                );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Security PIN set successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('PINs do not match or invalid length'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: Text('Set PIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthViewModel, CustomerViewModel>(
      builder: (context, authViewModel, customerViewModel, child) {
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _DashboardTab(
                customerViewModel: customerViewModel,
                authViewModel: authViewModel,
              ),
              CustomerShopsScreen(),
              CustomerTransactionsScreen(),
              _QRScannerScreen(
                customerViewModel: customerViewModel,
                authViewModel: authViewModel,
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: AppColors.primaryOrange,
            unselectedItemColor: AppColors.mediumGray,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.store),
                label: 'Shops',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner),
                label: 'Scan QR',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final CustomerViewModel customerViewModel;
  final AuthViewModel authViewModel;

  const _DashboardTab({
    required this.customerViewModel,
    required this.authViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.lightOrange, AppColors.white],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => customerViewModel.refresh(authViewModel.user!.id),
          color: AppColors.primaryOrange,
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
                              backgroundColor: AppColors.primaryOrange,
                              child: Text(
                                authViewModel.user?.initials ?? 'C',
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
                                    'Hello,',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: AppColors.mediumGray,
                                    ),
                                  ),
                                  Text(
                                    authViewModel.user?.displayName ?? 'Customer',
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
                    // Credit Overview Card
                    _CreditOverviewCard(customerViewModel: customerViewModel),
                    const SizedBox(height: 24),

                    // Quick Stats
                    _QuickStatsSection(customerViewModel: customerViewModel),
                    const SizedBox(height: 24),

                    // Due Date Alert
                    if (customerViewModel.nearestDueDate != null)
                      _DueDateAlert(customerViewModel: customerViewModel),

                    // Recent Activity
                    _RecentActivitySection(customerViewModel: customerViewModel),
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

class _CreditOverviewCard extends StatelessWidget {
  final CustomerViewModel customerViewModel;

  const _CreditOverviewCard({required this.customerViewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryOrange,
            AppColors.warmYellow,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Available Credit',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppColors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${customerViewModel.totalAvailableCredit.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _CreditStat(
                  label: 'Total Credit',
                  value: '₹${customerViewModel.totalCreditLimit.toStringAsFixed(0)}',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _CreditStat(
                  label: 'Used',
                  value: '₹${customerViewModel.totalUsedAmount.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditStat extends StatelessWidget {
  final String label;
  final String value;

  const _CreditStat({
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
            fontSize: 18,
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

class _QuickStatsSection extends StatelessWidget {
  final CustomerViewModel customerViewModel;

  const _QuickStatsSection({required this.customerViewModel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Registered Shops',
            value: customerViewModel.registeredShopsCount.toString(),
            icon: Icons.store,
            color: AppColors.accentBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Total Transactions',
            value: customerViewModel.transactions.length.toString(),
            icon: Icons.receipt_long,
            color: AppColors.primaryGreen,
          ),
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

class _DueDateAlert extends StatelessWidget {
  final CustomerViewModel customerViewModel;

  const _DueDateAlert({required this.customerViewModel});

  @override
  Widget build(BuildContext context) {
    final nearestDue = customerViewModel.nearestDueDate!;
    final daysLeft = nearestDue.daysUntilDue;
    final isUrgent = daysLeft <= 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUrgent ? AppColors.error.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? AppColors.error.withOpacity(0.3) : AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.error : Icons.schedule,
            color: isUrgent ? AppColors.error : AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrgent ? 'Payment Due Soon!' : 'Upcoming Payment',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                Text(
                  daysLeft > 0
                      ? '$daysLeft days left to pay ₹${nearestDue.usedAmount.toStringAsFixed(0)}'
                      : 'Payment overdue by ${(-daysLeft).abs()} days',
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
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  final CustomerViewModel customerViewModel;

  const _RecentActivitySection({required this.customerViewModel});

  @override
  Widget build(BuildContext context) {
    final recentTransactions = customerViewModel.transactions.take(5).toList();

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
                  color: AppColors.primaryOrange,
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
                const SizedBox(height: 8),
                Text(
                  'Scan a shop QR to make your first purchase',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.mediumGray,
                  ),
                  textAlign: TextAlign.center,
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

class _QRScannerScreen extends StatefulWidget {
  final CustomerViewModel customerViewModel;
  final AuthViewModel authViewModel;

  const _QRScannerScreen({
    required this.customerViewModel,
    required this.authViewModel,
  });

  @override
  State<_QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<_QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scan Shop QR Code',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.darkGray,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            onPressed: () => cameraController.toggleTorch(),
            icon: Icon(Icons.flash_on),
          ),
          IconButton(
            onPressed: () => cameraController.switchCamera(),
            icon: Icon(Icons.flip_camera_ios),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera View
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),

          // Overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
            child: Stack(
              children: [
                // Scanning area
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primaryOrange,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        // Corner indicators
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.primaryOrange, width: 4),
                                left: BorderSide(color: AppColors.primaryOrange, width: 4),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.primaryOrange, width: 4),
                                right: BorderSide(color: AppColors.primaryOrange, width: 4),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.primaryOrange, width: 4),
                                left: BorderSide(color: AppColors.primaryOrange, width: 4),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.primaryOrange, width: 4),
                                right: BorderSide(color: AppColors.primaryOrange, width: 4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Instructions
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Point your camera at the shop\'s QR code to scan',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.darkGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Processing QR Code...',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() => _isProcessing = true);

    try {
      final result = await widget.customerViewModel.handleQRScan(
        barcode.rawValue!,
        widget.authViewModel.user!.id,
      );

      if (result != null && mounted) {
        final parts = result.split(':');
        final action = parts[0];
        final shopId = parts[1];
        final shopName = parts[2];

        if (action == 'new_shop') {
          _showJoinShopDialog(shopId, shopName);
        } else if (action == 'approved') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerPaymentScreen(
                shopId: shopId,
                shopName: shopName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.customerViewModel.errorMessage ?? 'QR scan failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showJoinShopDialog(String shopId, String shopName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Join Shop',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store,
              size: 48,
              color: AppColors.primaryOrange,
            ),
            const SizedBox(height: 16),
            Text(
              'Do you want to send a request to join "$shopName"?',
              style: GoogleFonts.poppins(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The shopkeeper will review your request and set your credit limit.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.mediumGray,
              ),
              textAlign: TextAlign.center,
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
              Navigator.pop(context);
              final success = await widget.customerViewModel.sendJoinRequest(
                shopId,
                widget.authViewModel.user!.id,
              );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Request sent to $shopName!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: Text('Send Request'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}