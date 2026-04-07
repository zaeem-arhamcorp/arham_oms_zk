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
import android.app.NotificationChannel
import android.os.Build
import android.util.Log

class MainActivity : FlutterActivity() {
    private val BATTERY_CHANNEL = "com.arhamerp.app/battery"
    private val NOTIFICATION_CHANNEL = "com.arhamerp.app/notification"
    private val TRACKING_CONTROL_CHANNEL = "com.arhamerp.app/tracking_control"
    private val ACTIVITY_RECOGNITION_CHANNEL = "com.arhamerp.app/activity_recognition"
    private val MY_CHANNEL = "my_channel"
    
    private lateinit var activityRecognitionManager: ActivityRecognitionManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Initialize activity recognition manager
        activityRecognitionManager = ActivityRecognitionManager(this)
        ActivityRecognitionManager.setInstance(activityRecognitionManager)  // Register static instance
        activityRecognitionManager.initialize()  // CRITICAL: Start activity detection
        ActivityRecognitionReceiver.activityManager = activityRecognitionManager

        // Ensure notification channel is created
        createNotificationChannels()

        // Activity Recognition channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACTIVITY_RECOGNITION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initializeActivityRecognition" -> {
                        try {
                            val initialized = activityRecognitionManager.initialize()
                            Log.d("ActivityRecognitionChannel", "initializeActivityRecognition: $initialized")
                            result.success(initialized)
                        } catch (e: Exception) {
                            Log.e("ActivityRecognitionChannel", "Error initializing activity recognition: ${e.message}", e)
                            result.success(false)
                        }
                    }
                    "getCurrentActivity" -> {
                        try {
                            val activity = activityRecognitionManager.getCurrentActivity()
                            Log.d("ActivityRecognitionChannel", "getCurrentActivity: $activity")
                            result.success(activity)
                        } catch (e: Exception) {
                            Log.e("ActivityRecognitionChannel", "Error getting current activity: ${e.message}", e)
                            result.success("UNKNOWN")
                        }
                    }
                    "getActivityConfidence" -> {
                        try {
                            val confidence = activityRecognitionManager.getActivityConfidence()
                            Log.d("ActivityRecognitionChannel", "getActivityConfidence: $confidence")
                            result.success(confidence)
                        } catch (e: Exception) {
                            Log.e("ActivityRecognitionChannel", "Error getting confidence: ${e.message}", e)
                            result.success(0)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

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
                        android.util.Log.d("MethodChannel", "📲 setNotificationOngoing called from Dart")
                        val notificationId = call.argument<Int>("notificationId") ?: 888  // Use plugin's notification ID
                        val title = call.argument<String>("title") ?: "Location Tracking Active"
                        val message = call.argument<String>("message") ?: "Background location tracking is active. Please do not clear the app from background."
                        android.util.Log.d("MethodChannel", "   Title: $title, Message: $message, ID: $notificationId")
                        setForegroundNotificationOngoing(notificationId, title, message)
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Native watchdog channel to improve recovery after app swipe/kill.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRACKING_CONTROL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTrackingRecoveryWatchdog" -> {
                        TrackingRecoveryManager.startWatchdog(applicationContext)
                        result.success(true)
                    }

                    "stopTrackingRecoveryWatchdog" -> {
                        TrackingRecoveryManager.stopWatchdog(applicationContext)
                        result.success(true)
                    }

                    "stopForegroundService" -> {
                        stopForegroundLocationService()
                        result.success(true)
                    }

                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Manufacturer channel for one-time device-specific battery guidance in Flutter.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getManufacturer" -> {
                        result.success(Build.MANUFACTURER ?: "")
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
                // Check if app is restricted (NOT whitelisted) from battery optimization
                // isIgnoringBatteryOptimizations() returns:
                // - true: App is whitelisted (can run in background freely)
                // - false: App is restricted (battery optimization is limiting it)
                val isIgnoringBatteryOpt = powerManager.isIgnoringBatteryOptimizations(packageName)
                
                // Show dialog when app is NOT whitelisted (restricted from background)
                val shouldShowDialog = !isIgnoringBatteryOpt
                
                android.util.Log.d("BatteryOptimization", 
                    "isBatteryOptimizationEnabled: isIgnoringBatteryOpt=$isIgnoringBatteryOpt, shouldShow=$shouldShowDialog")
                
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
     * 
     * Uses the same notification channel and ID as flutter_background_service plugin.
     */
    private fun setForegroundNotificationOngoing(
        notificationId: Int,
        title: String,
        message: String
    ) {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Use the SAME channel ID as flutter_background_service plugin
            val notification = NotificationCompat.Builder(this, "flutter_background_service")
                .setContentTitle(title)
                .setContentText(message)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(false)
                .setOngoing(true)
                .build()
            
            // Apply FLAG_ONGOING_EVENT to make it non-dismissible
            notification.flags = notification.flags or Notification.FLAG_ONGOING_EVENT

            // Update the notification with the plugin's notification ID (888)
            manager.notify(notificationId, notification)
            android.util.Log.d("NotificationManager", "✅ Foreground notification updated: '$title' - '$message'")
            android.util.Log.d("NotificationManager", "   Channel: flutter_background_service, ID: $notificationId")
            
            // Post again after a short delay to ensure it sticks (in case plugin overwrites it)
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try {
                    manager.notify(notificationId, notification)
                    android.util.Log.d("NotificationManager", "🔄 Notification re-posted to ensure persistence")
                } catch (e: Exception) {
                    android.util.Log.e("NotificationManager", "Error re-posting notification: ${e.message}")
                }
            }, 300)
        } catch (e: Exception) {
            android.util.Log.e("NotificationManager", "❌ Error setting notification ongoing: ${e.message}")
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Create the flutter_background_service channel (high importance for persistent services)
            val backgroundServiceChannel = NotificationChannel(
                "flutter_background_service",
                "Background Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for background location tracking"
                enableVibration(false)
                enableLights(false)
                setSound(null, null)
            }
            manager.createNotificationChannel(backgroundServiceChannel)
            android.util.Log.d("NotificationChannel", "✅ Created 'flutter_background_service' channel")
            
            // Also ensure the app_channel exists
            val appChannel = NotificationChannel(
                "app_channel",
                "App Notifications",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "General app notifications"
            }
            manager.createNotificationChannel(appChannel)
        }
    }

    /**
     * Stops the foreground location tracking service.
     * This is called from Dart when the user punches out or logs out.
     * It stops the background service, dismisses the notification,
     * and ensures the watchdog won't restart it.
     */
    private fun stopForegroundLocationService() {
        try {
            android.util.Log.d("TrackingControl", "🛑 Stopping foreground location service...")
            
            // Step 1: Stop the FlutterBackgroundService
            val serviceIntent = Intent(this, id.flutter.flutter_background_service.BackgroundService::class.java)
            stopService(serviceIntent)
            android.util.Log.d("TrackingControl", "✅ Background service stopped")
            
            // Step 2: Cancel the ongoing notification
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(888)  // Use the same ID as flutter_background_service plugin
            android.util.Log.d("TrackingControl", "✅ Location tracking notification dismissed")

            // Step 3: Make sure watchdog is disabled (already should be from Dart side)
            TrackingRecoveryManager.stopWatchdog(applicationContext)
            android.util.Log.d("TrackingControl", "✅ Watchdog disabled")
            
            android.util.Log.d("TrackingControl", "✅ Foreground location service completely stopped")
        } catch (e: Exception) {
            android.util.Log.e("TrackingControl", "❌ Error stopping foreground service: ${e.message}")
            e.printStackTrace()
        }
    }
}
