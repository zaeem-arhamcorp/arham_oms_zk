package com.arhamerp.app

import android.content.Context
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import com.google.android.gms.tasks.OnFailureListener
import com.google.android.gms.tasks.OnSuccessListener

/**
 * Activity Recognition Manager
 * Detects user activity (WALKING, DRIVING, STATIONARY, etc.) using Google Play Services
 * Maintains current activity state and provides methods to query it
 */
class ActivityRecognitionManager(private val context: Context) {
    companion object {
        private const val TAG = "ActivityRecognitionManager"
        private const val UPDATE_INTERVAL_MS = 5000L // Update every 5 seconds
        
        // Static instance reference used by ActivityRecognitionReceiver and background isolates
        // This allows direct access without MethodChannel (which doesn't work in background isolates)
        private var instance: ActivityRecognitionManager? = null
        
        /**
         * Get current activity directly (for background isolates and other contexts)
         * Queries the static instance maintained by ActivityRecognitionReceiver
         */
        fun getActivityStatic(): String {
            return instance?.getCurrentActivity() ?: "UNKNOWN"
        }
        
        /**
         * Get confidence directly (for background isolates and other contexts)
         */
        fun getConfidenceStatic(): Int {
            return instance?.getActivityConfidence() ?: 0
        }
        
        /**
         * Set the instance reference (called by MainActivity)
         */
        fun setInstance(manager: ActivityRecognitionManager) {
            instance = manager
        }
    }

    private var currentActivity = "UNKNOWN"
    private var currentActivityConfidence = 0
    private var isInitialized = false

    /**
     * Initialize activity recognition
     * Sets up listener for activity updates
     */
    fun initialize(): Boolean {
        return try {
            Log.d(TAG, "🚀 Initializing activity recognition...")
            Log.d(TAG, "   Package name: ${context.packageName}")
            Log.d(TAG, "   Update interval: ${UPDATE_INTERVAL_MS}ms")
            
            // Save initial state to SharedPreferences
            saveActivityToPreferences()
            Log.d(TAG, "   ✅ Initial state saved to SharedPreferences")
            
            // Verify permission is granted at native level
            val hasPermission = android.content.pm.PackageManager.PERMISSION_GRANTED ==
                ContextCompat.checkSelfPermission(
                    context,
                    android.Manifest.permission.ACTIVITY_RECOGNITION
                )
            Log.d(TAG, "   Permission check: ${if (hasPermission) "✅ GRANTED" else "❌ DENIED"}")
            
            // Request activity updates
            val pendingIntent = getActivityDetectionPendingIntent()
            Log.d(TAG, "   Created PendingIntent for receiver")
            
            ActivityRecognition.getClient(context)
                .requestActivityUpdates(UPDATE_INTERVAL_MS, pendingIntent)
                .addOnSuccessListener(OnSuccessListener<Void?> {
                    Log.d(TAG, "✅ SUCCESS: Activity updates requested from Google Play Services")
                    Log.d(TAG, "   BroadcastReceiver will listen for updates at ${ActivityRecognitionReceiver::class.simpleName}")
                    isInitialized = true
                })
                .addOnFailureListener(OnFailureListener { e ->
                    Log.e(TAG, "❌ FAILED: Could not request activity updates: ${e.message}", e)
                    Log.e(TAG, "   Exception type: ${e.javaClass.simpleName}")
                    isInitialized = false
                })
            
            Log.d(TAG, "✅ Initialization call completed (check logs above for success/failure)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Initialization error: ${e.message}", e)
            e.printStackTrace()
            false
        }
    }

    /**
     * Get current detected activity
     * Returns: WALKING, DRIVING, CYCLING, STATIONARY, or UNKNOWN
     */
    fun getCurrentActivity(): String {
        Log.d(TAG, "Current activity: $currentActivity (confidence: $currentActivityConfidence%)")
        return currentActivity
    }

    /**
     * Get confidence score for current activity (0-100)
     */
    fun getActivityConfidence(): Int {
        return currentActivityConfidence
    }

