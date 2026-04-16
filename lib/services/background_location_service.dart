import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import 'package:http/http.dart' as http;
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/services/user_status_repository.dart';
import 'activity_recognition_service.dart';
import 'location_sync_service.dart';

/// Background Location Tracking Service
/// Captures GPS location every 40 seconds during active punch-in.
/// Stores locations locally in SQLite and syncs periodically when internet is available.
/// Continues running even when app is minimized or cleared from recent apps.
@pragma('vm:entry-point')
class BackgroundLocationService {
  static final BackgroundLocationService _instance =
      BackgroundLocationService._internal();

  factory BackgroundLocationService() => _instance;

  BackgroundLocationService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  final FlutterBackgroundService _service = FlutterBackgroundService();
  static const Duration _captureInterval = Duration(seconds: 40);
  static const String _activeTripTokenKey = 'active_trip_token';
  static const String _pendingAutoPunchOutKey = 'pending_auto_punch_out';
  static const String _pendingAutoPunchOutTripIdKey =
      'pending_auto_punch_out_trip_id';
  static const String _pendingAutoPunchOutSyncIdKey =
      'pending_auto_punch_out_sync_id';
  static const String _pendingAutoPunchOutTimeMsKey =
      'pending_auto_punch_out_time_ms';
  static const String _pendingAutoPunchOutLocIdKey =
      'pending_auto_punch_out_loc_id';
  static const platform = MethodChannel('com.arhamerp.app/notification');
  static const trackingControlPlatform =
      MethodChannel('com.arhamerp.app/tracking_control');

  bool _isRunning = false;
  String? _currentUserCd;
  int? _currentSyncId;
  String? _token;
  int? _currentTripId;

  // Guard against duplicate background tracking loops when resume/start is
  // triggered multiple times (for example, profile refresh + reconnect).
  static int _trackingLoopGeneration = 0;
  static bool _trackingLoopRunning = false;
  static int? _activeLoopTripId;
  static bool _commandListenersAttached = false;

  /// Check if background service is currently running
  bool get isRunning => _isRunning;

  String? get currentUserCd => _currentUserCd;

  int? get currentSyncId => _currentSyncId;

  int? get currentTripId => _currentTripId;

  static String _formatDateTimeForApi(int timestampMs) {
    // Use UTC with explicit timezone marker to avoid server-side timezone ambiguity.
    return DateTime.fromMillisecondsSinceEpoch(timestampMs)
        .toUtc()
        .toIso8601String();
  }

