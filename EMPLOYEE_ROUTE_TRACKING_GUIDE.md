# Employee Route Tracking with Punch In / Punch Out - Implementation Guide

## Overview

This implementation provides a complete employee route tracking system with Punch In/Punch Out functionality for the Arham OMS Flutter application. The system captures GPS location every 40 seconds during an active punch period and syncs all location data to the server with automatic retry on internet restoration.

## Architecture

### Key Components

1. **BackgroundLocationService** (`lib/services/background_location_service.dart`)
   - Manages background GPS location capture
   - Runs continuously even when app is minimized or closed
   - Captures location every 40 seconds
   - Syncs to server every 300 seconds (5 minutes) if internet is available

2. **LocationSyncService** (`lib/services/location_sync_service.dart`)
   - Handles syncing location data to the server
   - Syncs both continuous location tracking and punch-in/punch-out records
   - Manages offline queue and retry logic
   - Called both by background service and connectivity detection

3. **LocationService** (`lib/services/location_service.dart`)
   - Enhanced with `punchIn()` and `punchOut()` methods
   - Manages punch-in/punch-out operations
   - Verifies internet connectivity before punch
   - Starts/stops background service on punch in/out
   - Syncs remaining data on punch out

4. **DatabaseHelper** (`lib/services/database_helper.dart`)
   - Extended with `location_tracking` table for continuous GPS tracking
   - Provides CRUD operations for location tracking records
   - Manages both local punch records and continuous tracking data
   - Database version upgraded to 16

5. **ConnectivityService** (`lib/services/connectivity_service.dart`)
   - Enhanced to sync location tracking data when internet is restored
   - Automatically triggers location sync on connectivity changes

6. **MainActivity** (`android/app/src/main/kotlin/com/arhamerp/app/MainActivity.kt`)
   - Configured for flutter_background_service

## Database Schema

### location_tracking Table (New)

Stores continuous GPS location snapshots captured every 40 seconds.

```sql
CREATE TABLE location_tracking (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    latitude REAL NOT NULL DEFAULT 0.0,
    longitude REAL NOT NULL DEFAULT 0.0,
    timestamp INTEGER NOT NULL,        -- Original capture time (milliseconds)
    synced INTEGER NOT NULL DEFAULT 0, -- 0 = pending, 1 = synced
    user_cd TEXT NOT NULL,
    sync_id INTEGER NOT NULL,
    created_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP
)
```

Indexes:
- `idx_location_tracking_synced` on `synced` column
- `idx_location_tracking_user` on `(user_cd, sync_id)` columns

### locations Table (Existing - Enhanced)

Stores punch-in/punch-out records with location data.

```sql
CREATE TABLE locations (
    locId INTEGER PRIMARY KEY AUTOINCREMENT,
    USER_CD TEXT,
    VOUCH_DT TEXT NOT NULL,
    VOUCH_TIME TEXT NOT NULL DEFAULT '00:00:00',
    LAT REAL NOT NULL DEFAULT 0.0,
    LONGI REAL NOT NULL DEFAULT 0.0,
    REMARK TEXT NOT NULL DEFAULT '',
    SYNC_ID INTEGER NOT NULL,
    CREATED_BY TEXT NOT NULL DEFAULT '',
    CREATED_AT INTEGER NOT NULL,
    UPDATED_BY TEXT NOT NULL DEFAULT '',
    UPDATED_AT INTEGER NOT NULL,
    CREATED_APP_TYPE TEXT NOT NULL DEFAULT '',
    MODULE_NO TEXT NOT NULL,
    sync_status TEXT DEFAULT 'pending'
)
```

## API Endpoints

### Location Tracking Endpoint

**POST** `/location-tracking`

Receives continuous GPS location data from the background service.

```json
Request Body:
{
    "latitude": "20.5937",
    "longitude": "78.9629",
    "timestamp": "1678886400000",
    "user_cd": "EMP001",
    "sync_id": "1"
}

Response:
{
    "success": true,
    "message": "Location recorded"
}
```

### Punch Location Endpoint (Existing)

**POST** `/locations`

Receives punch-in/punch-out location records.

## Usage

### Punch In

```dart
import 'package:arham_corporation/services/location_service.dart';

final locationService = LocationService();

final result = await locationService.punchIn(
    userCd: 'EMP001',
    syncId: 1,
    token: authToken,
    vouchDt: '2024-03-13',
    vouchTime: '09:00:00',
    moduleNo: '203',
    createdBy: 'EMP001',
    remark: 'Daily route tracking'
);

if (result['success']) {
    print('Punch In Success: ${result['message']}');
    print('Tracking Started: ${result['tracking_started']}');
    print('Location: ${result['lat']}, ${result['longi']}');
} else {
    print('Punch In Failed: ${result['error']}');
}
```

