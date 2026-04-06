import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../widgets/user_search_dropdown.dart';
import 'trip_detail_map_screen.dart';

class RouteReportScreen extends StatefulWidget {
  final String? selectedUserCd;
  final String? selectedUserName;

  const RouteReportScreen({
    super.key,
    this.selectedUserCd,
    this.selectedUserName,
  });

  @override
  State<RouteReportScreen> createState() => _RouteReportScreenState();
}

class _RouteReportScreenState extends State<RouteReportScreen> {
  late DateTime _fromDate;
  late DateTime _toDate;

  bool _loading = false;

  String? _error;
  List<Map<String, dynamic>> _trips = <Map<String, dynamic>>[];
  final Map<int, Map<String, String>> _gapInfoByTripId =
      <int, Map<String, String>>{};
  final Map<int, Map<String, String>> _distanceBreakdownByTripId =
      <int, Map<String, String>>{};
  final Set<int> _gapLoadingIds = <int>{};

  // User dropdown state
  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = false;
  String? _selectedUserName;
  String _selectedUserCode = '';
  bool _usersFetchInitiated = false;

  @override
  void initState() {
    super.initState();
    CrashlyticsService.setScreenName('RouteReportScreen');
    CrashlyticsService.logAction('route_report_opened');

    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month, now.day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUsers();
      _fetchTrips();
    });
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _loadingUsers = true;
    });
    try {
      await CrashlyticsService.logAction('route_report_users_api_triggered');
      final ub = Provider.of<UserProvider>(context, listen: false);
      final token = ub.token;
      if (token == null || token.isEmpty) {
        setState(() {
          _users = [];
          _loadingUsers = false;
        });
        return;
      }
      final uri = Uri.parse('${AppConfig.baseURL}users/children');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
      );
      print(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final usersList = (data['data'] is List) ? data['data'] : [];

        setState(() {
          _users = List<Map<String, dynamic>>.from(
            usersList.map((user) {
              final userCode = user['USER_CD'] ?? '';
              final userName = (user['USER_NAME'] ?? '').trim();
              final phone = (user['MOBILENO'] ?? '').trim();
              return {
                'userCode': userCode,
                'userName': userName,
                'phone': phone,
              };
            }),
          );
          _loadingUsers = false;
        });
      } else {
        setState(() {
          _users = [];
          _loadingUsers = false;
        });
      }
    } catch (e, stack) {
      setState(() {
        _users = [];
        _loadingUsers = false;
      });
      await CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'route_report_users_fetch_failed',
      );
    }
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _displayDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final v = raw.trim();
    return v.length >= 10 ? v.substring(0, 10) : v;
  }

  String _displayDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final v = raw.trim();
    return v.replaceFirst('T', ' ').split('.').first;
  }

  String _datePart(String? raw) {
    final v = _displayDateTime(raw);
    if (v == '-') return '-';
    final parts = v.split(' ');
    if (parts.isEmpty) return '-';

    final dateStr = parts.first;
    try {
      final dt = DateTime.parse(dateStr);
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return '$dd/$mm/$yyyy';
    } catch (_) {
      return dateStr;
    }
  }

  String _timePart(String? raw) {
    final v = _displayDateTime(raw);
    if (v == '-') return '-';
    final parts = v.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '-';
  }

  /// Open date picker for "from date"
  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: _toDate,
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
      });
      _fetchTrips();
    }
  }

  /// Open date picker for "to date"
  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
      });
      _fetchTrips();
    }
  }

  /// Build date range filter widget
  Widget _buildDateRangeFilter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Date Range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // From Date
              Expanded(
                child: GestureDetector(
                  onTap: _pickFromDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'From Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fmtDate(_fromDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // To Date
              Expanded(
                child: GestureDetector(
                  onTap: _pickToDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'To Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fmtDate(_toDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _extractTripsFromResponseBody(String body) {
    final decoded = json.decode(body);
    final dynamic data = decoded['data'];

    dynamic tripsRaw = data;
    if (data is Map<String, dynamic> && data['trips'] is List) {
      tripsRaw = data['trips'];
    }

    return (tripsRaw is List)
        ? tripsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
  }

  int _tripIdFromMap(Map<String, dynamic> trip) {
    final dynamic raw =
        trip['id'] ?? trip['ID'] ?? trip['trip_id'] ?? trip['TRIP_ID'];
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _tripUserFromMap(Map<String, dynamic> trip) {
    final dynamic raw =
        trip['user_cd'] ?? trip['USER_CD'] ?? trip['userCd'] ?? trip['USERCD'];
    return raw?.toString() ?? '-';
  }

  String _tripStartFromMap(Map<String, dynamic> trip) {
    final dynamic raw = trip['start_time'] ??
        trip['START_TIME'] ??
        trip['started_at'] ??
        trip['STARTED_AT'] ??
        trip['created_at'] ??
        trip['CREATED_AT'];
    return _displayDateTime(raw?.toString());
  }

  String _tripStartDateFromMap(Map<String, dynamic> trip) {
    final dynamic raw = trip['start_time'] ??
        trip['START_TIME'] ??
        trip['started_at'] ??
        trip['STARTED_AT'] ??
        trip['created_at'] ??
        trip['CREATED_AT'];
    return _datePart(raw?.toString());
  }

  String _tripStartTimeFromMap(Map<String, dynamic> trip) {
    final dynamic raw = trip['start_time'] ??
        trip['START_TIME'] ??
        trip['started_at'] ??
        trip['STARTED_AT'] ??
        trip['created_at'] ??
        trip['CREATED_AT'];
    return _timePart(raw?.toString());
  }

  String _tripEndFromMap(Map<String, dynamic> trip) {
    final dynamic raw = trip['end_time'] ??
        trip['END_TIME'] ??
        trip['ended_at'] ??
        trip['ENDED_AT'];
    return _displayDateTime(raw?.toString());
  }

  String _tripEndDateFromMap(Map<String, dynamic> trip) {
    final dynamic raw = trip['end_time'] ??
        trip['END_TIME'] ??
        trip['ended_at'] ??
        trip['ENDED_AT'];
    return _datePart(raw?.toString());
  }

  String _tripEndTimeFromMap(Map<String, dynamic> trip) {
    final dynamic raw = trip['end_time'] ??
        trip['END_TIME'] ??
        trip['ended_at'] ??
        trip['ENDED_AT'];
    return _timePart(raw?.toString());
  }

  bool _tripActiveFromMap(Map<String, dynamic> trip) {
    final dynamic raw = trip['is_active'] ??
        trip['IS_ACTIVE'] ??
        trip['active'] ??
        trip['ACTIVE'];
    final String v = raw?.toString().toLowerCase() ?? '';
    return v == '1' || v == 'true' || v == 'y';
  }

  dynamic _firstValue(Map<String, dynamic> map, List<String> keys) {
    String normalize(String s) => s.toLowerCase().replaceAll('_', '');

    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) return map[key];

      final normalizedKey = normalize(key);
      for (final entry in map.entries) {
        if (normalize(entry.key) == normalizedKey && entry.value != null) {
          return entry.value;
        }
      }
    }
    return null;
  }

  String _durationFromMap(Map<String, dynamic> map) {
    final formatted = _firstValue(map, [
      'duration_formatted',
      'total_duration_formatted',
      // 'total_duration',
      'moving_time_formatted',
      'movingTimeFormatted',
      'durationFormatted',
    ]);
    if (formatted != null && formatted.toString().trim().isNotEmpty) {
      return formatted.toString();
    }

    final startRaw = _firstValue(map, ['start_time', 'START_TIME']);
    final endRaw = _firstValue(map, ['end_time', 'END_TIME']);
    try {
      if (startRaw != null && endRaw != null) {
        final start = DateTime.parse(startRaw.toString());
        final end = DateTime.parse(endRaw.toString());
        final diff = end.difference(start);
        if (!diff.isNegative) {
          final h = diff.inHours;
          final m = diff.inMinutes.remainder(60);
          final s = diff.inSeconds.remainder(60);
          return '${h}h ${m}m ${s}s';
        }
      }
    } catch (_) {}
    return '-';
  }

  String _distanceKmFromMap(Map<String, dynamic> map) {
    final distance = _firstValue(map, [
      'total_distance',
      'distance_km',
      'distance',
      'totalDistance',
      'DISTANCE'
    ]);
    if (distance == null) return '-';
    final value = double.tryParse(distance.toString());
    return value == null ? '-' : '${value.toStringAsFixed(2)} km';
  }

  String _speedFromMap(Map<String, dynamic> map) {
    final speed = _firstValue(map,
        ['avg_speed', 'average_speed', 'avgSpeed', 'averageSpeed', 'speed']);
    if (speed == null) return '-';
    final value = double.tryParse(speed.toString());
    return value == null ? '-' : '${value.toStringAsFixed(2)} km/h';
  }

  String _kmString(dynamic value) {
    if (value == null) return '-';
    final parsed = double.tryParse(value.toString());
    if (parsed == null) return '-';
    return '${parsed.toStringAsFixed(2)} km';
  }

  void _ensureTripGapInfo(int tripId) {
    if (tripId <= 0) return;
    if (_gapInfoByTripId.containsKey(tripId)) return;
    if (_gapLoadingIds.contains(tripId)) return;
    _fetchTripGapInfo(tripId);
  }

  Future<void> _fetchTripGapInfo(int tripId) async {
    final ub = Provider.of<UserProvider>(context, listen: false);
    final token = ub.token;
    if (token == null || token.isEmpty) return;

    _gapLoadingIds.add(tripId);
    try {
      final uri = Uri.parse('${AppConfig.baseURL}location/trip/$tripId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode != 200) return;

      final decoded = json.decode(response.body);
      final data = decoded['data'];
      if (data is! Map) return;

      final orderTiming = data['order_tracking_timing'];
      if (orderTiming is! Map) return;

      final punchGap = orderTiming['punch_in_to_first_in_gap'];
      final outGap = orderTiming['last_out_to_punch_out_gap'];
      final distanceBreakdown = orderTiming['distance_breakdown'];

      final punchFormatted =
          (punchGap is Map) ? (punchGap['formatted']?.toString() ?? '-') : '-';
      final punchKm =
          (punchGap is Map) ? _kmString(punchGap['distance_km']) : '-';

      final outFormatted =
          (outGap is Map) ? (outGap['formatted']?.toString() ?? '-') : '-';
      final outKm = (outGap is Map) ? _kmString(outGap['distance_km']) : '-';

      final businessKm = (distanceBreakdown is Map)
          ? _kmString(distanceBreakdown['business_km'])
          : '-';
      final transitKm = (distanceBreakdown is Map)
          ? _kmString(distanceBreakdown['transit_km'])
          : '-';

      if (!mounted) return;
      setState(() {
        _gapInfoByTripId[tripId] = {
          'punchFormatted': punchFormatted,
          'punchKm': punchKm,
          'outFormatted': outFormatted,
          'outKm': outKm,
        };

        _distanceBreakdownByTripId[tripId] = {
          'businessKm': businessKm,
          'transitKm': transitKm,
        };
      });
    } catch (e, stack) {
      await CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'route_report_trip_gap_fetch_failed',
        context: {'trip_id': tripId},
      );
      // Keep UI fallback as '-'
    } finally {
      _gapLoadingIds.remove(tripId);
    }
  }

  Future<void> _fetchTrips() async {
    final ub = Provider.of<UserProvider>(context, listen: false);
    final profile = Provider.of<ProfileProvider>(context, listen: false);

    final token = ub.token;

    // Use _selectedUserCode if user selected from dropdown,
    // otherwise use widget.selectedUserCd or logged-in user's code
    final userCd = _selectedUserCode.isNotEmpty
        ? _selectedUserCode
        : (widget.selectedUserCd ??
            (profile.userCode?.trim().isNotEmpty == true
                ? profile.userCode!.trim()
                : ''));

    final syncId = ub.syncId?.trim() ?? '';

    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Missing auth token';
      });
      return;
    }

    if (userCd.isEmpty) {
      setState(() {
        _error = 'Missing user code for trip lookup';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CrashlyticsService.logAction(
        'route_report_trips_api_triggered',
        context: {
          'user_cd': userCd,
          'from_date': _fmtDate(_fromDate),
          'to_date': _fmtDate(_toDate),
        },
      );

      final uri = Uri.parse('${AppConfig.baseURL}location/trip').replace(
        queryParameters: {
          'fromDate': _fmtDate(_fromDate),
          'toDate': _fmtDate(_toDate),
          'user_cd': userCd,
        },
      );

      print('[RouteReport] GET $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        List<Map<String, dynamic>> trips =
            _extractTripsFromResponseBody(response.body);

        if (trips.isEmpty && syncId.isNotEmpty && syncId != userCd) {
          final fallbackUri =
              Uri.parse('${AppConfig.baseURL}location/trip').replace(
            queryParameters: {
              'fromDate': _fmtDate(_fromDate),
              'toDate': _fmtDate(_toDate),
              'user_cd': syncId,
            },
          );

          print('[RouteReport] Fallback GET $fallbackUri');

          final fallbackResponse = await http.get(
            fallbackUri,
            headers: {
              'Authorization': 'Bearer $token',
              'x-app-type': 'oms',
            },
          );

          if (fallbackResponse.statusCode == 200) {
            trips = _extractTripsFromResponseBody(fallbackResponse.body);
          }
        }

        setState(() {
          _trips = trips;
        });
      } else {
        setState(() {
          _error = 'Failed to fetch trip history';
          _trips = <Map<String, dynamic>>[];
        });
      }
    } catch (e, stack) {
      setState(() {
        _error = 'Failed to fetch trip history: $e';
        _trips = <Map<String, dynamic>>[];
      });
      await CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'route_report_trips_fetch_failed',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _iconInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildTripTile(Map<String, dynamic> trip) {
    final tripId = _tripIdFromMap(trip);
    final isActive = _tripActiveFromMap(trip);
    final detail = trip;
    _ensureTripGapInfo(tripId);
    final gapInfo = _gapInfoByTripId[tripId];
    final distanceBreakdown = _distanceBreakdownByTripId[tripId];
    final startDate = _tripStartDateFromMap(detail);
    final endDate = _tripEndDateFromMap(detail);
    final startTime = _tripStartTimeFromMap(detail);
    final endTime = _tripEndTimeFromMap(detail);

    final punchGapText = gapInfo == null
        ? 'No order placed'
        : '${gapInfo['punchFormatted'] ?? 'No order placed'}';

    final punchDistanceGapText =
        gapInfo == null ? 'No order placed' : '${gapInfo['punchKm'] ?? '-'}';

    final outGapText = gapInfo == null
        ? 'No order placed'
        : '${gapInfo['outFormatted'] ?? 'No order placed'}';

    final outDistanceGapText =
        gapInfo == null ? 'No order placed' : '${gapInfo['outKm'] ?? '-'}';

    final businessKmText = distanceBreakdown == null
        ? 'No order'
        : '${distanceBreakdown['businessKm'] ?? '-'}';
    final transitKmText = distanceBreakdown == null
        ? 'No order'
        : '${distanceBreakdown['transitKm'] ?? '-'}';

    return GestureDetector(
      onTap: () {
        CrashlyticsService.logAction(
          'route_report_trip_opened',
          context: {'trip_id': tripId},
        );
        Get.to(
          () => TripDetailMapScreen(
            tripId: tripId,
            userName: widget.selectedUserName,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Trip: $tripId',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  isActive
                      ? Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(5),
                              border:
                                  Border.all(color: Colors.orange.shade200)),
                          child: Text(
                            "Active",
                            style: TextStyle(color: Colors.orange),
                          ),
                        )
                      : Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(5),
                              border:
                                  Border.all(color: Colors.blueGrey.shade100)),
                          child: Text(
                            "Ended",
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _iconInfo(
                              Icons.calendar_today_outlined, '$startDate'),
                          SizedBox(
                            height: 5,
                          ),
                          _iconInfo(Icons.access_time_outlined, '$startTime'),
                          // Row(
                          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          //   children: [
                          //     _iconInfo(Icons.calendar_today_outlined, '$startDate'),
                          //     // Icon(Icons.arrow_right_alt),
                          //     Text("|"),
                          //     _iconInfo(Icons.calendar_today_outlined, '$endDate'),
                          //   ],
                          // ),
                          // const SizedBox(height: 6),
                          // Row(
                          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          //   children: [
                          //     _iconInfo(Icons.access_time_outlined, '$startTime'),
                          //     // Icon(Icons.arrow_right_alt),
                          //     Text("|"),
                          //     _iconInfo(Icons.access_time_outlined, '$endTime'),
                          //   ],
                          // ),
                        ],
                      ),
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.black,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _iconInfo(Icons.calendar_today_outlined, '$endDate'),
                          SizedBox(
                            height: 5,
                          ),
                          _iconInfo(Icons.access_time_outlined, '$endTime'),
                          // Row(
                          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          //   children: [
                          //     _iconInfo(Icons.calendar_today_outlined, '$startDate'),
                          //     // Icon(Icons.arrow_right_alt),
                          //     Text("|"),
                          //     _iconInfo(Icons.calendar_today_outlined, '$endDate'),
                          //   ],
                          // ),
                          // const SizedBox(height: 6),
                          // Row(
                          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          //   children: [
                          //     _iconInfo(Icons.access_time_outlined, '$startTime'),
                          //     // Icon(Icons.arrow_right_alt),
                          //     Text("|"),
                          //     _iconInfo(Icons.access_time_outlined, '$endTime'),
                          //   ],
                          // ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _iconInfo(Icons.timer_outlined,
                        'Duration: ${_durationFromMap(detail)}'),
                    _iconInfo(Icons.social_distance_outlined,
                        'Distance: ${_distanceKmFromMap(detail)}'),
                    // _iconInfo(Icons.speed_outlined, 'Speed: ${_speedFromMap(detail)}'),
                    // _iconInfo(Icons.person_outline, 'User: ${_tripUserFromMap(detail)}'),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.login_outlined,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "IN gap",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          // _iconInfo(Icons.login_outlined, 'IN gap'),
                          _iconInfo(
                              Icons.timer_outlined, 'Time: $punchGapText'),
                          SizedBox(width: 6),
                          _iconInfo(Icons.social_distance_outlined,
                              'Distance: $punchDistanceGapText'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.logout_outlined,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "OUT gap",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          // _iconInfo(Icons.login_outlined, 'OUT gap'),
                          _iconInfo(Icons.timer_outlined, 'Time: $outGapText'),
                          _iconInfo(Icons.social_distance_outlined,
                              'Distance: $outDistanceGapText'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _iconInfo(Icons.business_center_outlined,
                        'Business Km: $businessKmText'),
                    _iconInfo(
                        Icons.alt_route_outlined, 'Transit Km: $transitKmText'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // User dropdown for filtering trips by user
  Widget _buildUserDropdown() {
    if (_loadingUsers && _users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 12),
            Text('Loading users...'),
          ],
        ),
      );
    }
    if (_users.isEmpty) return SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Filter by User",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          UserSearchDropdown(
            users: _users,
            selectedUserCode: _selectedUserCode,
            loading: _loadingUsers,
            hint: "Select User",
            onChanged: (value) {
              CrashlyticsService.logAction(
                'route_report_user_filter_changed',
                context: {'selected_user_cd': value ?? ''},
              );
              setState(() {
                _selectedUserCode = value ?? '';
                _selectedUserName = value == ''
                    ? 'Everyone'
                    : _users.firstWhere(
                        (user) => user['userCode'] == value,
                        orElse: () => {'userName': 'Unknown'},
                      )['userName'];
              });
              _fetchTrips();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _selectedUserName != null
        // ? ' 0{_selectedUserName}\'s Route Report'
        ? "$_selectedUserName's Route Report"
        : 'Route Report';

    return Scaffold(
      appBar: CustomAppBar(
        title: title,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildUserDropdown(),
          _buildDateRangeFilter(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _trips.isEmpty
                    ? const Center(child: Text('No trip history found'))
                    : ListView.builder(
                        itemCount: _trips.length,
                        itemBuilder: (context, index) =>
                            _buildTripTile(_trips[index]),
                      ),
          ),
        ],
      ),
    );
  }
}
