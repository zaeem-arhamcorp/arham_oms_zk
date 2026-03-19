package com.arhamerp.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class TrackingWatchdogReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.d("TrackingRecovery", "Watchdog alarm fired: ${intent?.action}")
        TrackingRecoveryManager.onAlarm(context, "watchdog_alarm")
    }
}