    /**
     * Update current activity from ActivityRecognitionResult
     * Called when new activity is detected
     * Also saves to SharedPreferences for background isolate access
     */
    fun updateActivity(result: ActivityRecognitionResult) {
        try {
            val activities = result.probableActivities
            
            if (activities.isEmpty()) {
                Log.d(TAG, "No activities detected")
                currentActivity = "UNKNOWN"
                currentActivityConfidence = 0
                saveActivityToPreferences()
                return
            }
            
            // Get most likely activity (first in list)
            val mostLikelyActivity = activities[0]
            currentActivityConfidence = mostLikelyActivity.confidence
            currentActivity = normalizeActivityType(mostLikelyActivity.type, mostLikelyActivity.confidence)
            
            Log.d(
                TAG,
                "Activity detected: $currentActivity (confidence: ${mostLikelyActivity.confidence}%)"
            )
            
            // Save to SharedPreferences for background isolate access (MethodChannel unavailable in background)
            saveActivityToPreferences()
            
            // Log all detected activities for debugging
            Log.d(TAG, "All detected activities:")
            for (activity in activities) {
                val activityName = getActivityTypeString(activity.type)
                Log.d(TAG, "  - $activityName: ${activity.confidence}%")
            }
        } catch (e: Exception) {
            Log.e(TAG, "⚠️ Error updating activity: ${e.message}", e)
            currentActivity = "UNKNOWN"
            currentActivityConfidence = 0
            saveActivityToPreferences()
        }
    }
    
    /**
     * Save current activity to SharedPreferences
     * Allows background isolates to read activity state (MethodChannels don't work there)
     */
    private fun saveActivityToPreferences() {
        try {
            val updatedAt = System.currentTimeMillis()

            // App-private prefs (native-only diagnostics/backward compatibility)
            val prefs = context.getSharedPreferences("activity_recognition", android.content.Context.MODE_PRIVATE)
            prefs.edit().apply {
                putString("current_activity", currentActivity)
                putInt("activity_confidence", currentActivityConfidence)
                putLong("activity_updated_at", updatedAt)
                apply()
            }

            // Flutter shared_preferences store. Keys must be prefixed with "flutter.".
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
            flutterPrefs.edit().apply {
                putString("flutter.current_activity", currentActivity)
                putInt("flutter.activity_confidence", currentActivityConfidence)
                putLong("flutter.activity_updated_at", updatedAt)
                apply()
            }
            Log.d(TAG, "✅ Activity saved to SharedPreferences: $currentActivity @ $updatedAt")
        } catch (e: Exception) {
            Log.e(TAG, "⚠️ Error saving to SharedPreferences: ${e.message}", e)
        }
    }

    /**
     * Normalize activity type from Android constant to standardized name
     * Returns: DRIVING, WALKING, CYCLING, STATIONARY, or UNKNOWN
     */
    private fun normalizeActivityType(activityType: Int, confidence: Int): String {
        return when (activityType) {
            DetectedActivity.IN_VEHICLE -> "DRIVING"
            DetectedActivity.ON_BICYCLE -> "CYCLING"
            DetectedActivity.WALKING, DetectedActivity.ON_FOOT -> "WALKING"
            DetectedActivity.RUNNING -> "WALKING" // Include running as walking for this app
            DetectedActivity.STILL -> "STATIONARY"
            DetectedActivity.TILTING -> "STATIONARY"
            else -> "UNKNOWN"
        }
    }

    /**
     * Get string representation of Android activity type (for logging)
     */
    private fun getActivityTypeString(activityType: Int): String {
        return when (activityType) {
            DetectedActivity.IN_VEHICLE -> "IN_VEHICLE"
            DetectedActivity.ON_BICYCLE -> "ON_BICYCLE"
            DetectedActivity.ON_FOOT -> "ON_FOOT"
            DetectedActivity.WALKING -> "WALKING"
            DetectedActivity.RUNNING -> "RUNNING"
            DetectedActivity.STILL -> "STILL"
            DetectedActivity.TILTING -> "TILTING"
            else -> "UNKNOWN"
        }
    }

    /**
     * Get PendingIntent for receiving activity updates
     * This should be implemented by the caller to route updates to ActivityRecognitionReceiver
     */
    private fun getActivityDetectionPendingIntent(): android.app.PendingIntent {
        val intent = android.content.Intent(context, ActivityRecognitionReceiver::class.java)
        return android.app.PendingIntent.getBroadcast(
            context,
            0,
            intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * Stop receiving activity updates
     */
    fun stop() {
        try {
            ActivityRecognition.getClient(context).removeActivityUpdates(
                getActivityDetectionPendingIntent()
            ).addOnSuccessListener {
                Log.d(TAG, "Activity updates stopped")
                isInitialized = false
            }.addOnFailureListener { e ->
                Log.e(TAG, "Failed to stop activity updates: ${e.message}", e)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping activity recognition: ${e.message}", e)
        }
    }
}
