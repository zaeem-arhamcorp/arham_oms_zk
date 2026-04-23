import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/services/services.dart';
import 'database_helper.dart';

/// Location Sync Service
/// Handles syncing of location tracking data to the server.
/// Used both by the background service and foreground connectivity detection.
class LocationSyncService {
  final DatabaseHelper _db = DatabaseHelper();

  /// Safely parse timestamp from both string (ISO8601) and int (epoch seconds) formats
  /// Handles migration from old string timestamps to new int format
  int? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    // If already an int, return directly
    if (timestamp is int) return timestamp;

    // If it's a string, try multiple parse strategies
    if (timestamp is String) {
      try {
        // Try parsing as integer seconds first (new format)
        return int.parse(timestamp);
      } catch (_) {
        try {
          // Try parsing as ISO8601 datetime string (old format)
          final dateTime = DateTime.parse(timestamp);
          return dateTime.millisecondsSinceEpoch ~/ 1000;
        } catch (e) {
          print(
              '[LocationSyncService] ⚠️ Failed to parse timestamp "$timestamp": $e');
          return null;
        }
      }
    }

    // If it's a double or other numeric type, convert to int
    if (timestamp is num) {
      return timestamp.toInt();
    }

    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  List<int> _extractIdList(dynamic value) {
    if (value is! List) return <int>[];
    return value.map((entry) => _parseInt(entry)).whereType<int>().toList();
  }

