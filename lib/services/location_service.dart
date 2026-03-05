import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import '../config/app_config.dart';

class LocationService {
  final DatabaseHelper db = DatabaseHelper();

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
        'sync_status': 'pending', // Will be changed to 'synced' after online upload
      };

      // Always save to local DB first
      int locId = await db.insertLocation(locationData);
      print('[LocationService] Saved punch $punchType locally: locId=$locId, user=$userCd');

      // If online, immediately push to server
      final isOnline = await NetworkHelper.hasInternet();
      if (isOnline) {
        try {
          // Prepare payload for server
          final body = {
            'USER_CD': userCd,
            'VOUCH_DT': vouchDt,
            'VOUCH_TIME': vouchTime,
            'LAT': lat.toString(),
            'LONGI': longi.toString(),
            'REMARK': remark,
            'SYNC_ID': syncId.toString(),
            'MODULE_NO': moduleNo,
            'CREATED_BY': createdBy,
            'CREATED_APP_TYPE': createdAppType,
          };

          print('[LocationService] POSTing to server: $body');

          final http.Response response = await http.post(
            Uri.parse("${AppConfig.baseURL}locations"),
            body: body,
            headers: {
              "Authorization": "Bearer $token",
              'x-app-type': 'oms',
            },
          );

          print('[LocationService] Server response: ${response.statusCode}');

          if (response.statusCode == 200 || response.statusCode == 201) {
            // Success: mark as synced in local DB
            await db.updateLocationSyncStatus(locId, 'synced', null);
            print('[LocationService] Punch $punchType synced to server: locId=$locId');
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
            print('[LocationService] Server error (${response.statusCode}), keeping pending');
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
          print('[LocationService] Server sync failed (keeping local): $e');
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
    return await db.getLocationsByUserAndDate(userCd, vouchDt);
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
}
