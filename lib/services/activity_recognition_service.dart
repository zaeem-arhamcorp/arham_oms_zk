import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Activity Recognition Service
/// Detects if user is walking, driving, or stationary
/// Used to enhance location tracking with user activity context
class ActivityRecognitionService {
  static final ActivityRecognitionService _instance =
      ActivityRecognitionService._internal();

  factory ActivityRecognitionService() => _instance;

  ActivityRecognitionService._internal();

  static const platform =
      MethodChannel('com.arhamerp.app/activity_recognition');

  String _currentActivity = 'UNKNOWN';
  String get currentActivity => _currentActivity;

  /// Initialize activity recognition service
  /// Requests necessary permissions on Android 10+
  /// NOTE: Only works on main thread - safe to call from background, will gracefully fail
  Future<bool> initialize() async {
    try {
      print('[ActivityRecognitionService] Initializing...');

      // If running in background isolate, skip permission request
      // The permission should have already been requested during punch-in on main thread
      try {
        final permission = await _requestActivityPermission();
        if (!permission) {
          print(
              '[ActivityRecognitionService] ⚠️ Activity recognition permission not granted');
          // Continue anyway - activity detection will return UNKNOWN
          return true; // Still return true to not block tracking
        }

        // Ensure native Android activity updates are requested after permission is granted.
        // This is required because app-start initialization may happen before permission grant.
        try {
          final nativeInit = await platform
                  .invokeMethod<bool>('initializeActivityRecognition') ??
              false;
          print(
              '[ActivityRecognitionService] Native initializeActivityRecognition: $nativeInit');
        } on MissingPluginException {
          // Expected in background isolate.
          print(
              '[ActivityRecognitionService] ℹ️ Native initialize unavailable in background isolate');
        }
      } catch (e) {
        // If permission request fails (e.g., running in background isolate),
        // still allow service to continue - activity will default to UNKNOWN
        print(
            '[ActivityRecognitionService] ℹ️ Permission check failed (background?): $e');
        return true;
      }

      print('[ActivityRecognitionService] ✅ Initialized successfully');
      return true;
    } catch (e) {
      print('[ActivityRecognitionService] ⚠️ Initialization error: $e');
      // Don't throw - let tracking continue without activity detection
      return true;
    }
  }

  /// Request activity recognition permission (Android 10+)
  /// Checks if already granted, only requests if not
  Future<bool> _requestActivityPermission() async {
    try {
      // First check if permission is already granted
      PermissionStatus currentStatus =
          await Permission.activityRecognition.status;
      print(
          '[ActivityRecognitionService] Current permission status: $currentStatus');

      if (currentStatus.isGranted) {
        print(
            '[ActivityRecognitionService] ✅ Permission already granted in settings');
        return true;
      }

      if (currentStatus.isDenied) {
        print(
            '[ActivityRecognitionService] Permission denied, requesting from user...');
        final status = await Permission.activityRecognition.request();
        print('[ActivityRecognitionService] Request result: $status');
        return status.isGranted;
      }

      if (currentStatus.isPermanentlyDenied) {
        print(
            '[ActivityRecognitionService] ⚠️ Permission permanently denied, opening app settings...');
        openAppSettings();
        return false;
      }

      return currentStatus.isGranted;
    } catch (e) {
      print('[ActivityRecognitionService] ⚠️ Permission request error: $e');
      return false;
    }
  }

  /// Get current user activity (WALKING, DRIVING, STATIONARY, etc.)
  /// Returns the most recently detected activity via native channel
  /// Falls back to SharedPreferences if running in background isolate
  Future<String> getCurrentActivity() async {
    try {
      print('[ActivityRecognitionService] Fetching current activity...');

      try {
        // Try MethodChannel first (works from main thread only)
        final String activityType =
            await platform.invokeMethod<String>('getCurrentActivity') ??
                'UNKNOWN';

        _currentActivity = activityType;
        print(
            '[ActivityRecognitionService] Current activity detected: $_currentActivity');
        return _currentActivity;
      } on MissingPluginException catch (e) {
        // Background isolate - MethodChannel doesn't work
        // Fall back to SharedPreferences (updated by native code on main thread)
        print(
            '[ActivityRecognitionService] ℹ️ MethodChannel unavailable (background isolate?), reading from SharedPreferences...');
        return await _getCurrentActivityFromPreferences();
      }
    } catch (e) {
      print(
          '[ActivityRecognitionService] ⚠️ Error getting current activity: $e');
      _currentActivity = 'UNKNOWN';
      return 'UNKNOWN';
    }
  }

  /// Read activity from SharedPreferences (for background isolate fallback)
  Future<String> _getCurrentActivityFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activity = prefs.getString('current_activity') ?? 'UNKNOWN';
      final updatedAtRaw = prefs.get('activity_updated_at');
      final updatedAt = updatedAtRaw is int
          ? updatedAtRaw
          : (updatedAtRaw is double ? updatedAtRaw.toInt() : 0);

      print(
          '[ActivityRecognitionService] ✅ Activity from SharedPreferences: $activity (updated ${DateTime.fromMillisecondsSinceEpoch(updatedAt)})');

      _currentActivity = activity;
      return activity;
    } catch (e) {
      print(
          '[ActivityRecognitionService] ⚠️ Error reading from SharedPreferences: $e');
      _currentActivity = 'UNKNOWN';
      return 'UNKNOWN';
    }
  }

  /// Normalize activity type from native values to standardized names
  /// Handles: DRIVING, WALKING, CYCLING, STATIONARY, UNKNOWN
  String _normalizeActivityType(String rawType) {
    final normalized = rawType.toUpperCase();
    if (normalized.contains('VEHICLE') || normalized.contains('DRIVING')) {
      return 'DRIVING';
    } else if (normalized.contains('BICYCLE') ||
        normalized.contains('CYCLING')) {
      return 'CYCLING';
    } else if (normalized.contains('FOOT') ||
        normalized.contains('WALKING') ||
        normalized.contains('RUNNING')) {
      return 'WALKING';
    } else if (normalized.contains('STILL') ||
        normalized.contains('STATIONARY')) {
      return 'STATIONARY';
    }
    return 'UNKNOWN';
  }

  /// Get confidence score for current activity (0-100)
  /// Higher values indicate higher confidence
  Future<int> getActivityConfidence() async {
    try {
      final int confidence =
          await platform.invokeMethod<int>('getActivityConfidence') ?? 0;
      return confidence;
    } on PlatformException catch (e) {
      print(
          '[ActivityRecognitionService] ℹ️ Native activity recognition not available: ${e.message}');
      return 0;
    } catch (e) {
      print('[ActivityRecognitionService] ⚠️ Error getting confidence: $e');
      return 0;
    }
  }

  /// Map activity to API-compatible activity type
  /// Returns: 'WALKING', 'DRIVING', 'STATIONARY', or 'UNKNOWN'
  Future<String> getActivityTypeForApi() async {
    try {
      await getCurrentActivity();
      return _currentActivity;
    } catch (e) {
      print(
          '[ActivityRecognitionService] ⚠️ Error getting activity for API: $e');
      return 'UNKNOWN';
    }
  }
}
