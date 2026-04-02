import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_status_repository.dart';

/// Background Heartbeat Service
/// Sends heartbeat to server every 10 seconds to maintain online status
/// Continues running even when app is minimized or cleared from recent apps
@pragma('vm:entry-point')
class HeartbeatService {
  static final HeartbeatService _instance = HeartbeatService._internal();

  factory HeartbeatService() => _instance;

  HeartbeatService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  /// Heartbeat sent every 30 seconds
  /// Backend marks user offline if no heartbeat received within 30 seconds
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  Timer? _heartbeatTimer;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Initialize heartbeat background service
  /// Should be called once during app startup
  Future<void> initialize() async {
    try {
      print('[HeartbeatService] Initializing heartbeat background service...');

      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          // Heartbeat doesn't need foreground mode (no notification needed)
          // Using background-only mode to avoid location permission requirements
          isForegroundMode: false,
          autoStart: false,
          autoStartOnBoot: false,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
        ),
      );

      print('[HeartbeatService] ✅ Heartbeat background service configured');
    } catch (e) {
      print('[HeartbeatService] ❌ Error initializing heartbeat service: $e');
      rethrow;
    }
  }

  /// Start heartbeat monitoring
  /// Can be called when user logs in
  Future<void> startHeartbeat() async {
    try {
      if (_isRunning) {
        print('[HeartbeatService] Heartbeat already running');
        return;
      }

      print('[HeartbeatService] Starting heartbeat service...');

      await _service.startService();

      print('[HeartbeatService] ✅ Heartbeat service started');
      _isRunning = true;
    } catch (e) {
      print('[HeartbeatService] ❌ Error starting heartbeat: $e');
    }
  }

  /// Stop heartbeat monitoring
  /// Can be called when user logs out
  Future<void> stopHeartbeat() async {
    try {
      print('[HeartbeatService] Stopping heartbeat service...');

      _heartbeatTimer?.cancel();
      _service.invoke('stop_heartbeat');

      print('[HeartbeatService] ✅ Heartbeat service stopped');
      _isRunning = false;
    } catch (e) {
      print('[HeartbeatService] ⚠️ Error stopping heartbeat: $e');
    }
  }

  /// Background service entry point
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) {
    print('[HeartbeatService] [CALLBACK] Background service started');

    DartPluginRegistrant.ensureInitialized();
    print('[HeartbeatService] [CALLBACK] DartPluginRegistrant initialized');

    // Timer to send heartbeat every 10 seconds
    Timer.periodic(_heartbeatInterval, (timer) {
      _sendHeartbeatAsync(timer);
    });

    // Handle stop command
    service.on('stop_heartbeat').listen((_) {
      print('[HeartbeatService] [CALLBACK] Stop command received');
      service.stopSelf();
    });

    print('[HeartbeatService] [CALLBACK] Service setup complete, heartbeat timer started');
  }

  /// Send heartbeat asynchronously
  /// Separated from Timer.periodic to avoid type issues
  static void _sendHeartbeatAsync(Timer timer) async {
    try {
      print('[HeartbeatService] [CALLBACK] Heartbeat timer fired');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      print('[HeartbeatService] [CALLBACK] DEBUG: token from SharedPreferences = $token');

      if (token == null || token.isEmpty) {
        print('[HeartbeatService] [CALLBACK] ❌ No token found in SharedPreferences, skipping heartbeat');
        return;
      }

      final repository = UserStatusRepository();
      final success = await repository.sendHeartbeat(token: token);

      if (success) {
        print('[HeartbeatService] [CALLBACK] ✅ Heartbeat sent (30s) - User ONLINE');
      } else {
        print('[HeartbeatService] [CALLBACK] ⚠️ Heartbeat failed - will retry in 30 seconds');
      }
    } catch (e) {
      print('[HeartbeatService] [CALLBACK] ❌ Exception in heartbeat timer: $e');
    }
  }
}
