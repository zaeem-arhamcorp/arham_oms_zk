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

  static Future<void> initialize() async {
    await Workmanager().initialize(
      locationTrackingCallbackDispatcher,
      isInDebugMode: false,
    );
  }

  static Future<void> registerPeriodicRecoveryTask() async {
    await Workmanager().registerPeriodicTask(
      _uniqueTaskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );
  }
}

@pragma('vm:entry-point')
void locationTrackingCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    try {
      final backgroundService = BackgroundLocationService();
      await backgroundService.initialize();

      final resumed = await backgroundService.resumeTrackingIfActiveTrip();
      if (!resumed) {
        return true;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('active_token');
      if (token != null && token.isNotEmpty) {
        final hasInternet = await NetworkHelper.hasInternet();
        if (hasInternet) {
          await LocationSyncService().syncLocationTracking(token);
        }
      }

      return true;
    } catch (e) {
      print('[LocationTrackingWorkmanager] Worker execution error: $e');
      return true;
    }
  });
}
