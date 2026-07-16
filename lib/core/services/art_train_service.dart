import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/strings.dart';
import '../models/art_train_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// ART Train service — handles train CRUD and operator assignment APIs
class ArtTrainService {
  static const String _base = '${AppStrings.apiBaseUrl}/art-trains';

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// List trains for division
  static Future<ApiResult<List<ArtTrainModel>>> getTrains({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(_base),
        headers: _headers(token),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final trains = (body['trains'] as List<dynamic>)
            .map((j) => ArtTrainModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return ApiResult(success: true, data: trains);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Create train
  static Future<ApiResult<ArtTrainModel>> createTrain({
    required String token,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_base),
        headers: _headers(token),
        body: jsonEncode(data),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 && body['success'] == true) {
        return ApiResult(
          success: true,
          data: ArtTrainModel.fromJson(body['train'] as Map<String, dynamic>),
          message: body['message'],
        );
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Update train
  static Future<ApiResult<ArtTrainModel>> updateTrain({
    required String token,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_base/$id'),
        headers: _headers(token),
        body: jsonEncode(data),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(
          success: true,
          data: ArtTrainModel.fromJson(body['train'] as Map<String, dynamic>),
          message: body['message'],
        );
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Delete train
  static Future<ApiResult<void>> deleteTrain({
    required String token,
    required String id,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$_base/$id'),
        headers: _headers(token),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'],
      );
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get available supervisors (annotated with assignment status)
  static Future<ApiResult<List<Map<String, dynamic>>>> getAvailableSupervisors({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_base/available-supervisors'),
        headers: _headers(token),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final supervisors = (body['supervisors'] as List<dynamic>)
            .map((j) => j as Map<String, dynamic>)
            .toList();
        return ApiResult(success: true, data: supervisors);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Swap supervisor (force assign)
  static Future<ApiResult<void>> swapSupervisor({
    required String token,
    required String trainId,
    required String supervisorId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_base/$trainId/swap-supervisor'),
        headers: _headers(token),
        body: jsonEncode({'supervisor_id': supervisorId}),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'],
      );
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// List operators in train
  static Future<ApiResult<List<UserModel>>> getTrainOperators({
    required String token,
    required String trainId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_base/$trainId/operators'),
        headers: _headers(token),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final operators = (body['operators'] as List<dynamic>)
            .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return ApiResult(success: true, data: operators);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get available operators (approved, unassigned in division)
  static Future<ApiResult<List<UserModel>>> getAvailableOperators({
    required String token,
    required String trainId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_base/$trainId/available-operators'),
        headers: _headers(token),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final operators = (body['operators'] as List<dynamic>)
            .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return ApiResult(success: true, data: operators);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Add operators to train
  static Future<ApiResult<void>> addOperators({
    required String token,
    required String trainId,
    required List<String> operatorIds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_base/$trainId/operators'),
        headers: _headers(token),
        body: jsonEncode({'operatorIds': operatorIds}),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'],
      );
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Reassign operator to another train
  static Future<ApiResult<void>> reassignOperator({
    required String token,
    required String trainId,
    required String operatorId,
    required String newTrainId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_base/$trainId/operators/$operatorId/reassign'),
        headers: _headers(token),
        body: jsonEncode({'newTrainId': newTrainId}),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'],
      );
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Remove operator from train
  static Future<ApiResult<void>> removeOperator({
    required String token,
    required String trainId,
    required String operatorId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$_base/$trainId/operators/$operatorId'),
        headers: _headers(token),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult(
        success: body['success'] == true,
        message: body['message'],
      );
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }
}
