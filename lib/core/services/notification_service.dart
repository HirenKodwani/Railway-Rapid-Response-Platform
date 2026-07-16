import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../features/permissions/permission_gate_screen.dart';

/// Local Notification Service to handle Module 3 critical full-screen intents
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init([GlobalKey<NavigatorState>? key]) async {
    if (key != null) {
      navigatorKey = key;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Initialization (requires permission, but we request later)
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _backgroundNotificationResponse,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      _handlePayload(response.payload!);
    }
  }

  static void _handlePayload(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data['type'] == 'INCIDENT_ALERT') {
        final incidentId = data['incidentId'];
        if (incidentId != null && navigatorKey?.currentContext != null) {
          // Push to permission gate screen which handles fetching the full incident and showing the alert
          
          Navigator.of(navigatorKey!.currentContext!).push(
            MaterialPageRoute(
              builder: (_) => PermissionGateScreen(pendingIncidentId: incidentId),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  /// Trigger a local full-screen critical alert (used for late logins)
  Future<void> showCriticalIncidentAlert({
    required String title,
    required String body,
    required String payload,
  }) async {
    final Int32List insistentFlag = Int32List.fromList(<int>[4]);

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'CRITICAL_ALERT_V2', // Must match the one in MainActivity.kt
      'Emergency Alerts',
      channelDescription: 'High-priority critical alerts for railway incidents',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      enableVibration: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('hooter'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.call,
      additionalFlags: insistentFlag,
      ongoing: true,
      autoCancel: false,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'hooter.wav',
      interruptionLevel: InterruptionLevel.critical,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0, // ID
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}

@pragma('vm:entry-point')
void _backgroundNotificationResponse(NotificationResponse response) {
  // Background response handler
}
