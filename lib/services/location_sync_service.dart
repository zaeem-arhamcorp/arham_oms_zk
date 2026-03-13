import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:arham_corporation/config/app_config.dart';
import 'database_helper.dart';

/// Location Sync Service
/// Handles syncing of location tracking data to the server.
/// Used both by the background service and foreground connectivity detection.
class LocationSyncService {
  final DatabaseHelper _db = DatabaseHelper();

  /// Sync background location tracking records
  /// Fetches all unsynced location_tracking records and sends them to the server
  /// Returns a map with sync statistics: {synced: count, failed: count}
  Future<Map<String, int>> syncLocationTracking(String token) async {
    print('[LocationSyncService] 🔄 Starting location tracking sync...');

    try {
      // Get all unsynced location tracking records
      final unsyncedLocations = await _db.getUnsyncedLocationTrackings();

      if (unsyncedLocations.isEmpty) {
        print('[LocationSyncService] ✅ No unsynced location tracking records');
        return {'synced': 0, 'failed': 0};
      }

      print('[LocationSyncService] 📊 Found ${unsyncedLocations.length} unsynced tracking records');

      int synced = 0;
      int failed = 0;
      final List<int> syncedIds = [];

      // Process each location
      for (var location in unsyncedLocations) {
        try {
          final id = location['id'] as int;
          final latitude = location['latitude'] as double;
          final longitude = location['longitude'] as double;
          final timestamp = location['timestamp'] as int;
          final tripId = location['trip_id'] as int? ?? 0;
          final accuracy = location['accuracy'] as double? ?? 0.0;
          final speed = location['speed'] as double? ?? 0.0;
          final altitude = location['altitude'] as double? ?? 0.0;

          print(
              '[LocationSyncService] 📤 Syncing location id=$id: ($latitude, $longitude) trip=$tripId');

          // Convert timestamp from milliseconds to seconds
          final timestampSeconds = timestamp ~/ 1000;

          // Send to server using /location/update endpoint (same as BackgroundLocationService)
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
              'timestamp': timestampSeconds,
            }),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            // Mark as synced in local database
            await _db.markLocationTrackingSynced(id);
            syncedIds.add(id);
            synced++;
            print('[LocationSyncService] ✅ Sync successful for id=$id: ${response.body}');
          } else {
            failed++;
            print('[LocationSyncService] ⚠️ Server error ${response.statusCode} for id=$id');
            print('[LocationSyncService]   Response: ${response.body}');
          }
        } catch (e) {
          failed++;
          print('[LocationSyncService] ❌ Error syncing location: $e');
        }
      }

      print('[LocationSyncService] 📊 Location tracking sync complete');
      print('[LocationSyncService]   ✅ Synced: $synced');
      print('[LocationSyncService]   ❌ Failed: $failed');

      return {'synced': synced, 'failed': failed};
    } catch (e) {
      print('[LocationSyncService] ❌ Error in location tracking sync: $e');
      return {'synced': 0, 'failed': 0};
    }
  }

  /// Sync punch in/out location records
  /// Fetches all pending punch locations and sends them to the server
  /// Returns a map with sync statistics: {synced: count, failed: count}
  Future<Map<String, int>> syncPunchLocations(String token) async {
    print('[LocationSyncService] 🔄 Starting punch location sync...');

    try {
      // Get all pending punch location records
      final pendingLocations = await _db.getPendingLocations();

      if (pendingLocations.isEmpty) {
        print('[LocationSyncService] ✅ No pending punch locations');
        return {'synced': 0, 'failed': 0};
      }

      print('[LocationSyncService] 📊 Found ${pendingLocations.length} pending punch locations');

      int synced = 0;
      int failed = 0;

      // Process each punch location
      for (var location in pendingLocations) {
        try {
          final locId = location['locId'] as int;
          final userCd = location['USER_CD'] as String;
          final vouchDt = location['VOUCH_DT'] as String;
          final vouchTime = location['VOUCH_TIME'] as String;
          final lat = location['LAT'] as double;
          final longi = location['LONGI'] as double;
          final remark = location['REMARK'] as String?;
          final syncId = location['SYNC_ID'] as int;
          final moduleNo = location['MODULE_NO'] as String;

          print(
              '[LocationSyncService] 📤 Syncing punch location locId=$locId: ($lat, $longi)');

          // Format time without microseconds for server compatibility
          final formattedVouchTime = vouchTime.split('.').first;

          // Send to server
          final body = {
            'lat': lat.toString(),
            'long': longi.toString(),
            'moduleNo': moduleNo.toString(),
            'remarks': remark ?? '',
            'USER_CD': userCd,
            'vouchDt': vouchDt,
            'vouchTime': formattedVouchTime,
            'LAT': lat.toString(),
            'LONGI': longi.toString(),
            'REMARK': remark ?? '',
            'SYNC_ID': syncId.toString(),
            'MODULE_NO': moduleNo.toString(),
          };

          final response = await http.post(
            Uri.parse('${AppConfig.baseURL}locations'),
            body: body,
            headers: {
              'Authorization': 'Bearer $token',
              'x-app-type': 'oms',
            },
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            // Mark as synced in local database
            await _db.updateLocationSyncStatus(locId, 'synced', null);
            synced++;
            print('[LocationSyncService] ✅ Sync successful for punch locId=$locId');
          } else {
            failed++;
            print('[LocationSyncService] ⚠️ Server error ${response.statusCode} for punch locId=$locId');
            print('[LocationSyncService]   Response: ${response.body}');
          }
        } catch (e) {
          failed++;
          print('[LocationSyncService] ❌ Error syncing punch location: $e');
        }
      }

      print('[LocationSyncService] 📊 Punch location sync complete');
      print('[LocationSyncService]   ✅ Synced: $synced');
      print('[LocationSyncService]   ❌ Failed: $failed');

      return {'synced': synced, 'failed': failed};
    } catch (e) {
      print('[LocationSyncService] ❌ Error in punch location sync: $e');
      return {'synced': 0, 'failed': 0};
    }
  }

  /// Sync all location-related data (both tracking and punch records)
  /// Called when internet is restored
  /// Returns combined statistics
  Future<Map<String, dynamic>> syncAllLocations(String token) async {
    print('[LocationSyncService] 🔄 Syncing ALL location data...');

    try {
      // Sync tracking locations first
      final trackingResult = await syncLocationTracking(token);

      // Then sync punch locations
      final punchResult = await syncPunchLocations(token);

      final result = {
        'tracking_synced': trackingResult['synced'] ?? 0,
        'tracking_failed': trackingResult['failed'] ?? 0,
        'punch_synced': punchResult['synced'] ?? 0,
        'punch_failed': punchResult['failed'] ?? 0,
        'total_synced':
            (trackingResult['synced'] ?? 0) + (punchResult['synced'] ?? 0),
        'total_failed':
            (trackingResult['failed'] ?? 0) + (punchResult['failed'] ?? 0),
      };

      print('[LocationSyncService] ✅ All location sync complete');
      print('[LocationSyncService]   Tracking: ${result['tracking_synced']} synced, ${result['tracking_failed']} failed');
      print('[LocationSyncService]   Punch: ${result['punch_synced']} synced, ${result['punch_failed']} failed');
      print('[LocationSyncService]   Total: ${result['total_synced']} synced, ${result['total_failed']} failed');

      return result;
    } catch (e) {
      print('[LocationSyncService] ❌ Error syncing all locations: $e');
      return {
        'tracking_synced': 0,
        'tracking_failed': 0,
        'punch_synced': 0,
        'punch_failed': 0,
        'total_synced': 0,
        'total_failed': 0,
        'error': e.toString(),
      };
    }
  }

  /// Get pending location statistics for UI display
  Future<Map<String, dynamic>> getPendingStats() async {
    try {
      final trackingStats = await _db.getLocationTrackingStats();
      final pendingPunchCount = (await _db.getPendingLocations()).length;

      return {
        'tracking_total': trackingStats['total'] ?? 0,
        'tracking_unsynced': trackingStats['unsynced'] ?? 0,
        'tracking_synced': trackingStats['synced'] ?? 0,
        'punch_pending': pendingPunchCount,
      };
    } catch (e) {
      print('[LocationSyncService] Error getting stats: $e');
      return {
        'tracking_total': 0,
        'tracking_unsynced': 0,
        'tracking_synced': 0,
        'punch_pending': 0,
      };
    }
  }
}
