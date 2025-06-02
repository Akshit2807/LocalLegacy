import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodel/customer_viewmodel.dart';
import '../../../viewmodel/auth_viewmodel.dart';

class CustomerPaymentScreen extends StatefulWidget {
  final String shopId;
  final String shopName;

  const CustomerPaymentScreen({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  @override
  State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen>
    with TickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  late AnimationController _animationController;
  late AnimationController _successAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _successScaleAnimation;
  bool _showSuccessDialog = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _successScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successAnimationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _pinController.dispose();
    _animationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CustomerViewModel, AuthViewModel>(
      builder: (context, customerViewModel, authViewModel, child) {
        final shopRelation = customerViewModel.getShopRelation(widget.shopId);

        if (shopRelation == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Payment')),
            body: Center(
              child: Text(
                'Shop not found or access denied',
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              // Main Content
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.lightOrange, AppColors.white],
                  ),
                ),
                child: SafeArea(
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Header
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.arrow_back_ios),
                                    color: AppColors.darkGray,
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Make Payment',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkGray,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 48), // Balance the back button
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Shop Info Card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryOrange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: const Icon(
                                        Icons.store,
                                        color: AppColors.primaryOrange,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.shopName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.darkGray,
                                            ),
                                          ),
                                          Text(
                                            'Scan successful',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.verified,
                                      color: AppColors.success,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Available Credit Display
                              Container(
                                width: double.infinity,
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
                                  children: [
                                    Text(
                                      'Available Credit',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: AppColors.white.withOpacity(0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '₹${shopRelation.availableCredit.toStringAsFixed(0)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          children: [
                                            Text(
                                              '₹${shopRelation.totalCreditLimit.toStringAsFixed(0)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.white,
                                              ),
                                            ),
                                            Text(
                                              'Total Limit',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: AppColors.white.withOpacity(0.9),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            Text(
                                              '₹${shopRelation.usedAmount.toStringAsFixed(0)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.white,
                                              ),
                                            ),
                                            Text(
                                              'Used',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: AppColors.white.withOpacity(0.9),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Amount Input
                              Container(
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
                                    Text(
                                      'Enter Amount',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.darkGray,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _amountController,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkGray,
                                      ),
                                      decoration: InputDecoration(
                                        prefixText: '₹ ',
                                        prefixStyle: GoogleFonts.poppins(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.darkGray,
                                        ),
                                        hintText: '0',
                                        hintStyle: GoogleFonts.poppins(
                                          fontSize: 24,
                                          color: AppColors.mediumGray,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        fillColor: AppColors.lightGray,
                                        filled: true,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Quick amount buttons
                                    Row(
                                      children: [
                                        _QuickAmountButton(
                                          amount: 100,
                                          onTap: () => _amountController.text = '100',
                                        ),
                                        const SizedBox(width: 8),
                                        _QuickAmountButton(
                                          amount: 500,
                                          onTap: () => _amountController.text = '500',
                                        ),
                                        const SizedBox(width: 8),
                                        _QuickAmountButton(
                                          amount: 1000,
                                          onTap: () => _amountController.text = '1000',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // PIN Input
                              Container(
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
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.security,
                                          color: AppColors.accentBlue,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Enter Security PIN',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.darkGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _pinController,
                                      keyboardType: TextInputType.number,
                                      obscureText: true,
                                      maxLength: 4,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 8,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '••••',
                                        hintStyle: GoogleFonts.poppins(
                                          fontSize: 18,
                                          color: AppColors.mediumGray,
                                          letterSpacing: 8,
                                        ),
                                        counterText: '',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        fillColor: AppColors.lightGray,
                                        filled: true,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Pay Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: customerViewModel.isLoading
                                      ? null
                                      : () => _processPayment(customerViewModel),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryOrange,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 8,
                                    shadowColor: AppColors.primaryOrange.withOpacity(0.3),
                                  ),
                                  child: customerViewModel.isLoading
                                      ? const CircularProgressIndicator(
                                    color: AppColors.white,
                                  )
                                      : Text(
                                    'Pay Now',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Security Notice
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.accentBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.shield,
                                      color: AppColors.accentBlue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Your transaction is secured with end-to-end encryption',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppColors.accentBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Success Dialog Overlay
              if (_showSuccessDialog)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _successScaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _successScaleAnimation.value,
                          child: Container(
                            margin: const EdgeInsets.all(40),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: AppColors.white,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Payment Successful!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkGray,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '₹${_amountController.text} paid to ${widget.shopName}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: AppColors.mediumGray,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() => _showSuccessDialog = false);
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                    ),
                                    child: Text(
                                      'Done',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _processPayment(CustomerViewModel customerViewModel) async {
    final amount = double.tryParse(_amountController.text);
    final pin = _pinController.text;

    if (amount == null || amount <= 0) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }

    if (pin.length != 4) {
      _showErrorSnackBar('Please enter a 4-digit PIN');
      return;
    }

    // Add haptic feedback
    HapticFeedback.lightImpact();

    final success = await customerViewModel.makePayment(
      widget.shopId,
      amount,
      pin,
    );

    if (success) {
      setState(() => _showSuccessDialog = true);
      _successAnimationController.forward();

      // Add success haptic feedback
      HapticFeedback.heavyImpact();

      // Clear form
      _amountController.clear();
      _pinController.clear();
    } else {
      _showErrorSnackBar(
        customerViewModel.errorMessage ?? 'Payment failed. Please try again.',
      );

      // Add error haptic feedback
      HapticFeedback.heavyImpact();

      // Clear PIN for security
      _pinController.clear();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final int amount;
  final VoidCallback onTap;

  const _QuickAmountButton({
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.3),
            ),
          ),
          child: Text(
            '₹$amount',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryOrange,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}