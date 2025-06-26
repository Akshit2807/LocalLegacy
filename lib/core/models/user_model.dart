import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced Firebase User Model with comprehensive validation and utilities
class FirebaseUserModel {
  final String id;
  final String email;
  final String? name;
  final String userType;
  final bool isEmailVerified;
  final String? phoneNumber;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? securityPin;
  final Map<String, dynamic>? metadata;
  final bool isActive;
  final DateTime? lastLoginAt;

  const FirebaseUserModel({
    required this.id,
    required this.email,
    this.name,
    required this.userType,
    required this.isEmailVerified,
    this.phoneNumber,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
    this.securityPin,
    this.metadata,
    this.isActive = true,
    this.lastLoginAt,
  });

  /// Create from Firestore document
  factory FirebaseUserModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception('User document does not exist');
    }

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('User document data is null');
    }

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
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] as Timestamp).toDate()
          : null,
      securityPin: data['security_pin'],
      metadata: data['metadata'] as Map<String, dynamic>?,
      isActive: data['is_active'] ?? true,
      lastLoginAt: data['last_login_at'] != null
          ? (data['last_login_at'] as Timestamp).toDate()
          : null,
    );
  }

  /// Create from Map with validation
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
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'])
          : null,
      securityPin: data['security_pin'],
      metadata: data['metadata'] as Map<String, dynamic>?,
      isActive: data['is_active'] ?? true,
      lastLoginAt: data['last_login_at'] != null
          ? DateTime.parse(data['last_login_at'])
          : null,
    );
  }

  /// Convert to Firestore document format
  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'email': email,
      'name': name,
      'user_type': userType,
      'email_verified': isEmailVerified,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'security_pin': securityPin,
      'metadata': metadata,
      'is_active': isActive,
    };

    // Handle timestamps properly
    if (createdAt != null) {
      data['created_at'] = Timestamp.fromDate(createdAt!);
    } else {
      data['created_at'] = FieldValue.serverTimestamp();
    }

    if (updatedAt != null) {
      data['updated_at'] = Timestamp.fromDate(updatedAt!);
    } else {
      data['updated_at'] = FieldValue.serverTimestamp();
    }

    if (lastLoginAt != null) {
      data['last_login_at'] = Timestamp.fromDate(lastLoginAt!);
    }

    return data;
  }

  /// Convert to Map for API usage
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
      'updated_at': updatedAt?.toIso8601String(),
      'security_pin': securityPin,
      'metadata': metadata,
      'is_active': isActive,
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  FirebaseUserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? userType,
    bool? isEmailVerified,
    String? phoneNumber,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? securityPin,
    Map<String, dynamic>? metadata,
    bool? isActive,
    DateTime? lastLoginAt,
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
      updatedAt: updatedAt ?? this.updatedAt,
      securityPin: securityPin ?? this.securityPin,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  /// Helper getters for user types
  bool get isShopkeeper => userType == 'shopkeeper';
  bool get isCustomer => userType == 'customer';

  /// Get display name with fallback
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (email.isNotEmpty) return email.split('@')[0];
    return 'User';
  }

  /// Get user initials for avatar
  String get initials {
    if (name != null && name!.isNotEmpty) {
      final parts = name!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name![0].toUpperCase();
    }
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'U';
  }

  /// Check if user has security pin
  bool get hasSecurityPin => securityPin != null && securityPin!.isNotEmpty;

  /// Check if user profile is complete
  bool get isProfileComplete {
    return name != null &&
        name!.isNotEmpty &&
        email.isNotEmpty &&
        isEmailVerified;
  }

  /// Get user status
  UserStatus get status {
    if (!isActive) return UserStatus.inactive;
    if (!isEmailVerified) return UserStatus.unverified;
    if (!isProfileComplete) return UserStatus.incomplete;
    return UserStatus.active;
  }

  /// Get account age in days
  int? get accountAgeDays {
    if (createdAt == null) return null;
    return DateTime.now().difference(createdAt!).inDays;
  }

  /// Check if user was active recently (within 30 days)
  bool get isRecentlyActive {
    if (lastLoginAt == null) return false;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return lastLoginAt!.isAfter(thirtyDaysAgo);
  }

  /// Validate user data
  List<String> validate() {
    final errors = <String>[];

    if (id.isEmpty) errors.add('User ID is required');
    if (email.isEmpty) errors.add('Email is required');
    if (!_isValidEmail(email)) errors.add('Email format is invalid');
    if (!['shopkeeper', 'customer'].contains(userType)) {
      errors.add('User type must be either shopkeeper or customer');
    }
    if (securityPin != null && securityPin!.length != 4) {
      errors.add('Security PIN must be 4 digits');
    }

    return errors;
  }

  /// Check if user data is valid
  bool get isValid => validate().isEmpty;

  /// Sanitize user data for safe storage
  FirebaseUserModel sanitize() {
    return copyWith(
      email: email.toLowerCase().trim(),
      name: name?.trim(),
      phoneNumber: phoneNumber?.replaceAll(RegExp(r'[^\d+]'), ''),
    );
  }

  /// Convert to public profile (without sensitive data)
  Map<String, dynamic> toPublicProfile() {
    return {
      'id': id,
      'name': displayName,
      'user_type': userType,
      'avatar_url': avatarUrl,
      'is_verified': isEmailVerified,
      'joined_at': createdAt?.toIso8601String(),
    };
  }

  /// Create update data for Firestore
  Map<String, dynamic> toUpdateData({
    String? name,
    String? phoneNumber,
    String? avatarUrl,
    String? securityPin,
    Map<String, dynamic>? metadata,
    bool? isActive,
  }) {
    final updates = <String, dynamic>{
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (name != null) updates['name'] = name;
    if (phoneNumber != null) updates['phone_number'] = phoneNumber;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (securityPin != null) updates['security_pin'] = securityPin;
    if (metadata != null) updates['metadata'] = metadata;
    if (isActive != null) updates['is_active'] = isActive;

    return updates;
  }

  /// Mark user as logged in
  Map<String, dynamic> toLoginUpdate() {
    return {
      'last_login_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  /// Private helper method to validate email
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);
  }

  /// Equality and hashCode
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FirebaseUserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FirebaseUserModel(id: $id, email: $email, userType: $userType, displayName: $displayName)';
  }

  /// JSON serialization support
  String toJson() {
    return '''
{
  "id": "$id",
  "email": "$email",
  "name": ${name != null ? '"$name"' : 'null'},
  "user_type": "$userType",
  "email_verified": $isEmailVerified,
  "phone_number": ${phoneNumber != null ? '"$phoneNumber"' : 'null'},
  "avatar_url": ${avatarUrl != null ? '"$avatarUrl"' : 'null'},
  "created_at": ${createdAt != null ? '"${createdAt!.toIso8601String()}"' : 'null'},
  "updated_at": ${updatedAt != null ? '"${updatedAt!.toIso8601String()}"' : 'null'},
  "is_active": $isActive,
  "last_login_at": ${lastLoginAt != null ? '"${lastLoginAt!.toIso8601String()}"' : 'null'}
}''';
  }
}

