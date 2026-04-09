# Activity Recognition Issue Analysis & Fix

## Problem Statement
When user PUNCHES IN, location tracking and activity recognition starts, but the notification always shows as **STATIONARY** in logs. The activity type should dynamically change based on actual user movement (WALKING, DRIVING, STATIONARY).

## Root Causes Identified

### 1. **SharedPreferences Key Mismatch (PRIMARY BUG)**
**Issue:** Native Android code saves to two different SharedPreferences stores:
- `"activity_recognition"` store with key `"current_activity"` (native-only diagnostics)
- `"FlutterSharedPreferences"` store with key `"flutter.current_activity"` (for Flutter access)

But Dart background isolate was reading from the WRONG location:
```dart
// ❌ WRONG - reading from native store, not Flutter store
final activity = prefs.getString('current_activity') ?? 'UNKNOWN';
```

**Solution:** Updated Dart to read from correct Flutter-prefixed key:
```dart
// ✅ CORRECT - reads from FlutterSharedPreferences store used by Flutter
var activity = prefs.getString('flutter.current_activity');
// With fallback to legacy key for compatibility
if (activity == null) {
    activity = prefs.getString('current_activity');
}
```

**Location:** [`lib/services/activity_recognition_service.dart`](lib/services/activity_recognition_service.dart#L139-L166)

---

### 2. **Missing Native Activity Updates (ROOT CAUSE)**
**Symptom:** Dart logs show:
```
[ActivityRecognitionService] ✅ Activity from SharedPreferences: UNKNOWN (updated 2026-04-09 22:58:24.267)
[BackgroundLocationService] 🔍 Activity Resolution: native=UNKNOWN, gpsSpeed=0.00m/s, speedDetected=STATIONARY, resolved=STATIONARY
```

**Issue:** The value is **UNKNOWN** with a timestamp matching app startup, meaning:
- BroadcastReceiver is **NOT being called** by Google Play Services with activity updates
- SharedPreferences never gets updated with actual activity data
- App stays at initial "UNKNOWN" value

**Possible Causes:**
1. Google Play Services ActivityRecognitionClient not sending updates (requires specific device conditions)
2. BroadcastReceiver not properly registered or receiving intents
3. Permission granted in Flutter but may not be communicated to native side correctly
4. Device not generating activity recognition updates (some devices/DOC versions don't support this)

**Solution:** Added comprehensive diagnostic logging to identify exactly where the failure occurs

---

## Changes Made

### Android (Kotlin) - Enhanced Diagnostics

#### **ActivityRecognitionManager.kt**
```kotlin
// Added update counter to track how many updates have been received
putInt("total_updates_received", (prefs.getInt("total_updates_received", 0) + 1))

// Added to logs:
- Device API Level
- Permission check with more details if denied
- PendingIntent creation details
- Count of total updates received
```

**Purpose:** Helps diagnose if BroadcastReceiver is being called by Google Play Services

#### **ActivityRecognitionReceiver.kt**
```kotlin
// Added diagnostics:
- App package name
- Thread name (diagnostic cross-check)
- Update count with timestamp
- Clear error message if activityManager is NULL
```

**Purpose:** Shows if the receiver is being invoked and by what thread

---

### Flutter (Dart) - Multiple Fixes

#### 1. **activity_recognition_service.dart** - SharedPreferences Key Fix
```dart
// Now reads from correct location:
// 1. First tries: flutter.current_activity (correct Flutter store)
// 2. Falls back to: current_activity (native store, for compatibility)
// 3. Falls back to: UNKNOWN

// Added diagnostic methods:
- getDiagnosticUpdateCount() → Shows how many updates received
- getDiagnosticLastUpdateTime() → Shows last update timestamp
```

#### 2. **background_location_service.dart** - Improved Diagnostics & Fallback
```dart
// Startup check:
final initialUpdateCount = await activityRecognition.getDiagnosticUpdateCount();
final lastUpdateTime = await activityRecognition.getDiagnosticLastUpdateTime();

if (initialUpdateCount == 0) {
    print('⚠️ WARNING: Activity Recognition may not be working');
    print('Will fallback to GPS speed-based detection');
}

// During tracking:
final speedStatus = activityType == 'UNKNOWN' 
    ? '⚠️ (native not working, using GPS)'
    : '';  // Shows indicator when activity recognition is not working
```

**Purpose:** Provides visibility into whether native activity recognition is working

---

## How Activity Recognition SHOULD Work (Current Design)

```
Timeline:
1. PUNCH IN → Request activity permission (main thread)
2. MainActivity.configureFlutterEngine() → Initialize ActivityRecognitionManager
3. Manager sends requestActivityUpdates() to Google Play Services
4. Google Play Services sends activity updates via BroadcastReceiver
5. Receiver updates the manager's currentActivity state
6. SharedPreferences updated with latest activity
7. Background isolate reads currentActivity via SharedPreferences
8. Activity type included in location tracking data
```

**Current Status:** Steps 1-2 work, step 4 shows no updates being received

---

## How to Diagnose Further

### Check Android Logcat for:
1. **Is BroadcastReceiver being called?**
   ```
   ActivityRecognitionReceiver: 🔔 onReceive() called by system
   ActivityRecognitionReceiver: Update #X received at TIMESTAMP
   ```
   
2. **Is manager being initialized?**
   ```
   ActivityRecognitionManager: 🚀 Initializing activity recognition...
   ActivityRecognitionManager: ✅ SUCCESS: Activity updates requested
   ```
   
3. **Permission status:**
   ```
   ActivityRecognitionManager: Permission check: ✅ GRANTED
   ```

### If BroadcastReceiver is NOT being called:
- Google Play Services may not be sending activity updates on this device
- Check device's "Physical Activity" settings
- Some Android versions/devices have limited activity recognition support

### If permission shows DENIED:
- Runtime permission not actually granted (only requested in UI)
- Verify in Android Settings → App Permissions → Activity Recognition

---

## Fallback Strategy Now Active

If native activity recognition isn't working (detects 0 updates), the app now:
1. Logs a clear warning message
2. Falls back to **GPS speed-based detection only**
3. Inference rules:
   - Speed ≥ 3.0 m/s → DRIVING
   - Speed 0.5-3.0 m/s → WALKING  
   - Speed < 0.5 m/s → STATIONARY

---

## Testing Steps

1. **Restart the app** - Logs will show update count during background tracking startup
2. **Check logcat** for "Activity Recognition" related logs
3. **Move around while tracking** - GPS speed should change if moving
4. If activity type is always STATIONARY:
   - Check if device is actually moving (GPS speed should be > 0.5 m/s when walking)
   - Check Android logcat for "ActivityRecognitionManager" and "ActivityRecognitionReceiver" messages
   - Monitor "total_updates_received" counter

---

## Summary

| Issue | Status | Impact |
|-------|--------|--------|
| SharedPreferences key mismatch | ✅ FIXED | Dart now reads from correct location |
| Missing diagnostic logging | ✅ FIXED | Can now trace exact failure point |
| No visibility into AR working | ✅ FIXED | Logs show update count and warnings |
| Fallback when AR fails | ✅ FIXED | GPS speed-based detection active |

**Next Investigation:** Check Android logcat to see if ActivityRecognitionReceiver is being called with actual activity updates.