**Response Map:**
- `success`: Boolean - Whether punch was recorded
- `locId`: Integer - Database ID of punch record
- `synced`: Boolean - Whether data was synced to server immediately
- `tracking_started`: Boolean - Whether background service started
- `lat`/`longi`: Double - Captured GPS coordinates
- `message`: String - Description of what happened
- `error`: String - Error message (if any)

**Requirements:**
- Internet connection REQUIRED (checked before punch)
- Location permissions must be granted
- User code and sync ID are required

### Punch Out

```dart
final result = await locationService.punchOut(
    userCd: 'EMP001',
    syncId: 1,
    token: authToken,
    vouchDt: '2024-03-13',
    vouchTime: '18:00:00',
    moduleNo: '203',
    createdBy: 'EMP001',
    remark: 'Day complete'
);

if (result['success']) {
    print('Punch Out Success: ${result['message']}');
    print('Tracking Stopped: ${result['tracking_stopped']}');
    
    // Check sync statistics
    final syncStats = result['sync_stats'];
    print('Tracking locations synced: ${syncStats['tracking_synced']}');
    print('Punch records synced: ${syncStats['punch_synced']}');
} else {
    print('Punch Out Failed: ${result['error']}');
}
```

**Response Map:**
- `success`: Boolean - Whether punch was recorded
- `locId`: Integer - Database ID of punch record
- `synced`: Boolean - Whether data was synced to server immediately
- `tracking_stopped`: Boolean - Whether background service was stopped
- `sync_stats`: Map - Statistics of synced data
  - `tracking_synced`: Count of synced location tracking records
  - `tracking_failed`: Count of failed location tracking records
  - `punch_synced`: Count of synced punch records
  - `punch_failed`: Count of failed punch records
  - `total_synced`: Total count of synced records
  - `total_failed`: Total count of failed records
- `message`: String - Description of what happened

**Requirements:**
- Internet connection REQUIRED (checked before punch)
- Background service must be running

### Manual Sync

```dart
final result = await locationService.syncPendingLocations(token);
if (result['success']) {
    print('Sync complete');
    final stats = result['sync_stats'];
    print('Total synced: ${stats['total_synced']}');
}
```

### Check Tracking Status

```dart
// Check if tracking is active
bool isActive = locationService.isTrackingActive();

// Get current statistics
final stats = await locationService.getTrackingStats();
print('Total locations tracked: ${stats['tracking_total']}');
print('Unsynced: ${stats['tracking_unsynced']}');
print('Synced: ${stats['tracking_synced']}');
print('Pending punch records: ${stats['punch_pending']}');
```

## Location Capture Flow

### During Active Punch Period

```
Every 40 seconds:
1. Capture current GPS location
2. Store in SQLite (location_tracking table)
   ├─ Always store locally first
   └─ Preserve original capture timestamp
3. Every 5 minutes:
   ├─ Check internet connectivity
   ├─ If connected:
   │  ├─ Fetch unsynced records
   │  ├─ Send to server `/location-tracking` endpoint
   │  └─ Mark as synced (synced = 1)
   └─ If offline:
      └─ Keep marked as pending (synced = 0)
```

### On Internet Restoration

```
Connectivity Service detects internet:
1. Fetch all unsynced location_tracking records (synced = 0)
2. Send batch to server
3. Mark as synced
4. Also sync punch records
5. Report completion
```

### On Punch Out

```
When user presses Punch Out:
1. Verify internet connection
2. Stop background service
3. Sync ALL remaining unsynced data
   ├─ location_tracking records
   └─ punch records
4. Record punch-out location
5. Return sync statistics
```

## Logging

The implementation includes comprehensive debug logging throughout. All log messages follow this format:

```
[ComponentName] 🚀 Action initiated
[ComponentName] 📍 Location captured: lat, lng
[ComponentName] 💾 Stored in SQLite: id=123
[ComponentName] 📤 Syncing to server...
[ComponentName] ✅ Success message
[ComponentName] ⚠️ Warning message
[ComponentName] ❌ Error message
```

### Sample Log Output

