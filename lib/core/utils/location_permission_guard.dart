import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/colors.dart';
import 'package:geolocator/geolocator.dart';

/// Utility to enforce mandatory location permissions before accepting an incident.
class LocationPermissionGuard {
  /// Checks location permissions and shows a blocking dialog if not granted.
  /// Returns `true` if both `locationWhenInUse` and `locationAlways` are granted.
  static Future<bool> ensureLocationPermission(BuildContext context) async {
    if (kIsWeb) {
      LocationPermission webPerm = await Geolocator.checkPermission();
      if (webPerm == LocationPermission.always || webPerm == LocationPermission.whileInUse) {
        return true;
      }
      webPerm = await Geolocator.requestPermission();
      return (webPerm == LocationPermission.always || webPerm == LocationPermission.whileInUse);
    }
    
    // Check current status
    final inUseStatus = await Permission.locationWhenInUse.status;
    final alwaysStatus = await Permission.locationAlways.status;

    if (inUseStatus.isGranted && alwaysStatus.isGranted) {
      return true;
    }

    if (!context.mounted) return false;

    // Show blocking dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_on_rounded, color: AppColors.primaryNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Location Required',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Location access is mandatory to accept this incident. Your live location is required for attendance, proximity checks, and navigation. You cannot accept this incident without granting location permission. Please grant it to proceed.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Request permissions sequentially
              final inUseReq = await Permission.locationWhenInUse.request();
              if (inUseReq.isGranted) {
                final alwaysReq = await Permission.locationAlways.request();
                Navigator.of(ctx).pop(alwaysReq.isGranted);
              } else if (inUseReq.isPermanentlyDenied) {
                // If denied permanently, guide them to settings
                await openAppSettings();
                Navigator.of(ctx).pop(false);
              } else {
                Navigator.of(ctx).pop(false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Grant',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
