import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Repository for user status and heartbeat API calls
/// Monitors online/offline status by sending periodic heartbeats
class UserStatusRepository {
  static final UserStatusRepository _instance =
      UserStatusRepository._internal();

  factory UserStatusRepository() => _instance;

  UserStatusRepository._internal();

  static const String _lastHeartbeatKey = 'user_status_last_heartbeat';
  static const String _onlineStatusKey = 'user_status_online';

  /// Send heartbeat to server every 30 seconds
  /// Backend marks user ONLINE while receiving heartbeats
  /// Backend marks user OFFLINE if no heartbeat received within 30 seconds
  /// Returns true if successful, false otherwise
  Future<bool> sendHeartbeat({required String token}) async {
    try {
      print('[UserStatusRepository] Sending heartbeat (30-second interval)...');
      print(
          '[UserStatusRepository] DEBUG: Token format check - starts with "eyJ": ${token.startsWith('eyJ')}');

      final url = Uri.parse(AppConfig.heartbeatURL);
      print('[UserStatusRepository] Heartbeat URL: $url');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('timeout', 408),
      );

      print(
          '[UserStatusRepository] Heartbeat response: ${response.statusCode}');
      print('[UserStatusRepository] Heartbeat response body: ${response.body}');

      // Store heartbeat timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastHeartbeatKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      // Accept 200, 201, or 204 as success (204 = No Content)
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        print(
            '[UserStatusRepository] ✅ Heartbeat sent successfully - User marked ONLINE');

        // Mark user as online
        await prefs.setBool(_onlineStatusKey, true);
        return true;
      } else if (response.statusCode == 401) {
        print(
            '[UserStatusRepository] ❌ 401 UNAUTHORIZED - Token may be invalid or expired');
        print('[UserStatusRepository] Response: ${response.body}');
        return false;
      } else {
        print(
            '[UserStatusRepository] ⚠️ Heartbeat failed with status: ${response.statusCode} - User may be marked OFFLINE if failures continue');
        print('[UserStatusRepository] Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[UserStatusRepository] ❌ Heartbeat exception: $e');
      return false;
    }
  }

  /// Get last heartbeat timestamp in milliseconds
  Future<int?> getLastHeartbeatTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastHeartbeatKey);
  }

  /// Check if user is marked as online
  Future<bool> isUserOnline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onlineStatusKey) ?? false;
  }

  /// Mark user as offline
  Future<void> markUserOffline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlineStatusKey, false);
    print('[UserStatusRepository] User marked as offline');
  }

  /// Mark user as online
  Future<void> markUserOnline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlineStatusKey, true);
    print('[UserStatusRepository] User marked as online');
  }

  /// Get heartbeat stats for debugging
  Future<Map<String, dynamic>> getHeartbeatStats() async {
    final prefs = await SharedPreferences.getInstance();
    final lastHeartbeat = prefs.getInt(_lastHeartbeatKey);
    final isOnline = prefs.getBool(_onlineStatusKey) ?? false;

    return {
      'lastHeartbeat': lastHeartbeat,
      'isOnline': isOnline,
      'lastHeartbeatAgo': lastHeartbeat != null
          ? DateTime.now().millisecondsSinceEpoch - lastHeartbeat
          : null,
    };
  }
}
