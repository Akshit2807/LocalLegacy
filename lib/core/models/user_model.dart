import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseUserModel {
  final String id;
  final String email;
  final String? name;
  final String userType; // 'shopkeeper' or 'customer'
  final bool isEmailVerified;
  final String? phoneNumber;
  final String? avatarUrl;
  final DateTime? createdAt;
  final String? securityPin; // For customers

  FirebaseUserModel({
    required this.id,
    required this.email,
    this.name,
    required this.userType,
    required this.isEmailVerified,
    this.phoneNumber,
    this.avatarUrl,
    this.createdAt,
    this.securityPin,
  });

  // From Firestore document
  factory FirebaseUserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirebaseUserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'],
      userType: data['user_type'] ?? 'customer',
      isEmailVerified: data['email_verified'] ?? false,
      phoneNumber: data['phone_number'],
      avatarUrl: data['avatar_url'],
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : null,
      securityPin: data['security_pin'],
    );
  }

  // From Map (for Firebase Auth user metadata)
  factory FirebaseUserModel.fromMap(Map<String, dynamic> data, String id) {
    return FirebaseUserModel(
      id: id,
      email: data['email'] ?? '',
      name: data['name'],
      userType: data['user_type'] ?? 'customer',
      isEmailVerified: data['email_verified'] ?? false,
      phoneNumber: data['phone_number'],
      avatarUrl: data['avatar_url'],
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : null,
      securityPin: data['security_pin'],
    );
  }

  // To Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'user_type': userType,
      'email_verified': isEmailVerified,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'security_pin': securityPin,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  // To Map (for API requests)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'user_type': userType,
      'email_verified': isEmailVerified,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
      'security_pin': securityPin,
    };
  }

  // Copy with (for state updates)
  FirebaseUserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? userType,
    bool? isEmailVerified,
    String? phoneNumber,
    String? avatarUrl,
    DateTime? createdAt,
    String? securityPin,
  }) {
    return FirebaseUserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      userType: userType ?? this.userType,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      securityPin: securityPin ?? this.securityPin,
    );
  }

  // Helper getters
  bool get isShopkeeper => userType == 'shopkeeper';
  bool get isCustomer => userType == 'customer';
  String get displayName => name ?? email.split('@')[0];
  String get initials => displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
  bool get hasSecurityPin => securityPin != null && securityPin!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FirebaseUserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FirebaseUserModel(id: $id, email: $email, userType: $userType)';
  }
}