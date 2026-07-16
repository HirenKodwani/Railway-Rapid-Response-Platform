import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'offline_queue_service.dart';
import 'incident_service.dart';
import '../utils/token_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/strings.dart';

const String syncTaskName = "offline_sync_task";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == syncTaskName) {
      await SyncService.flushQueues();
    }
    return true;
  });
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  void init() {
    if (kIsWeb) {
      debugPrint("Skipping Workmanager initialization on Web");
      return;
    }

    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // Register a periodic task to run every 15 minutes, ensuring offline items sync even if app is closed
    Workmanager().registerPeriodicTask(
      "periodic_sync_task",
      syncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );

    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        // If network is restored, trigger immediate flush and register background task
        flushQueues();
        Workmanager().registerOneOffTask(
          "1",
          syncTaskName,
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
      }
    });
  }

  static bool _isFlushing = false;

  static Future<void> flushQueues() async {
    if (_isFlushing) return;
    _isFlushing = true;
    
    try {
      final token = await TokenStorage.getTokenForBackground();
      if (token == null) return;

      final db = OfflineQueueService();
      
      // Process Attendance
      final pendingAttendance = await db.getPendingAttendanceAndMarkProcessing();
      if (pendingAttendance.isNotEmpty) {
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var record in pendingAttendance) {
          final id = record['incident_id'] as String;
          if (!grouped.containsKey(id)) grouped[id] = [];
          grouped[id]!.add(record);
        }

        for (var incidentId in grouped.keys) {
          try {
            final records = grouped[incidentId]!;
            final locations = records.map((r) => {
              'latitude': r['latitude'],
              'longitude': r['longitude'],
              'geofenceCheckRequired': r['geofenceCheckRequired'] == 1,
              'client_timestamp': r['timestamp'],
            }).toList();

            final response = await http.post(
              Uri.parse('${AppStrings.apiBaseUrl}/incidents/$incidentId/bulk-location'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'locations': locations}),
            );

            if (response.statusCode == 200) {
              for (var r in records) {
                await db.deleteAttendance(r['id']);
              }
            } else {
              // Revert if API failed
              final failedIds = records.map((r) => r['id'] as int).toList();
              await db.revertAttendanceToPending(failedIds);
            }
          } catch (e) {
            debugPrint("Background Sync Bulk Attendance Error: $e");
            final failedIds = grouped[incidentId]!.map((r) => r['id'] as int).toList();
            await db.revertAttendanceToPending(failedIds);
          }
        }
      }

      // Process Media
      // Process Media
      final pendingMedia = await db.getPendingMediaAndMarkProcessing();
      final fastMedia = pendingMedia.where((m) => m['proof_type'] == 'TEXT' || m['proof_type'] == 'IMAGE').toList();
      final slowMedia = pendingMedia.where((m) => m['proof_type'] == 'AUDIO' || m['proof_type'] == 'VIDEO').toList();

      Future<void> uploadRecord(Map<String, dynamic> record) async {
        try {
          final uri = Uri.parse('${AppStrings.apiBaseUrl}/incidents/${record['incident_id']}/proofs');
          final request = http.MultipartRequest('POST', uri);
          request.headers['Authorization'] = 'Bearer $token';
          
          request.fields['proofType'] = record['proof_type'];
          request.fields['timestamp'] = record['timestamp']; // Offline timestamp
          request.fields['geostamp'] = jsonEncode({'lat': record['latitude'], 'lng': record['longitude']});
          
          if (record['device_model'] != null && record['device_os'] != null) {
            request.fields['deviceInfo'] = jsonEncode({'model': record['device_model'], 'os': record['device_os']});
          }
          
          if (record['upload_id'] != null) {
            request.fields['uploadId'] = record['upload_id'];
          }
          
          if (record['text_content'] != null && record['text_content'].toString().isNotEmpty) {
            request.fields['textContent'] = record['text_content'];
          }
          
          if (record['file_path'] != null && record['file_path'].toString().isNotEmpty) {
            final file = File(record['file_path']);
            if (await file.exists()) {
               request.files.add(await http.MultipartFile.fromPath('file', file.path));
            } else {
               // File lost, delete record to prevent infinite loop
               await db.deleteMedia(record['id']);
               return;
            }
          }
          
          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);
          
          if (response.statusCode == 200) {
            await db.deleteMedia(record['id']);
            // Delete local file to save storage as requested
            if (record['file_path'] != null && record['file_path'].toString().isNotEmpty) {
               final file = File(record['file_path']);
               if (await file.exists()) {
                 await file.delete();
               }
            }
          } else {
             // Revert to pending for retry later
             await db.revertMediaToPending(record['id']);
          }
        } catch (e) {
          debugPrint("Background Sync Media Error: $e");
          await db.revertMediaToPending(record['id']);
        }
      }

      // Concurrently upload fast media in batches of 3
      for (var i = 0; i < fastMedia.length; i += 3) {
        final batch = fastMedia.skip(i).take(3).toList();
        await Future.wait(batch.map((record) => uploadRecord(record)));
      }

      // Sequentially upload slow media (AUDIO, VIDEO) so we don't choke the connection
      for (var record in slowMedia) {
        await uploadRecord(record);
      }
    } finally {
      _isFlushing = false;
    }
  }
}
