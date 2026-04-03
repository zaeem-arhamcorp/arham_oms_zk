import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'user_status_repository.dart';

/// Heartbeat WorkManager for periodic checks when app is completely closed
/// Runs as a fallback mechanism to maintain user online status even if background service is killed
class HeartbeatWorkmanager {
  static const String _taskName = 'heartbeat_periodic_task';
  static const String _uniqueTaskName = 'heartbeat_periodic_unique';

  static const String _lastRegisteredAtKey = 'hb_wm_last_registered_at';
  static const String _lastFiredAtKey = 'hb_wm_last_fired_at';
  static const String _lastSuccessAtKey = 'hb_wm_last_success_at';
  static const String _lastErrorKey = 'hb_wm_last_error';
  static const String _lastTaskNameKey = 'hb_wm_last_task_name';
  static const String _taskCountKey = 'hb_wm_task_count';

  /// Initialize WorkManager for heartbeat tasks
  static Future<void> initialize() async {
    // ✅ Workmanager is now initialized in main.dart
    // This method is kept for backward compatibility
    // Do NOT call Workmanager().initialize() again here to avoid double-initialization crashes
    print(
        '[HeartbeatWorkmanager] ✅ Using shared Workmanager instance from main');
  }

  /// Register periodic heartbeat task (every 15 minutes as recovery mechanism)
  /// Strategy:
  /// - PRIMARY: foreground location tracking service sends heartbeat every 30 seconds
  /// - FALLBACK: WorkManager fires every 15 minutes to recover if service is killed
  /// - GOAL: Ensure heartbeat is sent every 30 seconds to keep user online
  ///
  /// This runs even if the app is completely closed, ensuring user isn't marked offline
  static Future<void> registerPeriodicHeartbeatTask() async {
    try {
      print(
          '[HeartbeatWorkmanager] Attempting to register periodic heartbeat recovery task...');

      await Workmanager().registerPeriodicTask(
        _uniqueTaskName,
        _taskName,
        // Run every 15 minutes for recovery (WorkManager minimum is ~15 min)
        // Primary 30-second heartbeat is handled by flutter_background_service
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

      print(
          '[HeartbeatWorkmanager] ✅ Registered periodic heartbeat recovery task every 15 minutes ($_uniqueTaskName / $_taskName)');
      print(
          '[HeartbeatWorkmanager] ℹ️ PRIMARY: foreground location tracking service sends heartbeat every 30 seconds');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastRegisteredAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.remove(_lastErrorKey);
    } catch (e) {
      print(
          '[HeartbeatWorkmanager] ❌ FAILED to register periodic heartbeat task: $e');
      rethrow;
    }
  }

  /// Cancel all heartbeat tasks
  static Future<void> cancelHeartbeatTasks() async {
    try {
      print('[HeartbeatWorkmanager] Canceling heartbeat tasks...');
      await Workmanager().cancelByUniqueName(_uniqueTaskName);
      print('[HeartbeatWorkmanager] ✅ Heartbeat tasks canceled');
    } catch (e) {
      print('[HeartbeatWorkmanager] ⚠️ Error canceling tasks: $e');
    }
  }

  /// Log heartbeat worker stats for debugging
  static Future<void> logHeartbeatWorkerHeartbeat() async {
    final prefs = await SharedPreferences.getInstance();
    final registeredAt = prefs.getInt(_lastRegisteredAtKey);
    final firedAt = prefs.getInt(_lastFiredAtKey);
    final successAt = prefs.getInt(_lastSuccessAtKey);
    final taskName = prefs.getString(_lastTaskNameKey);
    final error = prefs.getString(_lastErrorKey);
    final taskCount = prefs.getInt(_taskCountKey) ?? 0;

    print('[HeartbeatWorkmanager] ===== Heartbeat Worker Stats =====');
    print('[HeartbeatWorkmanager] lastRegisteredAt: $registeredAt');
    print('[HeartbeatWorkmanager] lastFiredAt: $firedAt');
    print('[HeartbeatWorkmanager] lastSuccessAt: $successAt');
    print('[HeartbeatWorkmanager] lastTaskName: $taskName');
    print('[HeartbeatWorkmanager] taskCount: $taskCount');
    if (error != null) {
      print('[HeartbeatWorkmanager] lastError: $error');
    }
    print('[HeartbeatWorkmanager] ==================================');
  }
}

/// Callback dispatcher for heartbeat workmanager
/// This function is invoked in an isolate when WorkManager fires the periodic task
@pragma('vm:entry-point')
void heartbeatCallbackDispatcher() {
  print(
      '[HeartbeatWorkmanager] [CALLBACK] Dispatcher invoked, calling executeTask...');

  Workmanager().executeTask((task, inputData) async {
    print(
        '[HeartbeatWorkmanager] [CALLBACK] executeTask lambda entered for task=$task');

    try {
      print(
          '[HeartbeatWorkmanager] [CALLBACK] Initializing Flutter bindings...');
      WidgetsFlutterBinding.ensureInitialized();
      print(
          '[HeartbeatWorkmanager] [CALLBACK] WidgetsFlutterBinding initialized');

      DartPluginRegistrant.ensureInitialized();
      print(
          '[HeartbeatWorkmanager] [CALLBACK] DartPluginRegistrant initialized');

      print(
          '[HeartbeatWorkmanager] ▶️ Heartbeat recovery task fired: $task, inputData=$inputData');

      final prefs = await SharedPreferences.getInstance();

      // Log task execution
      await prefs.setInt(
        HeartbeatWorkmanager._lastFiredAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setString(HeartbeatWorkmanager._lastTaskNameKey, task);
      await prefs.remove(HeartbeatWorkmanager._lastErrorKey);

      // Increment task count
      final taskCount =
          (prefs.getInt(HeartbeatWorkmanager._taskCountKey) ?? 0) + 1;
      await prefs.setInt(HeartbeatWorkmanager._taskCountKey, taskCount);

      // Heartbeat should run only during active punch-in tracking sessions.
      final activeTripId = prefs.getInt('active_trip_id');
      if (activeTripId == null || activeTripId <= 0) {
        print(
            '[HeartbeatWorkmanager] [CALLBACK] ℹ️ No active trip. Skipping heartbeat recovery.');
        return true;
      }

      // Get token and send heartbeat
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        print(
            '[HeartbeatWorkmanager] [CALLBACK] ℹ️ No active token, user not logged in');
        return true;
      }

      final repository = UserStatusRepository();
      final success = await repository.sendHeartbeat(token: token);

      if (success) {
        print(
            '[HeartbeatWorkmanager] ✅ Heartbeat recovery sent successfully (count: $taskCount)');
        await prefs.setInt(
          HeartbeatWorkmanager._lastSuccessAtKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        print('[HeartbeatWorkmanager] ⚠️ Heartbeat recovery failed');
      }

      return true;
    } catch (e, stack) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        HeartbeatWorkmanager._lastErrorKey,
        e.toString(),
      );
      print(
          '[HeartbeatWorkmanager] [CALLBACK] ❌ EXCEPTION in heartbeat recovery: $e');
      print('[HeartbeatWorkmanager] [CALLBACK] Stack: $stack');
      return true;
    }
  });
}
