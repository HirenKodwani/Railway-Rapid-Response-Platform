import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/token_storage.dart';

/// Auth state — holds the current authentication status
class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final bool isAuthenticated;
  final String? errorMessage;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserModel? user,
    String? token,
    bool? isLoading,
    bool? isAuthenticated,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage,
    );
  }
}

/// Auth state notifier — manages authentication logic
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  Future<void> _syncFcmToken(String token) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await AuthService.updateFcmToken(token, fcmToken);
      }

      // Listen for future token changes and sync them automatically
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await AuthService.updateFcmToken(token, newToken);
      });
    } catch (e) {
      print('FCM Token sync error: $e');
    }
  }

  /// Attempt auto-login from stored token/user
  Future<bool> tryAutoLogin() async {
    try {
      final hasToken = await TokenStorage.hasToken();
      if (!hasToken) return false;

      final token = await TokenStorage.getToken();
      final user = await TokenStorage.getUser();

      if (token != null && user != null) {
        // Re-save to ensure SharedPreferences mirror is populated for background service
        await TokenStorage.saveToken(token);
        await TokenStorage.saveUser(user);
        
        await _syncFcmToken(token);

        state = AuthState(
          user: user,
          token: token,
          isAuthenticated: true,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Login with identifier (email/phone) and password
  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await AuthService.login(identifier, password);

    if (result.success && result.data != null) {
      // Save token and user data securely
      await TokenStorage.saveToken(result.data!.token);
      await TokenStorage.saveUser(result.data!.user);

      await _syncFcmToken(result.data!.token);

      state = AuthState(
        user: result.data!.user,
        token: result.data!.token,
        isAuthenticated: true,
        isLoading: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.message ?? 'Login failed',
      );
      return false;
    }
  }

  /// Logout — clear token and user data
  Future<void> logout() async {
    if (state.token != null) {
      await AuthService.logout(state.token!);
    }
    await TokenStorage.clearAll();
    state = AuthState();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Auth state provider (Riverpod)
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
