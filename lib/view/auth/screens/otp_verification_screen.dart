import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodel/auth_viewmodel.dart';
import 'dart:async';

import '../../customer/screens/customer_dashboard.dart';
import '../../shopkeeper/screens/shopkeeper_dashboard.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String userType;
  final bool isFromLogin;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.userType,
    required this.isFromLogin,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _resendOtp() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final success = await authViewModel.resendOtp(widget.email);

    if (success) {
      setState(() {
        _secondsRemaining = 60;
        _canResend = false;
      });
      _startTimer();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authViewModel.errorMessage ?? 'Failed to resend OTP'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.cream,
              AppColors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios),
                  color: AppColors.darkGray,
                ),
                const SizedBox(height: 40),

                // Icon
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.mark_email_read,
                      size: 50,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Header
                Center(
                  child: Text(
                    'Verify Your Email',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Center(
                  child: Text(
                    'We\'ve sent a 6-digit verification code to\n${widget.email}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppColors.mediumGray,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),

                // OTP Input
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 60,
                    fieldWidth: 50,
                    activeFillColor: AppColors.white,
                    inactiveFillColor: AppColors.lightGray,
                    selectedFillColor: AppColors.lightGreen,
                    activeColor: AppColors.primaryGreen,
                    inactiveColor: AppColors.mediumGray,
                    selectedColor: AppColors.primaryGreen,
                  ),
                  cursorColor: AppColors.primaryGreen,
                  animationDuration: const Duration(milliseconds: 300),
                  enableActiveFill: true,
                  onCompleted: (code) {
                    _verifyOtp(code);
                  },
                  onChanged: (value) {},
                ),
                const SizedBox(height: 30),

                // Timer and Resend
                Center(
                  child: _canResend
                      ? Consumer<AuthViewModel>(
                    builder: (context, authViewModel, child) {
                      return TextButton(
                        onPressed: authViewModel.isLoading ? null : _resendOtp,
                        child: Text(
                          authViewModel.isLoading ? 'Sending...' : 'Resend OTP',
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  )
                      : Text(
                    'Resend OTP in ${_secondsRemaining}s',
                    style: GoogleFonts.poppins(
                      color: AppColors.mediumGray,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Verify Button
                Consumer<AuthViewModel>(
                  builder: (context, authViewModel, child) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authViewModel.isLoading ? null : () {
                          if (_otpController.text.length == 6) {
                            _verifyOtp(_otpController.text);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter complete OTP'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                        child: authViewModel.isLoading
                            ? const CircularProgressIndicator(color: AppColors.white)
                            : const Text('Verify & Continue'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),

                // Change Email
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Change Email Address',
                      style: GoogleFonts.poppins(
                        color: AppColors.mediumGray,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _verifyOtp(String otp) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final success = await authViewModel.verifyOtp(widget.email, otp);

    if (success && context.mounted) {
      // Navigate to appropriate dashboard based on user type
      if (widget.userType == 'shopkeeper') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ShopkeeperDashboard()),
              (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CustomerDashboard()),
              (route) => false,
        );
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authViewModel.errorMessage ?? 'Invalid OTP'),
          backgroundColor: AppColors.error,
        ),
      );
      // Clear the OTP field on error
      _otpController.clear();
    }
  }
}