import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/strings.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../services/auth_service.dart';

/// Lead Supervisor service — handles approval queue and notification APIs
class LeadSupervisorService {
  /// Get pending operator registrations
  static Future<ApiResult<List<UserModel>>> getPendingOperators({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/lead-supervisor/pending-operators'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        final List<dynamic> opsJson = responseBody['operators'] ?? [];
        final operators = opsJson
            .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
            .toList();
        return ApiResult(success: true, data: operators);
      } else {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? 'Failed to fetch pending operators.',
        );
      }
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Approve an operator
  static Future<ApiResult<void>> approveOperator({
    required String token,
    required String operatorId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppStrings.apiBaseUrl}/lead-supervisor/approve-operator/$operatorId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return ApiResult(success: true, message: responseBody['message']);
      } else {
        return ApiResult(success: false, message: responseBody['message'] ?? 'Failed to approve.');
      }
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Reject an operator
  static Future<ApiResult<void>> rejectOperator({
    required String token,
    required String operatorId,
    String? reason,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppStrings.apiBaseUrl}/lead-supervisor/reject-operator/$operatorId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason ?? ''}),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return ApiResult(success: true, message: responseBody['message']);
      } else {
        return ApiResult(success: false, message: responseBody['message'] ?? 'Failed to reject.');
      }
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get notifications
  static Future<ApiResult<List<NotificationModel>>> getNotifications({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/lead-supervisor/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        final List<dynamic> notifJson = responseBody['notifications'] ?? [];
        final notifications = notifJson
            .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
            .toList();
        return ApiResult(success: true, data: notifications);
      } else {
        return ApiResult(success: false, message: responseBody['message'] ?? 'Failed.');
      }
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get unread notification count
  static Future<ApiResult<int>> getUnreadCount({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/lead-supervisor/notifications/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return ApiResult(success: true, data: responseBody['count'] ?? 0);
      } else {
        return ApiResult(success: false, data: 0, message: 'Failed.');
      }
    } catch (e) {
      return ApiResult(success: false, data: 0, message: AppStrings.networkError);
    }
  }

  /// Mark notification as read
  static Future<ApiResult<void>> markNotificationRead({
    required String token,
    required String notificationId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppStrings.apiBaseUrl}/lead-supervisor/notifications/$notificationId/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      return ApiResult(success: responseBody['success'] == true);
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }
  /// Get reports for lead supervisor (all incidents grouped by supervisor)
  static Future<ApiResult<Map<String, dynamic>>> getReports({
    required String token,
    String? division,
    String? status,
    String? category,
    int? severity,
    String? fromDate,
    String? toDate,
    String? search,
    bool? isMockDrill,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (division != null) queryParams['division'] = division;
      if (status != null) queryParams['status'] = status;
      if (category != null) queryParams['category'] = category;
      if (severity != null) queryParams['severity'] = severity.toString();
      if (fromDate != null) queryParams['fromDate'] = fromDate;
      if (toDate != null) queryParams['toDate'] = toDate;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (isMockDrill != null) queryParams['isMockDrill'] = isMockDrill.toString();

      final uri = Uri.parse('${AppStrings.apiBaseUrl}/lead-supervisor/reports')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return ApiResult(success: true, data: responseBody);
      } else {
        return ApiResult(
          success: false,
          message: responseBody['message'] ?? 'Failed to fetch reports.',
        );
      }
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }
}
