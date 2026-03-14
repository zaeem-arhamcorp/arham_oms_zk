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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.arhamerp.app/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
}
