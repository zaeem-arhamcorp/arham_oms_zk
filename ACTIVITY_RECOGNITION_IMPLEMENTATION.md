# Activity Recognition Implementation Guide

## Overview
Native Android implementation for detecting user activity (walking, driving, stationary) using Google Play Services ActivityRecognitionClient.

## Files Created

### 1. **ActivityRecognitionManager.kt**
- Location: `android/app/src/main/kotlin/com/arhamerp/app/ActivityRecognitionManager.kt`
- Handles all activity recognition logic
- Manages currentActivity state and confidence scores
- Updates activity from ActivityRecognitionResult
- Normalizes Android activity types to standardized names:
  - `IN_VEHICLE` → `DRIVING`
  - `ON_BICYCLE` / `ON_FOOT` → `CYCLING` / `WALKING`
  - `WALKING` / `RUNNING` → `WALKING`
  - `STILL` / `TILTING` → `STATIONARY`
  - Everything else → `UNKNOWN`

### 2. **ActivityRecognitionReceiver.kt**
- Location: `android/app/src/main/kotlin/com/arhamerp/app/ActivityRecognitionReceiver.kt`
- BroadcastReceiver for Google Play Services activity updates
- Updates ActivityRecognitionManager when new activity is detected
- Maintains static reference for communication between components

### 3. **MainActivity.kt** (Modified)
- Added ActivityRecognitionManager initialization
- Added MethodChannel handler for `com.arhamerp.app/activity_recognition`
- Handles two method calls:
  - `getCurrentActivity()` → Returns current activity string
  - `getActivityConfidence()` → Returns confidence (0-100)
- Links receiver to manager via static reference

### 4. **AndroidManifest.xml** (Modified)
- Added ActivityRecognitionReceiver to `<application>` section
- Permissions already included: `android.permission.ACTIVITY_RECOGNITION`

## How It Works

### Initialization Flow
1. **MainActivity starts** → Creates ActivityRecognitionManager
2. **Manager initializes** → Requests activity updates from Google Play Services
3. **Updates are sent** → To ActivityRecognitionReceiver (broadcast)
4. **Receiver processes** → Updates manager with new activity
5. **Dart calls via MethodChannel** → Retrieves current activity/confidence

### Background Service Flow
1. **LocationService.punchIn()** → Requests activity permission on main thread
2. **Background service starts** → Calls ActivityRecognitionService.getCurrentActivity()
3. **Dart calls native** → Via MethodChannel `com.arhamerp.app/activity_recognition`
4. **Native returns** → Current activity detected by ActivityRecognitionManager
5. **Location captured** → With `activity_type` field

## Dependencies
- Already included in `build.gradle`:
  - `com.google.android.gms:play-services-location:21.3.0`
  - Includes ActivityRecognitionClient

## Important Notes

### Thread Safety
- Activity updates are broadcast and can arrive on any thread
- Manager stores activity in instance variables (safe because only written from receiver)
- Dart calls via MethodChannel happen on main thread

### Graceful Degradation
- If native implementation fails to initialize, returns `UNKNOWN`
- No crashes - tracking continues normally
- All errors are logged for debugging

### Permission Handling
- Permission is requested in LocationService.punchIn() on main thread
- Background service doesn't try to request (would fail)
- Only needs to read from existing permission grant

### Activity Update Interval
- Updates every 5 seconds (configurable in `UPDATE_INTERVAL_MS`)
- Can be adjusted down for more frequent updates or up for battery saving

## Testing

### Manual Testing
1. Start punch-in (permission granted)
2. Check logs for "Activity detected: WALKING/DRIVING/STATIONARY/UNKNOWN"
3. Verify `activity_type` in API payload on `/location/update` calls

### Supported Activities
- **WALKING**: Includes on_foot, running
- **DRIVING**: In vehicle
- **CYCLING**: On bicycle  
- **STATIONARY**: Still or tilting device
- **UNKNOWN**: No activity detected or error

## Future Enhancements
- Make update interval configurable from Dart
- Add activity change listener stream for real-time updates in UI
- Filter activities by confidence threshold
- Add heuristic fallback (GPS speed-based) if native fails
