import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/config/firebase_config.dart';
import '../core/models/user_model.dart';

class AuthViewModel extends ChangeNotifier {
  FirebaseUserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  FirebaseUserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _setUser(FirebaseUserModel? user) {
    _user = user;
    notifyListeners();
  }

  // Initialize auth state
  Future<void> initializeAuth() async {
    try {
      final firebaseUser = FirebaseConfig.auth.currentUser;
      if (firebaseUser != null) {
        // Get user profile from Firestore
        final userDoc = await FirebaseConfig.usersCollection
            .doc(firebaseUser.uid)
            .get();

        if (userDoc.exists) {
          _setUser(FirebaseUserModel.fromFirestore(userDoc));
        } else {
          // Create user profile if doesn't exist
          final userData = FirebaseUserModel(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            name: firebaseUser.displayName,
            userType: 'customer', // Default
            isEmailVerified: firebaseUser.emailVerified,
          );

          await FirebaseConfig.usersCollection
              .doc(firebaseUser.uid)
              .set(userData.toFirestore());

          _setUser(userData);
        }
      }
    } catch (e) {
      _setError('Failed to initialize auth: $e');
    }
  }

  // Email/Password Sign Up - WITH USER TYPE VALIDATION
  Future<bool> signUpWithEmail(String name, String email, String password, String userType) async {
    _setLoading(true);
    _setError(null);

    try {
      // FIRST: Check if email already exists with different user type
      final existingUserQuery = await FirebaseConfig.usersCollection
          .where('email', isEqualTo: email)
          .get();

      if (existingUserQuery.docs.isNotEmpty) {
        final existingUser = FirebaseUserModel.fromFirestore(existingUserQuery.docs.first);
        if (existingUser.userType != userType) {
          _setError('An account with this email already exists as ${existingUser.userType}. Please use a different email or login with the correct user type.');
          _setLoading(false);
          return false;
        }
      }

      // Create Firebase Auth user
      final credential = await FirebaseConfig.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(name);

        // Create user profile in Firestore
        final userData = FirebaseUserModel(
          id: credential.user!.uid,
          email: email,
          name: name,
          userType: userType,
          isEmailVerified: true, // BYPASS email verification
          createdAt: DateTime.now(),
        );

        await FirebaseConfig.usersCollection
            .doc(credential.user!.uid)
            .set(userData.toFirestore());

        _setUser(userData);
        _setLoading(false);
        return true;
      } else {
        _setError('Sign up failed');
        _setLoading(false);
        return false;
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _setError('An account with this email already exists. Please login instead.');
          break;
        case 'weak-password':
          _setError('The password is too weak. Please use at least 6 characters.');
          break;
        case 'invalid-email':
          _setError('Please enter a valid email address.');
          break;
        default:
          _setError(e.message ?? 'Sign up failed');
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      _setLoading(false);
      return false;
    }
  }

  // Email/Password Login - WITH USER TYPE VALIDATION
  Future<bool> loginWithEmail(String email, String password, String userType) async {
    _setLoading(true);
    _setError(null);

    try {
      // Sign in with Firebase Auth
      final credential = await FirebaseConfig.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Get user profile from Firestore
        final userDoc = await FirebaseConfig.usersCollection
            .doc(credential.user!.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseConfig.auth.signOut();
          _setError('User profile not found. Please contact support.');
          _setLoading(false);
          return false;
        }

        final userData = FirebaseUserModel.fromFirestore(userDoc);

        // VALIDATE USER TYPE
        if (userData.userType != userType) {
          await FirebaseConfig.auth.signOut();
          _setError('This email is registered as ${userData.userType}. Please select the correct user type or use a different email.');
          _setLoading(false);
          return false;
        }

        _setUser(userData);
        _setLoading(false);
        return true;
      } else {
        _setError('Login failed');
        _setLoading(false);
        return false;
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          _setError('Invalid email or password. Please check your credentials.');
          break;
        case 'user-disabled':
          _setError('This account has been disabled. Please contact support.');
          break;
        case 'too-many-requests':
          _setError('Too many failed attempts. Please try again later.');
          break;
        default:
          _setError(e.message ?? 'Login failed');
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      _setLoading(false);
      return false;
    }
  }

