import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/strings.dart';
import '../services/auth_service.dart';

class ProfileService {
  /// Update user password
  static Future<ApiResult<void>> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String token,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppStrings.apiBaseUrl}/users/profile/password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return ApiResult(
          success: true,
          message: responseBody['message'] ?? 'Password updated successfully',
        );
      } else {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? 'Failed to update password',
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
