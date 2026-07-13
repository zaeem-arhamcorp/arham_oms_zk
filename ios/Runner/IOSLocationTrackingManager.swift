import Foundation
import CoreLocation
import Flutter
import UserNotifications

/// IOSLocationTrackingManager
///
/// Native iOS location tracking manager that uses CLLocationManager for
/// continuous background location updates. This is the iOS equivalent of
/// the Android TrackingRecoveryManager + flutter_background_service combo.
///
/// Architecture:
/// - Primary: CLLocationManager with continuous updates (distanceFilter = 10m)
/// - Backup:  Significant-change location service (can relaunch killed app)
/// - 40-second elapsed-time gate before dispatching to Flutter
/// - All location data flows to Flutter via FlutterMethodChannel for SQLite storage + server sync
///
/// This class does NOT manage any Flutter/Dart state.
/// All trip/sync/database logic lives in Dart (ios_background_location_service.dart).
class IOSLocationTrackingManager: NSObject, CLLocationManagerDelegate {

    // MARK: - Constants

    /// Minimum seconds between location dispatches to Flutter.
    /// Matches Android's 40-second capture interval.
    private static let captureIntervalSeconds: TimeInterval = 40.0

    /// Distance filter in meters. Prevents excessive callbacks when stationary
    /// while still giving iOS enough events to enforce the 40-second gate.
    private static let distanceFilterMeters: CLLocationDistance = kCLDistanceFilterNone

    /// Maximum accepted accuracy in meters. Locations with worse accuracy are dropped.
    private static let maxAcceptedAccuracyMeters: CLLocationAccuracy = 30.0

    /// SharedPreferences (UserDefaults) prefix used by Flutter's shared_preferences plugin.
    private static let flutterPrefix = "flutter."

    // MARK: - Properties

    /// Primary location manager for continuous updates.
    private let continuousLocationManager: CLLocationManager

    /// Backup location manager for significant-change monitoring.
    /// Can relaunch the app after force-quit when user moves ~500m.
    private let significantChangeLocationManager: CLLocationManager

    /// Flutter method channel for sending location data to Dart.
    private var methodChannel: FlutterMethodChannel?

    /// Whether tracking is currently active.
    private(set) var isTracking: Bool = false

    /// Timestamp of last location dispatch to Flutter.
    private var lastDispatchTime: Date?

    /// Current trip tracking state (cached from Dart start call).
    private var currentUserCd: String?
    private var currentSyncId: Int?
    private var currentToken: String?
    private var currentTripId: Int?

    /// Queued location update received before Flutter engine was ready.
    /// Dispatched once the method channel is set.
    private var pendingLocationUpdate: CLLocation?

    /// Background timer to force location updates
    private var backgroundTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.arhamerp.app.locationTimer", attributes: .concurrent)

    // MARK: - Initialization

    override init() {
        continuousLocationManager = CLLocationManager()
        significantChangeLocationManager = CLLocationManager()
        super.init()

        // Configure continuous location manager
        continuousLocationManager.delegate = self
        continuousLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        continuousLocationManager.distanceFilter = IOSLocationTrackingManager.distanceFilterMeters
        continuousLocationManager.allowsBackgroundLocationUpdates = true
        continuousLocationManager.pausesLocationUpdatesAutomatically = false
        continuousLocationManager.showsBackgroundLocationIndicator = true
        continuousLocationManager.activityType = .other

        // Configure significant-change location manager
        significantChangeLocationManager.delegate = self
        significantChangeLocationManager.allowsBackgroundLocationUpdates = true

        NSLog("[IOSLocationTracking] Manager initialized")
    }

    // MARK: - Public API

    /// Set the Flutter method channel for communication with Dart.
    /// Called from AppDelegate after Flutter engine is ready.
    func setMethodChannel(_ channel: FlutterMethodChannel) {
        self.methodChannel = channel
        NSLog("[IOSLocationTracking] Method channel set")

        // Dispatch any pending location update that arrived before channel was ready
        if let pending = pendingLocationUpdate {
            NSLog("[IOSLocationTracking] Dispatching queued location update")
            dispatchLocationToFlutter(pending)
            pendingLocationUpdate = nil
        }
    }

