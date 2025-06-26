import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/config/firebase_config.dart';
import '../core/models/user_model.dart';

/// Enhanced Firebase Authentication System
/// Handles all authentication operations with type safety and error handling
class AuthViewModel extends ChangeNotifier {
  // Private state variables
  FirebaseUserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String? _pendingUserType;
  bool _isInitialized = false;

  // Public getters
  FirebaseUserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null && _isInitialized;
  bool get isEmailVerified => _user?.isEmailVerified ?? false;
  bool get isInitialized => _isInitialized;
  String? get pendingUserType => _pendingUserType;

  // Firebase instances
  FirebaseAuth get _auth => FirebaseConfig.auth;
  CollectionReference get _usersCollection => FirebaseConfig.usersCollection;

  /// Initialize authentication state and setup listeners
  Future<void> initializeAuth() async {
    try {
      _setLoading(true);

      // Setup auth state listener
      _setupAuthStateListener();

      // Check current user
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _loadUserProfile(currentUser.uid);
      }

      _isInitialized = true;
    } catch (e) {
      _setError('Failed to initialize authentication: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Setup real-time auth state listener
  void _setupAuthStateListener() {
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        await _loadUserProfile(firebaseUser.uid);
      } else {
        _clearUserState();
      }
    });
  }

  /// Load user profile from Firestore
  Future<void> _loadUserProfile(String uid) async {
    try {
      final userDoc = await _usersCollection.doc(uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        _setUser(FirebaseUserModel.fromFirestore(userDoc));
      } else {
        // Handle orphaned Firebase Auth user
        await _handleOrphanedUser(uid);
      }
    } catch (e) {
      _setError('Failed to load user profile: $e');
    }
  }

  /// Handle users with Firebase Auth but no Firestore profile
  Future<void> _handleOrphanedUser(String uid) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    try {
      // Create minimal user profile
      final userData = FirebaseUserModel(
        id: uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName,
        userType: _pendingUserType ?? 'customer',
        isEmailVerified: firebaseUser.emailVerified,
        avatarUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
      );

      await _usersCollection.doc(uid).set(userData.toFirestore());
      _setUser(userData);
    } catch (e) {
      _setError('Failed to create user profile: $e');
    }
  }

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required String userType,
  }) async {
    return _executeAuthOperation(() async {
      // Validate input
      final validation = _validateSignUpInput(name, email, password, userType);
      if (!validation.isSuccess) {
        return validation;
      }

      // Check for existing user with different type
      final existingUserCheck = await _checkExistingUserType(email, userType);
      if (!existingUserCheck.isSuccess) {
        return existingUserCheck;
      }

      _pendingUserType = userType;

      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return AuthResult.failure('Account creation failed');
      }

      // Update display name
      await credential.user!.updateDisplayName(name);

      // Create Firestore profile
      final userData = FirebaseUserModel(
        id: credential.user!.uid,
        email: email,
        name: name,
        userType: userType,
        isEmailVerified: true, // Bypassing email verification
        createdAt: DateTime.now(),
      );

      await _usersCollection.doc(credential.user!.uid).set(userData.toFirestore());
      _setUser(userData);

      return AuthResult.success();
    });
  }

  /// Login with email and password
  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
    required String userType,
  }) async {
    return _executeAuthOperation(() async {
      // Validate input
      if (email.isEmpty || password.isEmpty) {
        return AuthResult.failure('Please enter email and password');
      }

      _pendingUserType = userType;

      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return AuthResult.failure('Login failed');
      }

      // Load and validate user profile
      final userDoc = await _usersCollection.doc(credential.user!.uid).get();

      if (!userDoc.exists) {
        await _auth.signOut();
        return AuthResult.failure('User profile not found. Please contact support.');
      }

      final userData = FirebaseUserModel.fromFirestore(userDoc);

      // Validate user type
      if (userData.userType != userType) {
        await _auth.signOut();
        return AuthResult.failure(
            'This email is registered as ${userData.userType}. '
                'Please select the correct user type or use a different email.'
        );
      }

      _setUser(userData);
      return AuthResult.success();
    });
  }

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle({required String userType}) async {
    GoogleSignIn? googleSignIn;

    return _executeAuthOperation(() async {
      googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

      // Start Google sign in flow
      final GoogleSignInAccount? googleUser = await googleSignIn!.signIn();
      if (googleUser == null) {
        return AuthResult.failure('Google sign in was cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      _pendingUserType = userType;

      // Sign in with Firebase
      final authResult = await _auth.signInWithCredential(credential);

      if (authResult.user == null) {
        return AuthResult.failure('Google sign in failed');
      }

      // Handle user profile
      final userDoc = await _usersCollection.doc(authResult.user!.uid).get();

      if (!userDoc.exists) {
        // First time Google sign in
        final userData = FirebaseUserModel(
          id: authResult.user!.uid,
          email: authResult.user!.email!,
          name: authResult.user!.displayName ?? googleUser.displayName,
          userType: userType,
          isEmailVerified: authResult.user!.emailVerified,
          avatarUrl: authResult.user!.photoURL,
          createdAt: DateTime.now(),
        );

        await _usersCollection.doc(authResult.user!.uid).set(userData.toFirestore());
        _setUser(userData);
      } else {
        // Validate existing user type
        final userData = FirebaseUserModel.fromFirestore(userDoc);

        if (userData.userType != userType) {
          await _auth.signOut();
          await googleSignIn!.signOut();
          return AuthResult.failure(
              'This Google account is registered as ${userData.userType}. '
                  'Please select the correct user type.'
          );
        }

        _setUser(userData);
      }

      return AuthResult.success();
    }, onError: () async {
      await googleSignIn?.signOut();
    });
  }

  /// Reset password
  Future<AuthResult> resetPassword(String email) async {
    return _executeAuthOperation(() async {
      if (email.isEmpty) {
        return AuthResult.failure('Please enter your email address');
      }

      if (!_isValidEmail(email)) {
        return AuthResult.failure('Please enter a valid email address');
      }

      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(message: 'Password reset email sent successfully');
    });
  }

  /// Update user profile
  Future<AuthResult> updateUserProfile({
    String? name,
    String? avatarUrl,
    String? securityPin,
  }) async {
    if (_user == null) {
      return AuthResult.failure('User not authenticated');
    }

    return _executeAuthOperation(() async {
      final updates = <String, dynamic>{};

      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (securityPin != null) updates['security_pin'] = securityPin;

      if (updates.isEmpty) {
        return AuthResult.failure('No updates provided');
      }

      updates['updated_at'] = FieldValue.serverTimestamp();

      await _usersCollection.doc(_user!.id).update(updates);

      _setUser(_user!.copyWith(
        name: name ?? _user!.name,
        avatarUrl: avatarUrl ?? _user!.avatarUrl,
        securityPin: securityPin ?? _user!.securityPin,
      ));

      return AuthResult.success(message: 'Profile updated successfully');
    });
  }

  /// Sign out
  Future<AuthResult> signOut() async {
    return _executeAuthOperation(() async {
      await GoogleSignIn().signOut();
      await _auth.signOut();
      _clearUserState();
      return AuthResult.success(message: 'Signed out successfully');
    });
  }

  /// Delete user account
  Future<AuthResult> deleteAccount() async {
    if (_user == null) {
      return AuthResult.failure('User not authenticated');
    }

    return _executeAuthOperation(() async {
      final uid = _user!.id;

      // Delete Firestore profile
      await _usersCollection.doc(uid).delete();

      // Delete Firebase Auth account
      await _auth.currentUser?.delete();

      _clearUserState();
      return AuthResult.success(message: 'Account deleted successfully');
    });
  }

  /// Re-authenticate user (for sensitive operations)
  Future<AuthResult> reauthenticateUser({
    String? email,
    String? password,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return AuthResult.failure('User not authenticated');
    }

    return _executeAuthOperation(() async {
      AuthCredential credential;

      if (email != null && password != null) {
        credential = EmailAuthProvider.credential(email: email, password: password);
      } else {
        return AuthResult.failure('Email and password required for re-authentication');
      }

      await currentUser.reauthenticateWithCredential(credential);
      return AuthResult.success(message: 'Re-authentication successful');
    });
  }

  /// Change password
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_user == null) {
      return AuthResult.failure('User not authenticated');
    }

    return _executeAuthOperation(() async {
      // Re-authenticate first
      final reauth = await reauthenticateUser(
        email: _user!.email,
        password: currentPassword,
      );

      if (!reauth.isSuccess) {
        return reauth;
      }

      // Change password
      await _auth.currentUser!.updatePassword(newPassword);
      return AuthResult.success(message: 'Password changed successfully');
    });
  }

  /// Bypass OTP verification (for demo purposes)
  Future<AuthResult> verifyOtp(String email, String otp) async {
    return _executeAuthOperation(() async {
      await Future.delayed(const Duration(seconds: 1));

      if (_user != null) {
        await _usersCollection.doc(_user!.id).update({'email_verified': true});
        _setUser(_user!.copyWith(isEmailVerified: true));
      }

      return AuthResult.success(message: 'Email verified successfully');
    });
  }

  /// Bypass OTP resend (for demo purposes)
  Future<AuthResult> resendOtp(String email) async {
    return _executeAuthOperation(() async {
      await Future.delayed(const Duration(seconds: 1));
      return AuthResult.success(message: 'OTP sent successfully');
    });
  }

  // Private helper methods

  /// Execute auth operation with error handling
  Future<AuthResult> _executeAuthOperation(
      Future<AuthResult> Function() operation, {
        Future<void> Function()? onError,
      }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await operation();
      return result;
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getFirebaseAuthErrorMessage(e);
      _setError(errorMessage);
      if (onError != null) await onError();
      return AuthResult.failure(errorMessage);
    } catch (e) {
      final errorMessage = 'An unexpected error occurred: $e';
      _setError(errorMessage);
      if (onError != null) await onError();
      return AuthResult.failure(errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  /// Validate sign up input
  AuthResult _validateSignUpInput(String name, String email, String password, String userType) {
    if (name.trim().isEmpty) {
      return AuthResult.failure('Please enter your name');
    }

    if (email.trim().isEmpty) {
      return AuthResult.failure('Please enter your email');
    }

    if (!_isValidEmail(email)) {
      return AuthResult.failure('Please enter a valid email address');
    }

    if (password.isEmpty) {
      return AuthResult.failure('Please enter a password');
    }

    if (password.length < 6) {
      return AuthResult.failure('Password must be at least 6 characters');
    }

    if (!['shopkeeper', 'customer'].contains(userType)) {
      return AuthResult.failure('Invalid user type');
    }

    return AuthResult.success();
  }

  /// Check for existing user with different type
  Future<AuthResult> _checkExistingUserType(String email, String userType) async {
    try {
      final existingUserQuery = await _usersCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingUserQuery.docs.isNotEmpty) {
        final existingUser = FirebaseUserModel.fromFirestore(existingUserQuery.docs.first);
        if (existingUser.userType != userType) {
          return AuthResult.failure(
              'An account with this email already exists as ${existingUser.userType}. '
                  'Please use a different email or login with the correct user type.'
          );
        }
      }

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('Failed to check existing user: $e');
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Get user-friendly error messages for Firebase Auth exceptions
  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Please login instead.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support.';
      case 'requires-recent-login':
        return 'Please re-authenticate to continue.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Set error message
  void _setError(String? error) {
    _errorMessage = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Set user
  void _setUser(FirebaseUserModel user) {
    _user = user;
    _pendingUserType = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Clear user state
  void _clearUserState() {
    _user = null;
    _pendingUserType = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Clear all state (for testing)
  void clearState() {
    _user = null;
    _isLoading = false;
    _errorMessage = null;
    _pendingUserType = null;
    _isInitialized = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Result class for authentication operations
class AuthResult {
  final bool isSuccess;
  final String? message;
  final String? errorCode;

  const AuthResult._({
    required this.isSuccess,
    this.message,
    this.errorCode,
  });

  factory AuthResult.success({String? message}) {
    return AuthResult._(
      isSuccess: true,
      message: message,
    );
  }

  factory AuthResult.failure(String message, {String? errorCode}) {
    return AuthResult._(
      isSuccess: false,
      message: message,
      errorCode: errorCode,
    );
  }

  bool get isFailure => !isSuccess;
}

/// Authentication state enum
enum AuthState {
  initial,
  authenticated,
  unauthenticated,
  loading,
  error,
}

/// Extension to get current auth state
extension AuthViewModelState on AuthViewModel {
  AuthState get currentState {
    if (isLoading) return AuthState.loading;
    if (errorMessage != null) return AuthState.error;
    if (isAuthenticated) return AuthState.authenticated;
    if (isInitialized) return AuthState.unauthenticated;
    return AuthState.initial;
  }
}