  static String _formatDateTimeWithOffsetForApi(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absOffset = offset.abs();
    final offsetHours = absOffset.inHours.toString().padLeft(2, '0');
    final offsetMinutes = (absOffset.inMinutes % 60).toString().padLeft(2, '0');

    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}$sign$offsetHours:$offsetMinutes';
  }

  static String _formatLocalDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _autoPunchOutDoneKeyForDate(DateTime dt) {
    return 'auto_punch_out_done_${_formatLocalDate(dt)}';
  }

  // Fallback classifier when native activity recognition is unavailable in background isolate.
  // GPS speed is often noisy and underestimated, so thresholds are calibrated conservatively:
  // - DRIVING: 3.0 m/s ≈ 10.8 km/h (typical car city speed, well above normal walking)
  // - WALKING: 0.5 m/s ≈ 1.8 km/h (very slow walk, accounts for GPS lag and urban canyon effects)
  // - STATIONARY: < 0.5 m/s (includes minor GPS jitter at rest)
  static String _inferActivityFromSpeed(double speedMps) {
    if (speedMps >= 3.0) return 'DRIVING';
    if (speedMps >= 0.5) return 'WALKING';
    return 'STATIONARY';
  }

  /// Check if the app has "Allow all the time" location permission
  /// Required for background location tracking to work
  Future<bool> hasBackgroundLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();

      print('[BackgroundLocationService] Checking location permission...');
      print('[BackgroundLocationService]   Permission status: $permission');

      // Only LocationPermission.always is valid for background tracking
      if (permission == LocationPermission.always) {
        print(
            '[BackgroundLocationService] ✅ "Allow all the time" permission granted');
        return true;
      } else {
        print(
            '[BackgroundLocationService] ❌ Permission is: $permission (needs "Always")');
        return false;
      }
    } catch (e) {
      print('[BackgroundLocationService] ⚠️ Error checking permission: $e');
      return false;
    }
  }

  /// Initialize background location service
  /// Should be called once during app startup
  Future<void> initialize() async {
    try {
      print('[BackgroundLocationService] Initializing background service...');

      // Configure the background service callback
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          // this will be executed when app is in foreground
          onStart: _onStart,
          // onIosConfiguration to inform ios app that you learned more about background service by installing flutter_background_service_ios package
          isForegroundMode: true,
          autoStart: false,
          autoStartOnBoot: false,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
      );

      print('[BackgroundLocationService] ✅ Background service initialized');
    } catch (e) {
      print('[BackgroundLocationService] ❌ Error initializing: $e');
    }
  }

  /// Update notification with current activity status
  /// Shows user what activity is being detected (WALKING, DRIVING, etc.)
  Future<void> updateNotificationWithActivity(String activityType) async {
    try {
      final message = activityType == 'UNKNOWN'
          ? 'Location tracking active (detecting activity...)'
          : 'Tracking: $activityType 📍';

      await setNotificationOngoing(
        title: 'Activity Recognition',
        message: message,
      );
    } catch (e) {
      print(
          '[BackgroundLocationService] ⚠️ Error updating activity notification: $e');
    }
  }

  /// Set foreground service notification as ongoing (non-dismissible)
  /// This prevents users from accidentally swiping away the location tracking notification
  Future<void> setNotificationOngoing({
    String title = 'Location Tracking Active',
    String message = 'Background location tracking is active',
  }) async {
    try {
      print(
          '[BackgroundLocationService] 📌 Setting notification as ongoing...');
      await platform.invokeMethod('setNotificationOngoing', {
        'notificationId':
            888, // Use flutter_background_service plugin's notification ID
        'title': title,
        'message': message,
      });
      print(
          '[BackgroundLocationService] ✅ Notification set as ongoing (non-dismissible)');
    } catch (e) {
      print(
          '[BackgroundLocationService] ⚠️ Error setting notification ongoing: $e');
    }
  }

  /// Start background location tracking service and initialize trip on server
  /// Should be called after successful punch-in
  /// Parameters:
  /// - userCd: Employee code
  /// - syncId: Organization ID
  /// - token: API authentication token
  /// - startLat: Punch-in latitude
  /// - startLng: Punch-in longitude
  /// Returns: {success: bool, trip_id: int, message: string, error?: string}
  Future<Map<String, dynamic>> startTracking({
    required String userCd,
    required int syncId,
    required String token,
    required double startLat,
    required double startLng,
    required String moduleNo,
    String tripName = 'Punch In Route',
  }) async {
    try {
      print('[BackgroundLocationService] 🚀 Starting background tracking...');
      print('[BackgroundLocationService]   User: $userCd');
      print('[BackgroundLocationService]   Sync ID: $syncId');

      // Verify permissions. Background tracking requires "always" permission.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[BackgroundLocationService] ❌ Location permission denied');
          return {
            'success': false,
            'message': 'Location permission denied',
            'error': 'Permission not granted',
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print(
            '[BackgroundLocationService] ❌ Location permission permanently denied');
        return {
          'success': false,
          'message': 'Location permission permanently denied',
          'error': 'Permission not granted',
        };
      }

      if (permission == LocationPermission.whileInUse) {
        print(
            '[BackgroundLocationService] ❌ Background location needs "Allow all the time" permission');
        return {
          'success': false,
          'message':
              'Please enable "Allow all the time" location permission for route tracking.',
          'error': 'Background location permission not granted',
        };
      }

      print('[BackgroundLocationService] ✅ Location permissions granted');

      final startTime = _formatDateTimeWithOffsetForApi(
        DateTime.now().millisecondsSinceEpoch,
      );

      // Step 1: Call /api/location/trip/start to initialize trip on server
      print('[BackgroundLocationService] 📤 Initiating trip on server...');
      print(
          '[BackgroundLocationService]   API URL: ${AppConfig.baseURL}location/trip/start');
      print(
          '[BackgroundLocationService]   Send data: start_time=$startTime, sync_id=$syncId, module_no=$moduleNo, trip_name=$tripName');
      try {
        print(
            '[BackgroundLocationService] API HIT: ${AppConfig.baseURL}location/trip/start');
        final parsedModuleNo = int.tryParse(moduleNo);
        final tripStartResponse = await http.post(
          Uri.parse('${AppConfig.baseURL}location/trip/start'),
          headers: {
            'Authorization': 'Bearer $token',
            'x-app-type': 'oms',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'sync_id': syncId,
            'module_no': parsedModuleNo ?? moduleNo,
            'trip_name': tripName,
            'start_time': startTime,
          }),
        );

        print('[BackgroundLocationService] ✅ Trip start response received');
        print(
            '[BackgroundLocationService]   HTTP Status: ${tripStartResponse.statusCode}');
        print(
            '[BackgroundLocationService]   Response Body: ${tripStartResponse.body}');

        if (tripStartResponse.statusCode != 200 &&
            tripStartResponse.statusCode != 201) {
          print(
              '[BackgroundLocationService] ❌ Trip start failed: ${tripStartResponse.statusCode}');
          print(
              '[BackgroundLocationService]   Response: ${tripStartResponse.body}');
          return {
            'success': false,
            'message': 'Failed to initialize trip on server',
            'error': 'Server error: ${tripStartResponse.statusCode}',
          };
        }

        // Parse trip_id from response
        int tripId = 0;
        try {
          // Assuming response has trip_id field
          final responseData = tripStartResponse.body;
          if (responseData.contains('trip_id')) {
            // Extract trip_id from response
            final match =
                RegExp(r'\"trip_id\"\s*:\s*(\d+)').firstMatch(responseData);
            if (match != null) {
              tripId = int.parse(match.group(1)!);
            }
          }
        } catch (e) {
          print('[BackgroundLocationService] ⚠️ Could not parse trip_id: $e');
        }

        if (tripId <= 0) {
          print('[BackgroundLocationService] ❌ Invalid trip_id received');
          return {
            'success': false,
            'message': 'Server did not return valid trip_id',
            'error': 'Invalid trip_id',
          };
        }

        print('[BackgroundLocationService] ✅ Trip created: trip_id=$tripId');

        // Store user info for the service in MEMORY
        _currentUserCd = userCd;
        _currentSyncId = syncId;
        _token = token;
        _currentTripId = tripId;
        _isRunning = true;

        // ALSO STORE IN PERSISTENT STORAGE in case app is backgrounded
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('active_trip_id', tripId);
          await prefs.setString('active_user_cd', userCd);
          await prefs.setInt('active_sync_id', syncId);
          await prefs.setString(_activeTripTokenKey, token);
          await prefs.setBool('tracking_explicitly_stopped', false);
          print(
              '[BackgroundLocationService] ✅ Trip data saved to SharedPreferences');
        } catch (e) {
          print(
              '[BackgroundLocationService] ⚠️ Could not save to SharedPreferences: $e');
        }

        // Start the background service
        await _service.startService();

        // Start native watchdog for extra recovery after app swipe/kill.
        try {
          await trackingControlPlatform
              .invokeMethod('startTrackingRecoveryWatchdog');
          print(
              '[BackgroundLocationService] ✅ Native tracking recovery watchdog enabled');
        } catch (e) {
          print(
              '[BackgroundLocationService] ⚠️ Could not enable native recovery watchdog: $e');
        }

        // Give the service a moment to fully initialize before updating notification
        await Future.delayed(const Duration(milliseconds: 500));

        // Set the notification as non-dismissible (non-swipeable)
        await setNotificationOngoing(
          title: 'Route Tracking Active',
          message:
              'Your location is being tracked during this route. Please DO NOT remove the app from background',
        );

        // Send initial configuration to the service
        _service.invoke('startLocationTracking', {
          'userCd': userCd,
          'syncId': syncId,
          'token': token,
          'tripId': tripId,
        });

        print('[BackgroundLocationService] ✅ Background tracking started');
        return {
          'success': true,
          'trip_id': tripId,
          'message': 'Tracking started successfully',
        };
      } catch (e) {
        print('[BackgroundLocationService] ❌ Error starting trip: $e');
        return {
          'success': false,
          'message': 'Failed to start trip',
          'error': e.toString(),
        };
      }
    } catch (e) {
      print('[BackgroundLocationService] ❌ Error starting tracking: $e');
      _isRunning = false;
      return {
        'success': false,
        'message': 'Failed to start tracking',
        'error': e.toString(),
      };
    }
  }

  /// Resume background tracking for an already active trip persisted locally.
  /// This is used by WorkManager after app process is killed.
  Future<bool> resumeTrackingIfActiveTrip() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final tripId = prefs.getInt('active_trip_id');
      final userCd = prefs.getString('active_user_cd');
      final syncId = prefs.getInt('active_sync_id');
      final token =
          prefs.getString(_activeTripTokenKey) ?? prefs.getString('token');
      final explicitlyStopped =
          prefs.getBool('tracking_explicitly_stopped') ?? false;
      final deferredAutoPunchOutPending =
          prefs.getBool(_pendingAutoPunchOutKey) ?? false;
      final autoPunchOutCompletedToday = await isAutoPunchOutCompletedToday();

      if (autoPunchOutCompletedToday) {
        print(
            '[BackgroundLocationService] Resume skipped: auto punch-out already completed today. Clearing stale active-trip context.');
        await prefs.setBool('tracking_explicitly_stopped', true);
        await prefs.remove('active_trip_id');
        await prefs.remove('active_user_cd');
        await prefs.remove('active_sync_id');
        await prefs.remove(_activeTripTokenKey);

        _isRunning = false;
        _currentUserCd = null;
        _currentSyncId = null;
        _token = null;
        _currentTripId = null;

        await dismissTrackingForegroundArtifacts();
        return false;
      }

      if (explicitlyStopped || deferredAutoPunchOutPending) {
        print(
            '[BackgroundLocationService] Resume skipped (explicit stop or deferred auto punch-out pending).');
        return false;
      }

      if (tripId == null || userCd == null || syncId == null || token == null) {
        print(
            '[BackgroundLocationService] No active trip in SharedPreferences. Skipping resume.');
        return false;
      }

      _currentTripId = tripId;
      _currentUserCd = userCd;
      _currentSyncId = syncId;
      _token = token;

      // Clear explicit-stop marker when we are intentionally resuming.
      await prefs.setBool('tracking_explicitly_stopped', false);

      bool serviceRunning = false;
      try {
        serviceRunning = await _service.isRunning();
      } catch (e) {
        print(
            '[BackgroundLocationService] Could not check service running state: $e');
      }

      if (!serviceRunning) {
        print(
            '[BackgroundLocationService] Recovering tracking service for active trip_id=$tripId');
        await _service.startService();

        // Give the plugin a brief moment to spin up the foreground isolate.
        await Future.delayed(const Duration(milliseconds: 700));

        bool startedAfterRecovery = false;
        try {
          startedAfterRecovery = await _service.isRunning();
        } catch (e) {
          print(
              '[BackgroundLocationService] Could not verify service state after recovery start: $e');
        }

        if (!startedAfterRecovery) {
          print(
              '[BackgroundLocationService] ⚠️ Recovery start requested but service is still not running');
          return false;
        }

        // Set the notification as non-dismissible when recovering
        await setNotificationOngoing(
          title: 'Route Tracking Resumed',
          message: 'Your location is being tracked during this route',
        );

        _service.invoke('startLocationTracking', {
          'userCd': userCd,
          'syncId': syncId,
          'token': token,
          'tripId': tripId,
        });
      } else {
        print(
            '[BackgroundLocationService] Background service already running. Reinitializing with new trip_id=$tripId');

        // Ensure the notification is set even when service is already running
        // (on resume/login to active trip scenario)
        try {
          await setNotificationOngoing(
            title: 'Route Tracking Active',
            message:
                'Your location is being tracked during this route. Please DO NOT remove the app from background',
          );
          print(
              '[BackgroundLocationService] ✅ Notification set for already-running service');
        } catch (e) {
          print(
              '[BackgroundLocationService] ⚠️ Could not set notification: $e');
        }

        // Service is running but we need to update it with the new trip_id
        _service.invoke('startLocationTracking', {
          'userCd': userCd,
          'syncId': syncId,
          'token': token,
          'tripId': tripId,
        });
      }

      _isRunning = true;
      return true;
    } catch (e) {
      print('[BackgroundLocationService] Error while resuming active trip: $e');
      return false;
    }
  }

  /// Stop background location tracking service.
  /// By default also ends the trip on server; can be skipped for punch-out flow
  /// so pending points sync before trip end.
  Future<void> stopTracking({bool endTripOnServer = true}) async {
    try {
      print('[BackgroundLocationService] 🛑 Stopping background tracking...');

      // Mark tracking as explicitly stopped so any accidental plugin/service
      // restart can self-terminate in _onStart.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('tracking_explicitly_stopped', true);
      } catch (e) {
        print(
            '[BackgroundLocationService] ⚠️ Could not persist explicit-stop marker: $e');
      }

      // Signal the service to stop (tracking loop will exit)
      _service.invoke('stopLocationTracking');

      // Ask background isolate to stop its service instance explicitly.
      // This prevents plugin-level restart behavior that can re-show
      // the default "Background Service / Preparing..." notification.
      _service.invoke('terminateService');

      // Disable native watchdog so it does not restart tracking after punch-out.
      try {
        await trackingControlPlatform
            .invokeMethod('stopTrackingRecoveryWatchdog');
        print(
            '[BackgroundLocationService] ✅ Native recovery watchdog disabled');
      } catch (e) {
        print(
            '[BackgroundLocationService] ⚠️ Could not disable native recovery watchdog: $e');
      }

      // Wait a moment for the service to stop
      await Future.delayed(Duration(milliseconds: 700));
      print('[BackgroundLocationService] ✅ Foreground service stopping...');

      // Try to get trip_id and token from memory first, then SharedPreferences
      int? tripIdToUse = _currentTripId;
      String? tokenToUse = _token;
      int? syncIdToUse = _currentSyncId;

      if (tripIdToUse == null || tokenToUse == null || syncIdToUse == null) {
        print(
            '[BackgroundLocationService] ⚠️ Trip data not in memory, checking SharedPreferences...');
        try {
          final prefs = await SharedPreferences.getInstance();
          tripIdToUse = prefs.getInt('active_trip_id');
          tokenToUse =
              prefs.getString(_activeTripTokenKey) ?? prefs.getString('token');
          syncIdToUse = prefs.getInt('active_sync_id');
          if (tripIdToUse != null &&
              tokenToUse != null &&
              syncIdToUse != null) {
            print(
                '[BackgroundLocationService] ✅ Retrieved trip data from SharedPreferences');
            print('[BackgroundLocationService]   trip_id=$tripIdToUse');
            print('[BackgroundLocationService]   sync_id=$syncIdToUse');
          }
        } catch (e) {
          print(
              '[BackgroundLocationService] ⚠️ Could not retrieve from SharedPreferences: $e');
        }
      }

      // End trip on server if requested and if we have trip_id+token
      if (endTripOnServer &&
          tripIdToUse != null &&
          tokenToUse != null &&
          syncIdToUse != null) {
        print(
            '[BackgroundLocationService] 📤 Ending trip on server (trip_id=$tripIdToUse)...');
        try {
          final endTime = _formatDateTimeWithOffsetForApi(
            DateTime.now().millisecondsSinceEpoch,
          );
          print(
              '[BackgroundLocationService]   Send data: trip_id=$tripIdToUse, end_time=$endTime, sync_id=$syncIdToUse');
          print(
              '[BackgroundLocationService] API HIT: ${AppConfig.baseURL}location/trip/end');
          final tripEndResponse = await http.post(
            Uri.parse('${AppConfig.baseURL}location/trip/end'),
            headers: {
              'Authorization': 'Bearer $tokenToUse',
              'x-app-type': 'oms',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'trip_id': tripIdToUse,
              'end_time': endTime,
              'sync_id': syncIdToUse,
            }),
          );

          if (tripEndResponse.statusCode == 200 ||
              tripEndResponse.statusCode == 201) {
            print(
                '[BackgroundLocationService] ✅ Trip ended successfully on server');
            // Clear SharedPreferences after successful end
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('active_trip_id');
              await prefs.remove('active_user_cd');
              await prefs.remove('active_sync_id');
              await prefs.remove(_activeTripTokenKey);
              print(
                  '[BackgroundLocationService] ✅ Cleared trip data from SharedPreferences');
            } catch (e) {
              print(
                  '[BackgroundLocationService] ⚠️ Could not clear SharedPreferences: $e');
            }
          } else {
            print(
                '[BackgroundLocationService] ⚠️ Trip end failed: ${tripEndResponse.statusCode}');
          }
        } catch (e) {
          print('[BackgroundLocationService] ⚠️ Error ending trip: $e');
        }
      } else if (endTripOnServer) {
        print(
            '[BackgroundLocationService] ⚠️ Missing trip_id or token - cannot end trip on server');
      } else {
        print(
            '[BackgroundLocationService] ℹ️ Trip end skipped now. Caller will end trip after pending sync.');
      }

      _isRunning = false;
      _currentUserCd = null;
      _currentSyncId = null;
      _token = null;
      _currentTripId = null;

      // ✅ STOP FOREGROUND SERVICE - Clear notification via platform channel
      print('[BackgroundLocationService] 🛑 Stopping foreground service...');
      try {
        // Invoke Android to stop the foreground service and dismiss notification
        await trackingControlPlatform.invokeMethod('stopForegroundService');
        print('[BackgroundLocationService] ✅ Foreground service stopped');
      } catch (e) {
        print(
            '[BackgroundLocationService] ⚠️ Error stopping foreground service: $e');
      }

      print(
          '[BackgroundLocationService] ✅ Background tracking completely stopped');
      print('[BackgroundLocationService]    - Tracking loop exited');
      print('[BackgroundLocationService]    - Foreground service STOPPED');
      print('[BackgroundLocationService]    - Notification DISMISSED');
      print(
          '[BackgroundLocationService]    - Trip end requested: $endTripOnServer');
      print('[BackgroundLocationService]    - All state cleared');
    } catch (e) {
      print('[BackgroundLocationService] ⚠️ Error stopping tracking: $e');
      _isRunning = false;
    }
  }

  /// End active trip on server using persisted trip data.
  /// Used when capture is already stopped and pending data has synced.
  Future<bool> endActiveTripOnServer() async {
    try {
      int? tripIdToUse = _currentTripId;
      String? tokenToUse = _token;
      int? syncIdToUse = _currentSyncId;

      if (tripIdToUse == null || tokenToUse == null || syncIdToUse == null) {
        final prefs = await SharedPreferences.getInstance();
        tripIdToUse = prefs.getInt('active_trip_id');
        tokenToUse =
            prefs.getString(_activeTripTokenKey) ?? prefs.getString('token');
        syncIdToUse = prefs.getInt('active_sync_id');
      }

      if (tripIdToUse == null || tokenToUse == null || syncIdToUse == null) {
        print(
            '[BackgroundLocationService] ⚠️ Missing trip/sync data, cannot end trip on server');
        return false;
      }

      print(
          '[BackgroundLocationService] API HIT: ${AppConfig.baseURL}location/trip/end');
      final endTime = _formatDateTimeWithOffsetForApi(
        DateTime.now().millisecondsSinceEpoch,
      );
      print(
          '[BackgroundLocationService]   Send data: trip_id=$tripIdToUse, end_time=$endTime, sync_id=$syncIdToUse');
      final tripEndResponse = await http.post(
        Uri.parse('${AppConfig.baseURL}location/trip/end'),
        headers: {
          'Authorization': 'Bearer $tokenToUse',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'trip_id': tripIdToUse,
          'end_time': endTime,
          'sync_id': syncIdToUse,
        }),
      );

      if (tripEndResponse.statusCode == 200 ||
          tripEndResponse.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('active_trip_id');
        await prefs.remove('active_user_cd');
        await prefs.remove('active_sync_id');
        await prefs.remove(_activeTripTokenKey);
        print(
            '[BackgroundLocationService] ✅ Trip ended and SharedPreferences cleared');
        return true;
      }

      print(
          '[BackgroundLocationService] ⚠️ Trip end failed: ${tripEndResponse.statusCode} ${tripEndResponse.body}');
      return false;
    } catch (e) {
      print('[BackgroundLocationService] ⚠️ Error ending trip on server: $e');
      return false;
    }
  }

  Future<bool> hasPendingAutoPunchOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingAutoPunchOutKey) ?? false;
  }

  Future<bool> isAutoPunchOutCompletedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _autoPunchOutDoneKeyForDate(DateTime.now());
    return prefs.getBool(key) ?? false;
  }

  /// Dismiss any lingering route-tracking foreground notification from main isolate.
  /// Safe to call after auto punch-out/deferred sync when no trip should remain active.
  Future<void> dismissTrackingForegroundArtifacts() async {
    try {
      await trackingControlPlatform.invokeMethod('stopForegroundService');
      print(
          '[BackgroundLocationService] ✅ Requested foreground service/notification dismissal');
    } catch (e) {
      print(
          '[BackgroundLocationService] ⚠️ Could not dismiss foreground service/notification: $e');
    }
  }

  /// Sync deferred auto punch-out trip-end call captured while offline.
  /// Uses the original offline timestamp for end_time.
  Future<bool> syncPendingAutoPunchOutIfNeeded(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPending = prefs.getBool(_pendingAutoPunchOutKey) ?? false;
      if (!hasPending) {
        return false;
      }

      final tripId = prefs.getInt(_pendingAutoPunchOutTripIdKey);
      final syncId = prefs.getInt(_pendingAutoPunchOutSyncIdKey);
      final endTimeMs = prefs.getInt(_pendingAutoPunchOutTimeMsKey);
      final pendingLocId = prefs.getInt(_pendingAutoPunchOutLocIdKey);

      if (tripId == null || syncId == null || endTimeMs == null) {
        print(
            '[AUTO-PUNCH-OUT] Pending offline auto punch-out data is incomplete. Clearing pending state.');
        await prefs.remove(_pendingAutoPunchOutKey);
        await prefs.remove(_pendingAutoPunchOutTripIdKey);
        await prefs.remove(_pendingAutoPunchOutSyncIdKey);
        await prefs.remove(_pendingAutoPunchOutTimeMsKey);
        await prefs.remove(_pendingAutoPunchOutLocIdKey);
        return false;
      }

      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) {
        print('[AUTO-PUNCH-OUT] Deferred trip-end sync skipped (offline).');
        return false;
      }

      if (pendingLocId != null) {
        final pendingLocations = await _db.getPendingLocations();
        final isPunchOutStillPending = pendingLocations.any((row) {
          final rowLocId = row['locId'];
          final parsedLocId = rowLocId is int
              ? rowLocId
              : int.tryParse(rowLocId?.toString() ?? '');
          return parsedLocId == pendingLocId;
        });

        if (isPunchOutStillPending) {
          print(
              '[AUTO-PUNCH-OUT] Waiting for local punch-out #$pendingLocId to sync before trip-end API call.');
          return false;
        }
      }

      final endTime = _formatDateTimeWithOffsetForApi(endTimeMs);
      print(
          '[AUTO-PUNCH-OUT] Syncing deferred trip-end with stored offline timestamp.');
      print('[AUTO-PUNCH-OUT] API HIT: ${AppConfig.baseURL}location/trip/end');
      print(
          '[AUTO-PUNCH-OUT]   Send data: trip_id=$tripId, end_time=$endTime, sync_id=$syncId');

      final endTripResponse = await http.post(
        Uri.parse('${AppConfig.baseURL}location/trip/end'),
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'trip_id': tripId,
          'end_time': endTime,
          'sync_id': syncId,
        }),
      );

      print(
          '[AUTO-PUNCH-OUT] Deferred /location/trip/end response: ${endTripResponse.statusCode}');

      if (endTripResponse.statusCode != 200 &&
          endTripResponse.statusCode != 201) {
        print(
            '[AUTO-PUNCH-OUT] Deferred trip end failed: ${endTripResponse.statusCode} ${endTripResponse.body}');
        return false;
      }

      await prefs.remove('active_trip_id');
      await prefs.remove('active_user_cd');
      await prefs.remove('active_sync_id');
      await prefs.remove(_activeTripTokenKey);
      await prefs.remove(_pendingAutoPunchOutKey);
      await prefs.remove(_pendingAutoPunchOutTripIdKey);
      await prefs.remove(_pendingAutoPunchOutSyncIdKey);
      await prefs.remove(_pendingAutoPunchOutTimeMsKey);
      await prefs.remove(_pendingAutoPunchOutLocIdKey);

      print('[AUTO-PUNCH-OUT] Deferred trip-end sync completed successfully.');
      return true;
    } catch (e) {
      print('[AUTO-PUNCH-OUT] Deferred trip-end sync exception: $e');
      return false;
    }
  }

  /// Callback for starting the background service (Android & iOS)
  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    print('[BackgroundLocationService] [Background] Service started');

    // Hard guard: if there is no active trip context or tracking was explicitly
    // stopped, do not allow the plugin service to remain alive.
    try {
      final prefs = await SharedPreferences.getInstance();
      final explicitlyStopped =
          prefs.getBool('tracking_explicitly_stopped') ?? false;
      final hasTrip = prefs.getInt('active_trip_id') != null;
      final hasUser = (prefs.getString('active_user_cd') ?? '').isNotEmpty;
      final hasSync = prefs.getInt('active_sync_id') != null;
      final hasToken = (prefs.getString(_activeTripTokenKey) ??
              prefs.getString('token') ??
              '')
          .isNotEmpty;

      if (explicitlyStopped || !(hasTrip && hasUser && hasSync && hasToken)) {
        print(
            '[BackgroundLocationService] [Background] No valid active trip context (or explicitly stopped); stopping self');
        await service.stopSelf();
        return;
      }
    } catch (e) {
      print(
          '[BackgroundLocationService] [Background] Guard check failed, stopping service to avoid ghost notification: $e');
      await service.stopSelf();
      return;
    }

    if (_commandListenersAttached) {
      print(
          '[BackgroundLocationService] [Background] Command listeners already attached, skipping re-attach');
      return;
    }
    _commandListenersAttached = true;

    // Handle service commands
    service.on('startLocationTracking').listen((event) async {
      final userCd = event?['userCd'] as String?;
      final syncId = event?['syncId'] as int?;
      final token = event?['token'] as String?;
      final tripId = event?['tripId'] as int?;

      if (userCd != null && syncId != null && token != null && tripId != null) {
        if (_trackingLoopRunning && _activeLoopTripId == tripId) {
          print(
              '[BackgroundLocationService] [Background] Duplicate start ignored for trip_id=$tripId');
          return;
        }

        final generation = ++_trackingLoopGeneration;
        print(
            '[BackgroundLocationService] [Background] Starting location tracking');
        print(
            '[BackgroundLocationService] [Background]   User: $userCd, Sync: $syncId, Trip: $tripId');

        if (_trackingLoopRunning) {
          print(
              '[BackgroundLocationService] [Background] Restarting active loop with new generation=$generation');
        }

        await _backgroundLocationTracking(
            service, userCd, syncId, token, tripId, generation);
      }
    });

    service.on('stopLocationTracking').listen((event) {
      _trackingLoopGeneration++;
      _trackingLoopRunning = false;
      _activeLoopTripId = null;
      print('[BackgroundLocationService] [Background] Received stop signal');
      // This will be handled by returning from _backgroundLocationTracking
    });

    service.on('terminateService').listen((event) async {
      _trackingLoopGeneration++;
      _trackingLoopRunning = false;
      _activeLoopTripId = null;
      print(
          '[BackgroundLocationService] [Background] Terminate command received, stopping service self');
      await service.stopSelf();
    });
  }

  /// Callback for iOS background
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }

  /// Main background location tracking loop
  /// Runs in the background and captures location every 40 seconds
  @pragma('vm:entry-point')
  static Future<void> _backgroundLocationTracking(
    ServiceInstance service,
    String userCd,
    int syncId,
    String token,
    int tripId,
    int generation,
  ) async {
    final db = DatabaseHelper();
    final activityRecognition = ActivityRecognitionService();
    _trackingLoopRunning = true;
    _activeLoopTripId = tripId;

    // Initialize activity recognition service
    print(
        '[BackgroundLocationService] [Background] Initializing activity recognition...');
    await activityRecognition.initialize();

    // Check if activity recognition is actually receiving updates (diagnostic)
    final initialUpdateCount =
        await activityRecognition.getDiagnosticUpdateCount();
    final lastUpdateTime =
        await activityRecognition.getDiagnosticLastUpdateTime();
    if (initialUpdateCount == 0) {
      print(
          '[BackgroundLocationService] [Background] ⚠️ WARNING: Activity Recognition may not be working - 0 updates received since app start');
      print(
          '[BackgroundLocationService] [Background]    Last activity update: ${lastUpdateTime ?? "NEVER"}');
      print(
          '[BackgroundLocationService] [Background]    Will fallback to GPS speed-based detection');
    } else {
      print(
          '[BackgroundLocationService] [Background] ✅ Activity Recognition initialized - $initialUpdateCount updates received');
      print(
          '[BackgroundLocationService] [Background]    Last update: $lastUpdateTime');
    }

    print(
        '[BackgroundLocationService] [Background] 🟢 Location tracking loop started');
    print(
        '[BackgroundLocationService] [Background]   Capture interval: 40 seconds');
    print(
        '[BackgroundLocationService] [Background]   Sync strategy: Immediate (after each capture)');
    print(
        '[BackgroundLocationService] [Background]   Heartbeat interval: 30 seconds (while tracking active)');
    print(
        '[HEARTBEAT] ACTIVE_TRIP_START: heartbeat lifecycle is now bound to punch-in tracking');

    final heartbeatRepository = UserStatusRepository();
    final locationSyncService = LocationSyncService();
    DateTime? lastHeartbeatAt;
    DateTime? lastAutoPunchOutAttemptAt;

    String formatDate(DateTime dt) {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    String formatTime(DateTime dt) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    }

    Future<bool> tryAutoPunchOutAt11Pm() async {
      final now = DateTime.now();

      // Trigger auto punch-out at 11:00 PM or later while tracking is active.
      if (now.hour < 23) {
        return false;
      }

      // Avoid hammering APIs every second on repeated failures.
      if (lastAutoPunchOutAttemptAt != null &&
          now.difference(lastAutoPunchOutAttemptAt!).inSeconds < 60) {
        return false;
      }
      lastAutoPunchOutAttemptAt = now;

      final today = formatDate(now);
      final autoDoneKey = 'auto_punch_out_done_$today';
      final prefs = await SharedPreferences.getInstance();

      if ((prefs.getBool(autoDoneKey) ?? false) == true) {
        print(
            '[AUTO-PUNCH-OUT] Already completed for $today. Stopping active tracking.');

        // Defensive cleanup in case stale active-trip context remained.
        await prefs.setBool('tracking_explicitly_stopped', true);
        await prefs.remove('active_trip_id');
        await prefs.remove('active_user_cd');
        await prefs.remove('active_sync_id');
        await prefs.remove(_activeTripTokenKey);

        final instance = BackgroundLocationService();
        instance._isRunning = false;
        instance._currentUserCd = null;
        instance._currentSyncId = null;
        instance._currentTripId = null;
        instance._token = null;

        return true;
      }

      print(
          '[AUTO-PUNCH-OUT] Trigger met at ${formatTime(now)} on $today. Starting auto punch out...');

      double lat = 0.0;
      double lng = 0.0;
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        lat = position.latitude;
        lng = position.longitude;
      } catch (e) {
        print('[AUTO-PUNCH-OUT] GPS unavailable, using 0,0 coordinates: $e');
      }

      final vouchDt = today;
      final vouchTime = formatTime(now);
      final createdAt = now.millisecondsSinceEpoch;

      final locId = await db.insertLocation({
        'USER_CD': userCd,
        'VOUCH_DT': vouchDt,
        'VOUCH_TIME': vouchTime,
        'LAT': lat,
        'LONGI': lng,
        'REMARK': 'PUNCH OUT',
        'SYNC_ID': syncId,
        'CREATED_BY': '',
        'CREATED_AT': createdAt,
        'UPDATED_BY': '',
        'UPDATED_AT': createdAt,
        'CREATED_APP_TYPE': 'oms',
        'MODULE_NO': '301',
        'sync_status': 'pending',
      });
      print('[AUTO-PUNCH-OUT] Local punch-out saved (locId=$locId)');

      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) {
        print(
            '[AUTO-PUNCH-OUT] Offline at trigger time. Stored punch-out locally and stopping tracking.');

        await prefs.setBool(_pendingAutoPunchOutKey, true);
        await prefs.setInt(_pendingAutoPunchOutTripIdKey, tripId);
        await prefs.setInt(_pendingAutoPunchOutSyncIdKey, syncId);
        await prefs.setInt(_pendingAutoPunchOutTimeMsKey, createdAt);
        await prefs.setInt(_pendingAutoPunchOutLocIdKey, locId);
        await prefs.setBool('tracking_explicitly_stopped', true);

        // tracking_control channel is registered on MainActivity engine only.
        // In background isolate, rely on persisted stop markers instead.
        print(
            '[AUTO-PUNCH-OUT] Background isolate: skipping watchdog channel call; using explicit-stop flags.');

        await prefs.remove('active_trip_id');
        await prefs.remove('active_user_cd');
        await prefs.remove('active_sync_id');
        await prefs.remove(_activeTripTokenKey);
        await prefs.setBool(autoDoneKey, true);

        final instance = BackgroundLocationService();
        instance._isRunning = false;
        instance._currentUserCd = null;
        instance._currentSyncId = null;
        instance._currentTripId = null;
        instance._token = null;

        print(
            '[AUTO-PUNCH-OUT] Offline punch-out captured. Deferred sync will end trip when internet is back.');
        return true;
      }

      print('[AUTO-PUNCH-OUT] API HIT: ${AppConfig.baseURL}locations');

      final punchOutResponse = await http.post(
        Uri.parse('${AppConfig.baseURL}locations'),
        body: {
          'lat': lat.toString(),
          'long': lng.toString(),
          'moduleNo': '301',
          'remarks': 'PUNCH OUT',
          'USER_CD': userCd,
          'vouchDt': vouchDt,
          'vouchTime': vouchTime,
          'LAT': lat.toString(),
          'LONGI': lng.toString(),
          'REMARK': 'PUNCH OUT',
          'SYNC_ID': syncId.toString(),
          'MODULE_NO': '301',
          'CREATED_BY': '',
          'CREATED_APP_TYPE': 'oms',
        },
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );
      print(
          '[AUTO-PUNCH-OUT] /locations response: ${punchOutResponse.statusCode}');

      if (punchOutResponse.statusCode != 200 &&
          punchOutResponse.statusCode != 201) {
        print(
            '[AUTO-PUNCH-OUT] Punch-out POST failed: ${punchOutResponse.statusCode} ${punchOutResponse.body}');
        return false;
      }

      await db.updateLocationSyncStatus(locId, 'synced', null);
      print('[AUTO-PUNCH-OUT] Punch-out POST successful and marked synced');

      final syncStats = await locationSyncService.syncAllLocations(token);
      print(
          '[AUTO-PUNCH-OUT] Synced pending location data: ${syncStats['total_synced']} synced, ${syncStats['total_failed']} failed');
      print('[AUTO-PUNCH-OUT] API HIT: ${AppConfig.baseURL}location/trip/end');

      final endTime = _formatDateTimeWithOffsetForApi(
        DateTime.now().millisecondsSinceEpoch,
      );
      print(
          '[AUTO-PUNCH-OUT]   Send data: trip_id=$tripId, end_time=$endTime, sync_id=$syncId');

      final endTripResponse = await http.post(
        Uri.parse('${AppConfig.baseURL}location/trip/end'),
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'trip_id': tripId,
          'end_time': endTime,
          'sync_id': syncId,
        }),
      );
      print(
          '[AUTO-PUNCH-OUT] /location/trip/end response: ${endTripResponse.statusCode}');

      if (endTripResponse.statusCode != 200 &&
          endTripResponse.statusCode != 201) {
        print(
            '[AUTO-PUNCH-OUT] Trip end failed: ${endTripResponse.statusCode} ${endTripResponse.body}');
        return false;
      }

      // tracking_control channel is registered on MainActivity engine only.
      // In background isolate, rely on persisted stop markers instead.
      print(
          '[AUTO-PUNCH-OUT] Background isolate: skipping watchdog channel call; using explicit-stop flags.');

      await prefs.remove('active_trip_id');
      await prefs.remove('active_user_cd');
      await prefs.remove('active_sync_id');
      await prefs.remove(_activeTripTokenKey);
      await prefs.remove(_pendingAutoPunchOutKey);
      await prefs.remove(_pendingAutoPunchOutTripIdKey);
      await prefs.remove(_pendingAutoPunchOutSyncIdKey);
      await prefs.remove(_pendingAutoPunchOutTimeMsKey);
      await prefs.remove(_pendingAutoPunchOutLocIdKey);
      await prefs.setBool(autoDoneKey, true);

      final instance = BackgroundLocationService();
      instance._isRunning = false;
      instance._currentUserCd = null;
      instance._currentSyncId = null;
      instance._currentTripId = null;
      instance._token = null;

      print('[AUTO-PUNCH-OUT] SUCCESS: User auto punched out at 11 PM.');
      return true;
    }

    Future<void> sendHeartbeatIfDue() async {
      final now = DateTime.now();
      if (lastHeartbeatAt != null &&
          now.difference(lastHeartbeatAt!).inSeconds < 30) {
        return;
      }

      print('[HEARTBEAT] POST_ATTEMPT: sending heartbeat to server...');
      print('[BackgroundLocationService] [Background] ❤️ Sending heartbeat...');
      final heartbeatOk = await heartbeatRepository.sendHeartbeat(token: token);

      if (heartbeatOk) {
        lastHeartbeatAt = now;
        print('[HEARTBEAT] POST_SUCCESS: server accepted heartbeat');
        print('[BackgroundLocationService] [Background] ✅ Heartbeat sent');
      } else {
        print('[HEARTBEAT] POST_FAILED: heartbeat call was not successful');
        print(
            '[BackgroundLocationService] [Background] ⚠️ Heartbeat send failed');
      }
    }

    Future<void> stopServiceForAutoPunchOut(String phase) async {
      try {
        if (service is AndroidServiceInstance) {
          try {
            await service.setAsBackgroundService();
            print(
                '[AUTO-PUNCH-OUT] Requested foreground demotion before stop ($phase).');
          } catch (e) {
            print(
                '[AUTO-PUNCH-OUT] Could not demote foreground service before stop ($phase): $e');
          }
        }
        await service.stopSelf();
      } catch (e) {
        print('[AUTO-PUNCH-OUT] Failed to stop service ($phase): $e');
      }
    }

    // Main tracking loop
    while (generation == _trackingLoopGeneration) {
      try {
        final autoPunchedOutBeforeCapture = await tryAutoPunchOutAt11Pm();
        if (autoPunchedOutBeforeCapture) {
          print(
              '[AUTO-PUNCH-OUT] Tracking loop exit after successful auto punch-out.');
          await stopServiceForAutoPunchOut('before-capture');
          return;
        }

        // Capture current location
        try {
          // Check internet status to determine appropriate timeout
          final isOnline = await NetworkHelper.hasInternet();
          final gpsTimeout = isOnline
              ? const Duration(
                  seconds: 10) // Online: GPS can use assisted location
              : const Duration(
                  seconds: 25); // Offline: Pure GPS needs more time

          print(
              '[BackgroundLocationService] [Background] 🌐 Internet: ${isOnline ? "ONLINE" : "OFFLINE"} - GPS timeout: ${gpsTimeout.inSeconds}s');

          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: gpsTimeout,
          );

          // Capture user activity (walking, driving, stationary)
          final activityType =
              await activityRecognition.getActivityTypeForApi();

          // Determine resolved activity: use speed-based detection if native returns UNKNOWN or STATIONARY
          // (STATIONARY from native might be stale; speed is a reliable real-time indicator of motion)
          final speedBasedActivity = _inferActivityFromSpeed(position.speed);
          final resolvedActivityType = (activityType == 'UNKNOWN' ||
                  (activityType == 'STATIONARY' &&
                      speedBasedActivity != 'STATIONARY'))
              ? speedBasedActivity
              : activityType;

          // Add detailed speed logging
          final speedStatus = activityType == 'UNKNOWN'
              ? '⚠️ (native not working, using GPS)'
              : (activityType == 'STATIONARY' &&
                      speedBasedActivity != 'STATIONARY')
                  ? '✅ (overridden by GPS)'
                  : '';

          print(
              '[BackgroundLocationService] [Background] 🔍 Activity Resolution: native=$activityType, gpsSpeed=${position.speed.toStringAsFixed(2)}m/s, speedDetected=$speedBasedActivity, resolved=$resolvedActivityType $speedStatus');

          // Update foreground notification from background isolate.
          // MethodChannels registered in MainActivity are unavailable here.
          try {
            final message = resolvedActivityType == 'UNKNOWN'
                ? 'Location tracking active (detecting activity...)'
                : 'Tracking: $resolvedActivityType';
            if (service is AndroidServiceInstance) {
              service.setForegroundNotificationInfo(
                title: 'Activity Recognition',
                content: message,
              );
            }
          } catch (e) {
            print(
                '[BackgroundLocationService] [Background] ⚠️ Could not update notification: $e');
          }

          final timestamp =
              (DateTime.now().millisecondsSinceEpoch / 1000).round();
          print(
              '[BackgroundLocationService] [Background] 📍 Captured location: ${position.latitude}, ${position.longitude}');
          print(
              '[BackgroundLocationService] [Background]   Accuracy: ${position.accuracy}m, Speed: ${position.speed}m/s, Altitude: ${position.altitude}m');
          print(
              '[BackgroundLocationService] [Background]   Activity: $resolvedActivityType');
          print(
              '[BackgroundLocationService] [Background]   Timestamp: $timestamp');

          // Store location in SQLite first (always, regardless of internet)
          try {
            print(
                '[BackgroundLocationService] [Background] 💾 Storing in local database...');
            final id = await db.insertLocationTracking(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: timestamp,
              userCd: userCd,
              syncId: syncId,
              tripId: tripId,
              accuracy: position.accuracy,
              speed: position.speed,
              altitude: position.altitude,
              activityType: resolvedActivityType,
            );
            print('[BackgroundLocationService] [Background] ✅ LOCAL DB STORED');
            print('[BackgroundLocationService] [Background]    Record ID: $id');
            print(
                '[BackgroundLocationService] [Background]    Trip ID: $tripId');
            print(
                '[BackgroundLocationService] [Background]    User: $userCd | Sync: $syncId');
            print(
                '[BackgroundLocationService] [Background]    Activity: $resolvedActivityType');

            // Step 2: Immediately try to sync this single location to server
            print(
                '[BackgroundLocationService] [Background] 📤 Starting immediate server sync...');
            await _syncSingleLocation(
                db,
                id,
                position.latitude,
                position.longitude,
                timestamp,
                position.accuracy,
                position.speed,
                position.altitude,
                tripId,
                token,
                activityType: resolvedActivityType);
          } catch (e) {
            print(
                '[BackgroundLocationService] [Background] ❌ Error storing location: $e');
          }
        } catch (e) {
          print('[BackgroundLocationService] [Background] ⚠️ GPS error: $e');

          // Fallback: Try to get last known location when current position fails
          try {
            print(
                '[BackgroundLocationService] [Background] 🔄 Attempting fallback: Using last known location...');
            final lastKnownPosition = await Geolocator.getLastKnownPosition();

            if (lastKnownPosition != null) {
              print(
                  '[BackgroundLocationService] [Background] ✅ Got last known location: ${lastKnownPosition.latitude}, ${lastKnownPosition.longitude}');

              // Store the last known location anyway (better than nothing for offline tracking)
              final activityType =
                  await activityRecognition.getActivityTypeForApi();
              final speedBasedActivity =
                  _inferActivityFromSpeed(lastKnownPosition.speed);
              final resolvedActivityType = (activityType == 'UNKNOWN' ||
                      (activityType == 'STATIONARY' &&
                          speedBasedActivity != 'STATIONARY'))
                  ? speedBasedActivity
                  : activityType;

              final timestamp =
                  (DateTime.now().millisecondsSinceEpoch / 1000).round();

              print(
                  '[BackgroundLocationService] [Background] 📍 Using fallback location: ${lastKnownPosition.latitude}, ${lastKnownPosition.longitude}');
              print(
                  '[BackgroundLocationService] [Background]   Accuracy: ${lastKnownPosition.accuracy}m, Speed: ${lastKnownPosition.speed}m/s, Altitude: ${lastKnownPosition.altitude}m');
              print(
                  '[BackgroundLocationService] [Background]   Activity: $resolvedActivityType');
              print(
                  '[BackgroundLocationService] [Background]   Timestamp: $timestamp');

              try {
                print(
                    '[BackgroundLocationService] [Background] 💾 Storing fallback location in local database...');
                final id = await db.insertLocationTracking(
                  latitude: lastKnownPosition.latitude,
                  longitude: lastKnownPosition.longitude,
                  timestamp: timestamp,
                  userCd: userCd,
                  syncId: syncId,
                  tripId: tripId,
                  accuracy: lastKnownPosition.accuracy,
                  speed: lastKnownPosition.speed,
                  altitude: lastKnownPosition.altitude,
                  activityType: resolvedActivityType,
                );
                print(
                    '[BackgroundLocationService] [Background] ✅ FALLBACK STORED');
                print(
                    '[BackgroundLocationService] [Background]    Record ID: $id');
                print(
                    '[BackgroundLocationService] [Background]    Trip ID: $tripId');
                print(
                    '[BackgroundLocationService] [Background]    User: $userCd | Sync: $syncId');
                print(
                    '[BackgroundLocationService] [Background]    Activity: $resolvedActivityType');
                print(
                    '[BackgroundLocationService] [Background]    Note: Location services disabled, using last known position');
              } catch (storageError) {
                print(
                    '[BackgroundLocationService] [Background] ❌ Error storing fallback location: $storageError');
              }
            } else {
              print(
                  '[BackgroundLocationService] [Background] ⚠️ No last known location available (device may have just enabled GPS)');
              print(
                  '[BackgroundLocationService] [Background]    This is normal on first capture attempt. Will retry in next cycle.');
            }
          } catch (fallbackError) {
            print(
                '[BackgroundLocationService] [Background] ⚠️ Fallback attempt also failed: $fallbackError');
            print(
                '[BackgroundLocationService] [Background]    💡 Tip: Enable Location Services on your device for better results');
          }
        }

        // Wait for the capture interval before next capture
        // Using periodic check in case service is stopped
        print(
            '[BackgroundLocationService] [Background] ⏳ Waiting 40 seconds before next capture cycle...');
        for (int i = 0; i < _captureInterval.inSeconds; i++) {
          if (generation != _trackingLoopGeneration) {
            print(
                '[BackgroundLocationService] [Background] Service stopped, exiting loop');
            return;
          }
          await sendHeartbeatIfDue();
          final autoPunchedOutDuringWait = await tryAutoPunchOutAt11Pm();
          if (autoPunchedOutDuringWait) {
            print(
                '[AUTO-PUNCH-OUT] Tracking loop exit during wait after successful auto punch-out.');
            await stopServiceForAutoPunchOut('during-wait');
            return;
          }
          await Future.delayed(const Duration(seconds: 1));
        }
        print('[BackgroundLocationService] [Background] ');
      } catch (e) {
        print(
            '[BackgroundLocationService] [Background] ❌ Error in tracking loop: $e');
        // Continue trying even on errors
        await Future.delayed(const Duration(seconds: 10));
      }
    }

    // Only the active generation may clear loop state.
    if (generation == _trackingLoopGeneration) {
      _trackingLoopRunning = false;
      _activeLoopTripId = null;
    }

    print(
        '[BackgroundLocationService] [Background] 🛑 Location tracking loop stopped');
  }

  /// Sync a single location immediately after capture
  /// If online: sends to server immediately
  /// If offline: leaves as unsynced for later retry
  static Future<void> _syncSingleLocation(
    DatabaseHelper db,
    int recordId,
    double latitude,
    double longitude,
    int timestamp,
    double accuracy,
    double speed,
    double altitude,
    int tripId,
    String token, {
    String activityType = 'UNKNOWN',
  }) async {
    try {
      final syncStartTime = DateTime.now();

      // Check internet connection
      print(
          '[BackgroundLocationService] [Background]    🌐 Checking internet connection...');
      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) {
        print(
            '[BackgroundLocationService] [Background] ❌ NO INTERNET - Cannot sync');
        print(
            '[BackgroundLocationService] [Background]    Record id=$recordId will be retried when online');
        return;
      }
      print('[BackgroundLocationService] [Background]    ✅ Internet available');

      final payload = {
        'trip_id': tripId,
        'lat': latitude,
        'lng': longitude,
        'accuracy': accuracy > 0 ? accuracy : null,
        'speed': speed > 0 ? speed : null,
        'altitude': altitude != 0 ? altitude : null,
        'timestamp': timestamp,
        'activity_type': activityType,
      };

      print(
          '[BackgroundLocationService] [Background]    📨 HTTP POST Request Details:');
      print(
          '[BackgroundLocationService] [Background]       URL: ${AppConfig.baseURL}location/update');
      print('[BackgroundLocationService] [Background]       Method: POST');
      print(
          '[BackgroundLocationService] [Background]       Content-Type: application/json');
      print('[BackgroundLocationService] [Background]       Payload:');
      print('[BackgroundLocationService] [Background]         {');
      print(
          '[BackgroundLocationService] [Background]           \"trip_id\": \"${payload['trip_id']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"lat\": \"${payload['lat']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"lng\": \"${payload['lng']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"accuracy\": \"${payload['accuracy']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"speed\": \"${payload['speed']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"altitude\": \"${payload['altitude']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"activity_type\": \"${payload['activity_type']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"timestamp\": \"${payload['timestamp']}\",');
      print(
          '[BackgroundLocationService] [Background]           \"timestamp_datetime\": \"${payload['timestamp_datetime']}\"');
      print('[BackgroundLocationService] [Background]         }');

      // Send to server via /api/location/update endpoint
      print('[BackgroundLocationService] [Background]    ⏳ Sending request...');
      print(
          '[BackgroundLocationService] [Background] API HIT: ${AppConfig.baseURL}location/update');
      final response = await http.post(
        Uri.parse('${AppConfig.baseURL}location/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final syncEndTime = DateTime.now();
      final syncElapsed = syncEndTime.difference(syncStartTime).inMilliseconds;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Mark as synced
        await db.markLocationTrackingSynced(recordId);
        print(
            '[BackgroundLocationService] [Background] ✅ SERVER SYNC SUCCESS (${syncElapsed}ms)');
        print(
            '[BackgroundLocationService] [Background]    Status Code: ${response.statusCode}');
        print(
            '[BackgroundLocationService] [Background]    Record ID: $recordId');
        print('[BackgroundLocationService] [Background]    Trip ID: $tripId');
        print(
            '[BackgroundLocationService] [Background]    Action: Marked as synced in local DB');
        print(
            '[BackgroundLocationService] [Background]    Server Response: ${response.body}');
      } else {
        print(
            '[BackgroundLocationService] [Background] ⚠️ SERVER SYNC FAILED (${syncElapsed}ms)');
        print(
            '[BackgroundLocationService] [Background]    Status Code: ${response.statusCode}');
        print(
            '[BackgroundLocationService] [Background]    Record ID: $recordId');
        print(
            '[BackgroundLocationService] [Background]    Server Error: ${response.body}');
        print(
            '[BackgroundLocationService] [Background]    Action: Will retry on next scheduled retry');
      }
    } catch (e) {
      print('[BackgroundLocationService] [Background] ❌ SYNC EXCEPTION');
      print('[BackgroundLocationService] [Background]    Record ID: $recordId');
      print('[BackgroundLocationService] [Background]    Error: $e');
      print(
          '[BackgroundLocationService] [Background]    Action: Will retry on next scheduled retry');
    }
  }

  /// Sync pending locations to server
  /// Fallback mechanism for any locations that failed immediate sync
  /// (e.g., due to brief network interruption during capture)
  /// Called periodically every 5 minutes as a retry mechanism
  static Future<void> _syncPendingLocations(
    DatabaseHelper db,
    String userCd,
    int syncId,
    String token,
    int tripId,
  ) async {
    try {
      // Check internet connection
      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) {
        print(
            '[BackgroundLocationService] [Background] 📵 No internet, skipping retry sync');
        return;
      }

      print(
          '[BackgroundLocationService] [Background] 🔄 Retry sync check: finding unsynced locations...');

      // Get all unsynced locations for this user
      final unsyncedLocations =
          await db.getUnsyncedLocationTrackingsByUser(userCd, syncId);

      if (unsyncedLocations.isEmpty) {
        print(
            '[BackgroundLocationService] [Background] ✅ No unsynced locations to retry');
        return;
      }

      print(
          '[BackgroundLocationService] [Background] 📤 Retrying ${unsyncedLocations.length} failed locations...');

      // Retry each unsynced location
      int successCount = 0;
      int failureCount = 0;

      for (var location in unsyncedLocations) {
        try {
          final id = location['id'] as int;
          final latitude = location['latitude'] as double;
          final longitude = location['longitude'] as double;
          final timestamp = location['timestamp'] as int;
          final accuracy = location['accuracy'] as double? ?? 0.0;
          final speed = location['speed'] as double? ?? 0.0;
          final altitude = location['altitude'] as double? ?? 0.0;

          // Send to server via /api/location/update endpoint
          print(
              '[BackgroundLocationService] [Background] API HIT: ${AppConfig.baseURL}location/update');
          final response = await http.post(
            Uri.parse('${AppConfig.baseURL}location/update'),
            headers: {
              'Authorization': 'Bearer $token',
              'x-app-type': 'oms',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'trip_id': tripId,
              'lat': latitude,
              'lng': longitude,
              'accuracy': accuracy > 0 ? accuracy : null,
              'speed': speed > 0 ? speed : null,
              'altitude': altitude != 0 ? altitude : null,
              'timestamp': timestamp,
            }),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            // Mark as synced
            await db.markLocationTrackingSynced(id);
            successCount++;
            print(
                '[BackgroundLocationService] [Background] ✅ Retry synced id=$id to trip=$tripId');
          } else {
            failureCount++;
            print(
                '[BackgroundLocationService] [Background] ⚠️ Retry failed for id=$id: ${response.statusCode}');
          }
        } catch (e) {
          failureCount++;
          print(
              '[BackgroundLocationService] [Background] ❌ Error retrying id: $e');
        }
      }

      print(
          '[BackgroundLocationService] [Background] 📊 Retry complete: $successCount success, $failureCount failed');
    } catch (e) {
      print(
          '[BackgroundLocationService] [Background] ❌ Error in retry sync batch: $e');
    }
  }

  /// Manually trigger retry sync of any pending locations
  /// Called from foreground when user wants to ensure sync happens
  /// This is a fallback for locations that failed immediate sync
  Future<void> syncNow() async {
    if (!_isRunning ||
        _currentUserCd == null ||
        _token == null ||
        _currentSyncId == null ||
        _currentTripId == null) {
      print('[BackgroundLocationService] ⚠️ Service not running, cannot sync');
      return;
    }

    print('[BackgroundLocationService] 🔄 Manual retry sync triggered');
    await _syncPendingLocations(
        _db, _currentUserCd!, _currentSyncId!, _token!, _currentTripId!);
  }
}