    /// Start continuous location tracking + significant-change monitoring.
    /// Called from Dart when user punches in.
    func startTracking(userCd: String, syncId: Int, token: String, tripId: Int) {
        NSLog("[IOSLocationTracking] 🚀 Starting tracking for user=\(userCd), syncId=\(syncId), tripId=\(tripId)")

        currentUserCd = userCd
        currentSyncId = syncId
        currentToken = token
        currentTripId = tripId
        lastDispatchTime = nil
        isTracking = true

        // Check authorization status
        let authStatus = continuousLocationManager.authorizationStatus

        if authStatus == .notDetermined {
            NSLog("[IOSLocationTracking] Requesting Always authorization...")
            continuousLocationManager.requestAlwaysAuthorization()
            // Tracking will start in locationManagerDidChangeAuthorization after user responds
            return
        }

        if authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse {
            startLocationUpdates()
        } else {
            NSLog("[IOSLocationTracking] ❌ Location authorization denied: \(authStatus.rawValue)")
        }
    }

    /// Stop all location tracking.
    /// Called from Dart when user punches out.
    func stopTracking() {
        NSLog("[IOSLocationTracking] 🛑 Stopping tracking")

        continuousLocationManager.stopUpdatingLocation()
        significantChangeLocationManager.stopMonitoringSignificantLocationChanges()

        isTracking = false
        currentUserCd = nil
        currentSyncId = nil
        currentToken = nil
        currentTripId = nil
        lastDispatchTime = nil

        stopBackgroundTimer()
        removeTrackingNotification()

        NSLog("[IOSLocationTracking] ✅ All location services stopped")
    }

    /// Resume tracking from SharedPreferences (UserDefaults) if an active trip exists.
    /// Called on app launch / significant-change relaunch.
    /// Returns true if tracking was resumed.
    func resumeTrackingFromPrefs() -> Bool {
        let defaults = UserDefaults.standard
        let prefix = IOSLocationTrackingManager.flutterPrefix

        // Read global pointer: which firm is currently being tracked
        let trackingSyncIdKey = "\(prefix)active_tracking_sync_id"
        guard defaults.object(forKey: trackingSyncIdKey) != nil else {
            NSLog("[IOSLocationTracking] No active_tracking_sync_id in UserDefaults, skip resume")
            return false
        }
        let trackingSyncId = defaults.integer(forKey: trackingSyncIdKey)
        guard trackingSyncId > 0 else {
            NSLog("[IOSLocationTracking] active_tracking_sync_id is 0 or negative, skip resume")
            return false
        }

        // Check if explicitly stopped
        let stoppedKey = "\(prefix)tracking_explicitly_stopped_\(trackingSyncId)"
        if defaults.bool(forKey: stoppedKey) {
            NSLog("[IOSLocationTracking] Tracking explicitly stopped for syncId=\(trackingSyncId), skip resume")
            return false
        }

        // Read firm-specific trip data
        let tripIdKey = "\(prefix)active_trip_id_\(trackingSyncId)"
        let userCdKey = "\(prefix)active_user_cd_\(trackingSyncId)"
        let tokenKey = "\(prefix)active_trip_token_\(trackingSyncId)"

        let tripId = defaults.integer(forKey: tripIdKey)
        let userCd = defaults.string(forKey: userCdKey) ?? ""
        var token = defaults.string(forKey: tokenKey) ?? ""

        // Fallback to login token
        if token.isEmpty {
            token = defaults.string(forKey: "\(prefix)token") ?? ""
        }

        guard tripId > 0, !userCd.isEmpty, !token.isEmpty else {
            NSLog("[IOSLocationTracking] Missing trip data for syncId=\(trackingSyncId): tripId=\(tripId), hasUser=\(!userCd.isEmpty), hasToken=\(!token.isEmpty)")
            return false
        }

        NSLog("[IOSLocationTracking] 🔄 Resuming tracking: tripId=\(tripId), user=\(userCd), syncId=\(trackingSyncId)")
        startTracking(userCd: userCd, syncId: trackingSyncId, token: token, tripId: tripId)
        return true
    }

    // MARK: - Private Methods

    /// Start both continuous and significant-change location updates.
    private func startLocationUpdates() {
        NSLog("[IOSLocationTracking] 📍 Starting continuous location updates (distanceFilter=\(IOSLocationTrackingManager.distanceFilterMeters)m)")
        continuousLocationManager.startUpdatingLocation()

        NSLog("[IOSLocationTracking] 📍 Starting significant-change monitoring (backup)")
        significantChangeLocationManager.startMonitoringSignificantLocationChanges()

        // Show local tracking notification
        showTrackingNotification()

        // Start background timer to force periodic updates
        startBackgroundTimer()
    }

    /// Dispatch a location update to Flutter via MethodChannel.
    private func dispatchLocationToFlutter(_ location: CLLocation) {
        guard let channel = methodChannel else {
            NSLog("[IOSLocationTracking] ⚠️ No method channel, queuing location")
            pendingLocationUpdate = location
            return
        }

        let speedMps = max(0, location.speed)
        let activityType = inferActivityFromSpeed(speedMps)

        let args: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "speed": speedMps,
            "altitude": location.altitude,
            "timestamp": Int(location.timestamp.timeIntervalSince1970),
            "activityType": activityType,
        ]

