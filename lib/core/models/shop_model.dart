class ShopModel {
  final String id;
  final String shopkeeperId;
  final String shopName;
  final String address;
  final String qrCode;
  final DateTime createdAt;
  final bool isActive;

  ShopModel({
    required this.id,
    required this.shopkeeperId,
    required this.shopName,
    required this.address,
    required this.qrCode,
    required this.createdAt,
    required this.isActive,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'] ?? '',
      shopkeeperId: json['shopkeeper_id'] ?? '',
      shopName: json['shop_name'] ?? '',
      address: json['address'] ?? '',
      qrCode: json['qr_code'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shopkeeper_id': shopkeeperId,
      'shop_name': shopName,
      'address': address,
      'qr_code': qrCode,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  ShopModel copyWith({
    String? id,
    String? shopkeeperId,
    String? shopName,
    String? address,
    String? qrCode,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return ShopModel(
      id: id ?? this.id,
      shopkeeperId: shopkeeperId ?? this.shopkeeperId,
      shopName: shopName ?? this.shopName,
      address: address ?? this.address,
      qrCode: qrCode ?? this.qrCode,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}