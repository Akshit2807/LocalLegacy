import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/firebase_config.dart';
import '../core/models/firebase_shop_model.dart';
import '../core/models/firebase_customer_shop_relation_model.dart';
import '../core/utils/qr_utils.dart';

class CustomerViewModel extends ChangeNotifier {
  List<FirebaseCustomerShopRelation> _registeredShops = [];
  List<FirebaseTransactionModel> _transactions = [];
  String? _securityPin;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<FirebaseCustomerShopRelation> get registeredShops => _registeredShops;
  List<FirebaseTransactionModel> get transactions => _transactions;
  String? get securityPin => _securityPin;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Analytics getters
  double get totalAvailableCredit => _registeredShops
      .where((s) => s.status == RequestStatus.approved)
      .fold(0.0, (sum, s) => sum + s.availableCredit);

  double get totalUsedAmount => _registeredShops
      .where((s) => s.status == RequestStatus.approved)
      .fold(0.0, (sum, s) => sum + s.usedAmount);

  double get totalCreditLimit => _registeredShops
      .where((s) => s.status == RequestStatus.approved)
      .fold(0.0, (sum, s) => sum + s.totalCreditLimit);

  int get registeredShopsCount => _registeredShops
      .where((s) => s.status == RequestStatus.approved)
      .length;

