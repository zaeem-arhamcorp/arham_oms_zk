import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import '../config/app_config.dart';

class OrderTrackingService {
  final DatabaseHelper db = DatabaseHelper();

  /// Start or end order: tries API immediately, then saves locally if needed.
  /// For type=2 (ORDER PLACED), pass orderDateTime to use correct order time instead of sync time.
  /// Returns {success: bool, synced: bool, message: string, ...}
  Future<Map<String, dynamic>> startEndOrder({
    required String accCd,
    required double latitude,
    required double longitude,
    required String type, // "1" for START, "2" for ORDER PLACED, "3" for END
    String? oId,
    required String token,
    String moduleNo = "205",
    String userCd = "",
    int syncId = 0,
    bool? isEndOrder, // true for END, false for START, null for unknown
    DateTime? orderDateTime, // For type=2, use order's actual creation time
  }) async {
    try {
      // Use passed orderDateTime for type=2 (ORDER PLACED), otherwise use current time
      final baseDateTime = orderDateTime ?? DateTime.now();
      final now = baseDateTime.millisecondsSinceEpoch;
      final vouchDt = baseDateTime.toString().split(' ')[0]; // YYYY-MM-DD
      final rawTime = baseDateTime.toString().split(' ')[1]; // HH:MM:SS.sssssss
      final vouchTime =
          rawTime.split('.').first; // Strip microseconds: HH:MM:SS

      // DEBUG: Log the timestamp being captured
      final isUsingPassedTime = orderDateTime != null;
      print('[OrderTrackingService] ⏰ TIMESTAMP CAPTURE DEBUG:');
      print(
          '[OrderTrackingService]   Passed orderDateTime: ${orderDateTime?.toString() ?? "NULL"}');
      print('[OrderTrackingService]   Using passed time: $isUsingPassedTime');
      print('[OrderTrackingService]   BaseDateTime used: $baseDateTime');
      print(
          '[OrderTrackingService]   VOUCH_DT=$vouchDt, VOUCH_TIME=$vouchTime');

      final remark =
          isEndOrder == null ? 'Order Tracking' : (isEndOrder ? 'OUT' : 'IN');
      final cleanedOId = (oId ?? '').trim();
      final parsedOId = type == '2' ? int.tryParse(cleanedOId) : null;

      print('[ORDER_TRACKING] 📋 Tracking initiated');
      print(
          '[ORDER_TRACKING]   Type: $type (${type == "1" ? "START" : type == "2" ? "ORDER_PLACED" : "END"})');
      print(
          '[ORDER_TRACKING]   Party: $accCd | Location: ($latitude, $longitude)');
      print('[ORDER_TRACKING]   REMARK: $remark | isEndOrder: $isEndOrder');

      // ⚡⚡⚡ TRY API IMMEDIATELY (no internet check - save 5 seconds!)
      print(
          '[ORDER_TRACKING] 🌐 Attempting API call immediately (no pre-check)');

      try {
        final body = {
          'accCd': accCd,
          'lat': latitude.toString(),
          'longi': longitude.toString(),
          'type': type,
          'moduleNo': moduleNo,
          'remark': remark,
          'REMARK': remark,
          'remarks': remark,
          'vouchDt': vouchDt,
          'vouchTime': vouchTime,
          'USER_CD': userCd,
          'SYNC_ID': syncId.toString(),
        };

        // Business rule: send oId only for ORDER PLACED (type=2).
        if (type == '2' && cleanedOId.isNotEmpty) {
          body['oId'] = cleanedOId;
        }

        print('[ORDER_TRACKING] 📤 POST ${AppConfig.baseURL}orders-tracking');
        print('[ORDER_TRACKING] 📦 Request payload: ${jsonEncode(body)}');

        final http.Response response = await http.post(
          Uri.parse("${AppConfig.baseURL}orders-tracking"),
          body: jsonEncode(body),
          headers: {
            "Authorization": "Bearer $token",
            'x-app-type': 'oms',
            'Content-Type': 'application/json',
          },
        ).timeout(Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          // ✅ API SUCCESS - Mark as synced immediately
          print('[ORDER_TRACKING] 🟢 API SUCCESS (${response.statusCode})');
          print('[ORDER_TRACKING]   Response: ${response.body}');

          // 📱 Background: Save to local DB in background
          Future.microtask(() async {
            try {
              final orderTrackingData = {
                'ACC_CD': accCd,
                'LAT': latitude,
                'LONGI': longitude,
                'oId': parsedOId,
                'VOUCH_DT': vouchDt,
                'VOUCH_TIME': vouchTime,
                'MODULE_NO': moduleNo,
                'SYNC_ID': syncId,
                'USER_CD': userCd,
                'CREATED_BY': userCd,
                'CREATED_AT': now,
                'UPDATED_BY': userCd,
                'UPDATED_AT': now,
                'CREATED_APP_TYPE': 'oms',
                'REMARK': remark,
                'tracking_type': type,
                'sync_status': 'synced', // Already synced
              };

              int trackingId = await db.insertOrderTracking(orderTrackingData);
              print(
                  '[ORDER_TRACKING] ✅ Background: Local DB saved (synced status) | trackingId=$trackingId');
            } catch (e) {
              print(
                  '[ORDER_TRACKING] ⚠️ Background: Failed to save to local DB: $e');
            }
          });

          return {
            'success': true,
            'synced': true,
            'message': 'Order tracking updated successfully',
          };
        } else {
          // ⚠️ API ERROR - Fall back to offline
          print('[ORDER_TRACKING] ⚠️ API ERROR (${response.statusCode})');
          print('[ORDER_TRACKING]   Response: ${response.body}');
          print('[ORDER_TRACKING] 📵 Falling back to offline mode');

          // Save to local DB immediately
          final orderTrackingData = {
            'ACC_CD': accCd,
            'LAT': latitude,
            'LONGI': longitude,
            'oId': parsedOId,
            'VOUCH_DT': vouchDt,
            'VOUCH_TIME': vouchTime,
            'MODULE_NO': moduleNo,
            'SYNC_ID': syncId,
            'USER_CD': userCd,
            'CREATED_BY': userCd,
            'CREATED_AT': now,
            'UPDATED_BY': userCd,
            'UPDATED_AT': now,
            'CREATED_APP_TYPE': 'oms',
            'REMARK': remark,
            'tracking_type': type,
            'sync_status': 'pending', // Will retry on sync
          };

          int trackingId = await db.insertOrderTracking(orderTrackingData);
          print(
              '[ORDER_TRACKING] ✅ Offline fallback: Saved to local DB | trackingId=$trackingId');

          return {
            'success': true,
            'synced': false,
            'message': 'Order tracking saved offline (will sync when online)',
            'error': 'Server error: ${response.statusCode}',
          };
        }
      } catch (apiError) {
        // ❌ NETWORK ERROR - Fallback to offline
        print('[ORDER_TRACKING] 🌐 NETWORK ERROR: $apiError');
        print('[ORDER_TRACKING] 📵 Falling back to offline mode');

        // Save to local DB immediately
        final orderTrackingData = {
          'ACC_CD': accCd,
          'LAT': latitude,
          'LONGI': longitude,
          'oId': parsedOId,
          'VOUCH_DT': vouchDt,
          'VOUCH_TIME': vouchTime,
          'MODULE_NO': moduleNo,
          'SYNC_ID': syncId,
          'USER_CD': userCd,
          'CREATED_BY': userCd,
          'CREATED_AT': now,
          'UPDATED_BY': userCd,
          'UPDATED_AT': now,
          'CREATED_APP_TYPE': 'oms',
          'REMARK': remark,
          'tracking_type': type,
          'sync_status': 'pending', // Will retry on sync
        };

        int trackingId = await db.insertOrderTracking(orderTrackingData);
        print(
            '[ORDER_TRACKING] ✅ Offline fallback: Saved to local DB | trackingId=$trackingId');
        print('[ORDER_TRACKING]   Will sync when online');

        return {
          'success': true,
          'synced': false,
          'message': 'Order tracking saved locally (will sync when online)',
          'error': apiError.toString(),
        };
      }
    } catch (e, stack) {
      print('[ORDER_TRACKING] ❌ CRITICAL ERROR: $e');
      print('[OrderTrackingService] Stack: $stack');
      return {
        'success': false,
        'message': 'Failed to process order tracking: $e',
      };
    }
  }
}
