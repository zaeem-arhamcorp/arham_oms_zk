package com.arhamerp.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.ActivityRecognitionResult

/**
 * Broadcast Receiver for Activity Recognition Updates
 * Receives activity detection results and updates the ActivityRecognitionManager
 */
class ActivityRecognitionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ActivityRecognitionReceiver"
        // Static reference to the manager for updates
        // This should be set from MainActivity during app initialization
        var activityManager: ActivityRecognitionManager? = null
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        try {
            Log.d(TAG, "🔔 onReceive() called by system")
            
            if (intent == null) {
                Log.w(TAG, "⚠️ Intent is null")
                return
            }
            
            Log.d(TAG, "   Intent action: ${intent.action}")
            Log.d(TAG, "   Has ActivityRecognitionResult: ${ActivityRecognitionResult.hasResult(intent)}")
            
            if (ActivityRecognitionResult.hasResult(intent)) {
                val result = ActivityRecognitionResult.extractResult(intent)
                if (result != null) {
                    Log.d(TAG, "✅ Activity recognition update received with ${result.probableActivities.size} activities")
                    result.probableActivities.forEach { activity ->
                        Log.d(TAG, "   📊 Detected: type=${activity.type}, confidence=${activity.confidence}%")
                    }
                    
                    if (activityManager != null) {
                        activityManager?.updateActivity(result)
                        Log.d(TAG, "✅ Manager updated with activity result")
                    } else {
                        Log.e(TAG, "❌ activityManager is NULL - cannot update!")
                    }
                } else {
                    Log.w(TAG, "⚠️ Could not extract ActivityRecognitionResult from intent")
                }
            } else {
                Log.w(TAG, "⚠️ Intent does not have ActivityRecognitionResult")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error processing activity recognition result: ${e.message}", e)
            e.printStackTrace()
        }
    }
}
