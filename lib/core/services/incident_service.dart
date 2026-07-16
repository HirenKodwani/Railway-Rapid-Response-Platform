import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/strings.dart';
import '../models/incident_model.dart';
import '../services/auth_service.dart';

/// Incident service — handles all incident-related API calls
class IncidentService {
  /// Create a new incident
  static Future<ApiResult<IncidentModel>> createIncident({
    required String token,
    required String trainNumber,
    required double latitude,
    required double longitude,
    required String incidentCategory,
    required String incidentSubcategory,
    required String affectedComponent,
    required int severity,
    required List<String> requiredSpecialisations,
    required bool isMockDrill,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'train_number': trainNumber,
          'latitude': latitude,
          'longitude': longitude,
          'incident_category': incidentCategory,
          'incident_subcategory': incidentSubcategory,
          'affected_component': affectedComponent,
          'severity': severity,
          'requiredSpecialisations': requiredSpecialisations,
          'is_mock_drill': isMockDrill,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 && body['success'] == true) {
        return ApiResult(
          success: true,
          data: IncidentModel.fromJson(body['incident']),
          message: body['message'],
        );
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed to create incident.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// List all incidents for the current user
  static Future<ApiResult<List<IncidentModel>>> getIncidents({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final incidents = (body['incidents'] as List)
            .map((j) => IncidentModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return ApiResult(success: true, data: incidents);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get the currently active incident
  static Future<ApiResult<IncidentModel?>> getActiveIncident({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/active'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        if (body['incident'] == null) {
          return ApiResult(success: true, data: null);
        }
        return ApiResult(
          success: true,
          data: IncidentModel.fromJson(body['incident']),
        );
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get pending incidents for an operator (late login)
  static Future<ApiResult<List<IncidentModel>>> getPendingIncidentsForOperator({
    required String token,
    required String operatorId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/pending-for-operator/$operatorId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final incidents = (body['incidents'] as List)
            .map((j) => IncidentModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return ApiResult(success: true, data: incidents);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get a single incident by ID
  static Future<ApiResult<IncidentModel>> getIncident({
    required String token,
    required String incidentId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(
          success: true,
          data: IncidentModel.fromJson(body['incident']),
        );
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Resolve an active incident
  static Future<ApiResult<IncidentModel>> resolveIncident({
    required String token,
    required String incidentId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/resolve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(
          success: true,
          data: IncidentModel.fromJson(body['incident']),
          message: body['message'],
        );
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Operator responds to an incident (accept/decline)
  static Future<ApiResult<void>> respondToIncident({
    required String token,
    required String incidentId,
    required String action,
    String? reason,
    bool locationConsent = false,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'action': action,
          if (reason != null) 'reason': reason,
          'locationConsent': locationConsent,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, message: body['message']);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  static Future<ApiResult<Map<String, dynamic>>> postLocation({
    required String token,
    required String incidentId,
    required double latitude,
    required double longitude,
    bool geofenceCheckRequired = false,
    String? clientTimestamp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'geofenceCheckRequired': geofenceCheckRequired,
          if (clientTimestamp != null) 'client_timestamp': clientTimestamp,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, data: body);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get operator locations for incident map
  static Future<ApiResult<List<OperatorLocationModel>>> getOperatorLocations({
    required String token,
    required String incidentId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/locations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final locations = (body['locations'] as List)
            .map((j) => OperatorLocationModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return ApiResult(success: true, data: locations);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get ART train live location
  static Future<ApiResult<Map<String, dynamic>>> getArtTrainLocation({
    required String token,
    required String trainId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/art-trains/$trainId/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, data: body);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get ART Train ETA to incident
  static Future<ApiResult<Map<String, dynamic>>> getArtEta({
    required String token,
    required String incidentId,
    required double artLat,
    required double artLng,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/art-eta?artLat=$artLat&artLng=$artLng'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, data: body);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get Navigation Route from Operator to ART Train
  static Future<ApiResult<Map<String, dynamic>>> getOperatorToArtRoute({
    required String token,
    required double operatorLat,
    required double operatorLng,
    required double artLat,
    required double artLng,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/navigation/operator-to-art?operatorLat=$operatorLat&operatorLng=$operatorLng&artLat=$artLat&artLng=$artLng'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, data: body);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get Acceptance Log
  static Future<ApiResult<Map<String, dynamic>>> getAcceptanceLog({
    required String token,
    required String incidentId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/acceptance-log'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, data: body);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get Attendance Log
  static Future<ApiResult<Map<String, dynamic>>> getAttendanceLog({
    required String token,
    required String incidentId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/attendance-log'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, data: body);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get Response Log
  static Future<ApiResult<Map<String, dynamic>>> getResponseLog({
    required String token,
    required String incidentId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/response-log'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, data: body);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Generate Incident PDF Report
  static Future<ApiResult<Map<String, dynamic>>> generateReport({
    required String token,
    required String incidentId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/generate-report'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, data: body);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed to generate report.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Upload Proof to backend
  static Future<ApiResult<Map<String, dynamic>>> uploadProof({
    required String token,
    required String incidentId,
    required String proofType,
    String? filePath,
    String? textContent,
    required String timestamp,
    required Map<String, dynamic> geostamp,
    required Map<String, dynamic> deviceInfo,
    required String uploadId,
  }) async {
    try {
      final uri = Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/proofs');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      
      request.fields['proofType'] = proofType;
      request.fields['timestamp'] = timestamp;
      request.fields['geostamp'] = jsonEncode(geostamp);
      request.fields['deviceInfo'] = jsonEncode(deviceInfo);
      request.fields['uploadId'] = uploadId;
      
      if (textContent != null) {
        request.fields['textContent'] = textContent;
      }
      
      if (filePath != null) {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      }
      
      final streamedResponse = await request.send().timeout(const Duration(minutes: 15));
      final response = await http.Response.fromStream(streamedResponse);
      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, data: body);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed to upload proof.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }

  /// Get Proofs for an incident
  static Future<ApiResult<List<dynamic>>> getProofs({
    required String token,
    required String incidentId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/proofs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult(success: true, data: body['proofs']);
      }
      return ApiResult(success: false, message: body['message'] ?? 'Failed.');
    } catch (e) {
      return ApiResult(success: false, message: AppStrings.networkError);
    }
  }
}
