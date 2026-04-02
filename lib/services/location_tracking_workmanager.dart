import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'background_location_service.dart';
import 'location_sync_service.dart';
import 'package:arham_corporation/helper/network_helper.dart';

class LocationTrackingWorkmanager {
  static const String _taskName = 'location_tracking_keepalive_task';
  static const String _uniqueTaskName = 'location_tracking_keepalive_unique';

  static const String _lastRegisteredAtKey = 'wm_last_registered_at';
  static const String _lastFiredAtKey = 'wm_last_fired_at';
  static const String _lastSuccessAtKey = 'wm_last_success_at';
  static const String _lastErrorKey = 'wm_last_error';
  static const String _lastTaskNameKey = 'wm_last_task_name';

  static Future<void> initialize() async {
    await Workmanager().initialize(
      locationTrackingCallbackDispatcher,
      isInDebugMode: false,
    );
  }

  static Future<void> registerPeriodicRecoveryTask() async {
    try {
      print(
          '[LocationTrackingWorkmanager] Attempting to register periodic recovery task...');
      await Workmanager().registerPeriodicTask(
        _uniqueTaskName,
        _taskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(
          networkType: NetworkType.not_required,
        ),
      );

      print(
          '[LocationTrackingWorkmanager] ✅ Registered periodic recovery task ($_uniqueTaskName / $_taskName)');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _lastRegisteredAtKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.remove(_lastErrorKey);
    } catch (e) {
      print(
          '[LocationTrackingWorkmanager] ❌ FAILED to register periodic task: $e');
      rethrow;
    }
  }

  static Future<void> logLastWorkerHeartbeat() async {
    final prefs = await SharedPreferences.getInstance();
    final registeredAt = prefs.getInt(_lastRegisteredAtKey);
    final firedAt = prefs.getInt(_lastFiredAtKey);
    final successAt = prefs.getInt(_lastSuccessAtKey);
    final taskName = prefs.getString(_lastTaskNameKey);
    final error = prefs.getString(_lastErrorKey);

    print('[LocationTrackingWorkmanager] ===== Worker heartbeat =====');
    print('[LocationTrackingWorkmanager] lastRegisteredAt=$registeredAt');
    print('[LocationTrackingWorkmanager] lastFiredAt=$firedAt');
    print('[LocationTrackingWorkmanager] lastSuccessAt=$successAt');
    print('[LocationTrackingWorkmanager] lastTaskName=$taskName');
    print('[LocationTrackingWorkmanager] lastError=$error');
    print('[LocationTrackingWorkmanager] ============================');
  }
}

@pragma('vm:entry-point')
void locationTrackingCallbackDispatcher() {
  print(
      '[LocationTrackingWorkmanager] [CALLBACK] Dispatcher invoked, calling executeTask...');

  Workmanager().executeTask((task, inputData) async {
    print(
        '[LocationTrackingWorkmanager] [CALLBACK] executeTask lambda entered for task=$task');

    try {
      print(
          '[LocationTrackingWorkmanager] [CALLBACK] Initializing Flutter bindings...');
      WidgetsFlutterBinding.ensureInitialized();
      print(
          '[LocationTrackingWorkmanager] [CALLBACK] WidgetsFlutterBinding initialized');

      DartPluginRegistrant.ensureInitialized();
      print(
          '[LocationTrackingWorkmanager] [CALLBACK] DartPluginRegistrant initialized');

      print(
          '[LocationTrackingWorkmanager] ▶️ Task fired: $task, inputData=$inputData');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(LocationTrackingWorkmanager._lastFiredAtKey,
          DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(LocationTrackingWorkmanager._lastTaskNameKey, task);
      await prefs.remove(LocationTrackingWorkmanager._lastErrorKey);

      final backgroundService = BackgroundLocationService();
      print(
          '[LocationTrackingWorkmanager] [CALLBACK] BackgroundLocationService created');

      await backgroundService.initialize();
      print(
          '[LocationTrackingWorkmanager] [CALLBACK] BackgroundLocationService initialized');

      final resumed = await backgroundService.resumeTrackingIfActiveTrip();
      if (!resumed) {
        print(
            '[LocationTrackingWorkmanager] ℹ️ No active trip found, nothing to recover');
        return true;
      }

      print(
          '[LocationTrackingWorkmanager] ✅ Active trip recovery attempted from WorkManager');

      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        final hasInternet = await NetworkHelper.hasInternet();
        if (hasInternet) {
          await LocationSyncService().syncLocationTracking(token);
          print(
              '[LocationTrackingWorkmanager] ✅ Triggered pending location sync from worker');
        } else {
          print(
              '[LocationTrackingWorkmanager] ℹ️ Worker fired without internet, sync skipped');
        }
      }

      await prefs.setInt(LocationTrackingWorkmanager._lastSuccessAtKey,
          DateTime.now().millisecondsSinceEpoch);
      print(
          '[LocationTrackingWorkmanager] [CALLBACK] Task execution complete, returning true');
      return true;
    } catch (e, stack) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          LocationTrackingWorkmanager._lastErrorKey, e.toString());
      print(
          '[LocationTrackingWorkmanager] [CALLBACK] ❌ EXCEPTION in executeTask: $e');
      print('[LocationTrackingWorkmanager] [CALLBACK] Stack: $stack');
      return true;
    }
  });
}
