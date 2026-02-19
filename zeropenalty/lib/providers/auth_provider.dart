import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _user = _authService.currentUser;
    _authService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  // Getters
  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get displayName => _user?.displayName ?? 'Driver';

  /// Sign up
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signUp(email: email, password: password);
    } catch (e) {
      debugPrint('SignUp error: $e');
      // Even if an exception was thrown, check if user was actually created
      if (_authService.currentUser == null) {
        _errorMessage = _mapError(e);
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }

    // If we reach here, user is created — try setting display name (non-critical)
    try {
      await _authService.updateDisplayName(name);
    } catch (_) {}

    _user = _authService.currentUser;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Sign in
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signIn(email: email, password: password);
    } catch (e) {
      debugPrint('SignIn error: $e');
      // Even if an exception was thrown, check if user is actually signed in
      if (_authService.currentUser == null) {
        _errorMessage = _mapError(e);
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }

    _user = _authService.currentUser;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Map any exception to a user-friendly message
  String _mapError(Object e) {
    String code = '';
    if (e is FirebaseAuthException) {
      code = e.code;
    } else if (e is FirebaseException) {
      code = e.code;
    } else {
      return e.toString();
    }
    return _getErrorMessage(code);
  }

  /// Human-readable error messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }
}
