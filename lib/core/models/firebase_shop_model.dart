import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseShopModel {
  final String id;
  final String shopkeeperId;
  final String shopName;
  final String address;
  final String qrCodeData; // The QR data string
  final String qrCodeBase64; // Base64 encoded QR image
  final String? qrCodeImageUrl; // Firebase Storage URL (optional)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  FirebaseShopModel({
    required this.id,
    required this.shopkeeperId,
    required this.shopName,
    required this.address,
    required this.qrCodeData,
    required this.qrCodeBase64,
    this.qrCodeImageUrl,
    required this.createdAt,
    this.updatedAt,
    required this.isActive,
  });

  // From Firestore document
  factory FirebaseShopModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirebaseShopModel(
      id: doc.id,
      shopkeeperId: data['shopkeeper_id'] ?? '',
      shopName: data['shop_name'] ?? '',
      address: data['address'] ?? '',
      qrCodeData: data['qr_code_data'] ?? '',
      qrCodeBase64: data['qr_code_base64'] ?? '',
      qrCodeImageUrl: data['qr_code_image_url'],
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] as Timestamp).toDate()
          : null,
      isActive: data['is_active'] ?? true,
    );
  }

  // From Map
  factory FirebaseShopModel.fromMap(Map<String, dynamic> data, String id) {
    return FirebaseShopModel(
      id: id,
      shopkeeperId: data['shopkeeper_id'] ?? '',
      shopName: data['shop_name'] ?? '',
      address: data['address'] ?? '',
      qrCodeData: data['qr_code_data'] ?? '',
      qrCodeBase64: data['qr_code_base64'] ?? '',
      qrCodeImageUrl: data['qr_code_image_url'],
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'])
          : null,
      isActive: data['is_active'] ?? true,
    );
  }

  // To Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'shopkeeper_id': shopkeeperId,
      'shop_name': shopName,
      'address': address,
      'qr_code_data': qrCodeData,
      'qr_code_base64': qrCodeBase64,
      'qr_code_image_url': qrCodeImageUrl,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': FieldValue.serverTimestamp(),
      'is_active': isActive,
    };
  }

  // To Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopkeeper_id': shopkeeperId,
      'shop_name': shopName,
      'address': address,
      'qr_code_data': qrCodeData,
      'qr_code_base64': qrCodeBase64,
      'qr_code_image_url': qrCodeImageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_active': isActive,
    };
  }

  // Copy with
  FirebaseShopModel copyWith({
    String? id,
    String? shopkeeperId,
    String? shopName,
    String? address,
    String? qrCodeData,
    String? qrCodeBase64,
    String? qrCodeImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return FirebaseShopModel(
      id: id ?? this.id,
      shopkeeperId: shopkeeperId ?? this.shopkeeperId,
      shopName: shopName ?? this.shopName,
      address: address ?? this.address,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      qrCodeBase64: qrCodeBase64 ?? this.qrCodeBase64,
      qrCodeImageUrl: qrCodeImageUrl ?? this.qrCodeImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Helper getters
  bool get hasQRCode => qrCodeBase64.isNotEmpty;
  bool get hasStorageUrl => qrCodeImageUrl != null && qrCodeImageUrl!.isNotEmpty;
  String get displayName => shopName.isNotEmpty ? shopName : 'My Shop';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FirebaseShopModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FirebaseShopModel(id: $id, shopName: $shopName, shopkeeperId: $shopkeeperId)';
  }
}