import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/widgets/common_timeline_tile.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class RouteMapView extends StatefulWidget {
  const RouteMapView({super.key});

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  static const String _statusLogicVersion = 'route-status-v5-2026-04-15';

  GoogleMapController? _mapController;
  static const LatLng _defaultCenter = LatLng(23.0225, 72.5714);

  // Users state
  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = false;
  String? _usersError;
  int _currentUsersPage = 1;
  int _totalUsersPages = 1;
  int _totalUsersCount = 0;
  int _usersPerPage = 20;
  bool _isLoadingMoreUsers = false;
  List<Map<String, dynamic>> _allUsersForSearch = [];
  bool _isLoadingAllUsersForSearch = false;
  bool _hasLoadedAllUsersForSearch = false;

  // Selected user and timeline state
  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _timelineData = [];
  bool _loadingTimeline = false;
  DateTime _selectedTimelineDate = DateTime.now();

  // Trips and selected trip state
  List<Map<String, dynamic>> _tripsForSelectedDate = [];
  Map<String, dynamic>? _selectedTrip;
  Map<int, List<Map<String, dynamic>>> _timelineByTrip = {};
  int _selectedTripIndex = 0;
  int _timelineRequestId = 0;
  int _loadedTripsCount = 0;
  int _totalTripsToLoad = 0;
  bool _isLoadingRemainingTrips = false;

  // Map polylines and markers
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  final Set<Marker> _userLocationMarkers =
      {}; // Persistent user location markers

  // Bottom sheet state
  double _currentSheetSize = 0.35;
  late DraggableScrollableController _sheetController;
  late ScrollController _usersListScrollController;

  // Trip summary state
  Map<int, Map<String, dynamic>> _tripSummaryData = {};

  // Search state
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('[RouteMapView] status_logic=$_statusLogicVersion');
    _sheetController = DraggableScrollableController();
    _usersListScrollController = ScrollController();
    _sheetController.addListener(() {
      setState(() {
        _currentSheetSize = _sheetController.size;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUsers();
    });
    _searchController.addListener(_onSearchQueryChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _usersListScrollController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged() {
    final query = _searchController.text.toLowerCase().trim();
    final shouldFetchAllUsers = query.isNotEmpty &&
        !_hasLoadedAllUsersForSearch &&
        !_isLoadingAllUsersForSearch;

    if (!mounted) {
      return;
    }

    setState(() {
      _searchQuery = query;
    });

    if (shouldFetchAllUsers) {
      _fetchAllUsersForSearch();
    }
  }

  Future<void> _fetchUsers({int page = 1}) async {
    final isFirstPage = page == 1;
    final today = DateTime.now();

    if (isFirstPage) {
      setState(() {
        _loadingUsers = true;
        _usersError = null;
      });
    } else {
      setState(() {
        _isLoadingMoreUsers = true;
      });
    }

    try {
      final ub = Provider.of<UserProvider>(context, listen: false);
      final token = ub.token;
      if (token == null || token.isEmpty) {
        setState(() {
          _users = [];
          _loadingUsers = false;
          _usersError = 'Missing auth token';
        });
        return;
      }

      final uri = Uri.parse('${AppConfig.baseURL}users/children').replace(
        queryParameters: {
          'date': _fmtDate(today),
          'page': page.toString(),
          'items_per_page': _usersPerPage.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
      );
      print('[RouteMapView] Users API: $uri');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final usersList = (data['data'] is List) ? data['data'] : [];

        // Extract pagination info
        final payload = data['payload'] as Map<String, dynamic>?;
        final pagination = payload?['pagination'] as Map<String, dynamic>?;

        if (pagination != null) {
          setState(() {
            _currentUsersPage = pagination['page'] ?? 1;
            _totalUsersPages = pagination['last_page'] ?? 1;
            _totalUsersCount = pagination['total'] ?? 0;
            _usersPerPage = pagination['items_per_page'] ?? 20;
          });
        }

        // Map users with initial data
        final usersWithData = _mapUsersFromChildrenPayload(
          usersList,
          today: today,
        );

        // Set users data (replace for first page, append for subsequent pages)
        setState(() {
          if (isFirstPage) {
            _users = usersWithData;
          } else {
            _users.addAll(usersWithData);
          }
          print(
              '[RouteMapView] ===== Users list after update: totalUsers=${_users.length}');
          for (int i = 0; i < _users.length; i++) {
            print(
                '[RouteMapView] [INDEX $i] ${_users[i]['userName']} | Code: ${_users[i]['userCode']} | PunchIn: "${_users[i]['punchInTime']}"');
          }
        });

        // Keep existing marker behavior (trip-based) and override only punch status
        // from users/children last punch fields after each fetch completes.
        final ub2 = Provider.of<UserProvider>(context, listen: false);
        final token2 = ub2.token;
        print(
            '[RouteMapView] ===== Fetching trips for ${usersWithData.length} new users');
        for (final user in usersWithData) {
          final userCode = _normalizeCode(user['userCode']);
          if (userCode.isEmpty) {
            continue;
          }

          final tripId = user['tripId'] is num
              ? (user['tripId'] as num).toInt()
              : (int.tryParse(user['tripId']?.toString() ?? '') ?? 0);
          final tripStatus = (user['tripStatus'] ?? '').toString();
          final enforcedPunchStatus =
              (user['punchStatus'] ?? 'absent').toString().trim().toLowerCase();
          final enforcedPunchInTime =
              (user['punchInTime'] ?? '').toString().trim();
          final enforcedPunchOutTime =
              (user['punchOutTime'] ?? '').toString().trim();

          print(
              '[RouteMapView] [TRIP FETCH] User: ${user['userName']} (${user['userCode']}) | tripStatus=$tripStatus | tripId=$tripId');

          _fetchLatestTripForUser(
            userCode,
            token2,
            knownTripId: tripId,
            knownTripStatus: tripStatus,
            knownLastGpsAt: user['lastGpsAt']?.toString(),
            knownPunchStatus: user['knownPunchStatus']?.toString(),
            knownPunchInTime: user['knownPunchInTime']?.toString(),
            knownPunchOutTime: user['knownPunchOutTime']?.toString(),
          ).whenComplete(() {
            _updateUserPunchStatus(
              userCode,
              punchStatus: enforcedPunchStatus,
              punchInTime: enforcedPunchInTime,
              punchOutTime: enforcedPunchOutTime,
              reason: 'children-last-punch-override',
            );
          });
        }

        setState(() {
          _loadingUsers = false;
          _isLoadingMoreUsers = false;
        });
      } else {
        setState(() {
          if (isFirstPage) {
            _users = [];
            _usersError = 'Failed to load users: HTTP ${response.statusCode}';
          }
          _loadingUsers = false;
          _isLoadingMoreUsers = false;
        });
      }
    } catch (e) {
      setState(() {
        if (isFirstPage) {
          _users = [];
          _usersError = 'Error: $e';
        }
        _loadingUsers = false;
        _isLoadingMoreUsers = false;
      });
      print('[RouteMapView] Error fetching users: $e');
    }
  }

  List<Map<String, dynamic>> _mapUsersFromChildrenPayload(
    List<dynamic> usersList, {
    required DateTime today,
  }) {
    final seenUserCodes = <String>{};
    final usersWithData = <Map<String, dynamic>>[];

    for (int userIndex = 0; userIndex < usersList.length; userIndex++) {
      final rawUser = usersList[userIndex];
      if (rawUser is! Map) {
        continue;
      }

      final user = Map<String, dynamic>.from(rawUser);
      final userCode = _extractUserCodeFromUserPayload(user);

      if (userCode.isEmpty) {
        print('[RouteMapView] Skipping user with empty userCode: $user');
        continue;
      }

      if (!seenUserCodes.add(userCode)) {
        print('[RouteMapView] Skipping duplicate userCode: $userCode');
        continue;
      }

      // Debug: Log first user's fields for punch-in extraction
      if (userIndex == 0) {
        print(
            '[RouteMapView] [DEBUG] First user raw payload keys: ${user.keys.toList()}');
        print('[RouteMapView] [DEBUG] Full first user payload: $user');
      }

      final userName = _extractUserNameFromUserPayload(user);
      final phone =
          (user['MOBILENO'] ?? user['mobileNo'] ?? user['phone'] ?? '')
              .toString()
              .trim();
      final photoUrl = (user['USER_IMAGE_URL'] ??
              user['userImageUrl'] ??
              user['photoUrl'] ??
              '')
          .toString()
          .trim();
      final status = (user['userStatus'] ?? user['USER_STATUS'] ?? 'active')
          .toString()
          .trim()
          .toLowerCase();
      final tripStatus = _extractTripStatusFromUserPayload(user);
      final tripId = _extractTripIdFromUserPayload(user);
      final knownPunchStatus = _extractPunchStatusFromUserPayload(user);
      final knownPunchInTime = _extractPunchInTimeFromUserPayload(user);
      final knownPunchOutTime = _extractPunchOutTimeFromUserPayload(user);

      // Debug: Log punch extraction for first user
      if (userIndex == 0) {
        print(
            '[RouteMapView] [DEBUG] Extracted for first user: punchStatus="$knownPunchStatus" punchInTime="$knownPunchInTime" punchOutTime="$knownPunchOutTime"');
      }

      final punchInTime = _resolveTodayReferenceTime(
        primaryTime: knownPunchInTime,
        today: today,
      );
      final punchOutTime = _resolveTodayReferenceTime(
        primaryTime: knownPunchOutTime,
        today: today,
      );
      final derivedPunchStatus = _derivePunchStatusFromTimes(
        punchInTime: punchInTime,
        punchOutTime: punchOutTime,
        fallbackStatus: knownPunchStatus,
      );
      final lastGpsAt =
          (user['LASTGPSAT'] ?? user['lastGpsAt'] ?? user['LAST_GPS_AT'] ?? '')
              .toString()
              .trim();

      usersWithData.add({
        'userCode': userCode,
        'userName': userName,
        'phone': phone,
        'photoUrl': photoUrl,
        'status': status,
        'tripStatus': tripStatus,
        'tripId': tripId,
        'knownPunchStatus': knownPunchStatus,
        'knownPunchInTime': knownPunchInTime,
        'knownPunchOutTime': knownPunchOutTime,
        'lastGpsAt': lastGpsAt,
        'punchInTime': punchInTime,
        'punchOutTime': punchOutTime,
        'punchStatus': derivedPunchStatus,
      });
    }

    return usersWithData;
  }

  Future<void> _fetchAllUsersForSearch() async {
    if (_isLoadingAllUsersForSearch || _hasLoadedAllUsersForSearch) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingAllUsersForSearch = true;
    });

    try {
      final ub = Provider.of<UserProvider>(context, listen: false);
      final token = ub.token;
      if (token == null || token.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoadingAllUsersForSearch = false;
        });
        return;
      }

      final allRawUsers = <dynamic>[];
      int currentPage = 1;
      int lastPage = 1;

      do {
        final uri = Uri.parse('${AppConfig.baseURL}users/children').replace(
          queryParameters: {
            'page': currentPage.toString(),
            'items_per_page': _usersPerPage.toString(),
          },
        );

        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'x-app-type': 'oms',
            'Content-Type': 'application/json',
          },
        );
        print('[RouteMapView] Search Users API (all): $uri');

        if (response.statusCode != 200) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isLoadingAllUsersForSearch = false;
          });
          return;
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final usersList = (data['data'] is List) ? data['data'] : <dynamic>[];
        allRawUsers.addAll(usersList);

        final payload = data['payload'] as Map<String, dynamic>?;
        final pagination = payload?['pagination'] as Map<String, dynamic>?;
        final pageFromResponse =
            int.tryParse((pagination?['page'] ?? currentPage).toString()) ??
                currentPage;
        lastPage = int.tryParse(
                (pagination?['last_page'] ?? pageFromResponse).toString()) ??
            pageFromResponse;
        currentPage = pageFromResponse + 1;
      } while (currentPage <= lastPage);

      final mappedUsers =
          _mapUsersFromChildrenPayload(allRawUsers, today: DateTime.now());

      if (!mounted) {
        return;
      }

      setState(() {
        _allUsersForSearch = mappedUsers;
        _hasLoadedAllUsersForSearch = true;
        _isLoadingAllUsersForSearch = false;
      });

      print(
          '[RouteMapView] Search users loaded across $lastPage pages: ${mappedUsers.length}');
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAllUsersForSearch = false;
      });
      print('[RouteMapView] Error fetching all users for search: $e');
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_currentUsersPage >= _totalUsersPages) {
      return; // Already on last page
    }
    await _fetchUsers(page: _currentUsersPage + 1);
  }

  String _normalizeCode(dynamic value) => value?.toString().trim() ?? '';

  String _extractUserCodeFromUserPayload(Map<String, dynamic> user) {
    final candidates = [
      user['USER_CD'],
      user['user_cd'],
      user['userCode'],
      user['USER_CODE'],
      user['USERCODE'],
      user['CHILD_USER_CD'],
      user['child_user_cd'],
      user['employee_cd'],
      user['EMP_CD'],
    ];

    for (final candidate in candidates) {
      final code = _normalizeCode(candidate);
      if (code.isNotEmpty) {
        return code;
      }
    }
    return '';
  }

  String _extractUserNameFromUserPayload(Map<String, dynamic> user) {
    final candidates = [
      user['USER_NAME'],
      user['user_name'],
      user['userName'],
      user['NAME'],
      user['name'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return 'Unknown User';
  }

  String _extractTripStatusFromUserPayload(Map<String, dynamic> user) {
    final candidates = [
      user['TRIP_STATUS'],
      user['TRIPSTATUS'],
      user['tripStatus'],
      user['TRIP_STATUS'],
      user['trip_status'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim().toLowerCase() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String _canonicalPunchStatus(dynamic raw) {
    if (raw is bool) {
      return raw ? 'punched_in' : 'absent';
    }

    final value = raw?.toString().trim().toLowerCase() ?? '';
    if (value.isEmpty) {
      return '';
    }

    if (value.contains('punch out') ||
        value.contains('punched out') ||
        value == 'punched_out' ||
        value == 'out' ||
        value == 'checkout' ||
        value == 'check out') {
      return 'punched_out';
    }

    if (value.contains('punch in') ||
        value.contains('punched in') ||
        value == 'punched_in' ||
        value == 'in' ||
        value == 'checkin' ||
        value == 'check in' ||
        value == 'true' ||
        value == '1' ||
        value == 'y' ||
        value == 'yes') {
      return 'punched_in';
    }

    if (value == 'false' || value == '0' || value == 'n' || value == 'no') {
      return 'absent';
    }

    return '';
  }

  String _extractPunchStatusFromUserPayload(Map<String, dynamic> user) {
    final candidates = [
      user['punchStatus'],
      user['PUNCH_STATUS'],
      user['punch_status'],
      user['punchState'],
      user['PUNCH_STATE'],
      user['punch_state'],
      user['remark'],
      user['REMARK'],
      user['lastRemark'],
      user['LAST_REMARK'],
      user['isPunchIn'],
      user['IS_PUNCH_IN'],
      user['is_punch_in'],
      user['IS_PUNCHIN'],
      user['isPunchedIn'],
      user['IS_PUNCHED_IN'],
      user['is_punched_in'],
    ];

    for (final candidate in candidates) {
      final canonical = _canonicalPunchStatus(candidate);
      if (canonical.isNotEmpty) {
        return canonical;
      }
    }

    return '';
  }

  String _extractPunchInTimeFromUserPayload(Map<String, dynamic> user) {
    final candidates = [
      user['LASTPUNCH_IN'],
      user['LASTPUNCHIN'],
      user['lastPunchIn'],
      user['LAST_PUNCH_IN'],
      user['last_punch_in'],
      user['punchInTime'],
      user['PUNCH_IN_TIME'],
      user['punch_in_time'],
      user['punchInAt'],
      user['PUNCH_IN_AT'],
      user['punch_in_at'],
      user['inTime'],
      user['IN_TIME'],
      user['in_time'],
      user['lastPunchInAt'],
      user['LAST_PUNCH_IN_AT'],
      user['last_punch_in_at'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }

    return '';
  }

  String _extractPunchOutTimeFromUserPayload(Map<String, dynamic> user) {
    final candidates = [
      user['LASTPUNCH_OUT'],
      user['LASTPUNCHOUT'],
      user['lastPunchOut'],
      user['LAST_PUNCH_OUT'],
      user['last_punch_out'],
      user['punchOutTime'],
      user['PUNCH_OUT_TIME'],
      user['punch_out_time'],
      user['punchOutAt'],
      user['PUNCH_OUT_AT'],
      user['punch_out_at'],
      user['outTime'],
      user['OUT_TIME'],
      user['out_time'],
      user['lastPunchOutAt'],
      user['LAST_PUNCH_OUT_AT'],
      user['last_punch_out_at'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }

    return '';
  }

  String _derivePunchStatusFromTimes({
    required String punchInTime,
    required String punchOutTime,
    String? fallbackStatus,
  }) {
    final inTime = _tryParseDateTime(punchInTime);
    final outTime = _tryParseDateTime(punchOutTime);

    if (inTime != null && outTime != null) {
      return inTime.isAfter(outTime) ? 'punched_in' : 'punched_out';
    }
    if (inTime != null) {
      return 'punched_in';
    }
    if (outTime != null) {
      return 'punched_out';
    }

    final canonicalFallback = _canonicalPunchStatus(fallbackStatus);
    return canonicalFallback.isNotEmpty ? canonicalFallback : 'absent';
  }

  int _extractTripIdFromUserPayload(Map<String, dynamic> user) {
    // Important: never use generic user `id` fields as trip IDs.
    // Some user payloads do not include current trip id; falling back to user id
    // can fetch an unrelated/old trip and show stale punch-out status.
    final candidates = [
      user['TRIP_ID'],
      user['TRIPID'],
      user['tripId'],
      user['trip_id'],
      user['activeTripId'],
      user['active_trip_id'],
      user['ACTIVE_TRIP_ID'],
      user['currentTripId'],
      user['current_trip_id'],
      user['CURRENT_TRIP_ID'],
      user['lastTripId'],
      user['last_trip_id'],
      user['LAST_TRIP_ID'],
    ];

    for (final candidate in candidates) {
      if (candidate is num && candidate > 0) {
        return candidate.toInt();
      }

      final parsed = int.tryParse(candidate?.toString().trim() ?? '');
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return 0;
  }

  String _extractUserCodeFromTripPayload(Map<String, dynamic> trip) {
    final nestedUser = trip['user'];
    final nestedUserMap = nestedUser is Map<String, dynamic>
        ? nestedUser
        : (nestedUser is Map ? Map<String, dynamic>.from(nestedUser) : null);

    final candidates = [
      trip['user_cd'],
      trip['userCd'],
      trip['USER_CD'],
      trip['user_code'],
      trip['USER_CODE'],
      trip['EMP_CD'],
      nestedUserMap?['USER_CD'],
      nestedUserMap?['user_cd'],
      nestedUserMap?['userCode'],
      nestedUserMap?['USER_CODE'],
    ];

    for (final candidate in candidates) {
      final code = _normalizeCode(candidate);
      if (code.isNotEmpty) {
        return code;
      }
    }

    return '';
  }

  Map<String, dynamic>? _pickLatestTripForUser(
      List<dynamic> trips, String userCode) {
    final targetCode = _normalizeCode(userCode);
    if (targetCode.isEmpty || trips.isEmpty) {
      return null;
    }

    Map<String, dynamic>? latestTrip;
    DateTime? latestStart;
    int latestTripId = 0;

    for (final rawTrip in trips) {
      if (rawTrip is! Map) {
        continue;
      }

      final trip = Map<String, dynamic>.from(rawTrip);
      final tripUserCode = _extractUserCodeFromTripPayload(trip);

      if (tripUserCode == targetCode) {
        final startTime = _tryParseDateTime(
          trip['start_time'] ??
              trip['START_TIME'] ??
              trip['started_at'] ??
              trip['STARTED_AT'],
        );
        final tripId = _extractTripIdFromTripPayload(trip);

        final shouldReplace = latestTrip == null ||
            (startTime != null &&
                (latestStart == null || startTime.isAfter(latestStart))) ||
            (startTime == null && latestStart == null && tripId > latestTripId);

        if (shouldReplace) {
          latestTrip = trip;
          latestStart = startTime;
          latestTripId = tripId;
        }
      }
    }

    return latestTrip;
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  DateTime? _tryParseDateTime(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }

    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _isSameCalendarDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isTimestampOnDate(dynamic raw, DateTime targetDate) {
    final parsed = _tryParseDateTime(raw);
    if (parsed == null) return false;
    return _isSameCalendarDate(parsed, targetDate);
  }

  /// Prefer a same-day primary timestamp, then a same-day fallback timestamp.
  /// Returns empty when both are missing/stale so UI does not show old "Xd ago".
  String _resolveTodayReferenceTime({
    String? primaryTime,
    String? secondaryTime,
    required DateTime today,
  }) {
    final primary = (primaryTime ?? '').toString().trim();
    if (_isTimestampOnDate(primary, today)) {
      return primary;
    }

    final secondary = (secondaryTime ?? '').toString().trim();
    if (_isTimestampOnDate(secondary, today)) {
      return secondary;
    }

    return '';
  }

  bool _applyChildrenPunchFallback(
    String normalizedUserCode, {
    required DateTime today,
    required String normalizedTripStatus,
    String? knownLastGpsAt,
    String? knownPunchStatus,
    String? knownPunchInTime,
    String? knownPunchOutTime,
    int? tripId,
    String reasonPrefix = 'children-punch-fallback',
  }) {
    final canonicalStatus = _canonicalPunchStatus(knownPunchStatus);
    final safeTripId = (tripId ?? 0) > 0 ? tripId : null;

    if (canonicalStatus == 'punched_in') {
      final inTime = _resolveTodayReferenceTime(
        primaryTime: knownPunchInTime,
        secondaryTime: knownLastGpsAt,
        today: today,
      );

      _updateUserPunchStatus(
        normalizedUserCode,
        punchStatus: 'punched_in',
        punchInTime: inTime,
        punchOutTime: '',
        tripStatus:
            normalizedTripStatus.isNotEmpty ? normalizedTripStatus : 'active',
        tripId: safeTripId,
        reason: _hasTimestampValue(inTime)
            ? '$reasonPrefix-punched-in'
            : '$reasonPrefix-punched-in-no-timestamp',
      );
      return true;
    }

    if (canonicalStatus == 'punched_out') {
      final outTime = _resolveTodayReferenceTime(
        primaryTime: knownPunchOutTime,
        secondaryTime: knownLastGpsAt,
        today: today,
      );

      _updateUserPunchStatus(
        normalizedUserCode,
        punchStatus: 'punched_out',
        punchInTime: '',
        punchOutTime: outTime,
        tripStatus: 'completed',
        tripId: safeTripId,
        reason: _hasTimestampValue(outTime)
            ? '$reasonPrefix-punched-out'
            : '$reasonPrefix-punched-out-no-timestamp',
      );
      return true;
    }

    return false;
  }

  String _extractTripStartTimeFromTripAndSummary(
    Map<String, dynamic> trip,
    Map<String, dynamic>? summary,
  ) {
    return (trip['start_time'] ??
            trip['START_TIME'] ??
            trip['started_at'] ??
            trip['STARTED_AT'] ??
            summary?['start_time'] ??
            summary?['started_at'] ??
            '')
        .toString()
        .trim();
  }

  int _extractTripIdFromTripPayload(Map<String, dynamic> trip) {
    final candidates = [
      trip['id'],
      trip['ID'],
      trip['trip_id'],
      trip['TRIP_ID'],
    ];

    for (final candidate in candidates) {
      if (candidate is num && candidate > 0) {
        return candidate.toInt();
      }

      final parsed = int.tryParse(candidate?.toString().trim() ?? '');
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return 0;
  }

  String _extractTripEndTime(Map<String, dynamic> trip) {
    return (trip['end_time'] ??
            trip['END_TIME'] ??
            trip['ended_at'] ??
            trip['ENDED_AT'] ??
            '')
        .toString()
        .trim();
  }

  bool _hasTimestampValue(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    return value.isNotEmpty && value.toLowerCase() != 'null';
  }

  bool _isTripPunchedOut(
    Map<String, dynamic> trip, {
    String? fallbackStatus,
  }) {
    final endTime = _extractTripEndTime(trip);
    if (_hasTimestampValue(endTime)) {
      return true;
    }

    final status = (trip['status'] ?? trip['STATUS'] ?? fallbackStatus ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return status == 'completed';
  }

  void _updateUserPunchStatus(
    String normalizedUserCode, {
    required String punchStatus,
    String punchInTime = '',
    String punchOutTime = '',
    String? tripStatus,
    int? tripId,
    String? reason,
  }) {
    if (!mounted) return;

    setState(() {
      final userIndex = _users.indexWhere(
          (u) => _normalizeCode(u['userCode']) == normalizedUserCode);
      if (userIndex >= 0) {
        final normalizedStatus = punchStatus.trim().toLowerCase();
        final today = DateTime.now();
        var sanitizedPunchInTime = punchInTime.trim();
        var sanitizedPunchOutTime = punchOutTime.trim();

        // Never keep stale timestamps on user cards; they produce misleading
        // multi-day "Punched in Xd ago" labels when backend trip rows lag.
        if (normalizedStatus == 'punched_in' &&
            !_isTimestampOnDate(sanitizedPunchInTime, today)) {
          sanitizedPunchInTime = '';
        }
        if (normalizedStatus == 'punched_out' &&
            !_isTimestampOnDate(sanitizedPunchOutTime, today)) {
          sanitizedPunchOutTime = '';
        }
        if (normalizedStatus == 'absent') {
          sanitizedPunchInTime = '';
          sanitizedPunchOutTime = '';
        }

        _users[userIndex]['punchStatus'] = normalizedStatus;
        _users[userIndex]['punchInTime'] = sanitizedPunchInTime;
        _users[userIndex]['punchOutTime'] = sanitizedPunchOutTime;

        if (tripStatus != null && tripStatus.trim().isNotEmpty) {
          _users[userIndex]['tripStatus'] = tripStatus.trim().toLowerCase();
        }

        if (tripId != null && tripId > 0) {
          _users[userIndex]['tripId'] = tripId;
        }

        print(
            '[RouteMapView] Updated punch status for $normalizedUserCode (${_users[userIndex]['userName']}) => $normalizedStatus | in=$sanitizedPunchInTime | out=$sanitizedPunchOutTime${reason != null && reason.isNotEmpty ? ' | reason=$reason' : ''}');
      } else {
        print(
            '[RouteMapView] Could not update punch status - user not found for userCode=$normalizedUserCode');
      }
    });
  }

  List<Map<String, dynamic>> _filterTripsForUser(
    List<Map<String, dynamic>> trips,
    String userCode,
  ) {
    final normalizedUserCode = _normalizeCode(userCode);
    if (normalizedUserCode.isEmpty || trips.isEmpty) {
      return [];
    }

    final matchingTrips = <Map<String, dynamic>>[];
    bool anyTripHasUserCode = false;

    for (final trip in trips) {
      final tripUserCode = _extractUserCodeFromTripPayload(trip);
      if (tripUserCode.isNotEmpty) {
        anyTripHasUserCode = true;
      }

      if (tripUserCode == normalizedUserCode) {
        matchingTrips.add(trip);
      }
    }

    if (matchingTrips.isNotEmpty) {
      print(
          '[RouteMapView] [FILTER] Returning ${matchingTrips.length} matched trips');
      return matchingTrips;
    }

    if (!anyTripHasUserCode) {
      print(
          '[RouteMapView] [FILTER] No trips have user codes - returning all ${trips.length} trips as fallback (server-filtered)');
      return trips;
    }

    print(
        '[RouteMapView] [FILTER] No matching trips found for $normalizedUserCode');
    return [];
  }

  Future<void> _fetchTimelineForUser(
      Map<String, dynamic> user, DateTime date) async {
    final requestId = ++_timelineRequestId;
    final userCode = _normalizeCode(user['userCode']);

    setState(() {
      _loadingTimeline = true;
      _timelineData = [];
      _selectedTrip = null;
      _selectedTripIndex = 0;
      _timelineByTrip = {};
      _loadedTripsCount = 0;
      _totalTripsToLoad = 0;
      _isLoadingRemainingTrips = false;
    });
    _polylines.clear();
    _markers.clear();
    // Re-add user location markers
    _markers.addAll(_userLocationMarkers);

    try {
      // First, fetch trips for the selected date
      await _fetchTripsForDate(userCode, date);

      if (!mounted || requestId != _timelineRequestId) {
        return;
      }

      // If trips found, fetch timeline for each trip
      if (_tripsForSelectedDate.isNotEmpty) {
        print(
            '[RouteMapView] Trips found: ${_tripsForSelectedDate.length} trips ready');
        Map<int, List<Map<String, dynamic>>> timelineByTrip = {};
        final tripsSnapshot =
            List<Map<String, dynamic>>.from(_tripsForSelectedDate);
        final firstTrip = tripsSnapshot[0];
        final firstTripId = firstTrip['id'] ??
            firstTrip['ID'] ??
            firstTrip['trip_id'] ??
            firstTrip['TRIP_ID'] ??
            0;

        setState(() {
          _selectedTripIndex = 0;
          _selectedTrip = firstTrip;
          _totalTripsToLoad = tripsSnapshot.length;
          _loadedTripsCount = 0;
          _isLoadingRemainingTrips = tripsSnapshot.length > 1;
        });

        // Load first trip immediately so UI can render quickly.
        if (firstTripId > 0) {
          print(
              '[RouteMapView] Fetching timeline for firstTripId=$firstTripId');
          final firstTimeline = await _fetchTripTimeline(firstTripId);
          print(
              '[RouteMapView] Timeline returned ${firstTimeline.length} events');

          if (!mounted || requestId != _timelineRequestId) {
            return;
          }

          for (var item in firstTimeline) {
            item['tripId'] = firstTripId;
            item['tripStartTime'] = firstTrip['start_time'] ??
                firstTrip['START_TIME'] ??
                firstTrip['started_at'] ??
                '';
          }

          firstTimeline.sort((a, b) {
            try {
              final timeA = DateTime.parse(a['timestamp'] ?? '');
              final timeB = DateTime.parse(b['timestamp'] ?? '');
              return timeA.compareTo(timeB);
            } catch (_) {
              return 0;
            }
          });

          timelineByTrip[firstTripId] = firstTimeline;
          await _fetchAndStoreTripSummary(firstTripId, requestId: requestId);

          if (!mounted || requestId != _timelineRequestId) {
            return;
          }

          setState(() {
            _timelineByTrip =
                Map<int, List<Map<String, dynamic>>>.from(timelineByTrip);
            _timelineData = firstTimeline;
            _loadingTimeline = false;
            _loadedTripsCount = 1;
            _isLoadingRemainingTrips = tripsSnapshot.length > 1;
          });

          _fetchAndDisplayTripRoute(firstTripId);
        } else {
          setState(() {
            _loadingTimeline = false;
          });
        }

        // Fetch remaining trips in background.
        for (int i = 1; i < tripsSnapshot.length; i++) {
          final trip = tripsSnapshot[i];
          final tripId = trip['id'] ??
              trip['ID'] ??
              trip['trip_id'] ??
              trip['TRIP_ID'] ??
              0;

          if (tripId <= 0) {
            continue;
          }

          _loadTripDataInBackground(trip, tripId, requestId);
        }
      } else {
        print(
            '[RouteMapView] No trips found for selected date - _tripsForSelectedDate is empty');
        setState(() {
          _timelineByTrip = {};
          _timelineData = [];
          _loadingTimeline = false;
          _loadedTripsCount = 0;
          _totalTripsToLoad = 0;
          _isLoadingRemainingTrips = false;
        });
      }
    } catch (e) {
      setState(() {
        _timelineData = [];
        _timelineByTrip = {};
        _loadingTimeline = false;
        _loadedTripsCount = 0;
        _totalTripsToLoad = 0;
        _isLoadingRemainingTrips = false;
      });
      print('[RouteMapView] Error fetching timeline: $e');
    }
  }

  Future<void> _loadTripDataInBackground(
    Map<String, dynamic> trip,
    int tripId,
    int requestId,
  ) async {
    final timeline = await _fetchTripTimeline(tripId);

    if (!mounted || requestId != _timelineRequestId) {
      return;
    }

    for (var item in timeline) {
      item['tripId'] = tripId;
      item['tripStartTime'] =
          trip['start_time'] ?? trip['START_TIME'] ?? trip['started_at'] ?? '';
    }

    timeline.sort((a, b) {
      try {
        final timeA = DateTime.parse(a['timestamp'] ?? '');
        final timeB = DateTime.parse(b['timestamp'] ?? '');
        return timeA.compareTo(timeB);
      } catch (_) {
        return 0;
      }
    });

    await _fetchAndStoreTripSummary(tripId, requestId: requestId);

    if (!mounted || requestId != _timelineRequestId) {
      return;
    }

    setState(() {
      _timelineByTrip[tripId] = timeline;

      if (_getTripIdAtIndex(_selectedTripIndex) == tripId) {
        _timelineData = timeline;
      }

      _loadedTripsCount++;
      _isLoadingRemainingTrips = _loadedTripsCount < _totalTripsToLoad;
    });
  }

  int _getTripIdAtIndex(int index) {
    if (index < 0 || index >= _tripsForSelectedDate.length) return 0;
    final trip = _tripsForSelectedDate[index];
    return trip['id'] ?? trip['ID'] ?? trip['trip_id'] ?? trip['TRIP_ID'] ?? 0;
  }

  Future<void> _fetchTripsForDate(String userCode, DateTime date) async {
    final ub = Provider.of<UserProvider>(context, listen: false);
    final token = ub.token;

    final normalizedUserCode = _normalizeCode(userCode);

    if (token == null || token.isEmpty || normalizedUserCode.isEmpty) {
      setState(() {
        _tripsForSelectedDate = [];
      });
      return;
    }

    try {
      // Always load trips by selected date so timelines can be fetched for that date.
      final dateStr = _fmtDate(date);
      final uri = Uri.parse('${AppConfig.baseURL}location/trip').replace(
        queryParameters: {
          'fromDate': dateStr,
          'toDate': dateStr,
          'user_cd': normalizedUserCode,
        },
      );

      print('[RouteMapView] Fetching trips: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final tripData = data['data'] as Map<String, dynamic>?;

        final trips = (tripData != null && tripData['trips'] is List)
            ? (tripData['trips'] as List).cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

        print(
            '[RouteMapView] [DEBUG] Trip list raw response: ${trips.length} trips returned from API for user=$normalizedUserCode');

        final filteredTrips = _filterTripsForUser(trips, normalizedUserCode);

        print(
            '[RouteMapView] [DEBUG] After filtering: ${filteredTrips.length} trips remain for user=$normalizedUserCode');

        setState(() {
          _tripsForSelectedDate = filteredTrips;
        });

        print(
            '[RouteMapView] [DEBUG] _tripsForSelectedDate updated: ${_tripsForSelectedDate.length} trips ready for timeline fetch');
      } else {
        setState(() {
          _tripsForSelectedDate = [];
        });
      }
    } catch (e) {
      print('[RouteMapView] Error fetching trips for date: $e');
      setState(() {
        _tripsForSelectedDate = [];
      });
    }
  }

  String _formatEventType(String eventType) {
    return eventType
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatEventDescription(Map<String, dynamic> event) {
    final eventType = event['event_type'] as String? ?? '';
    final source = event['source'] as String? ?? '';
    final reason = event['reason'] as String? ?? '';
    final status = event['status'] as String? ?? '';

    switch (eventType) {
      case 'trip_started':
        return 'Trip started';
      case 'trip_completed':
        return 'Trip completed';
      case 'offline_started':
        if (source == 'gps_gap') {
          return reason == 'timestamp_gap_exceeded'
              ? 'GPS gap detected (${event['gap_formatted'] ?? 'unknown'})'
              : 'GPS offline';
        }
        return 'Offline mode started';
      case 'offline_ended':
        if (source == 'gps_gap') {
          return 'GPS connection restored';
        }
        return 'Back online - ${event['closure_type'] ?? ''}';
      default:
        return status;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTripTimeline(int tripId) async {
    final ub = Provider.of<UserProvider>(context, listen: false);
    final token = ub.token;

    if (token == null || token.isEmpty || tripId <= 0) {
      return [];
    }

    try {
      final uri =
          Uri.parse('${AppConfig.baseURL}location/trip/$tripId/timeline');

      print('[RouteMapView] Fetching timeline for trip $tripId: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;

        if (data is Map<String, dynamic>) {
          // Timeline endpoint carries business metrics used in summary cards.
          final mergedSummary = <String, dynamic>{};
          final timelineSummary = data['timeline_summary'];
          final orderTrackingSummary = data['order_tracking_summary'];

          if (timelineSummary is Map) {
            mergedSummary.addAll(Map<String, dynamic>.from(timelineSummary));
          }
          if (orderTrackingSummary is Map) {
            mergedSummary
                .addAll(Map<String, dynamic>.from(orderTrackingSummary));
          }

          if (mergedSummary.isNotEmpty) {
            setState(() {
              _tripSummaryData[tripId] = {
                ...?_tripSummaryData[tripId],
                ...mergedSummary,
              };
            });
          }

          final timelineList = data['timeline'] as List? ?? [];

          return timelineList.whereType<Map<String, dynamic>>().map((event) {
            final timestamp = event['at'] as String? ?? '';
            final eventType = event['event_type'] as String? ?? '';
            final eventTitle =
                event['event_title'] as String? ?? _formatEventType(eventType);

            // Extract party and order information for order events
            final party = event['party'] as Map<String, dynamic>? ?? {};
            final order = event['order'] as Map<String, dynamic>? ?? {};

            return {
              'timestamp': timestamp,
              'name': eventTitle,
              'title': eventTitle,
              'description': _formatEventDescription(event),
              'subtitle': _formatEventDescription(event),
              'event_type': eventType,
              'status': event['status'],
              'source': event['source'],
              'reason': event['reason'],
              'gap_formatted': event['gap_formatted'],
              'closure_type': event['closure_type'],
              'party_code': event['party_code'],
              'party_name': party['party_name'] ?? '',
              'party_address': party['party_address'] ?? '',
              'order': order,
              'order_items':
                  (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [],
              'order_amount': event['order_amount'],
              ...event, // Include all original fields
            };
          }).toList();
        }
        return [];
      } else {
        print(
            '[RouteMapView] Failed to fetch timeline: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('[RouteMapView] Error fetching trip timeline: $e');
      return [];
    }
  }

  Future<void> _fetchAndDisplayTripRoute(int tripId) async {
    final ub = Provider.of<UserProvider>(context, listen: false);
    final token = ub.token;

    if (token == null || token.isEmpty || tripId <= 0) {
      return;
    }

    try {
      final uri = Uri.parse('${AppConfig.baseURL}location/trip/$tripId');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final tripData = decoded['data'] as Map<String, dynamic>?;

        if (tripData is Map<String, dynamic>) {
          final routePoints = _extractRoutePoints(tripData);
          _displayRouteOnMap(routePoints);
        }
      }
    } catch (e) {
      print('[RouteMapView] Error fetching trip route: $e');
    }
  }

  List<LatLng> _extractRoutePoints(Map<String, dynamic> tripData) {
    final trip = tripData['trip'] as Map<String, dynamic>?;
    if (trip == null) return [];

    final encoded = (trip['polyline_encoded'] ?? '').toString().trim();
    if (encoded.isEmpty) return [];

    try {
      return _decodePolyline(encoded);
    } catch (_) {
      return [];
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;

      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);

      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);

      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  void _displayRouteOnMap(List<LatLng> routePoints) {
    setState(() {
      _polylines.clear();
      _markers.clear();
      // Preserve user location markers
      _markers.addAll(_userLocationMarkers);
    });

    if (routePoints.isEmpty) {
      setState(() {});
      return;
    }

    final startPoint = routePoints.first;
    final endPoint = routePoints.last;

    _markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: startPoint,
        infoWindow: const InfoWindow(title: 'Start'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('end'),
        position: endPoint,
        infoWindow: const InfoWindow(title: 'End'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        ),
      ),
    );

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: Colors.blue,
        width: 5,
        geodesic: true,
      ),
    );

    if (_mapController != null) {
      _animateCameraToBounds(routePoints);
    }

    setState(() {});
  }

  void _animateCameraToBounds(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  void _selectUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUser = user;
      _selectedTimelineDate = DateTime.now();
      _selectedTrip = null;
    });
    _polylines.clear();
    _markers.clear();
    // Re-add user location markers
    _markers.addAll(_userLocationMarkers);
    _fetchTimelineForUser(user, DateTime.now());
  }

  void _clearSelectedUser() {
    _timelineRequestId++;
    setState(() {
      _selectedUser = null;
      _timelineData = [];
      _selectedTrip = null;
      _selectedTripIndex = 0;
      _timelineByTrip = {};
      _loadingTimeline = false;
      _loadedTripsCount = 0;
      _totalTripsToLoad = 0;
      _isLoadingRemainingTrips = false;
    });
    _polylines.clear();
    _markers.clear();
    // Re-add user location markers
    _markers.addAll(_userLocationMarkers);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedTimelineDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTimelineDate = picked;
      });
      if (_selectedUser != null) {
        _fetchTimelineForUser(_selectedUser!, picked);
      }
    }
  }

  void _callUser(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch call')),
        );
      }
    } catch (e) {
      print('[RouteMapView] Error launching call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch call')),
        );
      }
    }
  }

  void _showOrderItemsDialog(
    List<Map<String, dynamic>> items,
    String partyName,
    String partyCode,
    String partyAddress,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Items'),
            const SizedBox(height: 8),
            Text(
              '$partyName ($partyCode)',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: items.isEmpty
              ? const Center(child: Text('No items in this order'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final itemName = item['item_name'] as String? ?? '';
                    final itemSname = item['item_sname'] as String? ?? '';
                    final quantity = item['quantity'] ?? 0;
                    final rate = item['rate'] ?? 0;
                    final amount = item['amount'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        itemSname,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Amt: ₹${amount}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Qty: $quantity'),
                                Text('Rate: ₹$rate'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAndShowPartyHistory(
    String userCode,
    String partyCode, {
    String partyName = '',
  }) async {
    if (userCode.isEmpty || partyCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User or party information missing')),
      );
      return;
    }

    final ub = Provider.of<UserProvider>(context, listen: false);
    final token = ub.token;

    if (token == null || token.isEmpty) {
      return;
    }

    _showPartyHistoryDialog(userCode, partyCode, partyName, token);
  }

  Future<List<Map<String, dynamic>>> _fetchProductivePartyHistory({
    required String userCode,
    required String partyCode,
    required DateTime fromDate,
    required DateTime toDate,
    required String token,
  }) async {
    final uri = Uri.parse('${AppConfig.baseURL}reports/orders').replace(
      queryParameters: {
        'userCd': userCode,
        'fromDate': _fmtDate(fromDate),
        'toDate': _fmtDate(toDate),
        'partyCd': partyCode,
      },
    );

    print('[RouteMapView] Fetching productive history: $uri');

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'x-app-type': 'oms',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load productive history: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List? ?? [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchNonProductivePartyHistory({
    required String userCode,
    required String partyCode,
    required DateTime fromDate,
    required DateTime toDate,
    required String token,
  }) async {
    final uri = Uri.parse('${AppConfig.baseURL}orders-tracking').replace(
      queryParameters: {
        'non_productive': 'true',
        'user_cd': userCode,
        'fromDate': _fmtDate(fromDate),
        'toDate': _fmtDate(toDate),
        'party_cd': partyCode,
      },
    );

    print('[RouteMapView] Fetching non-productive history: $uri');

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'x-app-type': 'oms',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load non-productive history: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List? ?? [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _showPartyHistoryDialog(
    String userCode,
    String partyCode,
    String partyName,
    String token,
  ) {
    String filterType = 'Productive';
    DateTime toDate = DateTime.now();
    DateTime fromDate = toDate.subtract(const Duration(days: 10));
    List<Map<String, dynamic>> historyData = [];
    bool isLoading = false;
    String? loadError;
    bool initialLoadDone = false;
    int requestCounter = 0;

    Future<void> loadHistory(
      StateSetter setDialogState,
      BuildContext dialogContext,
    ) async {
      final requestId = ++requestCounter;

      setDialogState(() {
        isLoading = true;
        loadError = null;
      });

      try {
        final records = filterType == 'Productive'
            ? await _fetchProductivePartyHistory(
                userCode: userCode,
                partyCode: partyCode,
                fromDate: fromDate,
                toDate: toDate,
                token: token,
              )
            : await _fetchNonProductivePartyHistory(
                userCode: userCode,
                partyCode: partyCode,
                fromDate: fromDate,
                toDate: toDate,
                token: token,
              );

        if (!dialogContext.mounted || requestId != requestCounter) {
          return;
        }

        setDialogState(() {
          historyData = records;
          isLoading = false;
        });
      } catch (e) {
        if (!dialogContext.mounted || requestId != requestCounter) {
          return;
        }

        setDialogState(() {
          historyData = [];
          isLoading = false;
          loadError = e.toString();
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          if (!initialLoadDone) {
            initialLoadDone = true;
            Future.microtask(() => loadHistory(setDialogState, dialogContext));
          }

          return AlertDialog(
            title: const Text('Party History'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      partyName.trim().isNotEmpty
                          ? 'Party: $partyName'
                          : 'Party Code: $partyCode',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: filterType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Filter Type',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Productive',
                              child: Text('Productive'),
                            ),
                            DropdownMenuItem(
                              value: 'Non Productive',
                              child: Text('Non Productive'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              filterType = value;
                            });
                            loadHistory(setDialogState, dialogContext);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: isLoading
                            ? null
                            : () => loadHistory(setDialogState, dialogContext),
                        icon: Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: fromDate,
                              firstDate: DateTime(2020, 1, 1),
                              lastDate: toDate,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                fromDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'From Date',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            child:
                                Text(DateFormat('yyyy-MM-dd').format(fromDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: toDate,
                              firstDate: fromDate,
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                toDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'To Date',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            child:
                                Text(DateFormat('yyyy-MM-dd').format(toDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Data list
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : loadError != null
                            ? Center(
                                child: Text(
                                  loadError!,
                                  style: const TextStyle(fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : historyData.isEmpty
                                ? Center(
                                    child: Text(
                                      'No $filterType records found',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: historyData.length,
                                    itemBuilder: (context, index) {
                                      final record = historyData[index];

                                      final date =
                                          (record['VOUCH_DT'] ?? '').toString();
                                      final inTime = filterType == 'Productive'
                                          ? (() {
                                              final items =
                                                  record['ordritms'] as List?;
                                              if (items == null ||
                                                  items.isEmpty) {
                                                return '';
                                              }
                                              final firstItem =
                                                  items.first as Map?;
                                              return (firstItem?[
                                                          'VOUCH_TIME'] ??
                                                      '')
                                                  .toString();
                                            })()
                                          : (record['IN_TIME'] ?? '')
                                              .toString();
                                      final outTime = filterType == 'Productive'
                                          ? ''
                                          : (record['OUT_TIME'] ?? '')
                                              .toString();
                                      final amount = filterType == 'Productive'
                                          ? ((record['NET_AMT'] ??
                                                  record['OR_AMT']) ??
                                              0)
                                          : null;
                                      final indicator = filterType;
                                      final reason = filterType ==
                                              'Non Productive'
                                          ? (record['REASON'] ?? '').toString()
                                          : '';

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        date,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      Text(
                                                        outTime.isNotEmpty
                                                            ? '$inTime - $outTime'
                                                            : inTime,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: indicator ==
                                                                  'Productive'
                                                              ? Colors
                                                                  .green[100]
                                                              : Colors
                                                                  .orange[100],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          indicator,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: indicator ==
                                                                    'Productive'
                                                                ? Colors
                                                                    .green[700]
                                                                : Colors.orange[
                                                                    700],
                                                          ),
                                                        ),
                                                      ),
                                                      if (amount != null &&
                                                          amount > 0)
                                                        Text(
                                                          '₹${amount}',
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              if (reason.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  reason,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _markUserAbsent(String normalizedUserCode, {String? reason}) {
    _updateUserPunchStatus(
      normalizedUserCode,
      punchStatus: 'absent',
      reason: reason,
    );
  }

  Future<void> _fetchLatestTripForUser(
    String userCode,
    String? token, {
    int? knownTripId,
    String? knownTripStatus,
    String? knownLastGpsAt,
    String? knownPunchStatus,
    String? knownPunchInTime,
    String? knownPunchOutTime,
  }) async {
    final normalizedUserCode = _normalizeCode(userCode);
    if (normalizedUserCode.isEmpty || token == null || token.isEmpty) {
      return;
    }

    final normalizedTripStatus = (knownTripStatus ?? '').trim().toLowerCase();

    try {
      final activeTripId = knownTripId ?? 0;
      final today = DateTime.now();
      final knownOpenTrip =
          normalizedTripStatus == 'active' || normalizedTripStatus == 'paused';

      // Some users can be marked active/paused in children payload while trip rows are
      // delayed/missing. Keep active state, but only use same-day timestamps.
      if (knownOpenTrip && activeTripId <= 0) {
        final activeReferenceTime = _resolveTodayReferenceTime(
          secondaryTime: knownLastGpsAt,
          today: today,
        );

        _updateUserPunchStatus(
          normalizedUserCode,
          punchStatus: 'punched_in',
          punchInTime: activeReferenceTime,
          punchOutTime: '',
          tripStatus:
              normalizedTripStatus.isNotEmpty ? normalizedTripStatus : 'active',
          reason: _hasTimestampValue(activeReferenceTime)
              ? 'children-open-no-tripId'
              : 'children-open-no-tripId-no-timestamp',
        );
        return;
      }

      // Prefer children API tripId as source-of-truth per user and fetch direct trip details.
      if (activeTripId > 0) {
        final uri =
            Uri.parse('${AppConfig.baseURL}location/trip/$activeTripId');
        print(
            '[RouteMapView] Fetching trip details by tripId for userCode: $normalizedUserCode, URI: $uri');

        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'x-app-type': 'oms',
          },
        );

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body) as Map<String, dynamic>;
          final data = decoded['data'] as Map<String, dynamic>?;
          final trip = data?['trip'];
          final tripMap = trip is Map
              ? Map<String, dynamic>.from(trip)
              : <String, dynamic>{};

          final tripUserCode = _extractUserCodeFromTripPayload(tripMap);
          if (tripUserCode.isNotEmpty && tripUserCode != normalizedUserCode) {
            print(
                '[RouteMapView] Trip user mismatch for tripId=$activeTripId. requested=$normalizedUserCode, response=$tripUserCode');
            if (_applyChildrenPunchFallback(
              normalizedUserCode,
              today: today,
              normalizedTripStatus: normalizedTripStatus,
              knownLastGpsAt: knownLastGpsAt,
              knownPunchStatus: knownPunchStatus,
              knownPunchInTime: knownPunchInTime,
              knownPunchOutTime: knownPunchOutTime,
              tripId: activeTripId,
              reasonPrefix: 'trip-user-mismatch-fallback',
            )) {
              return;
            }
            _markUserAbsent(normalizedUserCode, reason: 'trip-user-mismatch');
            return;
          }

          final summary = data?['summary'] as Map<String, dynamic>?;
          final startTime =
              _extractTripStartTimeFromTripAndSummary(tripMap, summary);

          final activeReferenceTime = _resolveTodayReferenceTime(
            primaryTime: startTime,
            secondaryTime: knownLastGpsAt,
            today: today,
          );

          // Source-of-truth rule: users/children is already per-user and carries
          // live trip state (often from redis). If it says active/paused, keep user in
          // punched-in state even when trip detail payload is stale/inconsistent.
          if (knownOpenTrip) {
            _updateUserPunchStatus(
              normalizedUserCode,
              punchStatus: 'punched_in',
              punchInTime: activeReferenceTime,
              punchOutTime: '',
              tripStatus: normalizedTripStatus,
              tripId: activeTripId,
              reason: _hasTimestampValue(activeReferenceTime)
                  ? 'children-open-override'
                  : 'children-open-override-no-timestamp',
            );

            if (!mounted) return;
            setState(() {
              if (summary != null) {
                _tripSummaryData[activeTripId] = summary;
              }
            });

            if (summary != null) {
              final lastPoint = summary['last_point'];
              if (lastPoint is Map<String, dynamic>) {
                final lat = lastPoint['lat'] as num?;
                final lng = lastPoint['lng'] as num?;
                if (lat != null && lng != null) {
                  _addUserMarkerToMap(
                      activeTripId,
                      LatLng(lat.toDouble(), lng.toDouble()),
                      normalizedUserCode);
                }
              }
            }

            return;
          }

          if (startTime.isEmpty) {
            if (_applyChildrenPunchFallback(
              normalizedUserCode,
              today: today,
              normalizedTripStatus: normalizedTripStatus,
              knownLastGpsAt: knownLastGpsAt,
              knownPunchStatus: knownPunchStatus,
              knownPunchInTime: knownPunchInTime,
              knownPunchOutTime: knownPunchOutTime,
              tripId: activeTripId,
              reasonPrefix: 'tripId-empty-start-fallback',
            )) {
              return;
            }
            _markUserAbsent(normalizedUserCode,
                reason: 'empty-start-time-from-tripId');
            return;
          }

          if (!_isTimestampOnDate(startTime, today)) {
            if (_applyChildrenPunchFallback(
              normalizedUserCode,
              today: today,
              normalizedTripStatus: normalizedTripStatus,
              knownLastGpsAt: knownLastGpsAt,
              knownPunchStatus: knownPunchStatus,
              knownPunchInTime: knownPunchInTime,
              knownPunchOutTime: knownPunchOutTime,
              tripId: activeTripId,
              reasonPrefix: 'tripId-start-not-today-fallback',
            )) {
              return;
            }
            _markUserAbsent(normalizedUserCode,
                reason: 'tripId-start-not-today');
            return;
          }

          final normalizedStatus = (tripMap['status'] ?? normalizedTripStatus)
              .toString()
              .trim()
              .toLowerCase();
          final endTime = _extractTripEndTime(tripMap);
          final isPunchedOut = _isTripPunchedOut(
            tripMap,
            fallbackStatus: normalizedTripStatus,
          );

          _updateUserPunchStatus(
            normalizedUserCode,
            punchStatus: isPunchedOut ? 'punched_out' : 'punched_in',
            punchInTime: startTime,
            punchOutTime: isPunchedOut ? endTime : '',
            tripStatus: normalizedStatus,
            tripId: activeTripId,
            reason: 'tripId-match',
          );

          if (!mounted) return;
          setState(() {
            if (summary != null) {
              _tripSummaryData[activeTripId] = summary;
            }
          });

          if (summary != null) {
            final lastPoint = summary['last_point'];
            if (lastPoint is Map<String, dynamic>) {
              final lat = lastPoint['lat'] as num?;
              final lng = lastPoint['lng'] as num?;
              if (lat != null && lng != null) {
                _addUserMarkerToMap(activeTripId,
                    LatLng(lat.toDouble(), lng.toDouble()), normalizedUserCode);
              }
            }
          }

          return;
        }

        print(
            '[RouteMapView] Failed trip details by tripId for $normalizedUserCode: HTTP ${response.statusCode}');
        if (knownOpenTrip) {
          final activeReferenceTime = _resolveTodayReferenceTime(
            secondaryTime: knownLastGpsAt,
            today: today,
          );

          _updateUserPunchStatus(
            normalizedUserCode,
            punchStatus: 'punched_in',
            punchInTime: activeReferenceTime,
            punchOutTime: '',
            tripStatus: normalizedTripStatus.isNotEmpty
                ? normalizedTripStatus
                : 'active',
            tripId: activeTripId,
            reason: _hasTimestampValue(activeReferenceTime)
                ? 'children-open-tripId-http-failed'
                : 'children-open-tripId-http-failed-no-timestamp',
          );
          return;
        }
        if (_applyChildrenPunchFallback(
          normalizedUserCode,
          today: today,
          normalizedTripStatus: normalizedTripStatus,
          knownLastGpsAt: knownLastGpsAt,
          knownPunchStatus: knownPunchStatus,
          knownPunchInTime: knownPunchInTime,
          knownPunchOutTime: knownPunchOutTime,
          tripId: activeTripId,
          reasonPrefix: 'tripId-http-failed-fallback',
        )) {
          return;
        }
        _markUserAbsent(normalizedUserCode, reason: 'tripId-http-failed');
        return;
      }

      // If no reliable tripId is available from children API, fetch latest trip list
      // for this user and decide punch state based on whether latest trip is today.
      final uri = Uri.parse('${AppConfig.baseURL}location/trip').replace(
        queryParameters: {
          'user_cd': normalizedUserCode,
        },
      );

      print(
          '[RouteMapView] Fetching trip for userCode: $normalizedUserCode, URI: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tripData = data['data'];

        // Extract trips array from the response
        final trips = (tripData is Map && tripData['trips'] is List)
            ? (tripData['trips'] as List)
            : [];

        final latestTrip = _pickLatestTripForUser(trips, normalizedUserCode);

        if (latestTrip != null) {
          final startTime = (latestTrip['start_time'] ??
                  latestTrip['START_TIME'] ??
                  latestTrip['started_at'] ??
                  latestTrip['STARTED_AT'] ??
                  '')
              .toString()
              .trim();

          if (!_isTimestampOnDate(startTime, today)) {
            if (_applyChildrenPunchFallback(
              normalizedUserCode,
              today: today,
              normalizedTripStatus: normalizedTripStatus,
              knownLastGpsAt: knownLastGpsAt,
              knownPunchStatus: knownPunchStatus,
              knownPunchInTime: knownPunchInTime,
              knownPunchOutTime: knownPunchOutTime,
              reasonPrefix: 'list-start-not-today-fallback',
            )) {
              return;
            }
            _markUserAbsent(normalizedUserCode,
                reason: 'list-api-start-not-today');
            return;
          }

          final tripId = _extractTripIdFromTripPayload(latestTrip);
          final status = (latestTrip['status'] ?? normalizedTripStatus)
              .toString()
              .trim()
              .toLowerCase();
          final endTime = _extractTripEndTime(latestTrip);
          final isPunchedOut = _isTripPunchedOut(
            latestTrip,
            fallbackStatus: normalizedTripStatus,
          );

          print(
              '[RouteMapView] Trip found for $normalizedUserCode - tripId: $tripId, startTime: $startTime');

          _updateUserPunchStatus(
            normalizedUserCode,
            punchStatus: isPunchedOut ? 'punched_out' : 'punched_in',
            punchInTime: startTime,
            punchOutTime: isPunchedOut ? endTime : '',
            tripStatus: status,
            tripId: tripId,
            reason: 'latest-list-trip',
          );

          // Fetch trip details to get last_point
          if (tripId > 0) {
            await _fetchTripDetailsForMap(tripId, token, normalizedUserCode);
          }

          print(
              '[RouteMapView] Fetched today\'s trip for $normalizedUserCode: startTime="$startTime"');
        } else {
          print(
              '[RouteMapView] No matching trips today for $normalizedUserCode');
          if (_applyChildrenPunchFallback(
            normalizedUserCode,
            today: today,
            normalizedTripStatus: normalizedTripStatus,
            knownLastGpsAt: knownLastGpsAt,
            knownPunchStatus: knownPunchStatus,
            knownPunchInTime: knownPunchInTime,
            knownPunchOutTime: knownPunchOutTime,
            reasonPrefix: 'no-matching-trip-fallback',
          )) {
            return;
          }
          _markUserAbsent(normalizedUserCode,
              reason: 'no-matching-trip-in-list-api');
        }
      } else {
        if (_applyChildrenPunchFallback(
          normalizedUserCode,
          today: today,
          normalizedTripStatus: normalizedTripStatus,
          knownLastGpsAt: knownLastGpsAt,
          knownPunchStatus: knownPunchStatus,
          knownPunchInTime: knownPunchInTime,
          knownPunchOutTime: knownPunchOutTime,
          reasonPrefix: 'list-http-failed-fallback',
        )) {
          return;
        }
        _markUserAbsent(normalizedUserCode,
            reason: 'list-api-http-${response.statusCode}');
      }
    } catch (e) {
      print(
          '[RouteMapView] Error fetching today\'s trip for $normalizedUserCode: $e');
      if (_applyChildrenPunchFallback(
        normalizedUserCode,
        today: DateTime.now(),
        normalizedTripStatus: normalizedTripStatus,
        knownLastGpsAt: knownLastGpsAt,
        knownPunchStatus: knownPunchStatus,
        knownPunchInTime: knownPunchInTime,
        knownPunchOutTime: knownPunchOutTime,
        reasonPrefix: 'exception-fallback',
      )) {
        return;
      }
      _markUserAbsent(normalizedUserCode, reason: 'exception');
    }
  }

  Future<void> _fetchTripDetailsForMap(
      int tripId, String token, String userCode) async {
    if (tripId <= 0 || token.isEmpty || userCode.isEmpty) {
      return;
    }
    try {
      final uri = Uri.parse('${AppConfig.baseURL}location/trip/$tripId');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;

        if (data is Map<String, dynamic>) {
          final summary = data['summary'] as Map<String, dynamic>?;
          if (summary != null) {
            // Store trip summary data
            setState(() {
              _tripSummaryData[tripId] = summary;
            });

            // Extract and display last_point on map
            final lastPoint = summary['last_point'];
            if (lastPoint is Map<String, dynamic>) {
              final lat = lastPoint['lat'] as num?;
              final lng = lastPoint['lng'] as num?;
              if (lat != null && lng != null) {
                _addUserMarkerToMap(
                    tripId, LatLng(lat.toDouble(), lng.toDouble()), userCode);
              }
            }
          }
        }
      }
    } catch (e) {
      print('[RouteMapView] Error fetching trip details for $tripId: $e');
    }
  }

  void _addUserMarkerToMap(int tripId, LatLng point, String userCode) {
    // Look up the user from the _users list using userCode to get correct name and photo
    final userIndex = _users.indexWhere((u) => u['userCode'] == userCode);
    if (userIndex < 0) {
      print('[RouteMapView] User not found for userCode: $userCode');
      return;
    }

    final userObject = _users[userIndex];
    final photoUrl = userObject['photoUrl'] ?? '';
    final userName = (userObject['userName'] ?? 'U').toString().trim();

    print(
        '[RouteMapView] Creating marker - userCode: $userCode, userName: $userName, photoUrl: $photoUrl');

    _createCustomMarker(photoUrl, userName).then((customIcon) {
      setState(() {
        _userLocationMarkers.add(
          Marker(
            markerId: MarkerId('user_$tripId'),
            position: point,
            infoWindow: InfoWindow(title: userName),
            icon: customIcon,
          ),
        );
        // Also add to _markers so they're visible immediately
        _markers.add(
          Marker(
            markerId: MarkerId('user_$tripId'),
            position: point,
            infoWindow: InfoWindow(title: userName),
            icon: customIcon,
          ),
        );
      });
    }).catchError((e) {
      print('[RouteMapView] Error creating marker: $e');
    });
  }

  Future<BitmapDescriptor> _createCustomMarker(
      String photoUrl, String userName) async {
    try {
      // Create initial letter
      final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

      // If photo URL exists, try to use it
      if (photoUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(photoUrl));
          if (response.statusCode == 200) {
            final markerBytes =
                await _createCircleMarkerBytes(response.bodyBytes, initial);
            return BitmapDescriptor.fromBytes(markerBytes);
          }
        } catch (_) {
          // Fall through to initial-only marker
        }
      }

      // Create marker with initial only
      final markerBytes = await _createInitialMarkerBytes(initial);
      return BitmapDescriptor.fromBytes(markerBytes);
    } catch (e) {
      print('[RouteMapView] Error creating marker: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  Future<Uint8List> _createCircleMarkerBytes(
      List<int> imageBytes, String initial) async {
    const size = 120.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Draw circle background
    final paint = ui.Paint()
      ..color = Colors.blue
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    // Try to draw image
    try {
      final image = await decodeImageFromList(Uint8List.fromList(imageBytes));
      final squareCroppedImage = await _cropImageToSquare(image);
      final scaledImage = await _scaleImage(squareCroppedImage, size.toInt());
      final rect = Rect.fromLTWH(0, 0, size, size);

      // Keep photo inside a circular marker shape.
      canvas.save();
      canvas.clipPath(ui.Path()..addOval(rect));
      canvas.drawImageRect(
        scaledImage,
        Rect.fromLTWH(
            0, 0, scaledImage.width.toDouble(), scaledImage.height.toDouble()),
        rect,
        ui.Paint(),
      );
      canvas.restore();
    } catch (_) {
      // If image fails, just show initial
      _drawTextOnCanvas(canvas, initial, size);
    }

    // Draw border on top so it remains visible over the image.
    final borderPaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, borderPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Crop image to square by taking the center portion
  Future<ui.Image> _cropImageToSquare(ui.Image image) async {
    final minDimension = min(image.width, image.height);
    final offsetX = (image.width - minDimension) ~/ 2;
    final offsetY = (image.height - minDimension) ~/ 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(offsetX.toDouble(), offsetY.toDouble(),
          minDimension.toDouble(), minDimension.toDouble()),
      Rect.fromLTWH(0, 0, minDimension.toDouble(), minDimension.toDouble()),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    return picture.toImage(minDimension, minDimension);
  }

  Future<Uint8List> _createInitialMarkerBytes(String initial) async {
    const size = 120.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Draw circle background
    final paint = ui.Paint()
      ..color = Colors.blue
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    // Draw border
    final borderPaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, borderPaint);

    // Draw text
    _drawTextOnCanvas(canvas, initial, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _drawTextOnCanvas(ui.Canvas canvas, String text, double size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );
  }

  Future<ui.Image> _scaleImage(ui.Image image, int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    return picture.toImage(size, size);
  }

  Future<void> _fetchAndStoreTripSummary(
    int tripId, {
    int? requestId,
  }) async {
    final ub = Provider.of<UserProvider>(context, listen: false);
    final token = ub.token;

    if (token == null || token.isEmpty || tripId <= 0) {
      return;
    }

    try {
      final uri = Uri.parse('${AppConfig.baseURL}location/trip/$tripId');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;

        if (data is Map<String, dynamic>) {
          final summary = data['summary'] as Map<String, dynamic>?;
          if (summary != null) {
            if (!mounted ||
                (requestId != null && requestId != _timelineRequestId)) {
              return;
            }
            setState(() {
              _tripSummaryData[tripId] = {
                ...summary,
                ...?_tripSummaryData[tripId],
              };
            });
          }
        }
      }
    } catch (e) {
      print('[RouteMapView] Error fetching trip summary for $tripId: $e');
    }
  }

  String _calculateTimeAgo(String? punchInTimeStr) {
    if (punchInTimeStr == null || punchInTimeStr.isEmpty) {
      return 'N/A';
    }
    try {
      // Try parsing different date formats
      DateTime punchTime;
      try {
        punchTime = DateTime.parse(punchInTimeStr);
      } catch (e) {
        // Try alternate format if parsing fails
        return 'N/A';
      }

      final now = DateTime.now();
      final difference = now.difference(punchTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      print('[RouteMapView] Error calculating time ago: $e');
      return 'Absent';
    }
  }

  Widget _getBulletForEvent(String eventType) {
    switch (eventType) {
      case 'trip_started':
        return Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, size: 10, color: Colors.white),
        );
      case 'trip_completed':
        return Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.stop, size: 10, color: Colors.white),
        );
      case 'offline_started':
        return Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_off, size: 10, color: Colors.white),
        );
      case 'offline_ended':
        return Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_done, size: 10, color: Colors.white),
        );
      case 'order_placed':
        return Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.done, size: 10, color: Colors.white),
        );
      default:
        return Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.info, size: 10, color: Colors.white),
        );
    }
  }

  List<Map<String, dynamic>> _getFilteredUsers() {
    final usersSource = (_searchQuery.isNotEmpty && _hasLoadedAllUsersForSearch)
        ? _allUsersForSearch
        : _users;

    if (_searchQuery.isEmpty) {
      return usersSource;
    }
    return usersSource
        .where((user) =>
            user['userName'].toLowerCase().contains(_searchQuery) ||
            user['phone'].toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Google Map (Background)
            GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
              },
              initialCameraPosition: const CameraPosition(
                target: _defaultCenter,
                zoom: 12,
              ),
              myLocationEnabled: true,
              polylines: _polylines,
              markers: _markers,
            ),

            // Back Button
            Positioned(
              top: 5,
              left: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                ),
              ),
            ),

            // Tap overlay (to collapse sheet when fully expanded)
            if (_currentSheetSize > 0.85)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    // Scroll users list to top if visible
                    if (_selectedUser == null) {
                      // First scroll the main sheet with scrollController
                      if (_usersListScrollController.hasClients) {
                        _usersListScrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      }
                    }
                    _sheetController.animateTo(
                      0.35,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                  ),
                ),
              ),

            // Bottom Sheet (Foreground - anchored at bottom)
            Align(
              alignment: Alignment.bottomCenter,
              child: DraggableScrollableSheet(
                controller: _sheetController,
                expand: false,
                initialChildSize: 0.35,
                minChildSize: 0.25,
                maxChildSize: 0.9,
                builder: (context, scrollController) {
                  return _selectedUser == null
                      ? _buildUsersListSheet(scrollController)
                      : _buildTimelineSheet(scrollController);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersListSheet(ScrollController scrollController) {
    final filteredUsers = _getFilteredUsers();

    // Add scroll listener for infinite scroll
    scrollController.addListener(() => _onUsersListScroll(scrollController));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Text(
                    'Track Users',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (filteredUsers.isNotEmpty)
                    Chip(
                      label: Text('${filteredUsers.length}'),
                      backgroundColor: Colors.blue.withOpacity(0.2),
                    ),
                ],
              ),
            ),
            // Search Bar (always visible)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const Divider(),
            // Users List
            if (_loadingUsers)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_usersError != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_usersError!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('No child users found')),
              )
            else if (filteredUsers.isEmpty &&
                _searchQuery.isNotEmpty &&
                _isLoadingAllUsersForSearch)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Searching all users...'),
                    ],
                  ),
                ),
              )
            else if (filteredUsers.isEmpty && _searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child:
                    Center(child: Text('No users found for "$_searchQuery"')),
              )
            else
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  return _buildUserTile(user);
                },
              ),
            // Pagination info and Load More button
            if (filteredUsers.isEmpty == false && _searchQuery.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Center(
                  child: Text(
                    'Showing ${_users.length} of $_totalUsersCount users (Page $_currentUsersPage of $_totalUsersPages)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            // Loading indicator when fetching more users
            if (_isLoadingMoreUsers)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _onUsersListScroll(ScrollController controller) {
    if (_searchQuery.isNotEmpty || _isLoadingAllUsersForSearch) {
      return;
    }

    if (controller.position.pixels >=
        controller.position.maxScrollExtent - 500) {
      // User scrolled near bottom, load more if available
      if (!_isLoadingMoreUsers && _currentUsersPage < _totalUsersPages) {
        _loadMoreUsers();
      }
    }
  }

  Future<void> _showUserPhotoPreview({
    required String photoUrl,
    required String userName,
  }) async {
    final normalizedPhotoUrl = photoUrl.trim();
    if (normalizedPhotoUrl.isEmpty) {
      return;
    }

    final screenSize = MediaQuery.of(context).size;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
          child: Container(
            width: screenSize.width,
            constraints: BoxConstraints(maxHeight: screenSize.height * 0.82),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.network(
                      normalizedPhotoUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) {
                        return Center(
                          child: Text(
                            'Unable to load image',
                            style: TextStyle(color: Colors.grey[300]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Text(
                    userName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTappableUserAvatar({
    required String photoUrl,
    required String userName,
  }) {
    final normalizedPhotoUrl = photoUrl.trim();
    final displayName = userName.trim();
    final initials =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    final avatar = CircleAvatar(
      backgroundImage: normalizedPhotoUrl.isNotEmpty
          ? NetworkImage(normalizedPhotoUrl)
          : null,
      child: normalizedPhotoUrl.isEmpty ? Text(initials) : null,
    );

    if (normalizedPhotoUrl.isEmpty) {
      return avatar;
    }

    return GestureDetector(
      onTap: () {
        _showUserPhotoPreview(
            photoUrl: normalizedPhotoUrl, userName: displayName);
      },
      child: avatar,
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final punchInTimeStr = user['punchInTime']?.toString().trim() ?? '';
    final punchOutTimeStr = user['punchOutTime']?.toString().trim() ?? '';
    final punchStatus =
        (user['punchStatus'] ?? 'absent').toString().trim().toLowerCase();

    String statusText;
    Color statusColor;
    FontWeight statusWeight = FontWeight.normal;
    final now = DateTime.now();

    if (punchStatus == 'punched_out') {
      final canShowRelativeTime = _isTimestampOnDate(punchOutTimeStr, now);
      final timeAgo = _calculateTimeAgo(punchOutTimeStr);
      statusText = canShowRelativeTime ? 'Punched out $timeAgo' : 'Punched out';
      statusColor = Colors.deepOrange;
      statusWeight = FontWeight.w600;
    } else if (punchStatus == 'punched_in') {
      final canShowRelativeTime = _isTimestampOnDate(punchInTimeStr, now);
      final timeAgo = _calculateTimeAgo(punchInTimeStr);
      statusText = canShowRelativeTime ? 'Punched in $timeAgo' : 'Punched in';
      statusColor = Colors.green;
    } else {
      statusText = 'Absent';
      statusColor = Colors.red;
      statusWeight = FontWeight.bold;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        onTap: () => _selectUser(user),
        leading: _buildTappableUserAvatar(
          photoUrl: user['photoUrl']?.toString() ?? '',
          userName: user['userName']?.toString() ?? '',
        ),
        title: Text(user['userName']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['phone']),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: statusWeight,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.call, color: Colors.green),
          onPressed: () => _callUser(user['phone']),
        ),
      ),
    );
  }

  Widget _buildTimelineSheet(ScrollController scrollController) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button and date picker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _clearSelectedUser,
                    tooltip: 'Back to Users',
                  ),
                  SizedBox(
                    width: 3,
                  ),
                  _buildTappableUserAvatar(
                    photoUrl: _selectedUser?['photoUrl']?.toString() ?? '',
                    userName: _selectedUser?['userName']?.toString() ?? '',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedUser?['userName'] ?? 'User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _selectedUser?['phone'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Date Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trip Date:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM yyyy')
                                .format(_selectedTimelineDate),
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Trips Tab Bar (if multiple trips)
            if (_tripsForSelectedDate.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    _tripsForSelectedDate.length,
                    (index) {
                      final trip = _tripsForSelectedDate[index];
                      final tripId = trip['id'] ??
                          trip['ID'] ??
                          trip['trip_id'] ??
                          trip['TRIP_ID'] ??
                          0;

                      String tripDisplay = 'Trip: $tripId';

                      final isSelected = _selectedTripIndex == index;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTripIndex = index;
                              _selectedTrip = trip;
                              _timelineData =
                                  _timelineByTrip[_getTripIdAtIndex(index)] ??
                                      [];
                            });
                            // Fetch and display route for this trip
                            final tripId = _getTripIdAtIndex(index);
                            if (tripId > 0) {
                              _fetchAndDisplayTripRoute(tripId);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue
                                  : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.grey.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              tripDisplay,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const Divider(),
            if (_isLoadingRemainingTrips)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  'Loading remaining trips: $_loadedTripsCount/$_totalTripsToLoad',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            // Trip Summary
            _buildTripSummaryWidget(),
            const Divider(),
            // Timeline List
            if (_loadingTimeline)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_timelineData.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('No activities for this trip')),
              )
            else
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _timelineData.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final item = _timelineData[index];
                  final tripId = item['tripId'] as int? ?? 0;
                  final timestamp = item['timestamp'] as String? ?? '';
                  final eventType = item['event_type'] as String? ?? '';
                  final title = item['name'] ??
                      item['title'] ??
                      _formatEventType(eventType) ??
                      'Activity';
                  final subtitle =
                      item['description'] ?? item['subtitle'] ?? '';

                  // Format date and time
                  String dateStr = 'N/A';
                  String timeStr = 'N/A';
                  try {
                    if (timestamp.isNotEmpty) {
                      final dt = DateTime.parse(timestamp);
                      dateStr = DateFormat('dd MMM').format(dt);
                      timeStr = DateFormat('hh:mm a').format(dt);
                    }
                  } catch (_) {}

                  final isFirst = index == 0;
                  final isLast = index == _timelineData.length - 1;
                  final bullet = _getBulletForEvent(eventType);

                  // Check if this is an order_placed event
                  final isOrderPlaced =
                      eventType.toLowerCase() == 'order_placed';
                  final orderItems =
                      item['order_items'] as List<Map<String, dynamic>>? ?? [];
                  final partyName = item['party_name'] as String? ?? '';
                  final partyCode = item['party_code'] as String? ?? '';
                  final partyAddress = item['party_address'] as String? ?? '';

                  print(
                      '[RouteMapView] Timeline Event - Type: "$eventType", isOrderPlaced: $isOrderPlaced, itemsCount: ${orderItems.length}, partyName: "$partyName"');

                  // Build action buttons for order_placed events
                  Widget? actionButtons;
                  if (isOrderPlaced) {
                    actionButtons = Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _showOrderItemsDialog(
                                orderItems, partyName, partyCode, partyAddress);
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility,
                                size: 15,
                                color: Colors.blue,
                              ),
                              SizedBox(
                                width: 3,
                              ),
                              Text(
                                'View Items',
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: () {
                            _fetchAndShowPartyHistory(
                              _selectedUser?['userCode'] as String? ?? '',
                              item['party_code'] as String? ?? '',
                              partyName: partyName,
                            );
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                size: 15,
                                color: Colors.blue,
                              ),
                              SizedBox(
                                width: 3,
                              ),
                              Text(
                                'View History',
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return GestureDetector(
                    onTap: tripId > 0
                        ? () {
                            setState(() {
                              _selectedTrip = item;
                            });
                            _fetchAndDisplayTripRoute(tripId);
                          }
                        : null,
                    child: CommonTimelineTile(
                      date: dateStr,
                      time: timeStr,
                      title: title.toString(),
                      subtitle: subtitle.toString(),
                      isFirst: isFirst,
                      isLast: isLast,
                      bulletWidget: bullet,
                      actionButtons: actionButtons,
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTripSummaryWidget() {
    final tripId = _getTripIdAtIndex(_selectedTripIndex);
    final summary = _tripSummaryData[tripId] ?? {};

    // Extract summary data
    final totalDistance = (summary['total_distance'] as num?)?.toDouble() ??
        (summary['total_distance_km'] as num?)?.toDouble() ??
        0.0;
    final totalDurationFormatted =
        summary['total_duration_formatted'] ?? '0h 0m 0s';

    // Extract call and sales data from summary
    final totalCallsCount =
        (summary['total_calls_count'] as num?)?.toInt() ?? 0;
    final productiveCallsCount =
        (summary['productive_calls_count'] as num?)?.toInt() ?? 0;
    final nonProductiveCallsCount =
        (summary['non_productive_calls_count'] as num?)?.toInt() ?? 0;
    final totalSaleAmount =
        (summary['total_sale_amount'] as num?)?.toDouble() ?? 0.0;
    final totalSaleAmountText = totalSaleAmount % 1 == 0
        ? totalSaleAmount.toInt().toString()
        : totalSaleAmount.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // First row: Distance, Duration, Total Calls
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Distance',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalDistance.toStringAsFixed(2)} km',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Duration',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalDurationFormatted,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Calls',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalCallsCount.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Second row: Productive Calls, Non-Productive Calls, Total Sale Amount
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Productive Calls',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      productiveCallsCount.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Non-Productive Calls',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nonProductiveCallsCount.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Sale Amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹$totalSaleAmountText',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
