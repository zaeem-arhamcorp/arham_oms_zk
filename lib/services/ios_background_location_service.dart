import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import 'package:arham_corporation/services/user_status_repository.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';
import 'location_sync_service.dart';
import 'trip_prefs_helper.dart';

/// iOS Background Location Service
///
/// This is the iOS-specific counterpart of BackgroundLocationService (which is Android-only).
/// It mirrors the same public API so LocationService can delegate to either based on Platform.
///
/// Architecture:
/// - Native CLLocationManager (IOSLocationTrackingManager.swift) delivers location updates
/// - This class receives them via MethodChannel and stores/syncs them
/// - All SQLite + SharedPreferences + API logic is shared with Android
///
/// Key differences from Android version:
/// - No flutter_background_service dependency
/// - No WorkManager dependency
/// - No native watchdog/alarm/receiver
/// - No foreground notification management
/// - Location timing controlled by native iOS CLLocationManager callbacks
/// - Uses MethodChannel "com.arhamerp.app/ios_location"
///
/// Limitations (explicitly acknowledged):
/// - Tracking STOPS when user force-quits the app from app switcher
/// - Significant-change monitoring may relaunch the app when user moves ~500m
/// - No persistent status bar notification (only blue location indicator)
class IOSBackgroundLocationService {
  static final IOSBackgroundLocationService _instance =
      IOSBackgroundLocationService._internal();

  factory IOSBackgroundLocationService() => _instance;

  IOSBackgroundLocationService._internal();

  /// MethodChannel for communicating with native iOS location manager
  static const _iosLocationChannel =
      MethodChannel('com.arhamerp.app/ios_location');

  final DatabaseHelper _db = DatabaseHelper();
  final LocationSyncService _locationSyncService = LocationSyncService();

  /// Maximum accepted GPS accuracy in meters (matches Android)
  static const double _maxAcceptedAccuracyMeters = 30.0;

  /// SharedPreferences keys for pending auto punch-out (matches Android)
  static const String _pendingAutoPunchOutKey = 'pending_auto_punch_out';
  static const String _pendingAutoPunchOutTripIdKey =
      'pending_auto_punch_out_trip_id';
  static const String _pendingAutoPunchOutSyncIdKey =
      'pending_auto_punch_out_sync_id';
  static const String _pendingAutoPunchOutTimeMsKey =
      'pending_auto_punch_out_time_ms';
  static const String _pendingAutoPunchOutLocIdKey =
      'pending_auto_punch_out_loc_id';
  static const String _manualReopenAfterAutoPunchOutDateKey =
      'manual_reopen_after_auto_punch_out_date';

  /// Current tracking state
  bool _isRunning = false;
  String? _currentUserCd;
  int? _currentSyncId;
  String? _token;
  int? _currentTripId;

  /// Heartbeat tracking
  DateTime? _lastHeartbeatAt;
  DateTime? _lastAutoPunchOutAttemptAt;

  /// Whether the method channel listener is already set up
  bool _listenerAttached = false;

  // Public accessors (same as Android BackgroundLocationService)
  bool get isRunning => _isRunning;
  String? get currentUserCd => _currentUserCd;
  int? get currentSyncId => _currentSyncId;
  int? get currentTripId => _currentTripId;

  // ============================================================
  // SETUP
  // ============================================================

  /// Set up the MethodChannel listener to receive location updates from native iOS.
  /// Called once at app startup from main.dart.
  void setupMethodChannelListener() {
    if (!Platform.isIOS) return;
    if (_listenerAttached) return;
    _listenerAttached = true;

    _iosLocationChannel.setMethodCallHandler(_handleMethodCall);
    print('[IOSBackgroundLocationService] ✅ MethodChannel listener attached');
  }

