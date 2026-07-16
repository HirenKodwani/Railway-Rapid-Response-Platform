import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/strings.dart';
import '../services/auth_service.dart';

/// Registration service — handles operator self-registration API call
class RegistrationService {
  /// Register a new operator (public — no auth required)
  /// POST /api/auth/register-operator
  static Future<ApiResult<Map<String, dynamic>>> registerOperator({
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/auth/register-operator'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 201 && responseBody['success'] == true) {
        return ApiResult(
          success: true,
          data: responseBody,
          message: responseBody['message'] ?? 'Registration submitted successfully.',
        );
      } else {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? 'Registration failed.',
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: AppStrings.networkError,
      );
    }
  }
}
