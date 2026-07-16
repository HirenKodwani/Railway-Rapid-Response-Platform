import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Location result wrapper
class LocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final String? message;

  LocationResult({
    required this.success,
    this.latitude,
    this.longitude,
    this.message,
  });
}

/// Location service — handles GPS permission requests and coordinate fetching
class LocationService {
  /// Request location permission from the user
  /// Returns true if permission is granted
  static Future<bool> requestPermission() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      // User has permanently denied — they need to go to settings
      await openAppSettings();
      return false;
    }

    return false;
  }

  /// Check if location permission is already granted
  static Future<bool> hasPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Get current device location (lat/lng)
  /// Call requestPermission() first
  static Future<LocationResult> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          success: false,
          message:
              'Location services are disabled. Please enable GPS in your device settings.',
        );
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            success: false,
            message: 'Location permission was denied.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          success: false,
          message:
              'Location permission is permanently denied. Please enable it from app settings.',
        );
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return LocationResult(
        success: true,
        latitude: position.latitude,
        longitude: position.longitude,
        message: 'Location fetched successfully',
      );
    } catch (e) {
      return LocationResult(
        success: false,
        message: 'Failed to get location: ${e.toString()}',
      );
    }
  }
}
