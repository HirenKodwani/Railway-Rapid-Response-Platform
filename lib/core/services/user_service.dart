import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/strings.dart';
import '../models/user_model.dart';
import '../models/hierarchy_node.dart';
import '../services/auth_service.dart';

/// User management service — handles user CRUD API calls
class UserService {
  /// Create a new user (subordinate)
  /// Requires JWT token for authorization
  static Future<ApiResult<UserModel>> createUser({
    required Map<String, dynamic> userData,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/users/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(userData),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      // Handle token expiry globally
      if (response.statusCode == 401) {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? AppStrings.sessionExpired,
        );
      }

      if (response.statusCode == 201 && responseBody['success'] == true) {
        final user = UserModel.fromJson(responseBody['user']);
        return ApiResult(
          success: true,
          data: user,
          message: responseBody['message'] ?? 'User created successfully',
        );
      } else {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? 'Failed to create user',
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: AppStrings.networkError,
      );
    }
  }

  /// Fetch users created by the currently logged-in user
  /// Requires JWT token for authorization
  static Future<ApiResult<List<UserModel>>> getMyUsers({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      // Handle token expiry globally
      if (response.statusCode == 401) {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? AppStrings.sessionExpired,
        );
      }

      if (response.statusCode == 200 && responseBody['success'] == true) {
        final List<dynamic> usersJson = responseBody['users'] ?? [];
        final users = usersJson
            .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
            .toList();

        return ApiResult(
          success: true,
          data: users,
          message: 'Users fetched successfully',
        );
      } else {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? 'Failed to fetch users',
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: AppStrings.networkError,
      );
    }
  }

  /// Update an existing user
  /// PUT /api/users/:id
  static Future<ApiResult<UserModel>> updateUser({
    required String id,
    required Map<String, dynamic> userData,
    required String token,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppStrings.apiBaseUrl}/users/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(userData),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 401) {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? AppStrings.sessionExpired,
        );
      }

      if (response.statusCode == 200 && responseBody['success'] == true) {
        final user = UserModel.fromJson(responseBody['user']);
        return ApiResult(
          success: true,
          data: user,
          message: responseBody['message'] ?? 'User updated successfully',
        );
      } else {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? 'Failed to update user',
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: AppStrings.networkError,
      );
    }
  }

  /// Delete a user
  /// DELETE /api/users/:id
  static Future<ApiResult<void>> deleteUser({
    required String id,
    required String token,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppStrings.apiBaseUrl}/users/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 401) {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? AppStrings.sessionExpired,
        );
      }

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return ApiResult(
          success: true,
          message: responseBody['message'] ?? 'User deleted successfully',
        );
      } else {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? 'Failed to delete user',
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: AppStrings.networkError,
      );
    }
  }

  /// Fetch hierarchy tree
  /// GET /api/users/hierarchy
  static Future<ApiResult<HierarchyNode>> getHierarchyTree({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/users/hierarchy'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 401) {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? AppStrings.sessionExpired,
        );
      }

      if (response.statusCode == 200 && responseBody['success'] == true) {
        final hierarchy = HierarchyNode.fromJson(
          responseBody['hierarchy'] as Map<String, dynamic>,
        );
        return ApiResult(
          success: true,
          data: hierarchy,
          message: 'Hierarchy fetched successfully',
        );
      } else {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? 'Failed to fetch hierarchy',
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