  /// Handle incoming method calls from native iOS
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onLocationUpdate':
        final args = call.arguments as Map<dynamic, dynamic>;
        await _onLocationReceived(
          latitude: (args['latitude'] as num).toDouble(),
          longitude: (args['longitude'] as num).toDouble(),
          accuracy: (args['accuracy'] as num).toDouble(),
          speed: (args['speed'] as num).toDouble(),
          altitude: (args['altitude'] as num).toDouble(),
          timestamp: args['timestamp'] as int,
          activityType: args['activityType'] as String? ?? 'UNKNOWN',
        );
        return true;
      default:
        return null;
    }
  }

  // ============================================================
  // START TRACKING
  // ============================================================

  /// Start background location tracking and initialize trip on server.
  /// Mirrors BackgroundLocationService.startTracking() API.
  Future<Map<String, dynamic>> startTracking({
    required String userCd,
    required int syncId,
    required String token,
    required double startLat,
    required double startLng,
    required String moduleNo,
    String tripName = 'Punch In Route',
  }) async {
    if (!Platform.isIOS) {
      return {
        'success': false,
        'message': 'IOSBackgroundLocationService only works on iOS',
      };
    }

    try {
      print('[IOSBackgroundLocationService] 🚀 Starting iOS tracking...');
      print('[IOSBackgroundLocationService]   User: $userCd');
      print('[IOSBackgroundLocationService]   Sync ID: $syncId');

      // Verify "Always" permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {
            'success': false,
            'message': 'Location permission denied',
            'error': 'Permission not granted',
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'success': false,
          'message': 'Location permission permanently denied',
          'error': 'Permission not granted',
        };
      }

      // Note: On iOS, we accept "whenInUse" for now — iOS will still deliver
      // background updates if UIBackgroundModes includes "location".
      // "Always" is preferred for significant-change relaunch after force-quit.
      if (permission == LocationPermission.whileInUse) {
        print(
            '[IOSBackgroundLocationService] ⚠️ Only WhenInUse permission — background tracking will work but significant-change relaunch won\'t');
      }

      print('[IOSBackgroundLocationService] ✅ Location permissions OK');

      // Step 1: Start trip on server
      final startTime = _formatDateTimeWithOffsetForApi(
        DateTime.now().millisecondsSinceEpoch,
      );

      print(
          '[IOSBackgroundLocationService] 📤 Initiating trip on server...');
      print(
          '[IOSBackgroundLocationService] API HIT: ${AppConfig.baseURL}location/trip/start');

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

      print(
          '[IOSBackgroundLocationService] Trip start response: ${tripStartResponse.statusCode}');
      print(
          '[IOSBackgroundLocationService] Response body: ${tripStartResponse.body}');

      if (tripStartResponse.statusCode != 200 &&
          tripStartResponse.statusCode != 201) {
        return {
          'success': false,
          'message': 'Failed to initialize trip on server',
          'error': 'Server error: ${tripStartResponse.statusCode}',
        };
      }

      // Parse trip_id
      int tripId = 0;
      try {
        final responseData = tripStartResponse.body;
        if (responseData.contains('trip_id')) {
          final match =
              RegExp(r'\"trip_id\"\s*:\s*(\d+)').firstMatch(responseData);
          if (match != null) {
            tripId = int.parse(match.group(1)!);
          }
        }
      } catch (e) {
        print(
            '[IOSBackgroundLocationService] ⚠️ Could not parse trip_id: $e');
      }

      if (tripId <= 0) {
        return {
          'success': false,
          'message': 'Server did not return valid trip_id',
          'error': 'Invalid trip_id',
        };
      }

      print('[IOSBackgroundLocationService] ✅ Trip created: trip_id=$tripId');

      // Store state in memory
      _currentUserCd = userCd;
      _currentSyncId = syncId;
      _token = token;
      _currentTripId = tripId;
      _isRunning = true;
      _lastHeartbeatAt = null;
      _lastAutoPunchOutAttemptAt = null;

      // Step 2: Persist to SharedPreferences (same keys as Android)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(TripPrefsHelper.tripId(syncId), tripId);
        await prefs.setString(TripPrefsHelper.userCd(syncId), userCd);
        await prefs.setInt(TripPrefsHelper.syncIdKey(syncId), syncId);
        await prefs.setString(TripPrefsHelper.tripToken(syncId), token);
        await prefs.setBool(TripPrefsHelper.explicitlyStopped(syncId), false);
        await prefs.setInt(TripPrefsHelper.currentTrackingSyncId, syncId);
        await TripPrefsHelper.clearLegacyKeys(prefs);

        final now = DateTime.now();
        final today = _formatLocalDate(now);
        final autoDoneToday =
            prefs.getBool(_autoPunchOutDoneKeyForDate(now)) ?? false;

        if (autoDoneToday && now.hour >= 23) {
          await prefs.setString(
            _manualReopenAfterAutoPunchOutDateKey,
            today,
          );
          print(
              '[IOSBackgroundLocationService] ℹ️ Manual post-11PM punch-in detected');
        }

        print(
            '[IOSBackgroundLocationService] ✅ Trip data saved to SharedPreferences');
      } catch (e) {
        print(
            '[IOSBackgroundLocationService] ⚠️ Could not save to SharedPreferences: $e');
      }

      // Step 3: Start native iOS location tracking
      try {
        await _iosLocationChannel.invokeMethod('startTracking', {
          'userCd': userCd,
          'syncId': syncId,
          'token': token,
          'tripId': tripId,
        });
        print(
            '[IOSBackgroundLocationService] ✅ Native iOS location tracking started');
      } catch (e) {
        print(
            '[IOSBackgroundLocationService] ❌ Failed to start native tracking: $e');
        return {
          'success': false,
          'message': 'Failed to start native iOS location tracking',
          'error': e.toString(),
        };
      }

      // Ensure listener is attached
      setupMethodChannelListener();

      print('[IOSBackgroundLocationService] ✅ iOS tracking fully started');
      return {
        'success': true,
        'trip_id': tripId,
        'message': 'Tracking started successfully',
      };
    } catch (e) {
      print('[IOSBackgroundLocationService] ❌ Error starting tracking: $e');
      _isRunning = false;
      return {
        'success': false,
        'message': 'Failed to start tracking',
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // STOP TRACKING
  // ============================================================

  /// Stop background location tracking.
  /// Mirrors BackgroundLocationService.stopTracking() API.
  Future<void> stopTracking({bool endTripOnServer = true}) async {
    try {
      print('[IOSBackgroundLocationService] 🛑 Stopping iOS tracking...');

      // Mark as explicitly stopped
      try {
        final prefs = await SharedPreferences.getInstance();
        final stoppedSyncId = _currentSyncId ??
            prefs.getInt(TripPrefsHelper.currentTrackingSyncId);
        if (stoppedSyncId != null) {
          await prefs.setBool(
              TripPrefsHelper.explicitlyStopped(stoppedSyncId), true);
        }
      } catch (e) {
        print(
            '[IOSBackgroundLocationService] ⚠️ Could not persist stop marker: $e');
      }

      // Stop native iOS location tracking
      try {
        await _iosLocationChannel.invokeMethod('stopTracking');
        print(
            '[IOSBackgroundLocationService] ✅ Native iOS location tracking stopped');
      } catch (e) {
        print(
            '[IOSBackgroundLocationService] ⚠️ Error stopping native tracking: $e');
      }

      // End trip on server if requested
      if (endTripOnServer) {
        await endActiveTripOnServer();
      }

      _isRunning = false;
      _currentUserCd = null;
      _currentSyncId = null;
      _token = null;
      _currentTripId = null;
      _lastHeartbeatAt = null;
      _lastAutoPunchOutAttemptAt = null;

      print(
          '[IOSBackgroundLocationService] ✅ iOS tracking completely stopped');
    } catch (e) {
      print('[IOSBackgroundLocationService] ⚠️ Error stopping tracking: $e');
      _isRunning = false;
    }
  }

  // ============================================================
  // RESUME TRACKING
  // ============================================================

  /// Resume tracking for an already active trip from SharedPreferences.
  /// Called on app startup to restore tracking state.
  /// Mirrors BackgroundLocationService.resumeTrackingIfActiveTrip() API.
  Future<bool> resumeTrackingIfActiveTrip() async {
    if (!Platform.isIOS) return false;

    try {
      final prefs = await SharedPreferences.getInstance();

      final trackingSyncId =
          prefs.getInt(TripPrefsHelper.currentTrackingSyncId);
      final legacySyncId = prefs.getInt(TripPrefsHelper.legacySyncId);
      final resolvedSyncId = trackingSyncId ?? legacySyncId;

      final tripId = resolvedSyncId != null
          ? (prefs.getInt(TripPrefsHelper.tripId(resolvedSyncId)) ??
              prefs.getInt(TripPrefsHelper.legacyTripId))
          : prefs.getInt(TripPrefsHelper.legacyTripId);
      final userCd = resolvedSyncId != null
          ? (prefs.getString(TripPrefsHelper.userCd(resolvedSyncId)) ??
              prefs.getString(TripPrefsHelper.legacyUserCd))
          : prefs.getString(TripPrefsHelper.legacyUserCd);
      final syncId = resolvedSyncId;
      final token = resolvedSyncId != null
          ? (prefs.getString(TripPrefsHelper.tripToken(resolvedSyncId)) ??
              prefs.getString('token'))
          : prefs.getString('token');
      final explicitlyStopped = resolvedSyncId != null
          ? (prefs.getBool(TripPrefsHelper.explicitlyStopped(resolvedSyncId)) ??
              false)
          : (prefs.getBool(TripPrefsHelper.legacyExplicitlyStopped) ?? false);
      final deferredAutoPunchOutPending =
          prefs.getBool(_pendingAutoPunchOutKey) ?? false;
      final autoPunchOutCompletedToday = await isAutoPunchOutCompletedToday();

      if (autoPunchOutCompletedToday) {
        print(
            '[IOSBackgroundLocationService] Resume skipped: auto punch-out already completed today');
        return false;
      }

      if (explicitlyStopped || deferredAutoPunchOutPending) {
        print(
            '[IOSBackgroundLocationService] Resume skipped (explicit stop or deferred auto punch-out pending)');
        return false;
      }

      if (tripId == null || userCd == null || syncId == null || token == null) {
        print(
            '[IOSBackgroundLocationService] No active trip in SharedPreferences');
        return false;
      }

      _currentTripId = tripId;
      _currentUserCd = userCd;
      _currentSyncId = syncId;
      _token = token;
      _isRunning = true;
      _lastHeartbeatAt = null;
      _lastAutoPunchOutAttemptAt = null;

      // Clear explicit-stop marker
      await prefs.setBool(TripPrefsHelper.explicitlyStopped(syncId), false);

      // Start native iOS location tracking
      print(
          '[IOSBackgroundLocationService] 🔄 Resuming iOS tracking for trip_id=$tripId');
      try {
        await _iosLocationChannel.invokeMethod('startTracking', {
          'userCd': userCd,
          'syncId': syncId,
          'token': token,
          'tripId': tripId,
        });
        print(
            '[IOSBackgroundLocationService] ✅ Native iOS tracking resumed');
      } catch (e) {
        print(
            '[IOSBackgroundLocationService] ⚠️ Could not start native tracking on resume: $e');
        return false;
      }

      // Ensure listener is attached
      setupMethodChannelListener();

      return true;
    } catch (e) {
      print(
          '[IOSBackgroundLocationService] Error while resuming active trip: $e');
      return false;
    }
  }

  // ============================================================
  // END TRIP ON SERVER
  // ============================================================

  /// End the active trip on server using persisted trip data.
  /// Mirrors BackgroundLocationService.endActiveTripOnServer() API.
  Future<bool> endActiveTripOnServer() async {
    try {
      int? tripIdToUse = _currentTripId;
      String? tokenToUse = _token;
      int? syncIdToUse = _currentSyncId;

      if (tripIdToUse == null || tokenToUse == null || syncIdToUse == null) {
        final prefs = await SharedPreferences.getInstance();
        final ptrSyncId = prefs.getInt(TripPrefsHelper.currentTrackingSyncId) ??
            prefs.getInt(TripPrefsHelper.legacySyncId);
        if (ptrSyncId != null) {
          tripIdToUse = prefs.getInt(TripPrefsHelper.tripId(ptrSyncId)) ??
              prefs.getInt(TripPrefsHelper.legacyTripId);
          tokenToUse =
              prefs.getString(TripPrefsHelper.tripToken(ptrSyncId)) ??
                  prefs.getString('token');
          syncIdToUse = ptrSyncId;
        } else {
          tripIdToUse = prefs.getInt(TripPrefsHelper.legacyTripId);
          tokenToUse = prefs.getString('token');
          syncIdToUse = prefs.getInt(TripPrefsHelper.legacySyncId);
        }
      }

      if (tripIdToUse == null || tokenToUse == null || syncIdToUse == null) {
        print(
            '[IOSBackgroundLocationService] ⚠️ Missing trip/sync data, cannot end trip');
        return false;
      }

      final endTime = _formatDateTimeWithOffsetForApi(
        DateTime.now().millisecondsSinceEpoch,
      );

      print(
          '[IOSBackgroundLocationService] API HIT: ${AppConfig.baseURL}location/trip/end');
      print(
          '[IOSBackgroundLocationService]   trip_id=$tripIdToUse, end_time=$endTime, sync_id=$syncIdToUse');

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
        await TripPrefsHelper.clearFirmKeys(prefs, syncIdToUse);
        await TripPrefsHelper.clearLegacyKeys(prefs);
        await prefs.remove(TripPrefsHelper.currentTrackingSyncId);
        await prefs.remove(_manualReopenAfterAutoPunchOutDateKey);
        print(
            '[IOSBackgroundLocationService] ✅ Trip ended and SharedPreferences cleared');
        return true;
      }

      print(
          '[IOSBackgroundLocationService] ⚠️ Trip end failed: ${tripEndResponse.statusCode}');
      return false;
    } catch (e) {
      print(
          '[IOSBackgroundLocationService] ⚠️ Error ending trip on server: $e');
      return false;
    }
  }

  // ============================================================
  // PENDING AUTO PUNCH-OUT HELPERS
  // ============================================================

  Future<bool> hasPendingAutoPunchOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingAutoPunchOutKey) ?? false;
  }

  Future<bool> isAutoPunchOutCompletedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _autoPunchOutDoneKeyForDate(DateTime.now());
    return prefs.getBool(key) ?? false;
  }

  /// Dismiss tracking artifacts (no-op on iOS — no foreground notification)
  Future<void> dismissTrackingForegroundArtifacts() async {
    // iOS doesn't have a persistent foreground notification to dismiss
    print(
        '[IOSBackgroundLocationService] dismissTrackingForegroundArtifacts: no-op on iOS');
  }

  /// Sync deferred auto punch-out (reuses same logic as Android)
  Future<bool> syncPendingAutoPunchOutIfNeeded(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPending = prefs.getBool(_pendingAutoPunchOutKey) ?? false;
      if (!hasPending) return false;

      final tripId = prefs.getInt(_pendingAutoPunchOutTripIdKey);
      final syncId = prefs.getInt(_pendingAutoPunchOutSyncIdKey);
      final endTimeMs = prefs.getInt(_pendingAutoPunchOutTimeMsKey);

      if (tripId == null || syncId == null || endTimeMs == null) {
        await _clearPendingAutoPunchOutKeys(prefs);
        return false;
      }

      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) return false;

      final endTime = _formatDateTimeWithOffsetForApi(endTimeMs);
      print(
          '[IOSBackgroundLocationService] Syncing deferred trip-end...');

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

      if (endTripResponse.statusCode != 200 &&
          endTripResponse.statusCode != 201) {
        return false;
      }

      await _db.deleteLocationTrackingBySyncId(syncId);
      await TripPrefsHelper.clearFirmKeys(prefs, syncId);
      await TripPrefsHelper.clearLegacyKeys(prefs);
      await prefs.remove(TripPrefsHelper.currentTrackingSyncId);
      await _clearPendingAutoPunchOutKeys(prefs);
      await prefs.remove(_manualReopenAfterAutoPunchOutDateKey);

      print(
          '[IOSBackgroundLocationService] ✅ Deferred trip-end sync completed');
      return true;
    } catch (e) {
      print(
          '[IOSBackgroundLocationService] Deferred trip-end sync exception: $e');
      return false;
    }
  }

  // ============================================================
  // LOCATION RECEIVED FROM NATIVE iOS
  // ============================================================

  /// Called when native iOS CLLocationManager delivers a location update.
  /// This is the heart of the iOS tracking — equivalent to the Android
  /// _backgroundLocationTracking loop body.
  Future<void> _onLocationReceived({
    required double latitude,
    required double longitude,
    required double accuracy,
    required double speed,
    required double altitude,
    required int timestamp,
    required String activityType,
  }) async {
    if (!_isRunning || _currentTripId == null || _currentUserCd == null) {
      print(
          '[IOSBackgroundLocationService] ⚠️ Location received but service not active');
      return;
    }

    final tripId = _currentTripId!;
    final userCd = _currentUserCd!;
    final syncId = _currentSyncId!;
    final token = _token!;

    // Check for auto punch-out at 11 PM
    final autoPunchedOut = await _tryAutoPunchOutAt11Pm(
      userCd: userCd,
      syncId: syncId,
      token: token,
      tripId: tripId,
    );
    if (autoPunchedOut) {
      print(
          '[IOSBackgroundLocationService] Auto punch-out completed, stopping tracking');
      await stopTracking(endTripOnServer: false);
      return;
    }

    print(
        '[IOSBackgroundLocationService] 📍 Location received: $latitude, $longitude');
    print(
        '[IOSBackgroundLocationService]   Accuracy: ${accuracy}m, Speed: ${speed}m/s, Activity: $activityType');

    // Store in SQLite
    try {
      final id = await _db.insertLocationTracking(
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        userCd: userCd,
        syncId: syncId,
        tripId: tripId,
        accuracy: accuracy,
        speed: speed,
        altitude: altitude,
        activityType: activityType,
      );
      print('[IOSBackgroundLocationService] ✅ LOCAL DB STORED: id=$id');

      // Immediately sync to server
      await _syncSingleLocation(
        recordId: id,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        accuracy: accuracy,
        speed: speed,
        altitude: altitude,
        tripId: tripId,
        token: token,
        userCd: userCd,
        syncId: syncId,
        activityType: activityType,
      );
    } catch (e) {
      print('[IOSBackgroundLocationService] ❌ Error storing location: $e');
    }

    // Send heartbeat if due (every 30 seconds)
    await _sendHeartbeatIfDue(token);
  }

  // ============================================================
  // SYNC SINGLE LOCATION TO SERVER
  // ============================================================

  /// Sync a single location to server immediately after capture.
  /// Mirrors BackgroundLocationService._syncSingleLocation().
  Future<void> _syncSingleLocation({
    required int recordId,
    required double latitude,
    required double longitude,
    required int timestamp,
    required double accuracy,
    required double speed,
    required double altitude,
    required int tripId,
    required String token,
    required String userCd,
    required int syncId,
    String activityType = 'UNKNOWN',
  }) async {
    try {
      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) {
        print(
            '[IOSBackgroundLocationService] ❌ NO INTERNET - Record id=$recordId will retry');
        return;
      }

      if (accuracy > _maxAcceptedAccuracyMeters) {
        print(
            '[IOSBackgroundLocationService] ⚠️ Rejecting low-quality fix (accuracy=${accuracy}m)');
        return;
      }

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
          '[IOSBackgroundLocationService] API HIT: ${AppConfig.baseURL}location/update');

      final response = await http.post(
        Uri.parse('${AppConfig.baseURL}location/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _db.markLocationTrackingSynced(recordId);
        print(
            '[IOSBackgroundLocationService] ✅ SERVER SYNC SUCCESS for record=$recordId');
      } else {
        print(
            '[IOSBackgroundLocationService] ⚠️ SERVER SYNC FAILED: ${response.statusCode} for record=$recordId');
      }
    } catch (e) {
      print('[IOSBackgroundLocationService] ❌ SYNC EXCEPTION: $e');
    }
  }

  // ============================================================
  // HEARTBEAT
  // ============================================================

  Future<void> _sendHeartbeatIfDue(String token) async {
    final now = DateTime.now();
    if (_lastHeartbeatAt != null &&
        now.difference(_lastHeartbeatAt!).inSeconds < 30) {
      return;
    }

    print('[IOSBackgroundLocationService] ❤️ Sending heartbeat...');
    final heartbeatRepository = UserStatusRepository();
    final heartbeatOk = await heartbeatRepository.sendHeartbeat(token: token);

    if (heartbeatOk) {
      _lastHeartbeatAt = now;
      print('[IOSBackgroundLocationService] ✅ Heartbeat sent');
    } else {
      print('[IOSBackgroundLocationService] ⚠️ Heartbeat failed');
    }
  }

  // ============================================================
  // AUTO PUNCH-OUT AT 11 PM
  // ============================================================

  Future<bool> _tryAutoPunchOutAt11Pm({
    required String userCd,
    required int syncId,
    required String token,
    required int tripId,
  }) async {
    final now = DateTime.now();

    if (now.hour < 23) return false;

    if (_lastAutoPunchOutAttemptAt != null &&
        now.difference(_lastAutoPunchOutAttemptAt!).inSeconds < 60) {
      return false;
    }
    _lastAutoPunchOutAttemptAt = now;

    final today = _formatLocalDate(now);
    final autoDoneKey = 'auto_punch_out_done_$today';
    final prefs = await SharedPreferences.getInstance();
    final manualReopenDate =
        prefs.getString(_manualReopenAfterAutoPunchOutDateKey);
    final hasManualReopen =
        manualReopenDate != null && manualReopenDate.isNotEmpty;

    if (hasManualReopen) {
      print(
          '[IOSBackgroundLocationService] Manual post-11PM punch-in active; keeping tracking alive');
      return false;
    }

    if ((prefs.getBool(autoDoneKey) ?? false) == true) {
      print('[IOSBackgroundLocationService] Auto punch-out already done today');
      return true;
    }

    print(
        '[IOSBackgroundLocationService] ⏰ Auto punch-out triggered at 11 PM');

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
      print(
          '[IOSBackgroundLocationService] GPS unavailable for auto punch-out: $e');
    }

    final vouchDt = today;
    final vouchTime = _formatTime(now);
    final createdAt = now.millisecondsSinceEpoch;

    final locId = await _db.insertLocation({
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

    final isOnline = await NetworkHelper.hasInternet();
    if (!isOnline) {
      await prefs.setBool(_pendingAutoPunchOutKey, true);
      await prefs.setInt(_pendingAutoPunchOutTripIdKey, tripId);
      await prefs.setInt(_pendingAutoPunchOutSyncIdKey, syncId);
      await prefs.setInt(_pendingAutoPunchOutTimeMsKey, createdAt);
      await prefs.setInt(_pendingAutoPunchOutLocIdKey, locId);
      await prefs.setBool(TripPrefsHelper.explicitlyStopped(syncId), true);
      await TripPrefsHelper.clearFirmKeys(prefs, syncId);
      await TripPrefsHelper.clearLegacyKeys(prefs);
      await prefs.remove(TripPrefsHelper.currentTrackingSyncId);
      await prefs.setBool(autoDoneKey, true);
      _clearState();
      return true;
    }

    // Online: sync punch-out immediately
    try {
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

      if (punchOutResponse.statusCode == 200 ||
          punchOutResponse.statusCode == 201) {
        await _db.updateLocationSyncStatus(locId, 'synced', null);
      }

      // Sync remaining data and end trip
      await _locationSyncService.syncAllLocations(token);

      final endTime = _formatDateTimeWithOffsetForApi(
        DateTime.now().millisecondsSinceEpoch,
      );
      await http.post(
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

      await TripPrefsHelper.clearFirmKeys(prefs, syncId);
      await TripPrefsHelper.clearLegacyKeys(prefs);
      await prefs.remove(TripPrefsHelper.currentTrackingSyncId);
      await _clearPendingAutoPunchOutKeys(prefs);
      await prefs.remove(_manualReopenAfterAutoPunchOutDateKey);
      await prefs.setBool(autoDoneKey, true);

      _clearState();
      print('[IOSBackgroundLocationService] ✅ Auto punch-out at 11 PM SUCCESS');
      return true;
    } catch (e) {
      print(
          '[IOSBackgroundLocationService] ❌ Auto punch-out API error: $e');
      return false;
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  void _clearState() {
    _isRunning = false;
    _currentUserCd = null;
    _currentSyncId = null;
    _currentTripId = null;
    _token = null;
    _lastHeartbeatAt = null;
    _lastAutoPunchOutAttemptAt = null;
  }

  Future<void> _clearPendingAutoPunchOutKeys(SharedPreferences prefs) async {
    await prefs.remove(_pendingAutoPunchOutKey);
    await prefs.remove(_pendingAutoPunchOutTripIdKey);
    await prefs.remove(_pendingAutoPunchOutSyncIdKey);
    await prefs.remove(_pendingAutoPunchOutTimeMsKey);
    await prefs.remove(_pendingAutoPunchOutLocIdKey);
  }

  static String _formatDateTimeWithOffsetForApi(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absOffset = offset.abs();
    final offsetHours = absOffset.inHours.toString().padLeft(2, '0');
    final offsetMinutes =
        (absOffset.inMinutes % 60).toString().padLeft(2, '0');

    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}$sign$offsetHours:$offsetMinutes';
  }

  static String _formatLocalDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  static String _autoPunchOutDoneKeyForDate(DateTime dt) {
    return 'auto_punch_out_done_${_formatLocalDate(dt)}';
  }
}
