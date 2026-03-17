package com.arhamerp.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.BatteryManager
import android.os.PowerManager
import android.content.Context
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.NotificationCompat
import android.app.Notification
import android.app.NotificationManager

class MainActivity : FlutterActivity() {
    private val BATTERY_CHANNEL = "com.arhamerp.app/battery"
    private val NOTIFICATION_CHANNEL = "com.arhamerp.app/notification"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBatteryOptimizationEnabled" -> {
                        result.success(isBatteryOptimizationEnabled())
                    }
                    "openBatteryOptimizationSettings" -> {
                        openBatteryOptimizationSettings()
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Notification channel for setting ongoing notifications
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setNotificationOngoing" -> {
                        val notificationId = call.argument<Int>("notificationId") ?: 1
                        val title = call.argument<String>("title") ?: "Location Tracking Active"
                        val message = call.argument<String>("message") ?: "Background location tracking is active"
                        setForegroundNotificationOngoing(notificationId, title, message)
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun isBatteryOptimizationEnabled(): Boolean {
        return try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (powerManager != null) {
                // Show dialog only if:
                // 1. Power save mode IS enabled (battery optimization is active)
                // 2. App is NOT exempted from battery optimization
                val isInPowerSaveMode = powerManager.isPowerSaveMode
                val isIgnoringBatteryOpt = powerManager.isIgnoringBatteryOptimizations(packageName)
                
                val shouldShowDialog = isInPowerSaveMode && !isIgnoringBatteryOpt
                
                android.util.Log.d("BatteryOptimization", 
                    "isBatteryOptimizationEnabled: isInPowerSaveMode=$isInPowerSaveMode, isIgnoringBatteryOpt=$isIgnoringBatteryOpt, shouldShow=$shouldShowDialog")
                
                shouldShowDialog
            } else {
                android.util.Log.d("BatteryOptimization", "PowerManager is null")
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("BatteryOptimization", "Error checking battery optimization: ${e.message}")
            false
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            // Try to open app-specific battery settings
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = android.net.Uri.fromParts("package", packageName, null)
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to device battery settings
            try {
                val intent = Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
                startActivity(intent)
            } catch (ex: Exception) {
                // Fallback to general settings
                try {
                    val intent = Intent(Settings.ACTION_SETTINGS)
                    startActivity(intent)
                } catch (exx: Exception) {
                    exx.printStackTrace()
                }
            }
        }
    }

    /**
     * Sets the foreground service notification as ongoing (non-dismissible).
     * Users cannot swipe away or dismiss the notification.
     * This is important for background location tracking to remain persistent.
     */
    private fun setForegroundNotificationOngoing(
        notificationId: Int,
        title: String,
        message: String
    ) {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            val notification = NotificationCompat.Builder(this, "background_location_service")
                .setContentTitle(title)
                .setContentText(message)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(false)
                .build()
            
            // Apply FLAG_ONGOING_EVENT to make it non-dismissible
            notification.flags = notification.flags or Notification.FLAG_ONGOING_EVENT

            manager.notify(notificationId, notification)
            android.util.Log.d("NotificationManager", "✅ Foreground notification set as ongoing (non-dismissible)")
        } catch (e: Exception) {
            android.util.Log.e("NotificationManager", "❌ Error setting notification ongoing: ${e.message}")
        }
    }
}
