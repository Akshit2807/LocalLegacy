import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/firebase_config.dart';
import '../core/models/firebase_shop_model.dart';
import '../core/models/firebase_customer_shop_relation_model.dart';
import '../core/models/user_model.dart';
import '../core/services/qr_service.dart';
import '../core/utils/qr_utils.dart';

class ShopViewModel extends ChangeNotifier {
  FirebaseShopModel? _currentShop;
  List<FirebaseCustomerShopRelation> _customers = [];
  List<FirebaseTransactionModel> _transactions = [];
  List<CustomerRequestWithDetails> _customerRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  FirebaseShopModel? get currentShop => _currentShop;
  List<FirebaseCustomerShopRelation> get customers => _customers;
  List<FirebaseTransactionModel> get transactions => _transactions;
  List<CustomerRequestWithDetails> get customerRequests => _customerRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Analytics getters
  double get totalMoneyAllocated => _customers
      .where((c) => c.status == RequestStatus.approved)
      .fold(0.0, (sum, c) => sum + c.totalCreditLimit);

  double get totalMoneyUsed => _customers
      .where((c) => c.status == RequestStatus.approved)
      .fold(0.0, (sum, c) => sum + c.usedAmount);

  double get totalMoneyReturned => _transactions
      .where((t) => t.type == TransactionType.credit)
      .fold(0.0, (sum, t) => sum + t.amount);

  int get totalCustomers => _customers
      .where((c) => c.status == RequestStatus.approved)
      .length;

  int get pendingRequests => _customers
      .where((c) => c.status == RequestStatus.pending)
      .length;