  FirebaseCustomerShopRelation? get nearestDueDate => _registeredShops
      .where((s) => s.status == RequestStatus.approved)
      .fold<FirebaseCustomerShopRelation?>(null, (nearest, current) {
    if (nearest == null) return current;
    return current.dueDate.isBefore(nearest.dueDate) ? current : nearest;
  });

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Initialize customer data
  Future<void> initializeCustomer(String customerId) async {
    _setLoading(true);
    _setError(null);

    try {
      // Load security pin
      await _loadSecurityPin(customerId);

      // Load registered shops
      await _loadRegisteredShops(customerId);

      // Load transactions
      await _loadTransactions(customerId);

      // Setup real-time listeners
      _setupRealtimeListeners(customerId);

    } catch (e) {
      _setError('Failed to initialize customer: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load security pin
  Future<void> _loadSecurityPin(String customerId) async {
    try {
      final userDoc = await FirebaseConfig.usersCollection
          .doc(customerId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _securityPin = userData['security_pin'];
      }
    } catch (e) {
      // Security pin not set yet
      _securityPin = null;
    }
  }

  // Set security pin
  Future<bool> setSecurityPin(String customerId, String pin) async {
    _setLoading(true);
    _setError(null);

    try {
      await FirebaseConfig.usersCollection
          .doc(customerId)
          .update({
        'security_pin': pin,
        'updated_at': FieldValue.serverTimestamp(),
      });

      _securityPin = pin;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to set security pin: $e');
      _setLoading(false);
      return false;
    }
  }

  // Load registered shops
  Future<void> _loadRegisteredShops(String customerId) async {
    try {
      final snapshot = await FirebaseConfig.FirebaseCustomerShopRelationsCollection
          .where('customer_id', isEqualTo: customerId)
          .orderBy('joined_date', descending: true)
          .get();

      _registeredShops = snapshot.docs
          .map((doc) => FirebaseCustomerShopRelation.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load shops: $e');
    }
  }

  // Load transactions
  Future<void> _loadTransactions(String customerId) async {
    try {
      final snapshot = await FirebaseConfig.transactionsCollection
          .where('customer_id', isEqualTo: customerId)
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

  // Scan QR and handle shop interaction
  Future<String?> handleQRScan(String qrData, String customerId) async {
    _setLoading(true);
    _setError(null);

    try {
      // Parse QR data
      final qrInfo = QRUtils.parseQRData(qrData);
      if (qrInfo == null || qrInfo['type'] != 'shop') {
        _setError('Invalid QR code');
        _setLoading(false);
        return null;
      }

      final shopId = qrInfo['shop_id'] as String;

      // Get shop details
      final shopDoc = await FirebaseConfig.shopsCollection
          .doc(shopId)
          .get();

      if (!shopDoc.exists) {
        _setError('Shop not found');
        _setLoading(false);
        return null;
      }

      final shop = FirebaseShopModel.fromFirestore(shopDoc);

      // Check if customer is already registered with this shop
      final existingRelation = _registeredShops
          .where((r) => r.shopId == shop.id)
          .firstOrNull;

      if (existingRelation == null) {
        // First time - need to send request
        _setLoading(false);
        return 'new_shop:${shop.id}:${shop.shopName}';
      } else if (existingRelation.status == RequestStatus.pending) {
        _setError('Request already sent to this shop. Waiting for approval.');
        _setLoading(false);
        return null;
      } else if (existingRelation.status == RequestStatus.rejected) {
        _setError('Your request to this shop was rejected.');
        _setLoading(false);
        return null;
      } else {
        // Approved - can make payment
        _setLoading(false);
        return 'approved:${shop.id}:${shop.shopName}';
      }

    } catch (e) {
      _setError('Shop not found or QR code invalid: $e');
      _setLoading(false);
      return null;
    }
  }

  // Send request to join shop
  Future<bool> sendJoinRequest(String shopId, String customerId) async {
    _setLoading(true);
    _setError(null);

    try {
      // Get shop details
      final shopDoc = await FirebaseConfig.shopsCollection
          .doc(shopId)
          .get();

      if (!shopDoc.exists) {
        _setError('Shop not found');
        _setLoading(false);
        return false;
      }

      final shop = FirebaseShopModel.fromFirestore(shopDoc);

      // Create new relation document
      final relationDoc = FirebaseConfig.FirebaseCustomerShopRelationsCollection.doc();
      final newRelation = FirebaseCustomerShopRelation(
        id: relationDoc.id,
        customerId: customerId,
        shopId: shopId,
        shopkeeperId: shop.shopkeeperId,
        totalCreditLimit: 0.0,
        currentBalance: 0.0,
        usedAmount: 0.0,
        dueDate: DateTime.now().add(const Duration(days: 30)),
        joinedDate: DateTime.now(),
        status: RequestStatus.pending,
        isActive: true,
      );

      await relationDoc.set(newRelation.toFirestore());

      await _loadRegisteredShops(customerId);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to send request: $e');
      _setLoading(false);
      return false;
    }
  }

  // Make payment at shop
  Future<bool> makePayment(String shopId, double amount, String pin) async {
    _setLoading(true);
    _setError(null);

    try {
      // Verify pin
      if (pin != _securityPin) {
        _setError('Invalid security pin');
        _setLoading(false);
        return false;
      }

      // Get relation
      final relation = _registeredShops.firstWhere((r) => r.shopId == shopId);

      // Check available credit
      if (amount > relation.availableCredit) {
        _setError('Insufficient credit limit');
        _setLoading(false);
        return false;
      }

      // Start a batch operation
      final batch = FirebaseConfig.firestore.batch();

      // Create transaction
      final transactionDoc = FirebaseConfig.transactionsCollection.doc();
      final transaction = FirebaseTransactionModel(
        id: transactionDoc.id,
        customerId: relation.customerId,
        shopId: shopId,
        shopkeeperId: relation.shopkeeperId,
        amount: amount,
        type: TransactionType.debit,
        description: 'Purchase at ${await _getShopName(shopId)}',
        timestamp: DateTime.now(),
        securityPin: pin,
        metadata: {
          'payment_method': 'qr_scan',
          'available_credit_before': relation.availableCredit,
        },
      );

      batch.set(transactionDoc, transaction.toFirestore());

      // Update relation
      batch.update(
        FirebaseConfig.FirebaseCustomerShopRelationsCollection.doc(relation.id),
        {
          'current_balance': relation.currentBalance - amount,
          'used_amount': relation.usedAmount + amount,
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Commit batch
      await batch.commit();

      await _loadRegisteredShops(relation.customerId);
      await _loadTransactions(relation.customerId);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to make payment: $e');
      _setLoading(false);
      return false;
    }
  }

  // Helper method to get shop name
  Future<String> _getShopName(String shopId) async {
    try {
      final shopDoc = await FirebaseConfig.shopsCollection.doc(shopId).get();
      if (shopDoc.exists) {
        final shop = FirebaseShopModel.fromFirestore(shopDoc);
        return shop.shopName;
      }
      return 'Unknown Shop';
    } catch (e) {
      return 'Shop';
    }
  }

  // Make manual payment (credit payment)
  Future<bool> makeManualPayment(String shopId, double amount, String description) async {
    _setLoading(true);
    _setError(null);

    try {
      final relation = _registeredShops.firstWhere((r) => r.shopId == shopId);

      // Start a batch operation
      final batch = FirebaseConfig.firestore.batch();

      // Create transaction
      final transactionDoc = FirebaseConfig.transactionsCollection.doc();
      final transaction = FirebaseTransactionModel(
        id: transactionDoc.id,
        customerId: relation.customerId,
        shopId: shopId,
        shopkeeperId: relation.shopkeeperId,
        amount: amount,
        type: TransactionType.credit,
        description: description,
        timestamp: DateTime.now(),
        metadata: {
          'payment_method': 'manual',
          'initiated_by': 'customer',
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

      await _loadRegisteredShops(relation.customerId);
      await _loadTransactions(relation.customerId);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to make payment: $e');
      _setLoading(false);
      return false;
    }
  }

  // Setup real-time listeners
  void _setupRealtimeListeners(String customerId) {
    // Listen to relation changes
    FirebaseConfig.FirebaseCustomerShopRelationsCollection
        .where('customer_id', isEqualTo: customerId)
        .snapshots()
        .listen(
          (snapshot) {
        _registeredShops = snapshot.docs
            .map((doc) => FirebaseCustomerShopRelation.fromFirestore(doc))
            .toList();
        notifyListeners();
      },
      onError: (error) {
        _setError('Error listening to shop changes: $error');
      },
    );

    // Listen to transaction changes
    FirebaseConfig.transactionsCollection
        .where('customer_id', isEqualTo: customerId)
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
  }

  // Get shop details by ID
  FirebaseCustomerShopRelation? getShopRelation(String shopId) {
    return _registeredShops
        .where((r) => r.shopId == shopId)
        .firstOrNull;
  }

  // Get transactions for specific shop
  List<FirebaseTransactionModel> getShopTransactions(String shopId) {
    return _transactions
        .where((t) => t.shopId == shopId)
        .toList();
  }

  // Get pending shops
  List<FirebaseCustomerShopRelation> get pendingShops => _registeredShops
      .where((s) => s.status == RequestStatus.pending)
      .toList();

  // Get approved shops
  List<FirebaseCustomerShopRelation> get approvedShops => _registeredShops
      .where((s) => s.status == RequestStatus.approved)
      .toList();

  // Get overdue shops
  List<FirebaseCustomerShopRelation> get overdueShops => _registeredShops
      .where((s) => s.status == RequestStatus.approved && s.isOverdue)
      .toList();

  // Get monthly spending
  double getMonthlySpending([DateTime? month]) {
    final targetMonth = month ?? DateTime.now();
    return _transactions
        .where((t) =>
    t.type == TransactionType.debit &&
        t.timestamp.year == targetMonth.year &&
        t.timestamp.month == targetMonth.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get spending by shop
  Map<String, double> getSpendingByShop() {
    final spendingMap = <String, double>{};

    for (final transaction in _transactions) {
      if (transaction.type == TransactionType.debit) {
        spendingMap[transaction.shopId] =
            (spendingMap[transaction.shopId] ?? 0) + transaction.amount;
      }
    }

    return spendingMap;
  }

  // Search transactions
  List<FirebaseTransactionModel> searchTransactions(String query) {
    if (query.isEmpty) return _transactions;

    return _transactions.where((t) {
      return t.description.toLowerCase().contains(query.toLowerCase()) ||
          t.id.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Refresh data
  Future<void> refresh(String customerId) async {
    await _loadRegisteredShops(customerId);
    await _loadTransactions(customerId);
  }

  @override
  void dispose() {
    // Firestore listeners are automatically cleaned up
    super.dispose();
  }
}