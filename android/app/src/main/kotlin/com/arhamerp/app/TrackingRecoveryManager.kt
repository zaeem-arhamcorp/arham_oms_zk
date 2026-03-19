package com.arhamerp.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object TrackingRecoveryManager {
    private const val TAG = "TrackingRecovery"
    private const val PREFS_FILE = "FlutterSharedPreferences"
    private const val KEY_ACTIVE_TRIP_ID = "flutter.active_trip_id"
    private const val KEY_ACTIVE_TOKEN = "flutter.active_token"
    private const val KEY_WATCHDOG_ENABLED = "tracking_watchdog_enabled"
    private const val REQUEST_CODE_ALARM = 31041
    private const val INTERVAL_MS = 5 * 60 * 1000L

    const val ACTION_TRACKING_WATCHDOG_ALARM = "com.arhamerp.app.ACTION_TRACKING_WATCHDOG_ALARM"

    fun startWatchdog(context: Context) {
        try {
            context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_WATCHDOG_ENABLED, true)
                .apply()

            scheduleNext(context, 20_000L)
            Log.d(TAG, "Watchdog enabled and scheduled")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start watchdog: ${e.message}")
        }
    }

    fun stopWatchdog(context: Context) {
        try {
            context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_WATCHDOG_ENABLED, false)
                .apply()

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(alarmPendingIntent(context))
            Log.d(TAG, "Watchdog disabled")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop watchdog: ${e.message}")
        }
    }

    fun onAlarm(context: Context, reason: String) {
        try {
            if (!isWatchdogEnabled(context)) {
                Log.d(TAG, "Alarm ignored, watchdog disabled")
                return
            }

            if (hasActiveTrip(context)) {
                startFlutterBackgroundService(context, reason)
            } else {
                Log.d(TAG, "No active trip found; skipping recovery start")
            }
        } finally {
            if (isWatchdogEnabled(context)) {
                scheduleNext(context, INTERVAL_MS)
            }
        }
    }

    fun onBootOrPackageReplaced(context: Context, reason: String) {
        try {
            if (!hasActiveTrip(context)) {
                Log.d(TAG, "Boot/package event with no active trip; skip")
                return
            }

            context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_WATCHDOG_ENABLED, true)
                .apply()

            startFlutterBackgroundService(context, reason)
            scheduleNext(context, INTERVAL_MS)
        } catch (e: Exception) {
            Log.e(TAG, "Failed handling boot/package event: ${e.message}")
        }
    }

    private fun isWatchdogEnabled(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            .getBoolean(KEY_WATCHDOG_ENABLED, false)
    }

    private fun hasActiveTrip(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val tripId = prefs.getLong(KEY_ACTIVE_TRIP_ID, -1L)
        val token = prefs.getString(KEY_ACTIVE_TOKEN, null)
        val isActive = tripId > 0 && !token.isNullOrBlank()
        Log.d(TAG, "hasActiveTrip=$isActive tripId=$tripId")
        return isActive
    }

    private fun startFlutterBackgroundService(context: Context, reason: String) {
        try {
            val serviceClass = Class.forName("id.flutter.flutter_background_service.BackgroundService")
            val intent = Intent(context, serviceClass)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.d(TAG, "Requested flutter background service start (reason=$reason)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start flutter background service: ${e.message}")
        }
    }

    private fun scheduleNext(context: Context, delayMs: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAt = System.currentTimeMillis() + delayMs
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            alarmPendingIntent(context)
        )
        Log.d(TAG, "Scheduled next watchdog alarm in ${delayMs}ms")
    }

    private fun alarmPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, TrackingWatchdogReceiver::class.java).apply {
            action = ACTION_TRACKING_WATCHDOG_ALARM
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, REQUEST_CODE_ALARM, intent, flags)
    }
}
