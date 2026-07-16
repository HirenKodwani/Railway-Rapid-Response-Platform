import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/strings.dart';
import '../services/auth_service.dart';

/// Operator service — read-only access to assigned train and supervisor info
class OperatorService {
  /// Get the operator's assignment (ART train + supervisor details)
  static Future<ApiResult<Map<String, dynamic>?>> getMyAssignment({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/operator/my-assignment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        // assignment can be null if not assigned
        return ApiResult(
          success: true,
          data: body['assignment'] as Map<String, dynamic>?,
          message: body['message'],
        );
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }
}
