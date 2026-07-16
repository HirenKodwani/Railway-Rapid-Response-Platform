import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/strings.dart';
import '../models/user_model.dart';

/// Result wrapper for API calls — typed result objects, not raw http responses
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? message;

  ApiResult({required this.success, this.data, this.message});
}

/// Authentication result containing token and user
class AuthResult {
  final String token;
  final UserModel user;

  AuthResult({required this.token, required this.user});
}

/// Authentication service — handles login API call
class AuthService {
  /// Login with email/phone identifier and password
  /// Returns `ApiResult<AuthResult>` with typed data
  static Future<ApiResult<AuthResult>> login(
    String identifier,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier.trim(),
          'password': password,
        }),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        final user = UserModel.fromJson(responseBody['user']);
        final token = responseBody['token'] as String;

        return ApiResult(
          success: true,
          data: AuthResult(token: token, user: user),
          message: 'Login successful',
        );
      } else {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? 'Login failed',
        );
      }
    } catch (e) {
      // Network or parsing error
      return ApiResult(
        success: false,
        message: 'Network error. Please check your connection and try again.',
      );
    }
  }

  /// Sync FCM token to the backend
  static Future<void> updateFcmToken(String token, String fcmToken) async {
    try {
      await http.put(
        Uri.parse('${AppStrings.apiBaseUrl}/users/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'fcmToken': fcmToken}),
      );
    } catch (e) {
      // Ignore errors silently for token sync
    }
  }

  /// Logout from backend (clears FCM token)
  static Future<void> logout(String token) async {
    try {
      await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      // Ignore errors silently
    }
  }
}
