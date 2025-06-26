import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced Firebase Configuration with proper error handling and optimization
class FirebaseConfig {
  static bool _isInitialized = false;

  // Firebase instances (lazy initialization)
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Initialize Firebase with optimized settings
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase with your configuration
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          // Android configuration
          apiKey: 'AIzaSyC8-n2s26MLOhDai4UxEDvfaeoIITnMNAs',
          appId: '1:843864210321:android:bcd7b188abf06c45f87830',
          messagingSenderId: '843864210321',
          projectId: 'locallegacy-005',

          // iOS configuration (add when needed)
          // iosBundleId: 'com.example.ll2',
          // iosClientId: 'your-ios-client-id',
        ),
      );

      // Configure Firestore with optimized settings
      await _configureFirestore();

      // Configure Auth settings
      await _configureAuth();

      _isInitialized = true;
      print('✅ Firebase initialized successfully');

    } catch (e) {
      print('❌ Firebase initialization failed: $e');
      rethrow;
    }
  }

  /// Configure Firestore with optimal settings
  static Future<void> _configureFirestore() async {
    try {
      // Enable offline persistence with unlimited cache
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        ignoreUndefinedProperties: false,
      );

      // Enable network for Firestore
      await FirebaseFirestore.instance.enableNetwork();

      print('✅ Firestore configured successfully');
    } catch (e) {
      print('⚠️ Firestore configuration warning: $e');
      // Continue even if some settings fail
    }
  }

  /// Configure Firebase Auth settings
  static Future<void> _configureAuth() async {
    try {
      // Enable auth persistence
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

      // Set auth language (optional)
      // FirebaseAuth.instance.setLanguageCode('en');

      print('✅ Firebase Auth configured successfully');
    } catch (e) {
      print('⚠️ Firebase Auth configuration warning: $e');
      // Continue even if some settings fail
    }
  }

  // Collection references with proper typing
  static CollectionReference<Map<String, dynamic>> get usersCollection =>
      firestore.collection('users');

  static CollectionReference<Map<String, dynamic>> get shopsCollection =>
      firestore.collection('shops');

  static CollectionReference<Map<String, dynamic>> get customerShopRelationsCollection =>
      firestore.collection('customer_shop_relations');

  static CollectionReference<Map<String, dynamic>> get transactionsCollection =>
      firestore.collection('transactions');

  // Legacy collection reference (for backward compatibility)
  static CollectionReference<Map<String, dynamic>> get FirebaseCustomerShopRelationsCollection =>
      customerShopRelationsCollection;

  /// Check if Firebase is properly initialized
  static bool get isInitialized => _isInitialized;

  /// Get current user ID safely
  static String? get currentUserId => auth.currentUser?.uid;

  /// Get current user email safely
  static String? get currentUserEmail => auth.currentUser?.email;

  /// Check if user is signed in
  static bool get isUserSignedIn => auth.currentUser != null;

  /// Batch operation helper
  static WriteBatch batch() => firestore.batch();

  /// Transaction helper
  static Future<T> runTransaction<T>(
      Future<T> Function(Transaction transaction) updateFunction,
      ) =>
      firestore.runTransaction(updateFunction);

  /// Safe document reference creator
  static DocumentReference<Map<String, dynamic>> getUserDoc(String userId) =>
      usersCollection.doc(userId);

  static DocumentReference<Map<String, dynamic>> getShopDoc(String shopId) =>
      shopsCollection.doc(shopId);

  static DocumentReference<Map<String, dynamic>> getRelationDoc(String relationId) =>
      customerShopRelationsCollection.doc(relationId);

  static DocumentReference<Map<String, dynamic>> getTransactionDoc(String transactionId) =>
      transactionsCollection.doc(transactionId);

  /// Query helpers with proper error handling
  static Query<Map<String, dynamic>> getUsersByType(String userType) =>
      usersCollection.where('user_type', isEqualTo: userType);

  static Query<Map<String, dynamic>> getShopsByOwner(String shopkeeperId) =>
      shopsCollection.where('shopkeeper_id', isEqualTo: shopkeeperId);

  static Query<Map<String, dynamic>> getCustomerRelations(String customerId) =>
      customerShopRelationsCollection.where('customer_id', isEqualTo: customerId);

  static Query<Map<String, dynamic>> getShopRelations(String shopId) =>
      customerShopRelationsCollection.where('shop_id', isEqualTo: shopId);

  static Query<Map<String, dynamic>> getUserTransactions(String userId) =>
      transactionsCollection.where('customer_id', isEqualTo: userId);

  static Query<Map<String, dynamic>> getShopTransactions(String shopId) =>
      transactionsCollection.where('shop_id', isEqualTo: shopId);

  /// Utility methods

  /// Create server timestamp
  static FieldValue get serverTimestamp => FieldValue.serverTimestamp();

  /// Create array union
  static FieldValue arrayUnion(List<dynamic> elements) => FieldValue.arrayUnion(elements);

  /// Create array remove
  static FieldValue arrayRemove(List<dynamic> elements) => FieldValue.arrayRemove(elements);

  /// Create increment
  static FieldValue increment(num value) => FieldValue.increment(value);

  /// Delete field
  static FieldValue get delete => FieldValue.delete();

  /// Cleanup Firebase resources
  static Future<void> cleanup() async {
    try {
      // Sign out user
      if (isUserSignedIn) {
        await auth.signOut();
      }

      // Disable Firestore network
      await firestore.disableNetwork();

      _isInitialized = false;
      print('✅ Firebase cleanup completed');
    } catch (e) {
      print('⚠️ Firebase cleanup warning: $e');
    }
  }

  /// Test Firebase connection
  static Future<bool> testConnection() async {
    try {
      // Test Firestore connection
      await firestore.doc('test/connection').get();

      // Test Auth connection
      await auth.fetchSignInMethodsForEmail('test@example.com');

      return true;
    } catch (e) {
      print('❌ Firebase connection test failed: $e');
      return false;
    }
  }

  /// Get Firestore security rules for reference
  static String get firestoreSecurityRules => '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Shops can only be accessed by their owners
    match /shops/{shopId} {
      allow read, write: if request.auth != null &&
        resource.data.shopkeeper_id == request.auth.uid;
      allow read: if request.auth != null; // Allow customers to read shop info
    }

    // Customer-shop relations
    match /customer_shop_relations/{relationId} {
      allow read, write: if request.auth != null &&
        (resource.data.customer_id == request.auth.uid ||
         resource.data.shopkeeper_id == request.auth.uid);
    }

    // Transactions
    match /transactions/{transactionId} {
      allow read, write: if request.auth != null &&
        (resource.data.customer_id == request.auth.uid ||
         resource.data.shopkeeper_id == request.auth.uid);
    }
  }
}
''';

  /// Get Storage security rules for reference
  static String get storageSecurityRules => '''
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /qr_codes/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    match /user_avatars/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
''';
}