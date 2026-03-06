import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import '../config/app_config.dart';

class OrderTrackingService {
  final DatabaseHelper db = DatabaseHelper();

  /// Start or end order: saves locally first, then pushes to server if online.
  /// Returns {success: bool, synced: bool, message: string, ...}
  Future<Map<String, dynamic>> startEndOrder({
    required String accCd,
    required double latitude,
    required double longitude,
    required String type, // "3" for start/end
    String? oId,
    required String token,
    String moduleNo = "205",
    String userCd = "",
    int syncId = 0,
    bool? isEndOrder, // true for END, false for START, null for unknown
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final vouchDt = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD
      final vouchTime = DateTime.now().toString().split(' ')[1]; // HH:MM:SS

      // Save locally first - map to server schema
      // Set REMARK based on whether it's START or END order
      final remark =
          isEndOrder == null ? 'Order Tracking' : (isEndOrder ? 'OUT' : 'IN');

      final orderTrackingData = {
        'ACC_CD': accCd,
        'LAT': latitude,
        'LONGI': longitude,
        'oId': null,  // Tracking records NEVER have oId
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
        'sync_status': 'pending',
      };

      int trackingId = await db.insertOrderTracking(orderTrackingData);
      print('[OrderTrackingService] ✅ ORDER TRACKING SAVED TO LOCAL DB');
      print(
          '[OrderTrackingService]   trackingId=$trackingId | party=$accCd | type=$type');
      print('[OrderTrackingService]   lat=$latitude, lng=$longitude');
      print('[OrderTrackingService]   status=pending (waiting for sync)');

      // If online, immediately push to server
      final isOnline = await NetworkHelper.hasInternet();
      if (isOnline) {
        try {
          final body = {
            'accCd': accCd,
            'lat': latitude.toString(),
            'longi': longitude.toString(),
            'oId': oId ?? '',  // Include oId if provided (for END/OUT order)
            'type': type,  // Keep original type value (should be "3")
            'moduleNo': moduleNo,
            'remark': remark,
            'REMARK': remark,
            'remarks': remark,
            'VOUCH_DT': vouchDt,
            'VOUCH_TIME': vouchTime,
            'USER_CD': userCd,
            'SYNC_ID': syncId.toString(),
          };

          print(
              '[OrderTrackingService] 📤 ONLINE DETECTED - Pushing to server...');
          print(
              '[OrderTrackingService]   POST URL: ${AppConfig.baseURL}orders-tracking');
          print('[OrderTrackingService]   Payload: $body');

          final http.Response response = await http.post(
            Uri.parse("${AppConfig.baseURL}orders-tracking"),
            body: jsonEncode(body),
            headers: {
              "Authorization": "Bearer $token",
              'x-app-type': 'oms',
              'Content-Type': 'application/json',
            },
          );

          print(
              '[OrderTrackingService] 📥 Server response: ${response.statusCode}');
          print('[OrderTrackingService]   Response body: ${response.body}');

          if (response.statusCode == 200 || response.statusCode == 201) {
            // Success: mark as synced in local DB
            await db.updateOrderTrackingStatus(trackingId, 'synced', null);
            print('[OrderTrackingService] ✅ SYNC SUCCESSFUL');
            print(
                '[OrderTrackingService]   trackingId=$trackingId | Marked as synced');
            return {
              'success': true,
              'trackingId': trackingId,
              'synced': true,
              'message': 'Order tracking updated successfully',
            };
          } else {
            // Server error: keep as pending for later sync
            print(
                '[OrderTrackingService] ⚠️ SERVER ERROR ${response.statusCode}');
            print(
                '[OrderTrackingService]   trackingId=$trackingId | Status: PENDING (will retry)');
            return {
              'success': true,
              'trackingId': trackingId,
              'synced': false,
              'message': 'Order tracking saved (will sync when needed)',
              'error': 'Server error: ${response.statusCode}',
            };
          }
        } catch (e) {
          // Network/POST error: keep locally as pending
          print('[OrderTrackingService] ⚠️ POST FAILED');
          print('[OrderTrackingService]   trackingId=$trackingId | Error: $e');
          print(
              '[OrderTrackingService]   Status: PENDING (will retry when online)');
          return {
            'success': true,
            'trackingId': trackingId,
            'synced': false,
            'message': 'Order tracking saved locally (will sync when online)',
            'error': e.toString(),
          };
        }
      } else {
        // Offline: just local save, will sync later
        print('[OrderTrackingService] 📵 OFFLINE MODE - Saved locally only');
        print(
            '[OrderTrackingService]   trackingId=$trackingId | party=$accCd | type=$type');
        print(
            '[OrderTrackingService]   Status: PENDING (will sync when online)');
        return {
          'success': true,
          'trackingId': trackingId,
          'synced': false,
          'message': 'Order tracking saved offline (will sync when online)',
        };
      }
    } catch (e, stack) {
      print('[OrderTrackingService] Order tracking error: $e');
      print('[OrderTrackingService] Stack: $stack');
      return {
        'success': false,
        'message': 'Failed to process order tracking: $e',
      };
    }
  }
}
