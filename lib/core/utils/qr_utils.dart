import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRUtils {
  // Generate QR code and convert to base64
  static Future<String> generateQRAsBase64(String data, {double size = 200}) async {
    try {
      // Create QR code widget
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      // Convert to image
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      qrPainter.paint(canvas, Size(size, size));
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());

      // Convert to bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // Convert to base64
      final base64String = base64Encode(bytes);

      return base64String;
    } catch (e) {
      throw Exception('Failed to generate QR code: $e');
    }
  }

  // Convert base64 back to bytes for display
  static Uint8List base64ToBytes(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      throw Exception('Failed to decode QR code: $e');
    }
  }

  // Generate shop QR data with Firebase format
  static String generateShopQRData(String shopId, String shopkeeperId) {
    final qrData = {
      'type': 'shop',
      'shop_id': shopId,
      'shopkeeper_id': shopkeeperId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return 'll_shop_${base64Encode(utf8.encode(jsonEncode(qrData)))}';
  }

  // Parse QR data
  static Map<String, dynamic>? parseQRData(String qrCode) {
    try {
      if (!qrCode.startsWith('ll_shop_')) {
        return null;
      }

      final base64Data = qrCode.substring(8); // Remove 'll_shop_' prefix
      final jsonString = utf8.decode(base64Decode(base64Data));
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return data;
    } catch (e) {
      return null;
    }
  }

  // Validate QR code
  static bool isValidShopQR(String qrCode) {
    final data = parseQRData(qrCode);
    return data != null &&
        data['type'] == 'shop' &&
        data['shop_id'] != null &&
        data['shopkeeper_id'] != null;
  }

  // Create QR widget from base64
  static Widget createQRWidget(String base64String, {double? size}) {
    try {
      final bytes = base64ToBytes(base64String);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
          ),
        ),
      );
    } catch (e) {
      return Container(
        width: size ?? 200,
        height: size ?? 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red),
        ),
        child: const Center(
          child: Icon(Icons.error, color: Colors.red),
        ),
      );
    }
  }

  // Get QR code file size in KB
  static double getQRSizeKB(String base64String) {
    try {
      final bytes = base64ToBytes(base64String);
      return bytes.length / 1024;
    } catch (e) {
      return 0;
    }
  }

  // Compress base64 string if needed (for Firestore 1MB document limit)
  static String compressQRBase64(String base64String, {double maxSizeKB = 100}) {
    final currentSize = getQRSizeKB(base64String);
    if (currentSize <= maxSizeKB) {
      return base64String;
    }

    // If QR is too large, we can regenerate with smaller size
    // This is a simplified approach - in practice you'd regenerate with smaller dimensions
    return base64String;
  }
}