```
[LocationService] 🟢 PUNCH IN INITIATED
[LocationService]   User: EMP001 | Sync ID: 1
[LocationService]   Date: 2024-03-13 | Time: 09:00:00
[LocationService] ✅ Internet available, proceeding...
[LocationService] ✅ Punch recorded successfully
[LocationService] 🚀 Starting background location tracking...
[LocationService] ✅ PUNCH IN COMPLETE
[LocationService]   ✅ Location recorded: locId=42
[LocationService]   ✅ Background tracking started
[LocationService]   📍 Coordinates: 20.5937, 78.9629

[BackgroundLocationService] [Background] 🟢 Location tracking loop started
[BackgroundLocationService] [Background]   Capture interval: 40 seconds
[BackgroundLocationService] [Background]   Sync interval: 300 seconds

[BackgroundLocationService] [Background] 📍 Captured location: 20.59370, 78.96290
[BackgroundLocationService] [Background] 💾 Stored in SQLite: id=1
[BackgroundLocationService] [Background] 🔄 Sync interval reached, attempting sync...
[BackgroundLocationService] [Background] ✅ Synced id=1

[LocationService] 🔴 PUNCH OUT INITIATED
[LocationService] ✅ Internet available, proceeding...
[LocationService] 🛑 Stopping background tracking service...
[LocationService] 🔄 Syncing remaining location data...
[LocationService] ✅ PUNCH OUT COMPLETE
[LocationService]   📊 Sync complete: 1 success, 0 failed
```

## Android Permissions

The following permissions have been added to `AndroidManifest.xml`:

```xml
<!-- Fine location for precise GPS (always required) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Background location for Android 10+ -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Foreground service permissions -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

<!-- Wake lock to keep device running -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### Runtime Permissions

The app requests location permission at runtime using `permission_handler`. The background service will verify permissions before starting.

## Error Handling

### No Internet During Punch In
```
Error: "Punch In requires internet connection"
Action: Data is not recorded. User must be online to punch in.
```

### Location Permission Denied
```
Error: "Location permission permanently denied"
Action: Punch In is recorded but background tracking fails. User must grant permission in settings.
```

### Background Service Fails to Start
```
Warning: "Punch In recorded but background tracking failed to start"
Action: Punch is recorded, but continuous tracking won't work. User should check permissions.
```

### No Internet During Punch Out
```
Error: "Punch Out requires internet connection"
Action: Punch Out is not recorded. User must be online.
```

### Server Error During Sync
```
Warning: Location data is kept as pending and will retry on next sync attempt.
Retry Mechanism: Automatic retry when:
  - Internet is restored (ConnectivityService)
  - Next sync interval is reached (background service)
  - User manually triggers sync
```

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ PUNCH IN FLOW                                                   │
├─────────────────────────────────────────────────────────────────┤
│ 1. User presses Punch In                                        │
│    ↓                                                             │
│ 2. Check Internet (required)                                    │
│    ├─ Offline → Error, abort                                   │
│    └─ Online → Continue                                        │
│    ↓                                                             │
│ 3. Capture current GPS location                                │
│    ↓                                                             │
│ 4. Store punch-in record in SQLite (locations table)           │
│    ↓                                                             │
│ 5. Sync punch-in to server                                     │
│    ├─ Success → Mark as synced                                 │
│    └─ Fail → Mark as pending                                   │
│    ↓                                                             │
│ 6. Start BackgroundLocationService                             │
│    ↓ (Runs independently)                                       │
│ 7. Background: Every 40 seconds capture & store location       │
│    ↓                                                             │
│ 8. Background: Every 5 minutes attempt sync                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ LOCATION CAPTURE (Background Service)                           │
├─────────────────────────────────────────────────────────────────┤
│ 1. Wait 40 seconds                                              │
│    ↓                                                             │
│ 2. Get current GPS (with timeout)                              │
│    ├─ GPS available → Capture coords                           │
│    └─ GPS unavailable → Log, continue                          │
│    ↓                                                             │
│ 3. Store in SQLite location_tracking table                     │
│    ├─ latitude                                                  │
│    ├─ longitude                                                │
│    ├─ timestamp (original capture time)                        │
│    ├─ synced = 0 (pending)                                     │
│    └─ user_cd, sync_id                                         │
│    ↓                                                             │
│ 4. Update notification with latest location                    │
│    ↓                                                             │
│ 5. Check if 5-minute sync interval reached                     │
│    ├─ Yes → Attempt sync (see below)                           │
│    └─ No → Loop back to step 1                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ SYNC ATTEMPT                                                    │
├─────────────────────────────────────────────────────────────────┤
│ 1. Check internet connectivity                                  │
│    ├─ No internet → Skip, will retry later                      │
│    └─ Internet available → Continue                            │
│    ↓                                                             │
│ 2. Fetch unsynced records (synced = 0)                         │
│    ↓                                                             │
│ 3. For each location:                                           │
│    ├─ POST to /location-tracking endpoint                      │
│    ├─ Send: latitude, longitude, timestamp, user_cd, sync_id  │
│    ├─ Success (200/201) → Mark as synced (synced = 1)         │
│    └─ Failure → Keep as pending (synced = 0)                  │
│    ↓                                                             │
│ 4. Log: X synced, Y failed                                      │
│    ↓                                                             │
│ 5. Reset sync timer, wait 5 minutes for next attempt           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ PUNCH OUT FLOW                                                  │
├─────────────────────────────────────────────────────────────────┤
│ 1. User presses Punch Out                                       │
│    ↓                                                             │
│ 2. Check Internet (required)                                    │
│    ├─ Offline → Error, abort                                   │
│    └─ Online → Continue                                        │
│    ↓                                                             │
│ 3. Stop BackgroundLocationService                              │
│    ↓                                                             │
│ 4. Sync ALL remaining unsynced data                            │
│    ├─ location_tracking records (synced = 0)                   │
│    └─ punch records (sync_status = 'pending')                  │
│    ↓ (Wait for all to complete or fail)                        │
│ 5. Capture current GPS location                                │
│    ↓                                                             │
│ 6. Store punch-out record in SQLite                            │
│    ↓                                                             │
│ 7. Sync punch-out to server                                    │
│    ├─ Success → Mark as synced                                 │
│    └─ Fail → Mark as pending                                   │
│    ↓                                                             │
│ 8. Return: {success, message, sync_stats}                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ INTERNET RESTORATION (ConnectivityService)                      │
├─────────────────────────────────────────────────────────────────┤
│ 1. Connectivity changed from offline to online                  │
│    ↓                                                             │
│ 2. Verify actual internet (ping check)                         │
│    ├─ No real internet → Wait for next change                   │
│    └─ Real internet available → Continue                       │
│    ↓                                                             │
│ 3. Get user token from UserProvider                            │
│    ↓                                                             │
│ 4. Sync in this order:                                          │
│    ├─ Cart items                                                │
│    ├─ Offline orders                                            │
│    ├─ Punch locations (sync_status = 'pending')                │
│    ├─ Location tracking (synced = 0)                           │
│    └─ Order tracking records                                    │
│    ↓                                                             │
│ 5. Log completion: X synced, Y failed                           │
└─────────────────────────────────────────────────────────────────┘
```

