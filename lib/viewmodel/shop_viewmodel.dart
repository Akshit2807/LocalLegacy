import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/models/shop_model.dart';
import '../core/models/customer_shop_relation_model.dart';
import '../core/models/user_model.dart';

class ShopViewModel extends ChangeNotifier {
  ShopModel? _currentShop;
  List<CustomerShopRelation> _customers = [];
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  ShopModel? get currentShop => _currentShop;
  List<CustomerShopRelation> get customers => _customers;
  List<TransactionModel> get transactions => _transactions;
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

  List<CustomerShopRelation> get overdueCustomers => _customers
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
      // Get or create shop
      final shopResponse = await supabase
          .from('shops')
          .select()
          .eq('shopkeeper_id', shopkeeperId)
          .maybeSingle();

      if (shopResponse != null) {
        _currentShop = ShopModel.fromJson(shopResponse);
      } else {
        // Create new shop
        final newShopId = DateTime.now().millisecondsSinceEpoch.toString();
        final qrCode = 'shop_${shopkeeperId}_$newShopId';

        final newShop = ShopModel(
          id: newShopId,
          shopkeeperId: shopkeeperId,
          shopName: 'My Shop',
          address: '',
          qrCode: qrCode,
          createdAt: DateTime.now(),
          isActive: true,
        );

        await supabase.from('shops').insert(newShop.toJson());
        _currentShop = newShop;
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

  // Load customers for the shop
  Future<void> _loadCustomers() async {
    if (_currentShop == null) return;

    try {
      final response = await supabase
          .from('customer_shop_relations')
          .select('''
            *,
            profiles!customer_id (name, email)
          ''')
          .eq('shop_id', _currentShop!.id)
          .order('joined_date', ascending: false);

      _customers = (response as List)
          .map((json) => CustomerShopRelation.fromJson(json))
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
      final response = await supabase
          .from('transactions')
          .select('''
            *,
            profiles!customer_id (name)
          ''')
          .eq('shop_id', _currentShop!.id)
          .order('timestamp', ascending: false)
          .limit(50);

      _transactions = (response as List)
          .map((json) => TransactionModel.fromJson(json))
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
      await supabase
          .from('customer_shop_relations')
          .update({
        'status': 'approved',
        'total_credit_limit': creditLimit,
        'current_balance': creditLimit,
        'due_date': dueDate.toIso8601String(),
      })
          .eq('id', relationId);

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
      await supabase
          .from('customer_shop_relations')
          .update({'status': 'rejected'})
          .eq('id', relationId);

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

      await supabase
          .from('customer_shop_relations')
          .update({
        'total_credit_limit': newLimit,
        'current_balance': relation.currentBalance + difference,
      })
          .eq('id', relationId);

      // Create transaction record
      if (difference != 0) {
        final transaction = TransactionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          customerId: relation.customerId,
          shopId: relation.shopId,
          shopkeeperId: relation.shopkeeperId,
          amount: difference.abs(),
          type: difference > 0 ? TransactionType.credit : TransactionType.debit,
          description: 'Credit limit ${difference > 0 ? 'increased' : 'decreased'} by shopkeeper',
          timestamp: DateTime.now(),
        );

        await supabase.from('transactions').insert(transaction.toJson());
      }

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

      // Create transaction
      final transaction = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerId: customerId,
        shopId: _currentShop!.id,
        shopkeeperId: _currentShop!.shopkeeperId,
        amount: amount,
        type: TransactionType.credit,
        description: description,
        timestamp: DateTime.now(),
      );

      await supabase.from('transactions').insert(transaction.toJson());

      // Update relation
      await supabase
          .from('customer_shop_relations')
          .update({
        'current_balance': relation.currentBalance + amount,
        'used_amount': relation.usedAmount - amount,
      })
          .eq('id', relation.id);

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
      await supabase
          .from('shops')
          .update({
        'shop_name': shopName,
        'address': address,
      })
          .eq('id', _currentShop!.id);

      _currentShop = _currentShop!.copyWith(
        shopName: shopName,
        address: address,
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
    supabase
        .channel('customer_relations_${_currentShop!.id}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'customer_shop_relations',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'shop_id',
        value: _currentShop!.id,
      ),
      callback: (payload) {
        _loadCustomers();
      },
    )
        .subscribe();

    // Listen to transaction changes
    supabase
        .channel('transactions_${_currentShop!.id}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'transactions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'shop_id',
        value: _currentShop!.id,
      ),
      callback: (payload) {
        _loadTransactions();
      },
    )
        .subscribe();
  }

  // Refresh data
  Future<void> refresh() async {
    await _loadCustomers();
    await _loadTransactions();
  }

  @override
  void dispose() {
    // Clean up subscriptions
    if (_currentShop != null) {
      supabase.removeChannel(
        supabase.channel('customer_relations_${_currentShop!.id}'),
      );
      supabase.removeChannel(
        supabase.channel('transactions_${_currentShop!.id}'),
      );
    }
    super.dispose();
  }
}