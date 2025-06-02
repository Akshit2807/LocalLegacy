import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/models/shop_model.dart';
import '../core/models/customer_shop_relation_model.dart';

class CustomerViewModel extends ChangeNotifier {
  List<CustomerShopRelation> _registeredShops = [];
  List<TransactionModel> _transactions = [];
  String? _securityPin;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<CustomerShopRelation> get registeredShops => _registeredShops;
  List<TransactionModel> get transactions => _transactions;
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

  CustomerShopRelation? get nearestDueDate => _registeredShops
      .where((s) => s.status == RequestStatus.approved)
      .fold<CustomerShopRelation?>(null, (nearest, current) {
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
      final response = await supabase
          .from('profiles')
          .select('security_pin')
          .eq('id', customerId)
          .single();

      _securityPin = response['security_pin'];
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
      await supabase
          .from('profiles')
          .update({'security_pin': pin})
          .eq('id', customerId);

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
      final response = await supabase
          .from('customer_shop_relations')
          .select('''
            *,
            shops!shop_id (shop_name, address, qr_code)
          ''')
          .eq('customer_id', customerId)
          .order('joined_date', ascending: false);

      _registeredShops = (response as List)
          .map((json) => CustomerShopRelation.fromJson(json))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load shops: $e');
    }
  }

  // Load transactions
  Future<void> _loadTransactions(String customerId) async {
    try {
      final response = await supabase
          .from('transactions')
          .select('''
            *,
            shops!shop_id (shop_name)
          ''')
          .eq('customer_id', customerId)
          .order('timestamp', ascending: false)
          .limit(100);

      _transactions = (response as List)
          .map((json) => TransactionModel.fromJson(json))
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
      // Extract shop info from QR
      if (!qrData.startsWith('shop_')) {
        _setError('Invalid QR code');
        _setLoading(false);
        return null;
      }

      // Get shop details
      final shopResponse = await supabase
          .from('shops')
          .select()
          .eq('qr_code', qrData)
          .single();

      final shop = ShopModel.fromJson(shopResponse);

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
      _setError('Shop not found or QR code invalid');
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
      final shopResponse = await supabase
          .from('shops')
          .select()
          .eq('id', shopId)
          .single();

      final shop = ShopModel.fromJson(shopResponse);

      // Create new relation
      final relationId = DateTime.now().millisecondsSinceEpoch.toString();
      final newRelation = CustomerShopRelation(
        id: relationId,
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

      await supabase
          .from('customer_shop_relations')
          .insert(newRelation.toJson());

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

      // Create transaction
      final transactionId = DateTime.now().millisecondsSinceEpoch.toString();
      final transaction = TransactionModel(
        id: transactionId,
        customerId: relation.customerId,
        shopId: shopId,
        shopkeeperId: relation.shopkeeperId,
        amount: amount,
        type: TransactionType.debit,
        description: 'Purchase at shop',
        timestamp: DateTime.now(),
        securityPin: pin,
      );

      await supabase.from('transactions').insert(transaction.toJson());

      // Update relation
      await supabase
          .from('customer_shop_relations')
          .update({
        'current_balance': relation.currentBalance - amount,
        'used_amount': relation.usedAmount + amount,
      })
          .eq('id', relation.id);

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
    supabase
        .channel('customer_relations_$customerId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'customer_shop_relations',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'customer_id',
        value: customerId,
      ),
      callback: (payload) {
        _loadRegisteredShops(customerId);
      },
    )
        .subscribe();

    // Listen to transaction changes
    supabase
        .channel('customer_transactions_$customerId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'transactions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'customer_id',
        value: customerId,
      ),
      callback: (payload) {
        _loadTransactions(customerId);
      },
    )
        .subscribe();
  }

  // Get shop details by ID
  CustomerShopRelation? getShopRelation(String shopId) {
    return _registeredShops
        .where((r) => r.shopId == shopId)
        .firstOrNull;
  }

  // Get transactions for specific shop
  List<TransactionModel> getShopTransactions(String shopId) {
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
    // Clean up subscriptions
    supabase.removeAllChannels();
    super.dispose();
  }
}