## Testing Checklist

- [ ] Punch In without internet → Error shown
- [ ] Punch In with internet → Punch recorded, tracking started
- [ ] Location captured every 40 seconds → Check SQLite
- [ ] Sync every 5 minutes when online → Check logs
- [ ] Go offline, locations stored locally → Check synced = 0
- [ ] Internet restored → Locations synced automatically
- [ ] Punch Out without internet → Error shown
- [ ] Punch Out with internet → All data synced, service stopped
- [ ] Background service continues when app is minimized → GPS coordinates captured
- [ ] Background service continues when app is closed → Tap back to exit, check logs
- [ ] Location permission denied → Service fails gracefully
- [ ] Manual sync trigger → Works as expected

## Performance Considerations

1. **Database Size**: Long-term tracking can create many records. Consider:
   - Adding cleanup utility to delete records older than 90 days
   - Using `deleteOldLocationTracking(90)` method periodically

2. **Battery Usage**: GPS polling every 40 seconds will consume battery. Consider:
   - Using `LocationAccuracy.medium` instead of `high` if precision allows
   - Increasing interval if frequent updates aren't needed
   - Providing UI toggle to disable background tracking if needed

3. **Network Usage**: Continuous sync uses data. Consider:
   - The current 5-minute sync interval (adjust in `_syncIntervalSeconds` constant)
   - Batch syncing (already implemented)
   - Compress location data if possible

## Troubleshooting

### Background service not tracking
1. Check if Punch In was successful (tracking_started = true)
2. Verify location permissions are granted
3. Check logs for: `[BackgroundLocationService] 🟢 Location tracking loop started`
4. For Android: Ensure battery optimization is disabled for app

### Locations not syncing after Punch Out
1. Verify internet connection exists
2. Check logs for sync errors
3. Manually trigger sync with `syncPendingLocations(token)`
4. Check database: `SELECT COUNT(*) FROM location_tracking WHERE synced = 0`

### Battery draining quickly
1. Reduce location capture frequency (edit `_captureInterval` constant)
2. Use lower accuracy (edit `LocationAccuracy.high` to `.medium`)
3. Reduce sync frequency (edit `_syncIntervalSeconds` constant)
4. Check for stuck background service: `BackgroundLocationService().stopTracking()`

## Security Notes

1. **Authentication**: All API calls include `Authorization: Bearer $token` header
2. **User Isolation**: Each location record includes user_cd and sync_id for firm-specific isolation
3. **Data Integrity**: Original timestamp preserved for each location
4. **Permission Checking**: Background service verifies permissions before starting

## Migration from Previous Version

If upgrading from a previous version:

1. Database migration runs automatically (v15 → v16)
2. Existing punch records in `locations` table unchanged
3. New `location_tracking` table created empty
4. No action required; existing functionality preserved

## Future Enhancements

1. Send location snapshots as images for geofencing verification
2. Add route visualization/playback
3. Geofencing alerts (enter/leave client location)
4. Integration with attendance system
5. Real-time location sharing to supervisor
6. Location history reports and analytics
