import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/strings.dart';
import '../models/art_train_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Supervisor service — read-only access to assigned ART train and operators
class SupervisorService {
  /// Get the supervisor's assigned ART train
  static Future<ApiResult<ArtTrainModel?>> getMyArtTrain({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/supervisor/my-art-train'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        if (body['train'] == null) {
          return ApiResult(success: true, data: null, message: body['message']);
        }
        return ApiResult(
          success: true,
          data: ArtTrainModel.fromJson(body['train'] as Map<String, dynamic>),
        );
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get operators assigned to the supervisor's train
  static Future<ApiResult<List<UserModel>>> getMyArtTrainOperators({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/supervisor/my-art-train/operators'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
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

  /// Update the supervisor's assigned ART train location
  static Future<ApiResult<bool>> updateMyArtTrainLocation({
    required String token,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppStrings.apiBaseUrl}/supervisor/my-art-train/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'lat': lat, 'lng': lng}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, data: true, message: body['message']);
      }
      return ApiResult(success: false, data: false, message: body['message'] ?? 'Failed to update location.');
    } catch (e) {
      return ApiResult(success: false, data: false, message: AppStrings.networkError);
    }
  }
}
