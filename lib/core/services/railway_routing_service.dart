import 'package:dio/dio.dart';

class RailwayRoutingService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://anveshr312-railway-routing-service.hf.space',
    connectTimeout: const Duration(seconds: 120),
    receiveTimeout: const Duration(seconds: 120),
  ));

  Future<Map<String, dynamic>?> getRailRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final response = await _dio.post('/rail-route', data: {
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  Future<Map<String, dynamic>?> getNearestTrack({
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _dio.post('/nearest-track', data: {
        'lat': lat,
        'lng': lng,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }
}
