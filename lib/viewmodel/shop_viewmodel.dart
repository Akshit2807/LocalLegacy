import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/firebase_config.dart';
import '../core/models/firebase_shop_model.dart';
import '../core/models/firebase_customer_shop_relation_model.dart';
import '../core/utils/qr_utils.dart';

class ShopViewModel extends ChangeNotifier {
  FirebaseShopModel? _currentShop;
  List<FirebaseCustomerShopRelation> _customers = [];
  List<FirebaseTransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  FirebaseShopModel? get currentShop => _currentShop;
  List<FirebaseCustomerShopRelation> get customers => _customers;
  List<FirebaseTransactionModel> get transactions => _transactions;
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

      // Load customers and transactions
      await _loadCustomers();
      await _loadTransactions();

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

    // Generate QR data and base64 image
    final qrData = QRUtils.generateShopQRData(shopId, shopkeeperId);
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

    // Save shop to Firestore only (no Firebase Storage)
    await shopDocRef.set(newShop.toFirestore());
    _currentShop = newShop;
  }

  // Load customers for the shop
  Future<void> _loadCustomers() async {
    if (_currentShop == null) return;

    try {
      final snapshot = await FirebaseConfig.FirebaseCustomerShopRelationsCollection
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
          .limit(50)
          .get();

      _transactions = snapshot.docs
          .map((doc) => FirebaseTransactionModel.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load transactions: $e');
    }
  }

  // Accept customer request
  Future<bool> acceptCustomerRequest(String relationId, double creditLimit, DateTime dueDate) async {
    _setLoading(true);
    _setError(null);

    try {
      await FirebaseConfig.FirebaseCustomerShopRelationsCollection
          .doc(relationId)
          .update({
        'status': 'approved',
        'total_credit_limit': creditLimit,
        'current_balance': creditLimit,
        'due_date': Timestamp.fromDate(dueDate),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _loadCustomers();
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
      await FirebaseConfig.FirebaseCustomerShopRelationsCollection
          .doc(relationId)
          .update({
        'status': 'rejected',
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _loadCustomers();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to reject request: $e');
      _setLoading(false);
      return false;
    }
  }

  // Update customer credit limit
  Future<bool> updateCustomerCredit(String relationId, double newLimit) async {
    _setLoading(true);
    _setError(null);

    try {
      final relation = _customers.firstWhere((c) => c.id == relationId);
      final difference = newLimit - relation.totalCreditLimit;

      // Start a batch operation
      final batch = FirebaseConfig.firestore.batch();

      // Update relation
      batch.update(
        FirebaseConfig.FirebaseCustomerShopRelationsCollection.doc(relationId),
        {
          'total_credit_limit': newLimit,
          'current_balance': relation.currentBalance + difference,
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Create transaction record if there's a difference
      if (difference != 0) {
        final transactionDoc = FirebaseConfig.transactionsCollection.doc();
        final transaction = FirebaseTransactionModel(
          id: transactionDoc.id,
          customerId: relation.customerId,
          shopId: relation.shopId,
          shopkeeperId: relation.shopkeeperId,
          amount: difference.abs(),
          type: difference > 0 ? TransactionType.credit : TransactionType.debit,
          description: 'Credit limit ${difference > 0 ? 'increased' : 'decreased'} by shopkeeper',
          timestamp: DateTime.now(),
          metadata: {
            'previous_limit': relation.totalCreditLimit,
            'new_limit': newLimit,
            'adjustment_type': 'credit_limit_update',
          },
        );

        batch.set(transactionDoc, transaction.toFirestore());
      }

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

  // Process payment from customer
  Future<bool> processPayment(String customerId, double amount, String description) async {
    try {
      final relation = _customers.firstWhere((c) => c.customerId == customerId);

      // Start a batch operation
      final batch = FirebaseConfig.firestore.batch();

      // Create transaction
      final transactionDoc = FirebaseConfig.transactionsCollection.doc();
      final transaction = FirebaseTransactionModel(
        id: transactionDoc.id,
        customerId: customerId,
        shopId: _currentShop!.id,
        shopkeeperId: _currentShop!.shopkeeperId,
        amount: amount,
        type: TransactionType.credit,
        description: description,
        timestamp: DateTime.now(),
        metadata: {
          'payment_type': 'manual_payment',
          'processed_by': 'shopkeeper',
        },
      );

      batch.set(transactionDoc, transaction.toFirestore());

      // Update relation
      batch.update(
        FirebaseConfig.FirebaseCustomerShopRelationsCollection.doc(relation.id),
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
      return true;
    } catch (e) {
      _setError('Failed to process payment: $e');
      return false;
    }
  }

  // Update shop details
  Future<bool> updateShopDetails(String shopName, String address) async {
    if (_currentShop == null) return false;

    _setLoading(true);
    _setError(null);

    try {
      await FirebaseConfig.shopsCollection
          .doc(_currentShop!.id)
          .update({
        'shop_name': shopName,
        'address': address,
        'updated_at': FieldValue.serverTimestamp(),
      });

      _currentShop = _currentShop!.copyWith(
        shopName: shopName,
        address: address,
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

  // Regenerate QR code
  Future<bool> regenerateQRCode() async {
    if (_currentShop == null) return false;

    _setLoading(true);
    _setError(null);

    try {
      // Generate new QR data and base64 image
      final qrData = QRUtils.generateShopQRData(_currentShop!.id, _currentShop!.shopkeeperId);
      final qrBase64 = await QRUtils.generateQRAsBase64(qrData);

      // Update shop with new QR (stored only in Firestore)
      await FirebaseConfig.shopsCollection
          .doc(_currentShop!.id)
          .update({
        'qr_code_data': qrData,
        'qr_code_base64': qrBase64,
        'updated_at': FieldValue.serverTimestamp(),
      });

      _currentShop = _currentShop!.copyWith(
        qrCodeData: qrData,
        qrCodeBase64: qrBase64,
        updatedAt: DateTime.now(),
      );

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to regenerate QR code: $e');
      _setLoading(false);
      return false;
    }
  }

  // Setup real-time listeners
  void _setupRealtimeListeners() {
    if (_currentShop == null) return;

    // Listen to customer relation changes
    FirebaseConfig.FirebaseCustomerShopRelationsCollection
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
        .limit(50)
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

  // Get transactions for date range
  List<FirebaseTransactionModel> getTransactionsForDateRange(
      DateTime startDate, DateTime endDate) {
    return _transactions.where((t) {
      return t.timestamp.isAfter(startDate) && t.timestamp.isBefore(endDate);
    }).toList();
  }

  // Search customers
  List<FirebaseCustomerShopRelation> searchCustomers(String query) {
    if (query.isEmpty) return _customers;

    // Note: In a real app, you'd also search by customer name from user profiles
    return _customers.where((c) {
      return c.customerId.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Get pending customers
  List<FirebaseCustomerShopRelation> get pendingCustomers => _customers
      .where((c) => c.status == RequestStatus.pending)
      .toList();

  // Get approved customers
  List<FirebaseCustomerShopRelation> get approvedCustomers => _customers
      .where((c) => c.status == RequestStatus.approved)
      .toList();

  // Get rejected customers
  List<FirebaseCustomerShopRelation> get rejectedCustomers => _customers
      .where((c) => c.status == RequestStatus.rejected)
      .toList();

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

  // Get credit utilization percentage
  double getCreditUtilizationPercentage() {
    if (totalMoneyAllocated == 0) return 0;
    return (totalMoneyUsed / totalMoneyAllocated) * 100;
  }

  // Get average transaction amount
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

  // Refresh data
  Future<void> refresh() async {
    await _loadCustomers();
    await _loadTransactions();
  }

  // Get QR code widget
  Widget? getQRCodeWidget({double? size}) {
    if (_currentShop?.qrCodeBase64.isNotEmpty == true) {
      return QRUtils.createQRWidget(_currentShop!.qrCodeBase64, size: size);
    }
    return null;
  }

  // Validate QR code
  bool validateQRCode(String qrCode) {
    return QRUtils.isValidShopQR(qrCode);
  }

  // Get QR code size in KB
  double getQRCodeSize() {
    if (_currentShop?.qrCodeBase64.isNotEmpty == true) {
      return QRUtils.getQRSizeKB(_currentShop!.qrCodeBase64);
    }
    return 0;
  }

  // Export shop data as JSON
  Map<String, dynamic> exportShopData() {
    return {
      'shop': _currentShop?.toMap(),
      'customers': _customers.map((c) => c.toMap()).toList(),
      'transactions': _transactions.map((t) => t.toMap()).toList(),
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

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Firestore listeners are automatically cleaned up
    super.dispose();
  }
}