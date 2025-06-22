import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus { pending, approved, rejected }
enum TransactionType { credit, debit }

class FirebaseCustomerShopRelation {
  final String id;
  final String customerId;
  final String shopId;
  final String shopkeeperId;
  final double totalCreditLimit;
  final double currentBalance;
  final double usedAmount;
  final DateTime dueDate;
  final DateTime joinedDate;
  final DateTime? updatedAt;
  final RequestStatus status;
  final bool isActive;

  FirebaseCustomerShopRelation({
    required this.id,
    required this.customerId,
    required this.shopId,
    required this.shopkeeperId,
    required this.totalCreditLimit,
    required this.currentBalance,
    required this.usedAmount,
    required this.dueDate,
    required this.joinedDate,
    this.updatedAt,
    required this.status,
    required this.isActive,
  });

  // From Firestore document
  factory FirebaseCustomerShopRelation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirebaseCustomerShopRelation(
      id: doc.id,
      customerId: data['customer_id'] ?? '',
      shopId: data['shop_id'] ?? '',
      shopkeeperId: data['shopkeeper_id'] ?? '',
      totalCreditLimit: (data['total_credit_limit'] ?? 0.0).toDouble(),
      currentBalance: (data['current_balance'] ?? 0.0).toDouble(),
      usedAmount: (data['used_amount'] ?? 0.0).toDouble(),
      dueDate: data['due_date'] != null
          ? (data['due_date'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 30)),
      joinedDate: data['joined_date'] != null
          ? (data['joined_date'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] as Timestamp).toDate()
          : null,
      status: RequestStatus.values.firstWhere(
            (e) => e.toString() == 'RequestStatus.${data['status'] ?? 'pending'}',
        orElse: () => RequestStatus.pending,
      ),
      isActive: data['is_active'] ?? true,
    );
  }

  // From Map
  factory FirebaseCustomerShopRelation.fromMap(Map<String, dynamic> data, String id) {
    return FirebaseCustomerShopRelation(
      id: id,
      customerId: data['customer_id'] ?? '',
      shopId: data['shop_id'] ?? '',
      shopkeeperId: data['shopkeeper_id'] ?? '',
      totalCreditLimit: (data['total_credit_limit'] ?? 0.0).toDouble(),
      currentBalance: (data['current_balance'] ?? 0.0).toDouble(),
      usedAmount: (data['used_amount'] ?? 0.0).toDouble(),
      dueDate: data['due_date'] != null
          ? DateTime.parse(data['due_date'])
          : DateTime.now().add(const Duration(days: 30)),
      joinedDate: data['joined_date'] != null
          ? DateTime.parse(data['joined_date'])
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'])
          : null,
      status: RequestStatus.values.firstWhere(
            (e) => e.toString() == 'RequestStatus.${data['status'] ?? 'pending'}',
        orElse: () => RequestStatus.pending,
      ),
      isActive: data['is_active'] ?? true,
    );
  }

  // To Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'customer_id': customerId,
      'shop_id': shopId,
      'shopkeeper_id': shopkeeperId,
      'total_credit_limit': totalCreditLimit,
      'current_balance': currentBalance,
      'used_amount': usedAmount,
      'due_date': Timestamp.fromDate(dueDate),
      'joined_date': Timestamp.fromDate(joinedDate),
      'updated_at': FieldValue.serverTimestamp(),
      'status': status.toString().split('.').last,
      'is_active': isActive,
    };
  }

  // To Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'shop_id': shopId,
      'shopkeeper_id': shopkeeperId,
      'total_credit_limit': totalCreditLimit,
      'current_balance': currentBalance,
      'used_amount': usedAmount,
      'due_date': dueDate.toIso8601String(),
      'joined_date': joinedDate.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'status': status.toString().split('.').last,
      'is_active': isActive,
    };
  }

  // Copy with
  FirebaseCustomerShopRelation copyWith({
    String? id,
    String? customerId,
    String? shopId,
    String? shopkeeperId,
    double? totalCreditLimit,
    double? currentBalance,
    double? usedAmount,
    DateTime? dueDate,
    DateTime? joinedDate,
    DateTime? updatedAt,
    RequestStatus? status,
    bool? isActive,
  }) {
    return FirebaseCustomerShopRelation(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      shopId: shopId ?? this.shopId,
      shopkeeperId: shopkeeperId ?? this.shopkeeperId,
      totalCreditLimit: totalCreditLimit ?? this.totalCreditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      usedAmount: usedAmount ?? this.usedAmount,
      dueDate: dueDate ?? this.dueDate,
      joinedDate: joinedDate ?? this.joinedDate,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
    );
  }

  // Helper getters
  double get availableCredit => totalCreditLimit - usedAmount;
  bool get isOverdue => DateTime.now().isAfter(dueDate);
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
  bool get isPending => status == RequestStatus.pending;
  bool get isApproved => status == RequestStatus.approved;
  bool get isRejected => status == RequestStatus.rejected;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FirebaseCustomerShopRelation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FirebaseCustomerShopRelation(id: $id, customerId: $customerId, shopId: $shopId, status: $status)';
  }
}

