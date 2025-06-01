import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/models/user_model.dart';
import '../core/config/supabase_config.dart';

class AuthViewModel extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
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

  void _setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  // Initialize auth state
  Future<void> initializeAuth() async {
    try {
      final session = supabase.auth.currentSession;
      if (session != null) {
        // Get user profile from custom table
        final userProfile = await _getUserProfile(session.user.id);
        if (userProfile != null) {
          _setUser(UserModel.fromJson({
            ...session.user.toJson(),
            ...userProfile,
          }));
        } else {
          _setUser(UserModel.fromJson(session.user.toJson()));
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
      final existingProfile = await _getUserProfileByEmail(email);
      if (existingProfile != null) {
        _setError('An account with this email already exists as ${existingProfile['user_type']}. Please use a different email or login with the correct user type.');
        _setLoading(false);
        return false;
      }

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'user_type': userType,
        },
        emailRedirectTo: null, // Disable email confirmation
      );

      if (response.user != null) {
        // Create user profile in your custom table with user type
        await _createUserProfile(response.user!.id, name, email, userType);

        _setUser(UserModel(
          id: response.user!.id,
          email: email,
          name: name,
          userType: userType,
          isEmailVerified: true,
        ));

        _setLoading(false);
        return true;
      } else {
        _setError('Sign up failed');
        _setLoading(false);
        return false;
      }
    } on AuthException catch (e) {
      if (e.message.contains('User already registered')) {
        _setError('An account with this email already exists. Please login instead.');
      } else {
        _setError(e.message);
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
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Get user profile from your custom table
        final userProfile = await _getUserProfile(response.user!.id);

        if (userProfile == null) {
          _setError('User profile not found. Please contact support.');
          _setLoading(false);
          return false;
        }

        // VALIDATE USER TYPE
        final profileUserType = userProfile['user_type'];
        if (profileUserType != userType) {
          // Sign out the user since they logged in with wrong type
          await supabase.auth.signOut();
          _setError('This email is registered as $profileUserType. Please select the correct user type or use a different email.');
          _setLoading(false);
          return false;
        }

        _setUser(UserModel(
          id: response.user!.id,
          email: email,
          name: userProfile['name'] ?? response.user!.userMetadata?['name'],
          userType: profileUserType,
          isEmailVerified: true,
        ));

        _setLoading(false);
        return true;
      } else {
        _setError('Login failed');
        _setLoading(false);
        return false;
      }
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        _setError('Invalid email or password. Please check your credentials.');
      } else {
        _setError(e.message);
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
      const webClientId = 'YOUR_GOOGLE_WEB_CLIENT_ID'; // Replace with your Google Web Client ID
      const iosClientId = 'YOUR_GOOGLE_IOS_CLIENT_ID'; // Replace with your Google iOS Client ID

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        _setError('No access token found');
        _setLoading(false);
        return false;
      }
      if (idToken == null) {
        _setError('No ID token found');
        _setLoading(false);
        return false;
      }

      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        // Check if user profile exists
        final userProfile = await _getUserProfile(response.user!.id);

        if (userProfile == null) {
          // First time Google sign in - create profile with selected user type
          await _createUserProfile(
              response.user!.id,
              googleUser.displayName ?? 'Google User',
              response.user!.email!,
              userType
          );
        } else {
          // Validate user type for existing Google users
          final profileUserType = userProfile['user_type'];
          if (profileUserType != userType) {
            await supabase.auth.signOut();
            _setError('This Google account is registered as $profileUserType. Please select the correct user type.');
            _setLoading(false);
            return false;
          }
        }

        final finalUserProfile = userProfile ?? {
          'name': googleUser.displayName,
          'user_type': userType,
        };

        _setUser(UserModel(
          id: response.user!.id,
          email: response.user!.email!,
          name: googleUser.displayName ?? finalUserProfile['name'],
          userType: finalUserProfile['user_type'],
          isEmailVerified: true,
        ));

        _setLoading(false);
        return true;
      } else {
        _setError('Google sign in failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
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
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.locallegacy://reset-password/',
      );
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
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
      await supabase.auth.signOut();
      _setUser(null);
    } catch (e) {
      _setError('Sign out failed: $e');
    }
  }

  // Helper method to create user profile
  Future<void> _createUserProfile(String userId, String name, String email, String userType) async {
    try {
      await supabase.from('profiles').insert({
        'id': userId,
        'name': name,
        'email': email,
        'user_type': userType,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error creating user profile: $e');
    }
  }

  // Helper method to get user profile by ID
  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // NEW: Helper method to get user profile by email
  Future<Map<String, dynamic>?> _getUserProfileByEmail(String email) async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('email', email)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting user profile by email: $e');
      return null;
    }
  }

  // Listen to auth state changes
  void listenToAuthChanges() {
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          if (session?.user != null) {
            _setUser(UserModel.fromJson(session!.user.toJson()));
          }
          break;
        case AuthChangeEvent.signedOut:
          _setUser(null);
          break;
        case AuthChangeEvent.tokenRefreshed:
          if (session?.user != null) {
            _setUser(UserModel.fromJson(session!.user.toJson()));
          }
          break;
        default:
          break;
      }
    });
  }
}