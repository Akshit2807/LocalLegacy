import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/firebase_config.dart';
import '../core/models/firebase_shop_model.dart';
import '../core/models/firebase_customer_shop_relation_model.dart';
import '../core/models/user_model.dart';
import '../core/services/qr_service.dart';

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
      .where((s) => s.status == RequestStatus.approved && s.usedAmount > 0)
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
      final snapshot = await FirebaseConfig.customerShopRelationsCollection
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

  /// Enhanced QR scanning with proper shop detection
  Future<QRScanResult?> handleQRScan(String qrData, String customerId) async {
    _setLoading(true);
    _setError(null);

    try {
      print('Processing QR Data: $qrData');

      // Parse QR data using enhanced service
      final qrInfo = QRCodeService.parseShopQRData(qrData);
      if (qrInfo == null) {
        _setError('Invalid QR code format');
        _setLoading(false);
        return null;
      }

      final shopId = qrInfo['shop_id'] as String;
      final shopName = qrInfo['shop_name'] as String;

      // Verify shop exists in database
      final shopDoc = await FirebaseConfig.shopsCollection
          .doc(shopId)
          .get();

      if (!shopDoc.exists) {
        _setError('Shop not found in system');
        _setLoading(false);
        return null;
      }

      final shop = FirebaseShopModel.fromFirestore(shopDoc);

      // Get current user info for the request
      final userDoc = await FirebaseConfig.usersCollection
          .doc(customerId)
          .get();

      if (!userDoc.exists) {
        _setError('User profile not found');
        _setLoading(false);
        return null;
      }

      final user = FirebaseUserModel.fromFirestore(userDoc);

      // Check if customer is already registered with this shop
      final existingRelation = _registeredShops
          .where((r) => r.shopId == shop.id)
          .firstOrNull;

      if (existingRelation == null) {
        // First time - return new shop result
        _setLoading(false);
        return QRScanResult(
          type: QRScanResultType.newShop,
          shopId: shop.id,
          shopName: shop.shopName,
          shopkeeperName: shop.shopName, // Could be enhanced with actual shopkeeper name
          customerName: user.displayName,
          customerEmail: user.email,
          customerId: customerId,
        );
      } else if (existingRelation.status == RequestStatus.pending) {
        _setError('Request already sent to ${shop.shopName}. Waiting for approval.');
        _setLoading(false);
        return null;
      } else if (existingRelation.status == RequestStatus.rejected) {
        _setError('Your request to ${shop.shopName} was rejected.');
        _setLoading(false);
        return null;
      } else {
        // Approved - can make payment
        _setLoading(false);
        return QRScanResult(
          type: QRScanResultType.approvedShop,
          shopId: shop.id,
          shopName: shop.shopName,
          relation: existingRelation,
        );
      }

    } catch (e) {
      _setError('Failed to process QR code: $e');
      _setLoading(false);
      return null;
    }
  }

  /// Send join request to shop with user details
  Future<bool> sendJoinRequest(String shopId, String customerId) async {
    _setLoading(true);
    _setError(null);

    try {
      // Get shop and user details
      final shopDoc = await FirebaseConfig.shopsCollection.doc(shopId).get();
      final userDoc = await FirebaseConfig.usersCollection.doc(customerId).get();

      if (!shopDoc.exists || !userDoc.exists) {
        _setError('Shop or user not found');
        _setLoading(false);
        return false;
      }

      final shop = FirebaseShopModel.fromFirestore(shopDoc);
      final user = FirebaseUserModel.fromFirestore(userDoc);

      // Check if request already exists
      final existingQuery = await FirebaseConfig.customerShopRelationsCollection
          .where('customer_id', isEqualTo: customerId)
          .where('shop_id', isEqualTo: shopId)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        _setError('Request already exists for this shop');
        _setLoading(false);
        return false;
      }

      // Create new relation document with customer details
      final relationDoc = FirebaseConfig.customerShopRelationsCollection.doc();
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

      // Use batch to ensure data consistency
      final batch = FirebaseConfig.batch();

      // Add the relation
      batch.set(relationDoc, newRelation.toFirestore());

      // Add metadata for shopkeeper (customer details)
      final metadataDoc = FirebaseConfig.firestore
          .collection('customer_requests_metadata')
          .doc(relationDoc.id);

      batch.set(metadataDoc, {
        'relation_id': relationDoc.id,
        'customer_id': customerId,
        'customer_name': user.displayName,
        'customer_email': user.email,
        'customer_phone': user.phoneNumber,
        'shop_id': shopId,
        'shop_name': shop.shopName,
        'shopkeeper_id': shop.shopkeeperId,
        'request_date': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      await batch.commit();

      await _loadRegisteredShops(customerId);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to send request: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Make payment at shop with enhanced transaction recording
  Future<PaymentResult> makePayment(String shopId, double amount, String pin) async {
    _setLoading(true);
    _setError(null);

    try {
      // Verify pin
      if (pin != _securityPin) {
        _setError('Invalid security pin');
        _setLoading(false);
        return PaymentResult(success: false, message: 'Invalid security pin');
      }

      // Get relation
      final relation = _registeredShops.firstWhere((r) => r.shopId == shopId);

      // Check available credit
      if (amount > relation.availableCredit) {
        _setError('Insufficient credit limit');
        _setLoading(false);
        return PaymentResult(success: false, message: 'Insufficient credit limit');
      }

      // Get shop name for transaction description
      final shopName = await _getShopName(shopId);

      // Start a batch operation for atomic transaction
      final batch = FirebaseConfig.batch();

      // Create transaction
      final transactionDoc = FirebaseConfig.transactionsCollection.doc();
      final transaction = FirebaseTransactionModel(
        id: transactionDoc.id,
        customerId: relation.customerId,
        shopId: shopId,
        shopkeeperId: relation.shopkeeperId,
        amount: amount,
        type: TransactionType.debit,
        description: 'Purchase at $shopName',
        timestamp: DateTime.now(),
        securityPin: pin, // Store for verification
        metadata: {
          'payment_method': 'qr_scan',
          'available_credit_before': relation.availableCredit,
          'available_credit_after': relation.availableCredit - amount,
          'transaction_type': 'purchase',
          'shop_name': shopName,
        },
      );

      batch.set(transactionDoc, transaction.toFirestore());

      // Update relation
      batch.update(
        FirebaseConfig.customerShopRelationsCollection.doc(relation.id),
        {
          'current_balance': relation.currentBalance - amount,
          'used_amount': relation.usedAmount + amount,
          'updated_at': FieldValue.serverTimestamp(),
        },
      );

      // Commit batch
      await batch.commit();

      // Refresh data
      await _loadRegisteredShops(relation.customerId);
      await _loadTransactions(relation.customerId);

      _setLoading(false);
      return PaymentResult(
        success: true,
        message: 'Payment successful',
        transactionId: transaction.id,
        amount: amount,
        shopName: shopName,
        newBalance: relation.availableCredit - amount,
      );
    } catch (e) {
      _setError('Failed to make payment: $e');
      _setLoading(false);
      return PaymentResult(success: false, message: 'Payment failed: $e');
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

  // Setup real-time listeners
  void _setupRealtimeListeners(String customerId) {
    // Listen to relation changes
    FirebaseConfig.customerShopRelationsCollection
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

  // Refresh data
  Future<void> refresh(String customerId) async {
    await _loadRegisteredShops(customerId);
    await _loadTransactions(customerId);
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// QR Scan result types
enum QRScanResultType {
  newShop,      // First time scanning this shop
  approvedShop, // Already approved, can make payment
}

/// QR Scan result data
class QRScanResult {
  final QRScanResultType type;
  final String shopId;
  final String shopName;
  final String? shopkeeperName;
  final String? customerName;
  final String? customerEmail;
  final String? customerId;
  final FirebaseCustomerShopRelation? relation;

  QRScanResult({
    required this.type,
    required this.shopId,
    required this.shopName,
    this.shopkeeperName,
    this.customerName,
    this.customerEmail,
    this.customerId,
    this.relation,
  });
}

/// Payment result data
class PaymentResult {
  final bool success;
  final String message;
  final String? transactionId;
  final double? amount;
  final String? shopName;
  final double? newBalance;

  PaymentResult({
    required this.success,
    required this.message,
    this.transactionId,
    this.amount,
    this.shopName,
    this.newBalance,
  });
}