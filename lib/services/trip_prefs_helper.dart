/// Centralized helper for SharedPreferences keys used by punch-in/out
/// background location tracking.
///
/// All trip-state keys are **firm-specific**: they include the `syncId` so that
/// data from Firm A never bleeds into Firm B when the user has multiple firms.
///
/// Usage example:
///   await prefs.setInt(TripPrefsHelper.tripId(syncId), myTripId);
///   final id = prefs.getInt(TripPrefsHelper.tripId(syncId));
class TripPrefsHelper {
  TripPrefsHelper._(); // prevent instantiation

  // ──────────────────────────────────────────────────────────
  // Firm-scoped trip keys (append syncId to avoid cross-firm bleed)
  // ──────────────────────────────────────────────────────────

  /// Key for the currently active trip ID for a given firm.
  static String tripId(int syncId) => 'active_trip_id_$syncId';

  /// Key for the active user code for a given firm.
  static String userCd(int syncId) => 'active_user_cd_$syncId';

  /// Key for the active sync ID stored redundantly for quick access.
  static String syncIdKey(int syncId) => 'active_sync_id_$syncId';

  /// Key for the auth token used by the active trip for a given firm.
  static String tripToken(int syncId) => 'active_trip_token_$syncId';

  /// Key indicating tracking was explicitly stopped (punch-out) for a firm.
  static String explicitlyStopped(int syncId) =>
      'tracking_explicitly_stopped_$syncId';

  // ──────────────────────────────────────────────────────────
  // Global pointer (which firm is currently being tracked)
  // ──────────────────────────────────────────────────────────

  /// Stores the syncId of the firm currently being background-tracked.
  /// Read this first to know which firm-specific keys to use.
  /// Written on punch-in, cleared on punch-out.
  static const String currentTrackingSyncId = 'active_tracking_sync_id';

  // ──────────────────────────────────────────────────────────
  // Legacy global keys (kept for migration reads only)
  // After the first punch cycle these will no longer be written.
  // ──────────────────────────────────────────────────────────

  static const String legacyTripId = 'active_trip_id';
  static const String legacyUserCd = 'active_user_cd';
  static const String legacySyncId = 'active_sync_id';
  static const String legacyTripToken = 'active_trip_token';
  static const String legacyExplicitlyStopped = 'tracking_explicitly_stopped';

  // ──────────────────────────────────────────────────────────
  // Helper: clear all firm-specific tracking keys for a syncId
  // ──────────────────────────────────────────────────────────

  /// Remove all firm-specific trip keys for [syncId] from [prefs].
  /// Also clears the global pointer if it matches [syncId].
  static Future<void> clearFirmKeys(dynamic prefs, int syncId) async {
    await prefs.remove(tripId(syncId));
    await prefs.remove(userCd(syncId));
    await prefs.remove(syncIdKey(syncId));
    await prefs.remove(tripToken(syncId));
    await prefs.remove(explicitlyStopped(syncId));
    // Clear the global pointer only if it still points to this firm
    final pointer = prefs.getInt(currentTrackingSyncId);
    if (pointer == syncId) {
      await prefs.remove(currentTrackingSyncId);
    }
  }

  /// Also clear the old legacy global keys (one-time migration cleanup).
  static Future<void> clearLegacyKeys(dynamic prefs) async {
    await prefs.remove(legacyTripId);
    await prefs.remove(legacyUserCd);
    await prefs.remove(legacySyncId);
    await prefs.remove(legacyTripToken);
    await prefs.remove(legacyExplicitlyStopped);
  }
}
