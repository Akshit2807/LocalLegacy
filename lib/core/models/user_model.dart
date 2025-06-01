class UserModel {
  final String id;
  final String email;
  final String? name;
  final String userType; // 'shopkeeper' or 'customer'
  final bool isEmailVerified;
  final String? phoneNumber;
  final String? avatarUrl;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    required this.userType,
    required this.isEmailVerified,
    this.phoneNumber,
    this.avatarUrl,
    this.createdAt,
  });

  // From JSON (Supabase response)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? json['user_metadata']?['name'],
      userType: json['user_type'] ?? json['user_metadata']?['user_type'] ?? 'customer',
      isEmailVerified: json['email_confirmed_at'] != null,
      phoneNumber: json['phone'],
      avatarUrl: json['avatar_url'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  // To JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'user_type': userType,
      'phone': phoneNumber,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // Copy with (for state updates)
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? userType,
    bool? isEmailVerified,
    String? phoneNumber,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      userType: userType ?? this.userType,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper getters
  bool get isShopkeeper => userType == 'shopkeeper';
  bool get isCustomer => userType == 'customer';
  String get displayName => name ?? email.split('@')[0];
  String get initials => displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
}