        NSLog("[IOSLocationTracking] 📤 Dispatching to Flutter: lat=\(location.coordinate.latitude), lng=\(location.coordinate.longitude), accuracy=\(location.horizontalAccuracy)m, speed=\(speedMps)m/s, activity=\(activityType)")

        channel.invokeMethod("onLocationUpdate", arguments: args)
    }

    /// Infer activity type from GPS speed.
    /// Matches the Android _inferActivityFromSpeed logic.
    private func inferActivityFromSpeed(_ speedMps: Double) -> String {
        if speedMps >= 3.0 { return "DRIVING" }
        if speedMps >= 0.5 { return "WALKING" }
        return "STATIONARY"
    }

    /// Check if a location fix meets quality requirements.
    private func shouldKeepLocationFix(_ location: CLLocation) -> Bool {
        let accuracy = location.horizontalAccuracy
        return accuracy >= 0 && accuracy <= IOSLocationTrackingManager.maxAcceptedAccuracyMeters
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking, let location = locations.last else { return }

        // Log which manager delivered the update
        let source = (manager === significantChangeLocationManager) ? "significant-change" : "continuous"
        NSLog("[IOSLocationTracking] 📍 [\(source)] Location received: \(location.coordinate.latitude), \(location.coordinate.longitude) accuracy=\(location.horizontalAccuracy)m")

        // Quality gate: reject low-accuracy fixes
        guard shouldKeepLocationFix(location) else {
            NSLog("[IOSLocationTracking] ⚠️ Rejecting low-quality fix (accuracy=\(location.horizontalAccuracy)m > \(IOSLocationTrackingManager.maxAcceptedAccuracyMeters)m)")
            return
        }

        // Time gate: only dispatch if 40 seconds have elapsed
        let now = Date()
        if let lastDispatch = lastDispatchTime {
            let elapsed = now.timeIntervalSince(lastDispatch)
            if elapsed < IOSLocationTrackingManager.captureIntervalSeconds {
                // Not enough time has passed, skip this update
                return
            }
        }

        // Passed all gates — dispatch to Flutter
        lastDispatchTime = now
        dispatchLocationToFlutter(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("[IOSLocationTracking] ❌ Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        NSLog("[IOSLocationTracking] 🔑 Authorization changed: \(status.rawValue)")

        switch status {
        case .authorizedAlways:
            NSLog("[IOSLocationTracking] ✅ Always authorization granted")
            if isTracking {
                startLocationUpdates()
            }
        case .authorizedWhenInUse:
            NSLog("[IOSLocationTracking] ⚠️ Only WhenInUse authorization — background tracking will be limited")
            if isTracking {
                startLocationUpdates()
            }
        case .denied, .restricted:
            NSLog("[IOSLocationTracking] ❌ Location authorization denied/restricted")
        case .notDetermined:
            NSLog("[IOSLocationTracking] ℹ️ Authorization not determined yet")
        @unknown default:
            NSLog("[IOSLocationTracking] ℹ️ Unknown authorization status")
        }
    }

    private func startBackgroundTimer() {
        backgroundTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + IOSLocationTrackingManager.captureIntervalSeconds, repeating: IOSLocationTrackingManager.captureIntervalSeconds)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            NSLog("[IOSLocationTracking] ⏳ Background timer tick - Requesting location update...")
            DispatchQueue.main.async {
                if self.isTracking {
                    self.continuousLocationManager.requestLocation()
                }
            }
        }
        timer.resume()
        backgroundTimer = timer
        NSLog("[IOSLocationTracking] ✅ Background timer started (interval=\(IOSLocationTrackingManager.captureIntervalSeconds)s)")
    }

    private func stopBackgroundTimer() {
        backgroundTimer?.cancel()
        backgroundTimer = nil
        NSLog("[IOSLocationTracking] 🛑 Background timer stopped")
    }

    private func showTrackingNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Route Tracking Active"
        content.body = "Your location is being tracked during this route. Please DO NOT close the app."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "RouteTrackingNotification", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("[IOSLocationTracking] ❌ Error showing local notification: \(error.localizedDescription)")
            } else {
                NSLog("[IOSLocationTracking] 🔔 Local tracking notification displayed")
            }
        }
    }

    private func removeTrackingNotification() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["RouteTrackingNotification"])
        NSLog("[IOSLocationTracking] 🔔 Local tracking notification removed")
    }
}
