enum RequestStatus { pending, approved, rejected }
enum TransactionType { credit, debit }

class CustomerShopRelation {
  final String id;
  final String customerId;
  final String shopId;
  final String shopkeeperId;
  final double totalCreditLimit;
  final double currentBalance;
  final double usedAmount;
  final DateTime dueDate;
  final DateTime joinedDate;
  final RequestStatus status;
  final bool isActive;

  CustomerShopRelation({
    required this.id,
    required this.customerId,
    required this.shopId,
    required this.shopkeeperId,
    required this.totalCreditLimit,
    required this.currentBalance,
    required this.usedAmount,
    required this.dueDate,
    required this.joinedDate,
    required this.status,
    required this.isActive,
  });

  factory CustomerShopRelation.fromJson(Map<String, dynamic> json) {
    return CustomerShopRelation(
      id: json['id'] ?? '',
      customerId: json['customer_id'] ?? '',
      shopId: json['shop_id'] ?? '',
      shopkeeperId: json['shopkeeper_id'] ?? '',
      totalCreditLimit: (json['total_credit_limit'] ?? 0.0).toDouble(),
      currentBalance: (json['current_balance'] ?? 0.0).toDouble(),
      usedAmount: (json['used_amount'] ?? 0.0).toDouble(),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : DateTime.now().add(const Duration(days: 30)),
      joinedDate: json['joined_date'] != null
          ? DateTime.parse(json['joined_date'])
          : DateTime.now(),
      status: RequestStatus.values.firstWhere(
            (e) => e.toString() == 'RequestStatus.${json['status'] ?? 'pending'}',
        orElse: () => RequestStatus.pending,
      ),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
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
      'status': status.toString().split('.').last,
      'is_active': isActive,
    };
  }

  CustomerShopRelation copyWith({
    String? id,
    String? customerId,
    String? shopId,
    String? shopkeeperId,
    double? totalCreditLimit,
    double? currentBalance,
    double? usedAmount,
    DateTime? dueDate,
    DateTime? joinedDate,
    RequestStatus? status,
    bool? isActive,
  }) {
    return CustomerShopRelation(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      shopId: shopId ?? this.shopId,
      shopkeeperId: shopkeeperId ?? this.shopkeeperId,
      totalCreditLimit: totalCreditLimit ?? this.totalCreditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      usedAmount: usedAmount ?? this.usedAmount,
      dueDate: dueDate ?? this.dueDate,
      joinedDate: joinedDate ?? this.joinedDate,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
    );
  }

  double get availableCredit => totalCreditLimit - usedAmount;
  bool get isOverdue => DateTime.now().isAfter(dueDate);
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
}

class TransactionModel {
  final String id;
  final String customerId;
  final String shopId;
  final String shopkeeperId;
  final double amount;
  final TransactionType type;
  final String description;
  final DateTime timestamp;
  final String? securityPin;

  TransactionModel({
    required this.id,
    required this.customerId,
    required this.shopId,
    required this.shopkeeperId,
    required this.amount,
    required this.type,
    required this.description,
    required this.timestamp,
    this.securityPin,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      customerId: json['customer_id'] ?? '',
      shopId: json['shop_id'] ?? '',
      shopkeeperId: json['shopkeeper_id'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      type: TransactionType.values.firstWhere(
            (e) => e.toString() == 'TransactionType.${json['type'] ?? 'debit'}',
        orElse: () => TransactionType.debit,
      ),
      description: json['description'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      securityPin: json['security_pin'],
    );
  }

  Map<String, dynamic> toJson() {
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
    };
  }

  TransactionModel copyWith({
    String? id,
    String? customerId,
    String? shopId,
    String? shopkeeperId,
    double? amount,
    TransactionType? type,
    String? description,
    DateTime? timestamp,
    String? securityPin,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      shopId: shopId ?? this.shopId,
      shopkeeperId: shopkeeperId ?? this.shopkeeperId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      securityPin: securityPin ?? this.securityPin,
    );
  }
}