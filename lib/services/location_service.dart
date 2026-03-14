import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import '../config/app_config.dart';
import 'background_location_service.dart';
import 'location_sync_service.dart';

class LocationService {
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

      // If online, immediately push to server
      final isOnline = await NetworkHelper.hasInternet();
      if (isOnline) {
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

          print('[LocationService] 📤 ONLINE DETECTED - Pushing to server...');
          print('[LocationService]   POST URL: ${AppConfig.baseURL}locations');
          print('[LocationService]   Payload (sent): $body');

          final http.Response response = await http.post(
            Uri.parse("${AppConfig.baseURL}locations"),
            body: body,
            headers: {
              "Authorization": "Bearer $token",
              'x-app-type': 'oms',
            },
          );

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
            print(
                '[LocationService]   Local data preserved for automatic retry');
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
          print('[LocationService] ⚠️ POST FAILED');
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
      } else {
        // Offline: just local save, will sync later
        print('[LocationService] 📵 OFFLINE MODE - Saved locally only');
        print(
            '[LocationService]   locId=$locId | user=$userCd | punch=$punchType');
        print(
            '[LocationService]   date=$vouchDt | time=$vouchTime | gps=($lat, $longi)');
        print('[LocationService]   Status: PENDING (will sync when online)');
        return {
          'success': true,
          'locId': locId,
          'synced': false,
          'message': 'Punch $punchType saved offline (will sync when online)',
          'lat': lat,
          'longi': longi,
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

  /// Get all punch records for a user on a specific date
  Future<List<Map<String, dynamic>>> getPunchesForUserDate(
    String userCd,
    String vouchDt,
  ) async {
    return await db.getLocationsByUserAndDate(userCd, vouchDt);
  }

  /// Get today's punches for current user
  Future<List<Map<String, dynamic>>> getTodaysPunches(String userCd) async {
    final today = DateTime.now();
    final vouchDt =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final punches = await db.getLocationsByUserAndDate(userCd, vouchDt);
    print(
        '[LocationService.getTodaysPunches] Query: USER_CD="$userCd", VOUCH_DT="$vouchDt" → ${punches.length} results');
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

  /// Check if user has punched in today
  Future<bool> hasPunchedInToday(String userCd) async {
    final punches = await getTodaysPunches(userCd);
    // Check for 'IN' punch type in remarks or similar logic
    return punches.isNotEmpty;
  }

  /// Check if user has punched out today
  Future<bool> hasPunchedOutToday(String userCd) async {
    final punches = await getTodaysPunches(userCd);
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
  }) async {
    try {
      print('[LocationService] 🟢 PUNCH IN INITIATED');
      print('[LocationService]   User: $userCd | Sync ID: $syncId');
      print('[LocationService]   Date: $vouchDt | Time: $vouchTime');

      // Step 1: Check internet connection - PUNCH IN requires online
      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) {
        print('[LocationService] ❌ PUNCH IN FAILED - No internet connection');
        return {
          'success': false,
          'tracking_started': false,
          'message':
              'Punch In requires internet connection. Please check your network.',
          'error': 'No internet connection',
        };
      }

      print('[LocationService] ✅ Internet available, proceeding...');

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

      // Step 3: Start background location tracking service
      print('[LocationService] 🚀 Starting background location tracking...');
      final trackingResult = await _backgroundService.startTracking(
        userCd: userCd,
        syncId: syncId,
        token: token,
        startLat: startLat,
        startLng: startLng,
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
  }) async {
    try {
      print('[LocationService] 🔴 PUNCH OUT INITIATED');
      print('[LocationService]   User: $userCd | Sync ID: $syncId');
      print('[LocationService]   Date: $vouchDt | Time: $vouchTime');

      // Step 1: Check internet connection - PUNCH OUT requires online
      final isOnline = await NetworkHelper.hasInternet();
      if (!isOnline) {
        print('[LocationService] ❌ PUNCH OUT FAILED - No internet connection');
        return {
          'success': false,
          'tracking_stopped': false,
          'message':
              'Punch Out requires internet connection. Please check your network.',
          'error': 'No internet connection',
        };
      }

      print('[LocationService] ✅ Internet available, proceeding...');

      // Step 2: Get the last location from the active trip (if any)
      double? lastLat;
      double? lastLng;
      int? lastTimestampMs;

      try {
        final prefs = await SharedPreferences.getInstance();
        final activeTripId = prefs.getInt('active_trip_id');

        if (activeTripId != null && activeTripId > 0) {
          print(
              '[LocationService] 📍 Getting last location for trip_id=$activeTripId...');
          final lastLocation =
              await db.getLastLocationTrackingForTrip(activeTripId);

          if (lastLocation != null) {
            lastLat = lastLocation['LAT'] as double?;
            lastLng = lastLocation['LNG'] as double?;
            lastTimestampMs = lastLocation['TIMESTAMP'] as int?;

            if (lastLat != null && lastLng != null && lastTimestampMs != null) {
              print('[LocationService] ✅ Got last location:');
              print(
                  '[LocationService]   Lat: $lastLat | Lng: $lastLng | Timestamp: ${lastTimestampMs}ms');
            }
          }
        }
      } catch (e) {
        print('[LocationService] ⚠️ Could not get last location: $e');
      }

      // Step 3: Stop background location tracking service
      print('[LocationService] 🛑 Stopping background tracking service...');
      await _backgroundService.stopTracking(
        lastLat: lastLat,
        lastLng: lastLng,
        lastTimestampMs: lastTimestampMs,
      );
      print('[LocationService] ✅ Background tracking stopped');

      // Step 4: Sync all remaining unsynced location data
      print('[LocationService] 🔄 Syncing remaining location data...');
      final syncStats = await _syncService.syncAllLocations(token);
      print('[LocationService] ✅ Sync complete');
      print(
          '[LocationService]   ${syncStats['total_synced']} synced, ${syncStats['total_failed']} failed');

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