class FirebaseTransactionModel {
  final String id;
  final String customerId;
  final String shopId;
  final String shopkeeperId;
  final double amount;
  final TransactionType type;
  final String description;
  final DateTime timestamp;
  final String? securityPin;
  final Map<String, dynamic>? metadata;

  FirebaseTransactionModel({
    required this.id,
    required this.customerId,
    required this.shopId,
    required this.shopkeeperId,
    required this.amount,
    required this.type,
    required this.description,
    required this.timestamp,
    this.securityPin,
    this.metadata,
  });

  // From Firestore document
  factory FirebaseTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirebaseTransactionModel(
      id: doc.id,
      customerId: data['customer_id'] ?? '',
      shopId: data['shop_id'] ?? '',
      shopkeeperId: data['shopkeeper_id'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      type: TransactionType.values.firstWhere(
            (e) => e.toString() == 'TransactionType.${data['type'] ?? 'debit'}',
        orElse: () => TransactionType.debit,
      ),
      description: data['description'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      securityPin: data['security_pin'],
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  // From Map
  factory FirebaseTransactionModel.fromMap(Map<String, dynamic> data, String id) {
    return FirebaseTransactionModel(
      id: id,
      customerId: data['customer_id'] ?? '',
      shopId: data['shop_id'] ?? '',
      shopkeeperId: data['shopkeeper_id'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      type: TransactionType.values.firstWhere(
            (e) => e.toString() == 'TransactionType.${data['type'] ?? 'debit'}',
        orElse: () => TransactionType.debit,
      ),
      description: data['description'] ?? '',
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'])
          : DateTime.now(),
      securityPin: data['security_pin'],
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  // To Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'customer_id': customerId,
      'shop_id': shopId,
      'shopkeeper_id': shopkeeperId,
      'amount': amount,
      'type': type.toString().split('.').last,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'security_pin': securityPin,
      'metadata': metadata,
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  // To Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'shop_id': shopId,
      'shopkeeper_id': shopkeeperId,
      'amount': amount,
      'type': type.toString().split('.').last,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'security_pin': securityPin,
      'metadata': metadata,
    };
  }

  // Copy with
  FirebaseTransactionModel copyWith({
    String? id,
    String? customerId,
    String? shopId,
    String? shopkeeperId,
    double? amount,
    TransactionType? type,
    String? description,
    DateTime? timestamp,
    String? securityPin,
    Map<String, dynamic>? metadata,
  }) {
    return FirebaseTransactionModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      shopId: shopId ?? this.shopId,
      shopkeeperId: shopkeeperId ?? this.shopkeeperId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      securityPin: securityPin ?? this.securityPin,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper getters
  bool get isCredit => type == TransactionType.credit;
  bool get isDebit => type == TransactionType.debit;
  String get formattedAmount => '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(0)}';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FirebaseTransactionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FirebaseTransactionModel(id: $id, amount: $amount, type: $type)';
  }
}