  // Google Sign In - WITH USER TYPE VALIDATION
  Future<bool> signInWithGoogle(String userType) async {
    _setLoading(true);
    _setError(null);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return false; // User cancelled
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final authResult = await FirebaseConfig.auth.signInWithCredential(credential);

      if (authResult.user != null) {
        // Check if user profile exists
        final userDoc = await FirebaseConfig.usersCollection
            .doc(authResult.user!.uid)
            .get();

        if (!userDoc.exists) {
          // First time Google sign in - create profile with selected user type
          final userData = FirebaseUserModel(
            id: authResult.user!.uid,
            email: authResult.user!.email!,
            name: authResult.user!.displayName ?? googleUser.displayName,
            userType: userType,
            isEmailVerified: authResult.user!.emailVerified,
            avatarUrl: authResult.user!.photoURL,
            createdAt: DateTime.now(),
          );

          await FirebaseConfig.usersCollection
              .doc(authResult.user!.uid)
              .set(userData.toFirestore());

          _setUser(userData);
        } else {
          // Validate user type for existing Google users
          final userData = FirebaseUserModel.fromFirestore(userDoc);
          if (userData.userType != userType) {
            await FirebaseConfig.auth.signOut();
            await googleSignIn.signOut();
            _setError('This Google account is registered as ${userData.userType}. Please select the correct user type.');
            _setLoading(false);
            return false;
          }
          _setUser(userData);
        }

        _setLoading(false);
        return true;
      } else {
        _setError('Google sign in failed');
        _setLoading(false);
        return false;
      }
    } on FirebaseAuthException catch (e) {
      await GoogleSignIn().signOut();
      _setError('Google sign in failed: ${e.message}');
      _setLoading(false);
      return false;
    } catch (e) {
      await GoogleSignIn().signOut();
      _setError('Google sign in failed: $e');
      _setLoading(false);
      return false;
    }
  }

  // Reset Password
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _setError(null);

    try {
      await FirebaseConfig.auth.sendPasswordResetEmail(email: email);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _setError('No account found with this email address.');
          break;
        case 'invalid-email':
          _setError('Please enter a valid email address.');
          break;
        default:
          _setError(e.message ?? 'Failed to send reset email');
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to send reset email: $e');
      _setLoading(false);
      return false;
    }
  }

  // BYPASS: Mock OTP verification - always returns true
  Future<bool> verifyOtp(String email, String otp) async {
    _setLoading(true);
    _setError(null);

    await Future.delayed(const Duration(seconds: 1));

    if (_user != null) {
      // Update user as verified in Firestore
      await FirebaseConfig.usersCollection
          .doc(_user!.id)
          .update({'email_verified': true});

      _setUser(_user!.copyWith(isEmailVerified: true));
    }
    _setLoading(false);
    return true;
  }

  // BYPASS: Mock resend OTP - always returns true
  Future<bool> resendOtp(String email) async {
    _setLoading(true);
    _setError(null);

    await Future.delayed(const Duration(seconds: 1));

    _setLoading(false);
    return true;
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut(); // Sign out from Google
      await FirebaseConfig.auth.signOut();
      _setUser(null);
    } catch (e) {
      _setError('Sign out failed: $e');
    }
  }

  // Listen to auth state changes
  void listenToAuthChanges() {
    FirebaseConfig.auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        try {
          final userDoc = await FirebaseConfig.usersCollection
              .doc(firebaseUser.uid)
              .get();

          if (userDoc.exists) {
            _setUser(FirebaseUserModel.fromFirestore(userDoc));
          }
        } catch (e) {
          _setError('Failed to load user profile: $e');
        }
      } else {
        _setUser(null);
      }
    });
  }

  // Update user profile
  Future<bool> updateUserProfile({
    String? name,
    String? avatarUrl,
    String? securityPin,
  }) async {
    if (_user == null) return false;

    _setLoading(true);
    _setError(null);

    try {
      final updates = <String, dynamic>{};

      if (name != null) updates['name'] = name;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (securityPin != null) updates['security_pin'] = securityPin;

      if (updates.isNotEmpty) {
        updates['updated_at'] = FieldValue.serverTimestamp();

        await FirebaseConfig.usersCollection
            .doc(_user!.id)
            .update(updates);

        _setUser(_user!.copyWith(
          name: name ?? _user!.name,
          avatarUrl: avatarUrl ?? _user!.avatarUrl,
          securityPin: securityPin ?? _user!.securityPin,
        ));
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update profile: $e');
      _setLoading(false);
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}