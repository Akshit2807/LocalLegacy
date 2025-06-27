import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';
import '../../../viewmodel/customer_viewmodel.dart';
import '../../../viewmodel/auth_viewmodel.dart';
import 'customer_payment_screen.dart';

class EnhancedQRScannerScreen extends StatefulWidget {
  const EnhancedQRScannerScreen({super.key});

  @override
  State<EnhancedQRScannerScreen> createState() => _EnhancedQRScannerScreenState();
}

class _EnhancedQRScannerScreenState extends State<EnhancedQRScannerScreen>
    with TickerProviderStateMixin {
  late MobileScannerController _cameraController;
  late AnimationController _scanLineController;
  late AnimationController _pulseController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _pulseAnimation;

  bool _isProcessing = false;
  bool _isFlashOn = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
  }

  void _initializeControllers() {
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 1000,
      returnImage: false,
    );
  }

  void _setupAnimations() {
    _scanLineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanLineController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _scanLineController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera View
          MobileScanner(
            controller: _cameraController,
            onDetect: _onQRDetected,
          ),

          // Dark Overlay with Scanner Frame
          _buildScannerOverlay(),

          // Top Controls
          _buildTopControls(),

          // Bottom Instructions
          _buildBottomInstructions(),

          // Processing Overlay
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
      ),
      child: Stack(
        children: [
          // Scanner frame
          Center(
            child: Container(
              width: 280,
              height: 280,
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
                  ..._buildCornerIndicators(),

                  // Animated scan line
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 280 * _scanLineAnimation.value - 2,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primaryOrange,
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // QR Code Icon in center
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isProcessing ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                      Icons.qr_code_2,
                      color: AppColors.white,
                      size: 30,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerIndicators() {
    return [
      // Top-left corner
      Positioned(
        top: -1,
        left: -1,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.primaryOrange, width: 4),
              left: BorderSide(color: AppColors.primaryOrange, width: 4),
            ),
          ),
        ),
      ),
      // Top-right corner
      Positioned(
        top: -1,
        right: -1,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.primaryOrange, width: 4),
              right: BorderSide(color: AppColors.primaryOrange, width: 4),
            ),
          ),
        ),
      ),
      // Bottom-left corner
      Positioned(
        bottom: -1,
        left: -1,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.primaryOrange, width: 4),
              left: BorderSide(color: AppColors.primaryOrange, width: 4),
            ),
          ),
        ),
      ),
      // Bottom-right corner
      Positioned(
        bottom: -1,
        right: -1,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.primaryOrange, width: 4),
              right: BorderSide(color: AppColors.primaryOrange, width: 4),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildTopControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
            ),

            // Title
            Text(
              'Scan Shop QR Code',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),

            // Flash toggle
            GestureDetector(
              onTap: _toggleFlash,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: _isFlashOn ? AppColors.warmYellow : AppColors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInstructions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_scanner,
                color: AppColors.primaryOrange,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'Point your camera at the shop\'s QR code',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure the QR code is clearly visible within the frame',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInstructionItem(
                    Icons.center_focus_strong,
                    'Focus',
                  ),
                  _buildInstructionItem(
                    Icons.flash_on,
                    'Light',
                  ),
                  _buildInstructionItem(
                    Icons.payment,
                    'Pay',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.primaryOrange,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
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
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
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
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Processing QR Code...',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGray,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we verify the shop details',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.mediumGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleFlash() async {
    try {
      await _cameraController.toggleTorch();
      setState(() {
        _isFlashOn = !_isFlashOn;
      });

      // Haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  void _onQRDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    // Prevent duplicate scans
    if (_lastScannedCode == barcode.rawValue) return;
    _lastScannedCode = barcode.rawValue;

    // Start processing
    setState(() => _isProcessing = true);
    _pulseController.repeat(reverse: true);

    // Haptic feedback for scan detection
    HapticFeedback.mediumImpact();

    try {
      final customerViewModel = Provider.of<CustomerViewModel>(context, listen: false);
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

      if (authViewModel.user == null) {
        _showErrorDialog('User not authenticated. Please login again.');
        return;
      }

      print('Scanned QR: ${barcode.rawValue}');

      final result = await customerViewModel.handleQRScan(
        barcode.rawValue!,
        authViewModel.user!.id,
      );

      if (result != null && mounted) {
        if (result.type == QRScanResultType.newShop) {
          // Show join shop dialog
          _showJoinShopDialog(result);
        } else if (result.type == QRScanResultType.approvedShop) {
          // Navigate to payment screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerPaymentScreen(
                shopId: result.shopId,
                shopName: result.shopName,
              ),
            ),
          );
        }
      } else if (mounted) {
        // Show error message
        _showErrorDialog(
            customerViewModel.errorMessage ?? 'Failed to process QR code'
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An error occurred while processing the QR code: $e');
      }
    } finally {
      if (mounted) {
        _pulseController.stop();
        setState(() => _isProcessing = false);

        // Reset last scanned code after a delay to allow re-scanning
        Future.delayed(const Duration(seconds: 3), () {
          _lastScannedCode = null;
        });
      }
    }
  }

  void _showJoinShopDialog(QRScanResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.store,
                size: 30,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Join Shop',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
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
                color: AppColors.lightOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Shop Details',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.shopName,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOrange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Do you want to send a request to join "${result.shopName}"?',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.darkGray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.accentBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your Details Will Be Shared:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: AppColors.mediumGray),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          result.customerName ?? 'Your Name',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email, size: 14, color: AppColors.mediumGray),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          result.customerEmail ?? 'Your Email',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.mediumGray),
            ),
          ),
          Consumer<CustomerViewModel>(
            builder: (context, customerViewModel, child) {
              return ElevatedButton(
                onPressed: customerViewModel.isLoading
                    ? null
                    : () async {
                  final success = await customerViewModel.sendJoinRequest(
                    result.shopId,
                    result.customerId!,
                  );

                  if (success && mounted) {
                    Navigator.pop(context); // Close dialog
                    _showSuccessSnackBar(
                      'Request sent to ${result.shopName}! You\'ll be notified when approved.',
                    );

                    // Go back to previous screen
                    Navigator.pop(context);
                  } else if (mounted) {
                    _showErrorSnackBar(
                      customerViewModel.errorMessage ?? 'Failed to send request',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                ),
                child: customerViewModel.isLoading
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
                    : Text(
                  'Send Request',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 30,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan Error',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.darkGray,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
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