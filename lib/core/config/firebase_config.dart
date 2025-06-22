import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseConfig {
  // Firebase instances (all FREE services)
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  // Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        // Android
        apiKey: 'AIzaSyC8-n2s26MLOhDai4UxEDvfaeoIITnMNAs',
        appId: '1:843864210321:android:bcd7b188abf06c45f87830',
        messagingSenderId: '843864210321',
        projectId: 'locallegacy-005',

        // iOS (uncomment and add when setting up iOS)
        // iosApiKey: 'your-ios-api-key',
        // iosBundleId: 'com.example.ll2',
      ),
    );

    // Configure Firestore settings for offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Enable Firebase Auth persistence
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  // Collection references
  static CollectionReference get usersCollection =>
      firestore.collection('users');

  static CollectionReference get shopsCollection =>
      firestore.collection('shops');

  static CollectionReference get FirebaseCustomerShopRelationsCollection =>
      firestore.collection('customer_shop_relations');

  static CollectionReference get transactionsCollection =>
      firestore.collection('transactions');



// Firestore Security Rules (to be set in Firebase console):
/*
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
  */

// Storage Security Rules (to be set in Firebase console):
/*
  rules_version = '2';
  service firebase.storage {
    match /b/{bucket}/o {
      match /qr_codes/{allPaths=**} {
        allow read: if request.auth != null;
        allow write: if request.auth != null;
      }
    }
  }
  */
}