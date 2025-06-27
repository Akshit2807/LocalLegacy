import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/firebase_customer_shop_relation_model.dart';
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

  // Animation controllers
  late AnimationController _scaleAnimationController;
  late AnimationController _successAnimationController;
  late AnimationController _pulseAnimationController;

  // Animations
  late Animation<double> _scaleAnimation;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _successOpacityAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;

  bool _showSuccessDialog = false;
  bool _isProcessingPayment = false;
  PaymentResult? _paymentResult;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // Scale animation for main content
    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
          parent: _scaleAnimationController, curve: Curves.elasticOut),
    );

    // Success animation
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _successScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _successOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );

    // Pulse animation for processing
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
          parent: _pulseAnimationController, curve: Curves.easeInOut),
    );

    // Slide animation
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _successAnimationController, curve: Curves.easeInOut),
    );

    _scaleAnimationController.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _pinController.dispose();
    _scaleAnimationController.dispose();
    _successAnimationController.dispose();
    _pulseAnimationController.dispose();
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
                              _buildHeader(context),
                              const SizedBox(height: 32),
                              _buildShopInfoCard(),
                              const SizedBox(height: 32),
                              _buildCreditDisplayCard(shopRelation),
                              const SizedBox(height: 32),
                              _buildAmountInputCard(),
                              const SizedBox(height: 24),
                              _buildPinInputCard(),
                              const SizedBox(height: 32),
                              _buildPayButton(customerViewModel),
                              const SizedBox(height: 24),
                              _buildSecurityNotice(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Processing Overlay
              if (_isProcessingPayment)
                _buildProcessingOverlay(),

              // Success Dialog Overlay
              if (_showSuccessDialog && _paymentResult != null)
                _buildSuccessOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
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
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildShopInfoCard() {
    return Container(
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
                Row(
                  children: [
                    Icon(
                      Icons.verified,
                      color: AppColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Scan successful',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.qr_code_scanner,
              color: AppColors.success,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditDisplayCard(FirebaseCustomerShopRelation shopRelation) {
    return Container(
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
              _buildCreditStat(
                'Total Limit',
                '₹${shopRelation.totalCreditLimit.toStringAsFixed(0)}',
              ),
              _buildCreditStat(
                'Used',
                '₹${shopRelation.usedAmount.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
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

  Widget _buildAmountInputCard() {
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
          Row(
            children: [
              _buildQuickAmountButton(100),
              const SizedBox(width: 8),
              _buildQuickAmountButton(500),
              const SizedBox(width: 8),
              _buildQuickAmountButton(1000),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButton(int amount) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _amountController.text = amount.toString(),
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

  Widget _buildPinInputCard() {
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
    );
  }

  Widget _buildPayButton(CustomerViewModel customerViewModel) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isProcessingPayment ? _pulseAnimation.value : 1.0,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_isProcessingPayment || customerViewModel.isLoading)
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
              child: _isProcessingPayment
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ],
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
        );
      },
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
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
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseAnimationController,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryOrange,
                          ),
                          strokeWidth: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Processing Payment',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we process your transaction...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.mediumGray,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: AnimatedBuilder(
          animation: _successAnimationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _successScaleAnimation.value,
              child: Opacity(
                opacity: _successOpacityAnimation.value,
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
                      // Success animation icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Transform.scale(
                                scale: _successScaleAnimation.value,
                                child: const Icon(
                                  Icons.check,
                                  color: AppColors.white,
                                  size: 50,
                                ),
                              ),
                            ),
                            // Ripple effect
                            if (_successScaleAnimation.value > 0.8)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.success,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            if (_successScaleAnimation.value > 0.85)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.success,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            if (_successScaleAnimation.value > 0.9)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.success,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
                        '₹${_paymentResult?.amount?.toStringAsFixed(
                            0)} paid to ${_paymentResult?.shopName}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppColors.mediumGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'New Balance: ₹${_paymentResult?.newBalance
                              ?.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Done',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
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

    // Start processing animation
    setState(() => _isProcessingPayment = true);
    _pulseAnimationController.repeat(reverse: true);

    // Add haptic feedback
    HapticFeedback.lightImpact();

    // Simulate processing delay for better UX
    await Future.delayed(const Duration(milliseconds: 1500));

    final result = await customerViewModel.makePayment(
      widget.shopId,
      amount,
      pin,
    );

    // Stop processing animation
    _pulseAnimationController.stop();
    setState(() => _isProcessingPayment = false);

    if (result.success) {
      // Store result and show success animation
      _paymentResult = result;
      setState(() => _showSuccessDialog = true);
      _successAnimationController.forward();

      // Success haptic feedback
      HapticFeedback.heavyImpact();

      // Clear form
      _amountController.clear();
      _pinController.clear();
    } else {
      _showErrorSnackBar(result.message);

      // Error haptic feedback
      HapticFeedback.heavyImpact();

      // Clear PIN for security
      _pinController.clear();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}