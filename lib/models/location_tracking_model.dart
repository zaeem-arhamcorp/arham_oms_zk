/// Model class representing a location tracking record
/// Used for ongoing route tracking and background location capture
class LocationTrackingModel {
  final int? id;
  final double latitude;
  final double longitude;
  final int timestamp; // seconds since epoch
  final int synced; // 0 = not synced, 1 = synced
  final String userId;
  final int syncId;
  final String? remark;
  final DateTime capturedAt;

  LocationTrackingModel({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.synced,
    required this.userId,
    required this.syncId,
    this.remark,
    required this.capturedAt,
  });

  /// Convert to JSON for database storage
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'synced': synced,
      'userId': userId,
      'syncId': syncId,
      'remark': remark ?? '',
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  /// Create from database map
  factory LocationTrackingModel.fromMap(Map<String, dynamic> map) {
    return LocationTrackingModel(
      id: map['id'],
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      timestamp: map['timestamp'] ?? DateTime.now().toLocal().toIso8601String(),
      synced: map['synced'] ?? 0,
      userId: map['userId'] ?? '',
      syncId: map['syncId'] ?? 0,
      remark: map['remark'],
      capturedAt: map['capturedAt'] != null
          ? DateTime.parse(map['capturedAt'])
          : DateTime.now(),
    );
  }

  @override
  String toString() =>
      'LocationTracking(lat=$latitude, lng=$longitude, timestamp=$timestamp, synced=$synced)';
}
