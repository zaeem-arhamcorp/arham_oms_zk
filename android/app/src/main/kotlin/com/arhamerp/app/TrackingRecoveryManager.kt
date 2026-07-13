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

    // ── Global pointer (written by Dart on punch-in) ──────────────────────────
    // Stores the syncId of the firm currently being tracked.
    private const val KEY_CURRENT_TRACKING_SYNC_ID = "flutter.active_tracking_sync_id"

    // ── Legacy global keys (written by old app versions) ─────────────────────
    // Kept as fallback during migration period.
    private const val KEY_ACTIVE_TRIP_ID_LEGACY = "flutter.active_trip_id"
    private const val KEY_ACTIVE_TRIP_TOKEN_LEGACY = "flutter.active_trip_token"
    private const val KEY_ACTIVE_TOKEN_LEGACY = "flutter.active_token"
    private const val KEY_LOGIN_TOKEN = "flutter.token"
    private const val KEY_EXPLICITLY_STOPPED_LEGACY = "flutter.tracking_explicitly_stopped"

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

    /**
     * Determines if a punch-in tracking session is active.
     *
     * Strategy (multi-firm aware):
     * 1. Read `active_tracking_sync_id` — the global pointer written by Dart on punch-in.
     * 2. If found, build firm-specific keys: `active_trip_id_<syncId>` and `active_trip_token_<syncId>`.
     * 3. Also check firm-specific `tracking_explicitly_stopped_<syncId>` — if true, stop was intentional.
     * 4. Fall back to legacy global keys for devices that haven't done a punch cycle yet after the update.
     */
    private fun hasActiveTrip(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)

        // ── Step 1: Resolve the active firm via global pointer ────────────────
        // SharedPreferences integers are stored as Long in Android XML.
        val trackingSyncId = if (prefs.contains(KEY_CURRENT_TRACKING_SYNC_ID))
            prefs.getLong(KEY_CURRENT_TRACKING_SYNC_ID, -1L).takeIf { it > 0 }
        else null

        Log.d(TAG, "hasActiveTrip: trackingSyncId=$trackingSyncId")

        // ── Step 2: Firm-specific path ────────────────────────────────────────
        if (trackingSyncId != null) {
            val tripIdKey   = "flutter.active_trip_id_$trackingSyncId"
            val tripTokKey  = "flutter.active_trip_token_$trackingSyncId"
            val stoppedKey  = "flutter.tracking_explicitly_stopped_$trackingSyncId"

            val explicitlyStopped = prefs.getBoolean(stoppedKey, false)
            if (explicitlyStopped) {
                Log.d(TAG, "hasActiveTrip=false (firm $trackingSyncId explicitly stopped)")
                return false
            }

            val tripId = if (prefs.contains(tripIdKey))
                prefs.getLong(tripIdKey, -1L) else -1L

            val token = prefs.getString(tripTokKey, null)
                ?: prefs.getString(KEY_LOGIN_TOKEN, null)

            val isActive = tripId > 0 && !token.isNullOrBlank()
            Log.d(TAG, "hasActiveTrip=$isActive (firm-specific) tripId=$tripId hasToken=${!token.isNullOrBlank()} syncId=$trackingSyncId")
            return isActive
        }

        // ── Step 3: Legacy fallback ───────────────────────────────────────────
        val legacyStopped = prefs.getBoolean(KEY_EXPLICITLY_STOPPED_LEGACY, false)
        if (legacyStopped) {
            Log.d(TAG, "hasActiveTrip=false (legacy explicitly stopped)")
            return false
        }

        val tripId = prefs.getLong(KEY_ACTIVE_TRIP_ID_LEGACY, -1L)
        var tokenSource = "none"
        val token = when {
            !prefs.getString(KEY_ACTIVE_TRIP_TOKEN_LEGACY, null).isNullOrBlank() -> {
                tokenSource = "active_trip_token (legacy)"
                prefs.getString(KEY_ACTIVE_TRIP_TOKEN_LEGACY, null)
            }
            !prefs.getString(KEY_ACTIVE_TOKEN_LEGACY, null).isNullOrBlank() -> {
                tokenSource = "active_token (legacy)"
                prefs.getString(KEY_ACTIVE_TOKEN_LEGACY, null)
            }
            else -> {
                tokenSource = "login token"
                prefs.getString(KEY_LOGIN_TOKEN, null)
            }
        }
        val isActive = tripId > 0 && !token.isNullOrBlank()
        Log.d(TAG, "hasActiveTrip=$isActive (legacy) tripId=$tripId hasToken=${!token.isNullOrBlank()} tokenKey=$tokenSource")
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
