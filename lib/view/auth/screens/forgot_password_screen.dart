import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodel/auth_viewmodel.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String userType;

  const ForgotPasswordScreen({super.key, required this.userType});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isEmailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
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
              AppColors.lightBlue,
              AppColors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
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
                        color: AppColors.accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        _isEmailSent ? Icons.mark_email_read : Icons.lock_reset,
                        size: 50,
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Header
                  Center(
                    child: Text(
                      _isEmailSent ? 'Check Your Email' : 'Forgot Password?',
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
                      _isEmailSent
                          ? 'We\'ve sent a password reset link to\n${_emailController.text}'
                          : 'Don\'t worry! Enter your email address and we\'ll send you a link to reset your password.',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: AppColors.mediumGray,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (!_isEmailSent) ...[
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),

                    // Send Reset Link Button
                    Consumer<AuthViewModel>(
                      builder: (context, authViewModel, child) {
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: authViewModel.isLoading ? null : () async {
                              if (_formKey.currentState!.validate()) {
                                final result = await authViewModel.resetPassword(
                                  _emailController.text,
                                );

                                if (result.isSuccess) {
                                  setState(() {
                                    _isEmailSent = true;
                                  });
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(authViewModel.errorMessage ?? 'Failed to send reset email'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                            child: authViewModel.isLoading
                                ? const CircularProgressIndicator(color: AppColors.white)
                                : const Text('Send Reset Link'),
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    // Success Actions
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Open email app functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please check your email app'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        child: const Text('Open Email App'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Consumer<AuthViewModel>(
                      builder: (context, authViewModel, child) {
                        return SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: authViewModel.isLoading ? null : () async {
                              final result = await authViewModel.resetPassword(_emailController.text);

                              if (result.isSuccess && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Reset link sent again!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(authViewModel.errorMessage ?? 'Failed to resend email'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                            child: authViewModel.isLoading
                                ? const CircularProgressIndicator()
                                : const Text('Resend Email'),
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Back to Login
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_back,
                            size: 18,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Back to Login',
                            style: GoogleFonts.poppins(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}