  List<FirebaseCustomerShopRelation> get overdueCustomers => _customers
      .where((c) => c.status == RequestStatus.approved && c.isOverdue)
      .toList();

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Initialize shop for shopkeeper
  Future<void> initializeShop(String shopkeeperId) async {
    _setLoading(true);
    _setError(null);

    try {
      // Get existing shop
      final shopQuery = await FirebaseConfig.shopsCollection
          .where('shopkeeper_id', isEqualTo: shopkeeperId)
          .limit(1)
          .get();

      if (shopQuery.docs.isNotEmpty) {
        _currentShop = FirebaseShopModel.fromFirestore(shopQuery.docs.first);
      } else {
        // Create new shop with QR code
        await _createNewShop(shopkeeperId);
      }

      // Load customers, transactions and requests
      await _loadCustomers();
      await _loadTransactions();
      await _loadCustomerRequests();

      // Setup real-time listeners
      _setupRealtimeListeners();

    } catch (e) {
      _setError('Failed to initialize shop: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Create new shop with QR code
  Future<void> _createNewShop(String shopkeeperId) async {
    final shopDocRef = FirebaseConfig.shopsCollection.doc();
    final shopId = shopDocRef.id;

    // Generate QR data using the service
    final qrData = QRCodeService.generateShopQRData(
      shopId: shopId,
      shopName: 'My Shop',
      shopkeeperId: shopkeeperId,
    );

    // Generate base64 QR image
    final qrBase64 = await QRUtils.generateQRAsBase64(qrData);

    final newShop = FirebaseShopModel(
      id: shopId,
      shopkeeperId: shopkeeperId,
      shopName: 'My Shop',
      address: '',
      qrCodeData: qrData,
      qrCodeBase64: qrBase64,
      createdAt: DateTime.now(),
      isActive: true,
    );

    // Save shop to Firestore
    await shopDocRef.set(newShop.toFirestore());
    _currentShop = newShop;
  }

  // Load customers for the shop
  Future<void> _loadCustomers() async {
    if (_currentShop == null) return;

    try {
      final snapshot = await FirebaseConfig.customerShopRelationsCollection
          .where('shop_id', isEqualTo: _currentShop!.id)
          .orderBy('joined_date', descending: true)
          .get();

      _customers = snapshot.docs
          .map((doc) => FirebaseCustomerShopRelation.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load customers: $e');
    }
  }

  // Load transactions for the shop
  Future<void> _loadTransactions() async {
    if (_currentShop == null) return;

    try {
      final snapshot = await FirebaseConfig.transactionsCollection
          .where('shop_id', isEqualTo: _currentShop!.id)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      _transactions = snapshot.docs
          .map((doc) => FirebaseTransactionModel.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load transactions: $e');
    }
  }

  // Load customer requests with details
  Future<void> _loadCustomerRequests() async {
    if (_currentShop == null) return;

    try {
      final requestsSnapshot = await FirebaseConfig.firestore
          .collection('customer_requests_metadata')
          .where('shop_id', isEqualTo: _currentShop!.id)
          .where('status', isEqualTo: 'pending')
          .orderBy('request_date', descending: true)
          .get();

      _customerRequests = [];

      for (final doc in requestsSnapshot.docs) {
        final data = doc.data();
        final customerRequest = CustomerRequestWithDetails(
          relationId: data['relation_id'],
          customerId: data['customer_id'],
          customerName: data['customer_name'] ?? 'Unknown Customer',
          customerEmail: data['customer_email'] ?? '',
          customerPhone: data['customer_phone'],
          shopId: data['shop_id'],
          shopName: data['shop_name'],
          shopkeeperId: data['shopkeeper_id'],
          requestDate: (data['request_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: data['status'] ?? 'pending',
        );
        _customerRequests.add(customerRequest);
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load customer requests: $e');
    }
  }

  // Accept customer request with enhanced tracking
  Future<bool> acceptCustomerRequest(
      String relationId,
      double creditLimit,
      DateTime dueDate, {
        CustomerRequestWithDetails? requestDetails,
      }) async {
    _setLoading(true);
    _setError(null);

    try {
      final batch = FirebaseConfig.batch();

      // Update the relation
      batch.update(
        FirebaseConfig.customerShopRelationsCollection.doc(relationId),
        {
          'status': 'approved',
          'total_credit_limit': creditLimit,
          'current_balance': creditLimit,
          'due_date': Timestamp.fromDate(dueDate),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Update request metadata
      final metadataQuery = await FirebaseConfig.firestore
          .collection('customer_requests_metadata')
          .where('relation_id', isEqualTo: relationId)
          .limit(1)
          .get();

      if (metadataQuery.docs.isNotEmpty) {
        batch.update(metadataQuery.docs.first.reference, {
          'status': 'approved',
          'approved_date': FieldValue.serverTimestamp(),
          'credit_limit_set': creditLimit,
          'due_date_set': Timestamp.fromDate(dueDate),
        });
      }

      // Create welcome transaction
      if (requestDetails != null) {
        final transactionDoc = FirebaseConfig.transactionsCollection.doc();
        final welcomeTransaction = FirebaseTransactionModel(
          id: transactionDoc.id,
          customerId: requestDetails.customerId,
          shopId: _currentShop!.id,
          shopkeeperId: _currentShop!.shopkeeperId,
          amount: creditLimit,
          type: TransactionType.credit,
          description: 'Welcome to ${_currentShop!.shopName} - Credit limit approved',
          timestamp: DateTime.now(),
          metadata: {
            'transaction_type': 'credit_approval',
            'customer_name': requestDetails.customerName,
            'initial_credit_limit': creditLimit,
            'approved_by': 'shopkeeper',
          },
        );

        batch.set(transactionDoc, welcomeTransaction.toFirestore());
      }

      // Commit all changes
      await batch.commit();

      // Refresh data
      await _loadCustomers();
      await _loadTransactions();
      await _loadCustomerRequests();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to accept request: $e');
      _setLoading(false);
      return false;
    }
  }

  // Reject customer request
  Future<bool> rejectCustomerRequest(String relationId) async {
    _setLoading(true);
    _setError(null);

    try {
      final batch = FirebaseConfig.batch();

      // Update the relation
      batch.update(
        FirebaseConfig.customerShopRelationsCollection.doc(relationId),
        {
          'status': 'rejected',
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Update request metadata
      final metadataQuery = await FirebaseConfig.firestore
          .collection('customer_requests_metadata')
          .where('relation_id', isEqualTo: relationId)
          .limit(1)
          .get();

      if (metadataQuery.docs.isNotEmpty) {
        batch.update(metadataQuery.docs.first.reference, {
          'status': 'rejected',
          'rejected_date': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await _loadCustomers();
      await _loadCustomerRequests();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to reject request: $e');
      _setLoading(false);
      return false;
    }
  }

  // Update customer credit limit (Lend More functionality)
  Future<bool> updateCustomerCredit(String relationId, double newLimit, {String? reason}) async {
    _setLoading(true);
    _setError(null);

    try {
      final relation = _customers.firstWhere((c) => c.id == relationId);
      final difference = newLimit - relation.totalCreditLimit;

      // Start a batch operation
      final batch = FirebaseConfig.batch();

      // Update relation
      batch.update(
        FirebaseConfig.customerShopRelationsCollection.doc(relationId),
        {
          'total_credit_limit': newLimit,
          'current_balance': relation.currentBalance + difference,
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Create transaction record
      final transactionDoc = FirebaseConfig.transactionsCollection.doc();
      final transaction = FirebaseTransactionModel(
        id: transactionDoc.id,
        customerId: relation.customerId,
        shopId: relation.shopId,
        shopkeeperId: relation.shopkeeperId,
        amount: difference.abs(),
        type: difference > 0 ? TransactionType.credit : TransactionType.debit,
        description: difference > 0
            ? 'Lend More - Credit limit increased by shopkeeper'
            : 'Credit limit reduced by shopkeeper',
        timestamp: DateTime.now(),
        metadata: {
          'previous_limit': relation.totalCreditLimit,
          'new_limit': newLimit,
          'adjustment_amount': difference,
          'adjustment_type': difference > 0 ? 'lend_more' : 'credit_reduction',
          'reason': reason ?? 'Manual adjustment by shopkeeper',
          'initiated_by': 'shopkeeper',
        },
      );

      batch.set(transactionDoc, transaction.toFirestore());

      // Commit batch
      await batch.commit();

      await _loadCustomers();
      await _loadTransactions();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update credit: $e');
      _setLoading(false);
      return false;
    }
  }

  // Process payment from customer (Paid Up functionality)
  Future<bool> processPaidUpPayment(String customerId, double amount, String description) async {
    _setLoading(true);
    _setError(null);

    try {
      final relation = _customers.firstWhere((c) => c.customerId == customerId);

      // Start a batch operation
      final batch = FirebaseConfig.batch();

      // Create transaction
      final transactionDoc = FirebaseConfig.transactionsCollection.doc();
      final transaction = FirebaseTransactionModel(
        id: transactionDoc.id,
        customerId: customerId,
        shopId: _currentShop!.id,
        shopkeeperId: _currentShop!.shopkeeperId,
        amount: amount,
        type: TransactionType.credit,
        description: 'Paid Up - $description',
        timestamp: DateTime.now(),
        metadata: {
          'payment_type': 'paid_up',
          'processed_by': 'shopkeeper',
          'previous_balance': relation.currentBalance,
          'previous_used_amount': relation.usedAmount,
          'new_balance': relation.currentBalance + amount,
          'new_used_amount': relation.usedAmount - amount,
        },
      );

      batch.set(transactionDoc, transaction.toFirestore());

      // Update relation
      batch.update(
        FirebaseConfig.customerShopRelationsCollection.doc(relation.id),
        {
          'current_balance': relation.currentBalance + amount,
          'used_amount': relation.usedAmount - amount,
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Commit batch
      await batch.commit();

      await _loadCustomers();
      await _loadTransactions();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to process payment: $e');
      _setLoading(false);
      return false;
    }
  }

  // Update shop details
  Future<bool> updateShopDetails(String shopName, String address) async {
    if (_currentShop == null) return false;

    _setLoading(true);
    _setError(null);

    try {
      // Update shop in Firestore
      await FirebaseConfig.shopsCollection
          .doc(_currentShop!.id)
          .update({
        'shop_name': shopName,
        'address': address,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Regenerate QR code with new shop name
      final newQrData = QRCodeService.generateShopQRData(
        shopId: _currentShop!.id,
        shopName: shopName,
        shopkeeperId: _currentShop!.shopkeeperId,
        address: address,
      );

      final newQrBase64 = await QRUtils.generateQRAsBase64(newQrData);

      // Update QR code data
      await FirebaseConfig.shopsCollection
          .doc(_currentShop!.id)
          .update({
        'qr_code_data': newQrData,
        'qr_code_base64': newQrBase64,
      });

      _currentShop = _currentShop!.copyWith(
        shopName: shopName,
        address: address,
        qrCodeData: newQrData,
        qrCodeBase64: newQrBase64,
        updatedAt: DateTime.now(),
      );

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update shop: $e');
      _setLoading(false);
      return false;
    }
  }

  // Setup real-time listeners
  void _setupRealtimeListeners() {
    if (_currentShop == null) return;

    // Listen to customer relation changes
    FirebaseConfig.customerShopRelationsCollection
        .where('shop_id', isEqualTo: _currentShop!.id)
        .snapshots()
        .listen(
          (snapshot) {
        _customers = snapshot.docs
            .map((doc) => FirebaseCustomerShopRelation.fromFirestore(doc))
            .toList();
        notifyListeners();
      },
      onError: (error) {
        _setError('Error listening to customer changes: $error');
      },
    );

    // Listen to transaction changes
    FirebaseConfig.transactionsCollection
        .where('shop_id', isEqualTo: _currentShop!.id)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
        _transactions = snapshot.docs
            .map((doc) => FirebaseTransactionModel.fromFirestore(doc))
            .toList();
        notifyListeners();
      },
      onError: (error) {
        _setError('Error listening to transaction changes: $error');
      },
    );

    // Listen to customer request changes
    FirebaseConfig.firestore
        .collection('customer_requests_metadata')
        .where('shop_id', isEqualTo: _currentShop!.id)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          (snapshot) async {
        _customerRequests = [];

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final customerRequest = CustomerRequestWithDetails(
            relationId: data['relation_id'],
            customerId: data['customer_id'],
            customerName: data['customer_name'] ?? 'Unknown Customer',
            customerEmail: data['customer_email'] ?? '',
            customerPhone: data['customer_phone'],
            shopId: data['shop_id'],
            shopName: data['shop_name'],
            shopkeeperId: data['shopkeeper_id'],
            requestDate: (data['request_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
            status: data['status'] ?? 'pending',
          );
          _customerRequests.add(customerRequest);
        }
        notifyListeners();
      },
      onError: (error) {
        _setError('Error listening to request changes: $error');
      },
    );
  }

  // Get customer by ID
  FirebaseCustomerShopRelation? getCustomer(String customerId) {
    return _customers
        .where((c) => c.customerId == customerId)
        .firstOrNull;
  }

  // Get customer transactions
  List<FirebaseTransactionModel> getCustomerTransactions(String customerId) {
    return _transactions
        .where((t) => t.customerId == customerId)
        .toList();
  }

  // Get today's transactions
  List<FirebaseTransactionModel> getTodayTransactions() {
    final today = DateTime.now();
    return _transactions.where((t) {
      return t.timestamp.year == today.year &&
          t.timestamp.month == today.month &&
          t.timestamp.day == today.day;
    }).toList();
  }

  // Get monthly revenue
  double getMonthlyRevenue([DateTime? month]) {
    final targetMonth = month ?? DateTime.now();
    return _transactions
        .where((t) =>
    t.type == TransactionType.debit &&
        t.timestamp.year == targetMonth.year &&
        t.timestamp.month == targetMonth.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get daily revenue
  double getDailyRevenue([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    return _transactions
        .where((t) =>
    t.type == TransactionType.debit &&
        t.timestamp.year == targetDate.year &&
        t.timestamp.month == targetDate.month &&
        t.timestamp.day == targetDate.day)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get pending customers with details
  List<CustomerRequestWithDetails> get pendingCustomerRequests =>
      _customerRequests.where((r) => r.status == 'pending').toList();

  // Get approved customers
  List<FirebaseCustomerShopRelation> get approvedCustomers => _customers
      .where((c) => c.status == RequestStatus.approved)
      .toList();

  // Get rejected customers
  List<FirebaseCustomerShopRelation> get rejectedCustomers => _customers
      .where((c) => c.status == RequestStatus.rejected)
      .toList();

  // Analytics methods
  double getCreditUtilizationPercentage() {
    if (totalMoneyAllocated == 0) return 0;
    return (totalMoneyUsed / totalMoneyAllocated) * 100;
  }

  double getAverageTransactionAmount() {
    if (_transactions.isEmpty) return 0;
    final totalAmount = _transactions.fold(0.0, (sum, t) => sum + t.amount);
    return totalAmount / _transactions.length;
  }

  // Get top customers by spending
  List<FirebaseCustomerShopRelation> getTopCustomers({int limit = 5}) {
    final customerSpending = <String, double>{};

    for (final transaction in _transactions) {
      if (transaction.type == TransactionType.debit) {
        customerSpending[transaction.customerId] =
            (customerSpending[transaction.customerId] ?? 0) + transaction.amount;
      }
    }

    final sortedCustomers = _customers.where((c) => c.isApproved).toList();
    sortedCustomers.sort((a, b) {
      final aSpending = customerSpending[a.customerId] ?? 0;
      final bSpending = customerSpending[b.customerId] ?? 0;
      return bSpending.compareTo(aSpending);
    });

    return sortedCustomers.take(limit).toList();
  }

  // Search customers
  List<FirebaseCustomerShopRelation> searchCustomers(String query) {
    if (query.isEmpty) return _customers;

    return _customers.where((c) {
      // Search by customer ID or find by request details
      return c.customerId.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Get customer request details by relation ID
  CustomerRequestWithDetails? getCustomerRequestDetails(String relationId) {
    return _customerRequests
        .where((r) => r.relationId == relationId)
        .firstOrNull;
  }

  // Export shop data
  Map<String, dynamic> exportShopData() {
    return {
      'shop': _currentShop?.toMap(),
      'customers': _customers.map((c) => c.toMap()).toList(),
      'transactions': _transactions.map((t) => t.toMap()).toList(),
      'customer_requests': _customerRequests.map((r) => r.toMap()).toList(),
      'analytics': {
        'total_money_allocated': totalMoneyAllocated,
        'total_money_used': totalMoneyUsed,
        'total_money_returned': totalMoneyReturned,
        'total_customers': totalCustomers,
        'pending_requests': pendingRequests,
        'overdue_customers': overdueCustomers.length,
        'credit_utilization_percentage': getCreditUtilizationPercentage(),
        'monthly_revenue': getMonthlyRevenue(),
        'daily_revenue': getDailyRevenue(),
        'average_transaction_amount': getAverageTransactionAmount(),
      },
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  // Refresh data
  Future<void> refresh() async {
    await _loadCustomers();
    await _loadTransactions();
    await _loadCustomerRequests();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Customer request with detailed information
class CustomerRequestWithDetails {
  final String relationId;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;
  final String shopId;
  final String shopName;
  final String shopkeeperId;
  final DateTime requestDate;
  final String status;

  CustomerRequestWithDetails({
    required this.relationId,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    this.customerPhone,
    required this.shopId,
    required this.shopName,
    required this.shopkeeperId,
    required this.requestDate,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'relation_id': relationId,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'customer_phone': customerPhone,
      'shop_id': shopId,
      'shop_name': shopName,
      'shopkeeper_id': shopkeeperId,
      'request_date': requestDate.toIso8601String(),
      'status': status,
    };
  }

  String get displayName => customerName.isNotEmpty ? customerName : 'Unknown Customer';
  String get displayEmail => customerEmail.isNotEmpty ? customerEmail : 'No email';
  String get displayPhone => customerPhone?.isNotEmpty == true ? customerPhone! : 'No phone';

  String get formattedRequestDate {
    final now = DateTime.now();
    final difference = now.difference(requestDate);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${requestDate.day}/${requestDate.month}/${requestDate.year}';
    }
  }
}