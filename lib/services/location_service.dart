import 'package:arham_corporation/helper/network_helper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'activity_recognition_service.dart';
import 'background_location_service.dart';
import 'database_helper.dart';
import 'location_sync_service.dart';

class LocationService {
  static const String _activeTripTokenKey = 'active_trip_token';
  final DatabaseHelper db = DatabaseHelper();
  final BackgroundLocationService _backgroundService =
      BackgroundLocationService();
  final LocationSyncService _syncService = LocationSyncService();

  /// Punch in/out operation: captures location and saves to local + online (if online)
  /// If online: immediately POSTs to server and saves as synced locally
  /// If offline: saves locally with pending status, syncs when offline->online
  Future<Map<String, dynamic>> punchInOut({
    required String userCd,
    required String vouchDt,
    required String vouchTime,
    required String punchType,
    required String remark,
    required int syncId,
    required String moduleNo,
    required String token,
    String createdBy = '',
    String createdAppType = 'oms',
  }) async {
    try {
      // ⚠️ OFFLINE CHECK: Do not allow punch in/out without internet
      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) {
        print('[LocationService] ❌ OFFLINE - Punch in/out not allowed');
        return {
          'success': false,
          'message':
              'You are offline. Cannot punch in/out without internet connection.',
        };
      }

      // Get current GPS location
      double lat = 0.0, longi = 0.0;
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );
        lat = position.latitude;
        longi = position.longitude;
        print('[LocationService] Got GPS: lat=$lat, longi=$longi');
      } catch (e) {
        print('[LocationService] GPS error (continuing with 0,0): $e');
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      final locationData = {
        'USER_CD': userCd,
        'VOUCH_DT': vouchDt,
        'VOUCH_TIME': vouchTime,
        'LAT': lat,
        'LONGI': longi,
        'REMARK': remark,
        'SYNC_ID': syncId,
        'CREATED_BY': createdBy,
        'CREATED_AT': now,
        'UPDATED_BY': createdBy,
        'UPDATED_AT': now,
        'CREATED_APP_TYPE': createdAppType,
        'MODULE_NO': moduleNo,
        'sync_status':
            'pending', // Will be changed to 'synced' after online upload
      };

      // Always save to local DB first
      int locId = await db.insertLocation(locationData);
      print('[LocationService] ✅ PUNCH SAVED TO LOCAL DB');
      print(
          '[LocationService]   locId=$locId | user=$userCd | punch=$punchType');
      print(
          '[LocationService]   date=$vouchDt | time=$vouchTime | gps=($lat, $longi)');
      print(
          '[LocationService]   remark=$remark | syncId=$syncId | moduleNo=$moduleNo');
      print('[LocationService]   status=pending (waiting for sync)');

      // 📡 Optimistic loading: Try API immediately (no pre-flight check)
      // If offline, the API call will fail and we keep the local DB record
      try {
        // Prepare payload for server
        // Format time without microseconds for server compatibility
        final formattedVouchTime = vouchTime.split('.').first;

        // Server historically expects lowercase keys like `lat`, `long`, `moduleNo`, `remarks`.
        // Include both forms to be compatible with either server variant.
        final body = {
          // legacy / expected keys
          'lat': lat.toString(),
          'long': longi.toString(),
          'moduleNo': moduleNo.toString(),
          'remarks': remark,

          // detailed keys (kept for compatibility / audit)
          'USER_CD': userCd,
          'vouchDt': vouchDt,
          'vouchTime': formattedVouchTime,
          'LAT': lat.toString(),
          'LONGI': longi.toString(),
          'REMARK': remark,
          'SYNC_ID': syncId.toString(),
          'MODULE_NO': moduleNo.toString(),
          'CREATED_BY': createdBy,
          'CREATED_APP_TYPE': createdAppType,
        };

        print('[LocationService] 📤 Pushing to server...');
        print('[LocationService]   POST URL: ${AppConfig.baseURL}locations');
        print('[LocationService]   Payload (sent): $body');

        final http.Response response = await http.post(
          Uri.parse("${AppConfig.baseURL}locations"),
          body: body,
          headers: {
            "Authorization": "Bearer $token",
            'x-app-type': 'oms',
          },
        ).timeout(Duration(seconds: 10));

        print('[LocationService] 📥 Server response: ${response.statusCode}');
        print('[LocationService]   Response body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Success: mark as synced in local DB
          await db.updateLocationSyncStatus(locId, 'synced', null);
          print('[LocationService] ✅ SYNC SUCCESSFUL');
          print(
              '[LocationService]   locId=$locId | Marked as synced in local DB');
          print(
              '[LocationService]   user=$userCd | punch=$punchType | Local record kept for history');
          return {
            'success': true,
            'locId': locId,
            'synced': true,
            'message': 'Punch $punchType recorded successfully',
            'lat': lat,
            'longi': longi,
          };
        } else {
          // Server error: keep as pending for later sync
          print('[LocationService] ⚠️ SERVER ERROR ${response.statusCode}');
          print(
              '[LocationService]   locId=$locId | Status: PENDING (will retry on next sync)');
          print('[LocationService]   Local data preserved for automatic retry');
          return {
            'success': true,
            'locId': locId,
            'synced': false,
            'message': 'Punch $punchType saved (will sync when needed)',
            'lat': lat,
            'longi': longi,
            'error': 'Server error: ${response.statusCode}',
          };
        }
      } catch (e) {
        // Network/POST error: keep locally as pending
        print('[LocationService] ⚠️ API FAILED - Saved locally only');
        print('[LocationService]   locId=$locId | Error: $e');
        print(
            '[LocationService]   Status: PENDING (will retry when online returns)');
        return {
          'success': true,
          'locId': locId,
          'synced': false,
          'message': 'Punch $punchType saved locally (will sync when online)',
          'lat': lat,
          'longi': longi,
          'error': e.toString(),
        };
      }
    } catch (e, stack) {
      print('[LocationService] Punch error: $e');
      print('[LocationService] Stack: $stack');
      return {
        'success': false,
        'message': 'Failed to record punch: $e',
      };
    }
  }

  /// Get all punch records for a user on a specific date in a specific firm
  Future<List<Map<String, dynamic>>> getPunchesForUserDate(
    String userCd,
    String vouchDt,
    int syncId,
  ) async {
    return await db.getLocationsByUserAndDate(userCd, vouchDt, syncId);
  }

  /// Get today's punches for current user
  Future<List<Map<String, dynamic>>> getTodaysPunches(
      String userCd, int syncId) async {
    final today = DateTime.now();
    final vouchDt =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final punches = await db.getLocationsByUserAndDate(userCd, vouchDt, syncId);
    print(
        '[LocationService.getTodaysPunches] Query: USER_CD="$userCd", VOUCH_DT="$vouchDt", SYNC_ID="$syncId" → ${punches.length} results');
    return punches;
  }

  /// Get all punches within a date range (for reports)
  Future<List<Map<String, dynamic>>> getPunchesInDateRange(
    String startDate,
    String endDate,
  ) async {
    return await db.getLocationsByDateRange(startDate, endDate);
  }

  /// Get pending (un-synced) punches
  Future<List<Map<String, dynamic>>> getPendingPunches() async {
    return await db.getPendingLocations();
  }

  /// Check if user has punched in today in a specific firm
  Future<bool> hasPunchedInToday(String userCd, int syncId) async {
    final punches = await getTodaysPunches(userCd, syncId);
    // Check for 'IN' punch type in remarks or similar logic
    return punches.isNotEmpty;
  }

  /// Check if user has punched out today in a specific firm
  Future<bool> hasPunchedOutToday(String userCd, int syncId) async {
    final punches = await getTodaysPunches(userCd, syncId);
    if (punches.isEmpty) return false;
    // Check for 'OUT' punch type in remarks or similar logic
    return punches.length >= 2; // Simple check: at least IN and OUT
  }

  /// =====================================================
  /// PUNCH IN WITH BACKGROUND LOCATION TRACKING
  /// =====================================================
  /// Punch in with automatic location tracking start.
  /// Requirements:
  /// - Employee is online (checked)
  /// - Captures current location at punch time
  /// - Starts background service that tracks location every 40 seconds
  /// - Service continues even when app is minimized or cleared from recent
  ///
  /// Parameters:
  /// - userCd: Employee code
  /// - syncId: Firm/organization ID
  /// - token: API authentication token
  /// - vouchDt: Date of punch (YYYY-MM-DD)
  /// - vouchTime: Time of punch (HH:MM:SS)
  /// - moduleNo: Module number
  /// - createdBy: Created by user code
  /// - remark: Optional remark/note
  ///
  /// Returns:
  /// - success: true if punch was recorded, false otherwise
  /// - locId: Database ID of punch record
  /// - synced: true if data was synced to server, false if pending
  /// - tracking_started: true if background service was started successfully
  /// - message: Description of what happened
  /// - lat/longi: Captured GPS coordinates
  /// - error: Error message (if any)
  Future<Map<String, dynamic>> punchIn({
    required String userCd,
    required int syncId,
    required String token,
    required String vouchDt,
    required String vouchTime,
    required String moduleNo,
    String createdBy = '',
    String remark = '',
    String createdAppType = 'oms',
    bool continuousLocationTracking = true,
  }) async {
    try {
      print('[LocationService] 🟢 PUNCH IN INITIATED');
      print('[LocationService]   User: $userCd | Sync ID: $syncId');
      print('[LocationService]   Date: $vouchDt | Time: $vouchTime');

      // 📡 Optimistic loading: Try API immediately (no pre-flight check)
      // If offline or connection fails, API call will fail with appropriate error message

      // Step 2: Record punch in location (existing logic)
      final punchResult = await punchInOut(
        userCd: userCd,
        vouchDt: vouchDt,
        vouchTime: vouchTime,
        punchType: 'IN',
        remark: remark,
        syncId: syncId,
        moduleNo: moduleNo,
        token: token,
        createdBy: createdBy,
        createdAppType: createdAppType,
      );

      if (!punchResult['success']) {
        print('[LocationService] ❌ Failed to record punch');
        return {
          ...punchResult,
          'tracking_started': false,
        };
      }

      print('[LocationService] ✅ Punch recorded successfully');
      final locId = punchResult['locId'];
      final startLat = punchResult['lat'] as double;
      final startLng = punchResult['longi'] as double;

      // Check if continuous location tracking is enabled
      if (!continuousLocationTracking) {
        print(
            '[LocationService] ℹ️ Continuous location tracking disabled for this user');
        print(
            '[LocationService] ✅ PUNCH IN COMPLETE (on-demand location tracking mode)');
        print('[LocationService]   ✅ Location recorded: locId=$locId');
        print('[LocationService]   📍 Coordinates: $startLat, $startLng');
        print(
            '[LocationService]   ℹ️ Background service NOT started (on-demand mode)');

        return {
          ...punchResult,
          'tracking_started': false,
          'message': 'Punch In successful. Using on-demand location tracking.',
        };
      }

      // Step 3: Request activity recognition permission on main thread
      // This must be done here (main thread) before background service starts
      print(
          '[LocationService] 🎤 Requesting activity recognition permission...');
      final activityRecognition = ActivityRecognitionService();
      try {
        await activityRecognition.initialize();
        print('[LocationService] ✅ Activity recognition permission handled');
      } catch (e) {
        print(
            '[LocationService] ℹ️ Activity recognition permission setup (non-blocking): $e');
        // Continue anyway - activity detection will use UNKNOWN
      }

      // Step 4: Start background location tracking service
      print('[LocationService] 🚀 Starting background location tracking...');
      final trackingResult = await _backgroundService.startTracking(
        userCd: userCd,
        syncId: syncId,
        token: token,
        startLat: startLat,
        startLng: startLng,
        moduleNo: moduleNo,
      );

      if (trackingResult['success']) {
        final tripId = trackingResult['trip_id'] as int;
        print('[LocationService] ✅ PUNCH IN COMPLETE');
        print('[LocationService]   ✅ Location recorded: locId=$locId');
        print(
            '[LocationService]   ✅ Background tracking started with trip_id=$tripId');
        print('[LocationService]   📍 Coordinates: $startLat, $startLng');

        return {
          ...punchResult,
          'tracking_started': true,
          'trip_id': tripId,
          'message': 'Punch In successful. Route tracking started.',
        };
      } else {
        print(
            '[LocationService] ⚠️ Background tracking failed to start: ${trackingResult['error']}');
        return {
          ...punchResult,
          'tracking_started': false,
          'message':
              'Punch In recorded but background tracking failed to start. Please check location permissions.',
          'warning': 'Tracking service failed: ${trackingResult['message']}',
        };
      }
    } catch (e, stack) {
      print('[LocationService] ❌ Punch In error: $e');
      print('[LocationService] Stack: $stack');
      return {
        'success': false,
        'tracking_started': false,
        'message': 'Failed to punch in: $e',
        'error': e.toString(),
      };
    }
  }

  /// =====================================================
  /// PUNCH OUT WITH BACKGROUND LOCATION TRACKING STOP
  /// =====================================================
  /// Punch out with automatic location tracking stop and sync.
  /// Requirements:
  /// - Employee is online (checked)
  /// - Stops background service
  /// - Syncs all remaining unsynced location data
  /// - Records the punch out location
  ///
  /// Parameters:
  /// - userCd: Employee code
  /// - syncId: Firm/organization ID
  /// - token: API authentication token
  /// - vouchDt: Date of punch (YYYY-MM-DD)
  /// - vouchTime: Time of punch (HH:MM:SS)
  /// - moduleNo: Module number
  /// - createdBy: Created by user code
  /// - remark: Optional remark/note
  ///
  /// Returns:
  /// - success: true if punch was recorded, false otherwise
  /// - locId: Database ID of punch record
  /// - synced: true if data was synced to server
  /// - tracking_stopped: true if background service was stopped
  /// - sync_stats: Statistics of synced location data
  /// - message: Description of what happened
  /// - error: Error message (if any)

  /// =====================================================
  /// RESTART LOCATION TRACKING (After Logout/Login)
  /// =====================================================
  /// Restarts background location tracking without recording a new punch.
  /// Used when user logs back in and was previously punched in.
  /// The punch record already exists on the server - we just restart tracking.
  ///
  /// Parameters:
  /// - userCd: User code
  /// - syncId: Sync id
  /// - token: Auth token
  /// - moduleNo: Module number (defaults to '301')
  /// - logTag: Log tag prefix for debugging
  ///
  /// Returns:
  /// - success: true if tracking started successfully
  /// - message: Description of what happened
  /// - error: Error message (if any)
  Future<Map<String, dynamic>> restartTracking({
    required String userCd,
    required int syncId,
    required String token,
    String moduleNo = '301',
    String logTag = '[LocationService]',
  }) async {
    try {
      print(
          '$logTag 🔄 RESTART TRACKING - User logged back in (was previously punched in)');

      if (userCd.isEmpty || token.isEmpty || syncId <= 0) {
        print(
            '$logTag ❌ Missing user data: userCd=$userCd, syncId=$syncId, hasToken=${token.isNotEmpty}');
        return {
          'success': false,
          'message': 'Missing user data',
          'error': 'Cannot restart tracking without user credentials',
        };
      }

      print('$logTag ℹ️ User: $userCd | Sync ID: $syncId');

      // Step 2: Get current GPS location (or last known)
      late double currentLat, currentLng;
      try {
        final Position position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.bestForNavigation)
            .timeout(const Duration(seconds: 15));
        currentLat = position.latitude;
        currentLng = position.longitude;
        print('$logTag 📍 Current GPS location: $currentLat, $currentLng');
      } catch (e) {
        print('$logTag ⚠️ Could not get current GPS: $e - trying last known');
        // Try to get last known position
        try {
          final Position? lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            currentLat = lastKnown.latitude;
            currentLng = lastKnown.longitude;
            print(
                '$logTag 📍 Last known GPS location: $currentLat, $currentLng');
          } else {
            print('$logTag ⚠️ No last known position available');
            currentLat = 0;
            currentLng = 0;
          }
        } catch (e2) {
          print('$logTag ⚠️ Could not get last known position either: $e2');
          currentLat = 0;
          currentLng = 0;
        }
      }

      // Step 3: Start background location tracking service
      print('$logTag 🚀 Restarting background location tracking service...');
      final trackingResult = await _backgroundService.startTracking(
        userCd: userCd,
        syncId: syncId,
        token: token,
        startLat: currentLat,
        startLng: currentLng,
        moduleNo: moduleNo,
      );

      if (trackingResult['success']) {
        final tripId = trackingResult['trip_id'] as int?;
        print('$logTag ✅ RESTART TRACKING SUCCESSFUL');
        print('$logTag   ✅ Background tracking restarted with trip_id=$tripId');
        print('$logTag   📍 Coordinates: $currentLat, $currentLng');
        return {
          'success': true,
          'trip_id': tripId,
          'message': 'Location tracking restarted successfully.',
        };
      } else {
        print(
            '$logTag ⚠️ Background tracking failed to restart: ${trackingResult['error']}');
        return {
          'success': false,
          'message':
              'Background tracking failed to restart. Please check location permissions.',
          'error': trackingResult['message'],
        };
      }
    } catch (e, stack) {
      print('$logTag ❌ Restart tracking error: $e');
      print('$logTag Stack: $stack');
      return {
        'success': false,
        'message': 'Failed to restart tracking: $e',
        'error': e.toString(),
      };
    }
  }

  /// Resume an existing active trip without creating a new one
  /// Called when user logs back in and we found an active trip on server
  Future<Map<String, dynamic>> resumeExistingTrip(
      {required int tripId,
      required String userCd,
      required int syncId,
      required String token}) async {
    try {
      print('[LocationService] 🔄 RESUME EXISTING TRIP - trip_id=$tripId');

      final deferredAutoPunchOutPending =
          await _backgroundService.hasPendingAutoPunchOut();
      if (deferredAutoPunchOutPending) {
        print(
            '[LocationService] ⏸️ Resume skipped: deferred auto punch-out sync is pending');
        return {
          'success': false,
          'message':
              'Deferred auto punch-out sync pending. Trip resume skipped.',
          'deferred_auto_punch_out_pending': true,
        };
      }

      // Store trip data in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_trip_id', tripId);
      await prefs.setString('active_user_cd', userCd);
      await prefs.setInt('active_sync_id', syncId);
      await prefs.setString(_activeTripTokenKey, token);
      print('[LocationService] ✅ Trip data stored in SharedPreferences');

      // Resume background service with existing trip_id
      final resumeSuccess =
          await _backgroundService.resumeTrackingIfActiveTrip();

      if (resumeSuccess) {
        print('[LocationService] ✅ RESUME TRACKING SUCCESSFUL');
        return {
          'success': true,
          'trip_id': tripId,
          'message': 'Trip tracking resumed successfully',
          'resumed': true,
        };
      } else {
        print('[LocationService] ⚠️ Resume tracking failed');
        return {
          'success': false,
          'message': 'Failed to resume tracking',
          'error': 'Service resume failed',
        };
      }
    } catch (e) {
      print('[LocationService] ❌ Resume trip error: $e');
      return {
        'success': false,
        'message': 'Failed to resume trip: $e',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> punchOut({
    required String userCd,
    required int syncId,
    required String token,
    required String vouchDt,
    required String vouchTime,
    required String moduleNo,
    String createdBy = '',
    String remark = '',
    String createdAppType = 'oms',
    bool continuousLocationTracking = true,
  }) async {
    try {
      print('[LocationService] 🔴 PUNCH OUT INITIATED');
      print('[LocationService]   User: $userCd | Sync ID: $syncId');
      print('[LocationService]   Date: $vouchDt | Time: $vouchTime');

      // 📡 Optimistic loading: Try API immediately (no pre-flight check)
      // If offline or connection fails, API call will fail with appropriate error message

      // Initialize syncStats with default value (used for both continuous and on-demand modes)
      Map<String, dynamic> syncStats = {
        'total_synced': 0,
        'total_failed': 0,
      };

      int? tripIdToClear = _backgroundService.currentTripId;
      if (tripIdToClear == null) {
        final prefs = await SharedPreferences.getInstance();
        tripIdToClear = prefs.getInt('active_trip_id');
      }

      // Step 2: Stop background location capture if continuous tracking was enabled
      if (continuousLocationTracking) {
        print('[LocationService] 🛑 Stopping background tracking service...');
        await _backgroundService.stopTracking(endTripOnServer: false);
        print('[LocationService] ✅ Background tracking stopped');

        // Step 3: Sync all remaining unsynced location data
        print('[LocationService] 🔄 Syncing remaining location data...');
        syncStats = await _syncService.syncAllLocations(token);
        print('[LocationService] ✅ Sync complete');
        print(
            '[LocationService]   ${syncStats['total_synced']} synced, ${syncStats['total_failed']} failed');

        // Step 4: End trip on server only after pending points have synced.
        final tripEnded = await _backgroundService.endActiveTripOnServer();
        print(
            '[LocationService] ${tripEnded ? '✅' : '⚠️'} Trip end after sync');

        if (tripIdToClear != null && tripIdToClear > 0) {
          try {
            final deleted = await db.deleteLocationTrackingBySyncId(syncId);
            print(
                '[LocationService] 🧹 Cleared $deleted tracking points for sync_id=$syncId');
          } catch (e) {
            print(
                '[LocationService] ⚠️ Failed to clear tracking points for trip_id=$tripIdToClear: $e');
          }
        }
      } else {
        print(
            '[LocationService] ℹ️ Continuous tracking disabled, skipping background service stop');
        // For on-demand mode, clear the location_tracking table after punch out
        print('[LocationService] 🧹 Clearing location tracking data...');
        try {
          await db.clearLocationTracking();
          print('[LocationService] ✅ Location tracking data cleared');
        } catch (e) {
          print('[LocationService] ⚠️ Failed to clear location data: $e');
        }
      }

      // Step 5: Record punch out location
      print('[LocationService] 📍 Recording punch out location...');
      final punchResult = await punchInOut(
        userCd: userCd,
        vouchDt: vouchDt,
        vouchTime: vouchTime,
        punchType: 'OUT',
        remark: remark,
        syncId: syncId,
        moduleNo: moduleNo,
        token: token,
        createdBy: createdBy,
        createdAppType: createdAppType,
      );

      if (!punchResult['success']) {
        print('[LocationService] ⚠️ Failed to record punch out');
        return {
          ...punchResult,
          'tracking_stopped': true,
          'sync_stats': syncStats,
        };
      }

      print('[LocationService] ✅ PUNCH OUT COMPLETE');
      print(
          '[LocationService]   ✅ Location recorded: locId=${punchResult['locId']}');
      print('[LocationService]   ✅ Background tracking stopped');
      print('[LocationService]   ✅ All location data synced');
      print(
          '[LocationService]   📍 Coordinates: ${punchResult['lat']}, ${punchResult['longi']}');

      return {
        ...punchResult,
        'tracking_stopped': true,
        'sync_stats': syncStats,
        'message':
            'Punch Out successful. All route tracking data has been synced.',
      };
    } catch (e, stack) {
      print('[LocationService] ❌ Punch Out error: $e');
      print('[LocationService] Stack: $stack');

      // Try to stop service even on error
      try {
        await _backgroundService.stopTracking();
      } catch (_) {}

      return {
        'success': false,
        'tracking_stopped': false,
        'message': 'Failed to punch out: $e',
        'error': e.toString(),
      };
    }
  }

  /// Delete all location tracking records for a specific sync id.
  /// This keeps the trip-id delete path available for future use.
  Future<int> deleteLocationTrackingBySyncId(int syncId) async {
    return await db.deleteLocationTrackingBySyncId(syncId);
  }

  /// Force sync of pending location data (manual trigger)
  /// Used by UI to manually trigger sync when user wants to ensure data is sent
  Future<Map<String, dynamic>> syncPendingLocations(String token) async {
    try {
      print('[LocationService] 🔄 Manual sync triggered');
      final result = await _syncService.syncAllLocations(token);
      return {
        'success': true,
        'sync_stats': result,
        'message': 'Location data synced successfully',
      };
    } catch (e) {
      print('[LocationService] ❌ Manual sync failed: $e');
      return {
        'success': false,
        'message': 'Failed to sync: $e',
        'error': e.toString(),
      };
    }
  }

  /// Check if background tracking is currently active
  bool isTrackingActive() {
    return _backgroundService.isRunning;
  }

  /// Get current tracking statistics
  Future<Map<String, dynamic>> getTrackingStats() async {
    return await _syncService.getPendingStats();
  }
}