/// User status enumeration
enum UserStatus {
  active,
  inactive,
  unverified,
  incomplete,
}

/// Extension for UserStatus
extension UserStatusExtension on UserStatus {
  String get displayName {
    switch (this) {
      case UserStatus.active:
        return 'Active';
      case UserStatus.inactive:
        return 'Inactive';
      case UserStatus.unverified:
        return 'Unverified';
      case UserStatus.incomplete:
        return 'Incomplete Profile';
    }
  }

  bool get isActive => this == UserStatus.active;
  bool get needsVerification => this == UserStatus.unverified;
  bool get needsCompletion => this == UserStatus.incomplete;
}

/// User type enumeration
enum UserType {
  shopkeeper,
  customer,
}

/// Extension for UserType
extension UserTypeExtension on UserType {
  String get value {
    switch (this) {
      case UserType.shopkeeper:
        return 'shopkeeper';
      case UserType.customer:
        return 'customer';
    }
  }

  String get displayName {
    switch (this) {
      case UserType.shopkeeper:
        return 'Shopkeeper';
      case UserType.customer:
        return 'Customer';
    }
  }

  static UserType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'shopkeeper':
        return UserType.shopkeeper;
      case 'customer':
        return UserType.customer;
      default:
        throw ArgumentError('Invalid user type: $value');
    }
  }
}