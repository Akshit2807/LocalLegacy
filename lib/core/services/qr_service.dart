import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class QRCodeService {
  /// Parse QR data from Local Legacy shop QR codes
  static Map<String, dynamic>? parseShopQRData(String qrData) {
    try {
      // Check if it's valid JSON format first
      if (qrData.startsWith('{') && qrData.endsWith('}')) {
        final data = json.decode(qrData) as Map<String, dynamic>;

        // Validate Local Legacy shop QR structure
        if (data['type'] == 'local_legacy_shop' &&
            data.containsKey('shop_id') &&
            data.containsKey('shop_name') &&
            data.containsKey('shopkeeper_id')) {
          return data;
        }
      }

      // Fallback: check for legacy format (if any)
      if (qrData.startsWith('ll_shop_')) {
        return _parseLegacyFormat(qrData);
      }

      print('Invalid QR format: $qrData');
      return null;
    } catch (e) {
      print('Error parsing QR data: $e');
      return null;
    }
  }

  /// Parse legacy QR format for backward compatibility
  static Map<String, dynamic>? _parseLegacyFormat(String qrData) {
    try {
      if (!qrData.startsWith('ll_shop_')) return null;

      final base64Data = qrData.substring(8); // Remove 'll_shop_' prefix
      final jsonString = utf8.decode(base64.decode(base64Data));
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return data;
    } catch (e) {
      print('Error parsing legacy QR: $e');
      return null;
    }
  }

  /// Generate QR data for shop (already used in shopkeeper dashboard)
  static String generateShopQRData({
    required String shopId,
    required String shopName,
    required String shopkeeperId,
    String? address,
  }) {
    final qrData = {
      'type': 'local_legacy_shop',
      'shop_id': shopId,
      'shop_name': shopName,
      'shopkeeper_id': shopkeeperId,
      'version': '1.0',
      if (address != null && address.isNotEmpty) 'address': address,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return json.encode(qrData);
  }

  /// Validate shop QR data structure
  static bool isValidShopQR(String qrData) {
    final data = parseShopQRData(qrData);
    if (data == null) return false;

    // Check required fields
    final requiredFields = ['type', 'shop_id', 'shop_name', 'shopkeeper_id', 'version'];
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        return false;
      }
    }

    // Check if it's the correct type
    if (data['type'] != 'local_legacy_shop') return false;

    // Check if timestamp is not too old (if present) - 30 days max
    if (data.containsKey('timestamp')) {
      final timestamp = data['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxAge = 30 * 24 * 60 * 60 * 1000; // 30 days in milliseconds

      if (now - timestamp > maxAge) {
        print('QR code is too old');
        return false;
      }
    }

    return true;
  }

  /// Extract shop ID from QR data
  static String? extractShopId(String qrData) {
    final data = parseShopQRData(qrData);
    return data?['shop_id'];
  }

  /// Extract shop name from QR data
  static String? extractShopName(String qrData) {
    final data = parseShopQRData(qrData);
    return data?['shop_name'];
  }

  /// Generate user-friendly QR display ID
  static String generateDisplayId(String shopId) {
    final random = Random();
    final hash = shopId.substring(0, min(4, shopId.length)).toUpperCase();
    final randomNum = random.nextInt(999).toString().padLeft(3, '0');
    return 'LL$hash$randomNum';
  }

  /// Generate hash for verification
  static String generateVerificationHash(String shopId, String customerId) {
    final input = '$shopId-$customerId-${DateTime.now().day}';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8);
  }
}