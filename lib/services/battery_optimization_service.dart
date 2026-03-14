import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryOptimizationService {
  static const platform = MethodChannel('com.arhamerp.app/battery');
  static const String _sessionKey = 'battery_optimization_shown_this_session';

  /// Check if battery optimization is enabled on the device
  static Future<bool> isBatteryOptimizationEnabled() async {
    try {
      print(
          '[BatteryOptimization] Calling platform method: isBatteryOptimizationEnabled');
      final bool result =
          await platform.invokeMethod('isBatteryOptimizationEnabled');
      print(
          '[BatteryOptimization] Platform returned: isBatteryOptimizationEnabled=$result');
      return result;
    } catch (e) {
      print('[BatteryOptimization] Error checking battery optimization: $e');
      return false; // Default to false if error
    }
  }

  /// Open battery optimization settings
  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await platform.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      print('[BatteryOptimization] Error opening settings: $e');
    }
  }

  /// Check if we should show the dialog (only once per session)
  static Future<bool> shouldShowDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool(_sessionKey) ?? false;
      print(
          '[BatteryOptimization] Checking shouldShowDialog: alreadyShown=$alreadyShown, key=$_sessionKey');

      if (alreadyShown) {
        print(
            '[BatteryOptimization] Dialog already shown this session, skipping');
        return false;
      }

      final isBatteryOptEnabled = await isBatteryOptimizationEnabled();
      print(
          '[BatteryOptimization] shouldShowDialog result: isBatteryOptEnabled=$isBatteryOptEnabled');
      return isBatteryOptEnabled;
    } catch (e) {
      print('[BatteryOptimization] Error checking if should show dialog: $e');
      return false;
    }
  }

  /// Mark dialog as shown for this session
  static Future<void> markDialogAsShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, true);
      print('[BatteryOptimization] Marked dialog as shown for this session');
    } catch (e) {
      print('[BatteryOptimization] Error marking dialog as shown: $e');
    }
  }

  /// Reset dialog flag for new login session
  /// Call this when user logs in to allow battery dialog to show again
  static Future<void> resetForNewSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      print('[BatteryOptimization] Reset flag for new login session');
    } catch (e) {
      print('[BatteryOptimization] Error resetting for new session: $e');
    }
  }
}
