import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class QRCodeService {
  // Use a consistent encryption key for the app
  static const String _encryptionKey = 'LocalLegacyApp2024SecureKey123'; // 32 chars
  static final _key = Key.fromBase64(base64.encode(_encryptionKey.codeUnits.take(32).toList()));
  static final _iv = IV.fromSecureRandom(16);
  static final _encrypter = Encrypter(AES(_key));

  /// Generate encrypted QR data for a shop
  static String generateShopQRData({
    required String shopId,
    required String shopName,
    required String shopkeeperId,
    required String address,
  }) {
    try {
      // Create shop data object
      final shopData = {
        'type': 'shop',
        'shop_id': shopId,
        'shop_name': shopName,
        'shopkeeper_id': shopkeeperId,
        'address': address,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'version': '1.0',
      };

      // Convert to JSON string
      final jsonString = json.encode(shopData);

      // Encrypt the data
      final encrypted = _encrypter.encrypt(jsonString, iv: _iv);

      // Create final QR data with prefix and encrypted content
      final qrData = 'LL_SHOP:${base64.encode(_iv.bytes)}:${encrypted.base64}';

      print('Generated QR Data: $qrData');
      return qrData;
    } catch (e) {
      print('Error generating QR data: $e');
      throw Exception('Failed to generate QR code: $e');
    }
  }

  /// Decrypt and parse shop QR data
  static Map<String, dynamic>? decryptShopQRData(String qrData) {
    try {
      // Check if it's a valid Local Legacy shop QR
      if (!qrData.startsWith('LL_SHOP:')) {
        print('Invalid QR format: $qrData');
        return null;
      }

      // Remove prefix and split data
      final dataParts = qrData.substring(8).split(':'); // Remove 'LL_SHOP:'
      if (dataParts.length != 2) {
        print('Invalid QR data structure');
        return null;
      }

      // Extract IV and encrypted data
      final ivBytes = base64.decode(dataParts[0]);
      final encryptedData = dataParts[1];

      // Create IV from bytes
      final iv = IV(ivBytes);

      // Decrypt the data
      final encrypted = Encrypted.fromBase64(encryptedData);
      final decrypted = _encrypter.decrypt(encrypted, iv: iv);

      // Parse JSON
      final shopData = json.decode(decrypted) as Map<String, dynamic>;

      // Validate data structure
      if (!_validateShopData(shopData)) {
        print('Invalid shop data structure');
        return null;
      }

      print('Decrypted shop data: $shopData');
      return shopData;
    } catch (e) {
      print('Error decrypting QR data: $e');
      return null;
    }
  }

  /// Validate shop data structure
  static bool _validateShopData(Map<String, dynamic> data) {
    final requiredFields = [
      'type',
      'shop_id',
      'shop_name',
      'shopkeeper_id',
      'timestamp',
      'version'
    ];

    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        print('Missing required field: $field');
        return false;
      }
    }

    // Check if it's a shop type
    if (data['type'] != 'shop') {
      print('Invalid QR type: ${data['type']}');
      return false;
    }

    // Check timestamp (shouldn't be too old - 30 days)
    final timestamp = data['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAge = 30 * 24 * 60 * 60 * 1000; // 30 days in milliseconds

    if (now - timestamp > maxAge) {
      print('QR code is too old');
      return false;
    }

    return true;
  }

  /// Generate a simple hash for QR verification
  static String generateQRHash(String shopId) {
    final input = '$shopId${DateTime.now().day}$_encryptionKey';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8); // First 8 characters
  }

  /// Generate user-friendly QR identifier for display
  static String generateDisplayId(String shopId) {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = generateQRHash(shopId);
    final randomNum = random.nextInt(999).toString().padLeft(3, '0');
    return 'LL${hash.substring(0, 4).toUpperCase()}$randomNum';
  }

  /// Check if QR data is valid Local Legacy format
  static bool isValidLocalLegacyQR(String qrData) {
    return qrData.startsWith('LL_SHOP:') && qrData.split(':').length == 3;
  }

  /// Extract shop ID from encrypted QR (for caching purposes)
  static String? extractShopIdFromQR(String qrData) {
    final decryptedData = decryptShopQRData(qrData);
    return decryptedData?['shop_id'];
  }
}