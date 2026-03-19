import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationPermissionService {
  static const String _sessionKey = 'location_permission_shown_this_session';

  /// Check if user has "Allow all the time" location permission
  static Future<bool> hasBackgroundLocationPermission() async {
    try {
      print('[LocationPermission] Checking location permission...');
      final permission = await Geolocator.checkPermission();

      print('[LocationPermission]   Permission status: $permission');

      // Only LocationPermission.always is valid for background tracking
      if (permission == LocationPermission.always) {
        print('[LocationPermission] ✅ "Allow all the time" permission granted');
        return true;
      } else {
        print(
            '[LocationPermission] ❌ Permission is: $permission (needs "Always")');
        return false;
      }
    } catch (e) {
      print('[LocationPermission] ⚠️ Error checking permission: $e');
      return false;
    }
  }

  /// Request location permission
  static Future<LocationPermission> requestLocationPermission() async {
    try {
      print('[LocationPermission] Requesting location permission...');
      final permission = await Geolocator.requestPermission();
      print('[LocationPermission]   User response: $permission');
      return permission;
    } catch (e) {
      print('[LocationPermission] ⚠️ Error requesting permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Open location settings
  static Future<bool> openLocationSettings() async {
    try {
      print('[LocationPermission] Opening location settings...');
      final opened = await Geolocator.openLocationSettings();
      print('[LocationPermission] ✅ Location settings opened: $opened');
      return opened;
    } catch (e) {
      print('[LocationPermission] ⚠️ Error opening location settings: $e');
      return false;
    }
  }

  /// Check if we should show the dialog (only once per session)
  static Future<bool> shouldShowDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool(_sessionKey) ?? false;
      print(
          '[LocationPermission] Checking shouldShowDialog: alreadyShown=$alreadyShown, key=$_sessionKey');
      return !alreadyShown;
    } catch (e) {
      print('[LocationPermission] Error checking shouldShowDialog: $e');
      return false;
    }
  }

  /// Mark that we've shown the dialog this session
  static Future<void> markDialogShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, true);
      print('[LocationPermission] Marked dialog as shown this session');
    } catch (e) {
      print('[LocationPermission] Error marking dialog shown: $e');
    }
  }

  /// Reset the session flag (for testing or new login)
  static Future<void> resetSessionFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      print('[LocationPermission] Session flag reset');
    } catch (e) {
      print('[LocationPermission] Error resetting session flag: $e');
    }
  }
}
