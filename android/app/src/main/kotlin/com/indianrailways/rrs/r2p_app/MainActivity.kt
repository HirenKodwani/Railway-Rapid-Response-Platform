package com.indianrailways.rrs.r2p_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.app.Notification
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // FORCE the screen to wake up and show over the lock screen for full-screen intents
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(android.content.Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun onResume() {
        super.onResume()
        createIncidentAlertChannel()
    }

    /**
     * Creates the INCIDENT_ALERT_CHANNEL notification channel for Module 3.
     * Key: AudioAttributes.USAGE_ALARM bypasses silent/DND mode so the hooter
     * sound plays regardless of phone volume settings.
     * This is additive — existing channels are not modified.
     */
    private fun createIncidentAlertChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            // Only create if it doesn't already exist
            if (notificationManager.getNotificationChannel("CRITICAL_ALERT_V2") != null) {
                return
            }

            val channel = NotificationChannel(
                "CRITICAL_ALERT_V2",
                "Emergency Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High-priority critical alerts for railway incidents"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                // USAGE_ALARM is critical: it bypasses silent mode and DND
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setBypassDnd(true) // Explicitly bypass Do Not Disturb
                setSound(
                    Uri.parse("android.resource://${packageName}/raw/hooter"),
                    audioAttributes
                )
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.indianrailways.rrs/incident").setMethodCallHandler { call, result ->
            if (call.method == "getInitialIncident") {
                // Check if the activity was launched from the LockScreenActivity
                if (intent.getStringExtra("action") == "open_incident") {
                    val incidentId = intent.getStringExtra("incidentId")
                    result.success(incidentId)
                    
                    // Clear the intent action so we don't open it again on resume
                    intent.removeExtra("action")
                    intent.removeExtra("incidentId")
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