  Map<String, dynamic>? _decodeJsonBody(String body) {
    try {
      final decoded = json.decode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _refreshActiveTripId({
    required String userCd,
    required int syncId,
    required String token,
  }) async {
    try {
      final activeTrip =
          await Services().getActiveTripStatus(userCd, syncId, token);
      final tripId = _parseInt(activeTrip?['trip_id']);
      if (tripId != null && tripId > 0) {
        print(
            '[LocationSyncService] ✅ Refreshed active trip_id=$tripId for user_cd=$userCd');
        return tripId;
      }
    } catch (e) {
      print('[LocationSyncService] ⚠️ Failed to refresh active trip: $e');
    }
    return null;
  }

  Future<void> _applyBatchOutcome({
    required List<int> ids,
    required Map<String, dynamic>? responseData,
  }) async {
    if (ids.isEmpty) return;

    if (responseData == null) {
      await _db.markLocationTrackingsSynced(ids);
      return;
    }

    final acceptedIds = _extractIdList(
      responseData['accepted_point_ids'] ??
          responseData['accepted_ids'] ??
          responseData['synced_ids'],
    );
    final rejectedIds = _extractIdList(
      responseData['rejected_point_ids'] ??
          responseData['rejected_ids'] ??
          responseData['failed_ids'],
    );

    final acceptedCount = _parseInt(
          responseData['accepted_points_count'] ??
              responseData['accepted_count'] ??
              responseData['synced_count'],
        ) ??
        (acceptedIds.isNotEmpty ? acceptedIds.length : null);
    final rejectedCount = _parseInt(
          responseData['rejected_points_count'] ??
              responseData['rejected_count'] ??
              responseData['failed_count'],
        ) ??
        (rejectedIds.isNotEmpty ? rejectedIds.length : null);

    final normalizedAcceptedIds = <int>[];
    final normalizedRejectedIds = <int>[];

    if (acceptedIds.isNotEmpty) {
      normalizedAcceptedIds.addAll(acceptedIds.where(ids.contains));
    } else if (acceptedCount != null) {
      normalizedAcceptedIds.addAll(
        ids.take(acceptedCount.clamp(0, ids.length).toInt()),
      );
    }

    if (rejectedIds.isNotEmpty) {
      normalizedRejectedIds.addAll(rejectedIds.where(ids.contains));
    } else if (rejectedCount != null) {
      final acceptedSet = normalizedAcceptedIds.toSet();
      normalizedRejectedIds.addAll(
        ids
            .where((id) => !acceptedSet.contains(id))
            .take(rejectedCount.clamp(0, ids.length).toInt()),
      );
    }

    if (normalizedAcceptedIds.isEmpty && normalizedRejectedIds.isEmpty) {
      await _db.markLocationTrackingsSynced(ids);
      return;
    }

    if (normalizedAcceptedIds.isNotEmpty) {
      await _db.markLocationTrackingsSynced(
        normalizedAcceptedIds.toSet().toList(),
      );
    }

    if (normalizedRejectedIds.isNotEmpty) {
      await _db.markLocationTrackingsRejected(
        normalizedRejectedIds.toSet().toList(),
      );
    }
  }

  /// Sync background location tracking records in BULK
  /// Groups locations by trip_id and sends in batch format for efficiency
  /// Offline scenarios: Instead of 50+ individual API calls, sends 1-2 bulk calls
  /// Format: { trip_id: X, points: [{local_id, lat, lng, accuracy, speed, altitude, timestamp}, ...] }
  /// Returns: {synced: count, failed: count}
  Future<Map<String, int>> syncLocationTracking(String token) async {
    print('[LocationSyncService] 🔄 Starting location tracking sync...');

    try {
      // Get all unsynced location tracking records
      final unsyncedLocations = await _db.getUnsyncedLocationTrackings();

      if (unsyncedLocations.isEmpty) {
        print('[LocationSyncService] ✅ No unsynced location tracking records');
        return {'synced': 0, 'failed': 0};
      }

      print(
          '[LocationSyncService] 📊 Found ${unsyncedLocations.length} unsynced tracking records');
      print(
          '[LocationSyncService] 📍 OFFLINE SYNC: Syncing previously stored locations...');

      // Print details of each unsynced location
      for (var location in unsyncedLocations) {
        final id = location['id'] as int;
        final latitude = (location['latitude'] as num?)?.toDouble() ?? 0.0;
        final longitude = (location['longitude'] as num?)?.toDouble() ?? 0.0;
        final accuracy = (location['accuracy'] as num?)?.toDouble() ?? 0.0;
        final speed = (location['speed'] as num?)?.toDouble() ?? 0.0;
        final altitude = (location['altitude'] as num?)?.toDouble() ?? 0.0;
        final activityType = location['activity_type'] ?? 'UNKNOWN';
        final timestamp = _parseTimestamp(location['timestamp']);
        final tripId = location['trip_id'] as int?;

        if (timestamp != null) {
          final timestampDateTime =
              DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
                  .toLocal()
                  .toIso8601String();

          print(
              '[LocationSyncService] [OFFLINE] 📍 Queued location: $latitude, $longitude');
          print(
              '[LocationSyncService] [OFFLINE]   Accuracy: ${accuracy}m, Speed: ${speed}m/s, Altitude: ${altitude}m');
          print('[LocationSyncService] [OFFLINE]   Activity: $activityType');
          print(
              '[LocationSyncService] [OFFLINE]   Timestamp: $timestampDateTime');
          print(
              '[LocationSyncService] [OFFLINE]   Record ID: $id | Trip ID: $tripId');
        }
      }

      // Group locations by trip_id for bulk sync
      final Map<int, List<Map>> locationsByTrip = {};
      final Map<int, List<int>> idsByTrip = {};

      for (var location in unsyncedLocations) {
        final tripId = location['trip_id'] as int? ?? 0;
        final id = location['id'] as int;

        if (!locationsByTrip.containsKey(tripId)) {
          locationsByTrip[tripId] = [];
          idsByTrip[tripId] = [];
        }

        locationsByTrip[tripId]!.add(location);
        idsByTrip[tripId]!.add(id);
      }

      int totalSynced = 0;
      int totalFailed = 0;

      // Send bulk request for each trip
      for (var entry in locationsByTrip.entries) {
        final tripId = entry.key;
        final locations = entry.value;
        final ids = idsByTrip[tripId]!;
        final firstLocation = locations.first;
        final userCd = (firstLocation['user_cd'] ?? '').toString();
        final syncId = (firstLocation['sync_id'] as num?)?.toInt() ?? 0;

        print(
            '[LocationSyncService] 📦 Preparing bulk sync for trip_id=$tripId');
        print(
            '[LocationSyncService]    Batch size: ${locations.length} locations');

        try {
          // Build batch array
          final points = locations.map((location) {
            final localId = _parseInt(location['id']);
            final latitude = (location['latitude'] as num?)?.toDouble() ?? 0.0;
            final longitude =
                (location['longitude'] as num?)?.toDouble() ?? 0.0;
            final accuracy = (location['accuracy'] as num?)?.toDouble() ?? 0.0;
            final speed = (location['speed'] as num?)?.toDouble() ?? 0.0;
            final altitude = (location['altitude'] as num?)?.toDouble() ?? 0.0;
            final timestamp = _parseTimestamp(location['timestamp']);

            return {
              if (localId != null) 'local_id': localId,
              'lat': latitude,
              'lng': longitude,
              'accuracy': accuracy > 0 ? accuracy : null,
              'speed': speed > 0 ? speed : null,
              'altitude': altitude != 0 ? altitude : null,
              'timestamp': timestamp,
            };
          }).toList();

          // Send bulk request
          print(
              '[LocationSyncService] 📤 Sending OFFLINE SYNC bulk request to /location/update');
          print('[LocationSyncService]    trip_id: $tripId');
          print('[LocationSyncService]    points: ${points.length}');
          print('[LocationSyncService]    Method: POST');
          print('[LocationSyncService]    Content-Type: application/json');
          print(
              '[LocationSyncService] API HIT: ${AppConfig.baseURL}location/update');

          Future<http.Response> postPoints(int targetTripId) {
            return http.post(
              Uri.parse('${AppConfig.baseURL}location/update'),
              headers: {
                'Authorization': 'Bearer $token',
                'x-app-type': 'oms',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'trip_id': targetTripId,
                'points': points,
              }),
            );
          }

          final response = await postPoints(tripId);
          final responseData = _decodeJsonBody(response.body);

          if (response.statusCode == 409) {
            final refreshedTripId = await _refreshActiveTripId(
              userCd: userCd,
              syncId: syncId,
              token: token,
            );
            if (refreshedTripId != null && refreshedTripId != tripId) {
              print(
                  '[LocationSyncService] 🔄 Retrying batch with refreshed trip_id=$refreshedTripId');
              final retryResponse = await postPoints(refreshedTripId);
              if (retryResponse.statusCode == 200 ||
                  retryResponse.statusCode == 201) {
                final retryData = _decodeJsonBody(retryResponse.body);
                await _applyBatchOutcome(ids: ids, responseData: retryData);
                final acceptedCount = _parseInt(
                      retryData?['accepted_points_count'],
                    ) ??
                    ids.length;
                final rejectedCount = _parseInt(
                      retryData?['rejected_points_count'],
                    ) ??
                    0;
                totalSynced += acceptedCount.clamp(0, ids.length).toInt();
                totalFailed += rejectedCount.clamp(0, ids.length).toInt();
                print(
                    '[LocationSyncService] ✅ OFFLINE SYNC SUCCESS after refresh for trip_id=$refreshedTripId');
                print(
                    '[LocationSyncService]    Status Code: ${retryResponse.statusCode}');
                print(
                    '[LocationSyncService]    Accepted points: $acceptedCount');
                print(
                    '[LocationSyncService]    Rejected points: $rejectedCount');
                print(
                    '[LocationSyncService]    Server Response: ${retryResponse.body}');
                continue;
              }
              print(
                  '[LocationSyncService] ⚠️ Retry after 409 still failed: ${retryResponse.statusCode} ${retryResponse.body}');
            }

            totalFailed += ids.length;
            print(
                '[LocationSyncService] ⚠️ OFFLINE SYNC CONFLICT for trip_id=$tripId - keeping points pending');
            continue;
          }

          if (response.statusCode == 200 || response.statusCode == 201) {
            await _applyBatchOutcome(ids: ids, responseData: responseData);
            final acceptedCount = _parseInt(
                  responseData?['accepted_points_count'],
                ) ??
                ids.length;
            final rejectedCount = _parseInt(
                  responseData?['rejected_points_count'],
                ) ??
                0;
            totalSynced += acceptedCount.clamp(0, ids.length).toInt();
            totalFailed += rejectedCount.clamp(0, ids.length).toInt();
            print(
                '[LocationSyncService] ✅ OFFLINE SYNC SUCCESS for trip_id=$tripId');
            print(
                '[LocationSyncService]    Status Code: ${response.statusCode}');
            print('[LocationSyncService]    Accepted points: $acceptedCount');
            print('[LocationSyncService]    Rejected points: $rejectedCount');
            print('[LocationSyncService]    Record IDs: ${ids.join(', ')}');
            print('[LocationSyncService]    Server Response: ${response.body}');
          } else {
            totalFailed += ids.length;
            print(
                '[LocationSyncService] ⚠️ OFFLINE SYNC FAILED - Server error ${response.statusCode} for trip_id=$tripId');
            print('[LocationSyncService]    Response: ${response.body}');
            print(
                '[LocationSyncService]    Action: Will retry on next sync attempt');
          }
        } catch (e) {
          totalFailed += ids.length;
          print(
              '[LocationSyncService] ❌ OFFLINE SYNC EXCEPTION for trip_id=$tripId: $e');
          print(
              '[LocationSyncService]    Action: Will retry on next sync attempt');
        }
      }

      print('[LocationSyncService] 📊 OFFLINE LOCATION TRACKING SYNC COMPLETE');
      print('[LocationSyncService]   ✅ Total synced: $totalSynced');
      print('[LocationSyncService]   ❌ Total failed: $totalFailed');

      return {'synced': totalSynced, 'failed': totalFailed};
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

      print(
          '[LocationSyncService] 📊 Found ${pendingLocations.length} pending punch locations');

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
            print(
                '[LocationSyncService] ✅ Sync successful for punch locId=$locId');
          } else {
            failed++;
            print(
                '[LocationSyncService] ⚠️ Server error ${response.statusCode} for punch locId=$locId');
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
      print(
          '[LocationSyncService]   Tracking: ${result['tracking_synced']} synced, ${result['tracking_failed']} failed');
      print(
          '[LocationSyncService]   Punch: ${result['punch_synced']} synced, ${result['punch_failed']} failed');
      print(
          '[LocationSyncService]   Total: ${result['total_synced']} synced, ${result['total_failed']} failed');

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
