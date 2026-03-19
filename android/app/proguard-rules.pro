# Keep Flutter/Dart entry points and plugin registration.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep WorkManager callback entry points and background service plumbing.
-keep class be.tramckrijte.workmanager.** { *; }
-keep class id.flutter.flutter_background_service.** { *; }

# Keep app recovery receivers and manager used for restart watchdog.
-keep class com.arhamerp.app.TrackingRecoveryManager { *; }
-keep class com.arhamerp.app.TrackingWatchdogReceiver { *; }
-keep class com.arhamerp.app.TrackingBootReceiver { *; }
