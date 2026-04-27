import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../widgets/user_search_dropdown.dart';
import 'route%20timeline/route_map_view.dart';

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
  List<Map<String, dynamic>> _allUsersForSearch = [];
  bool _loadingUsers = false;
  bool _isLoadingAllUsersForSearch = false;
  bool _hasLoadedAllUsersForSearch = false;
  static const int _usersPerPage = 20;
  int _currentUsersPage = 1;
  int _totalUsersPages = 1;
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
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final initialUserCode =
          (widget.selectedUserCd?.trim().isNotEmpty ?? false)
              ? widget.selectedUserCd!.trim()
              : '';
      final initialUserName =
          (widget.selectedUserName?.trim().isNotEmpty ?? false)
              ? widget.selectedUserName!.trim()
              : (profileProvider.userName?.trim() ?? '');

      if (initialUserCode.isNotEmpty) {
        _selectedUserCode = initialUserCode;
      }
      if (initialUserName.isNotEmpty) {
        _selectedUserName = initialUserName;
      }

      _fetchAllUsersForSearch(
        forceRefresh: true,
        syncPrimaryUsers: true,
        source: 'init_preload',
      );
      _fetchTrips();
    });
  }

  int _toInt(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<Map<String, dynamic>> _mapUsers(List<dynamic> usersList) {
    return List<Map<String, dynamic>>.from(
      usersList.whereType<Map>().map((user) {
        final normalized = Map<String, dynamic>.from(user);
        final userCode = (normalized['USER_CD'] ?? '').toString().trim();
        final userName = (normalized['USER_NAME'] ?? '').toString().trim();
        final phone = (normalized['MOBILENO'] ?? '').toString().trim();
        return {
          'userCode': userCode,
          'userName': userName,
          'phone': phone,
        };
      }),
    );
  }

  List<Map<String, dynamic>> _mergeUsersByCode(
    List<Map<String, dynamic>> base,
    List<Map<String, dynamic>> incoming,
  ) {
    final merged = <Map<String, dynamic>>[];
    final seenCodes = <String>{};

    for (final user in base) {
      final code = (user['userCode'] ?? '').toString().trim();
      if (code.isEmpty || seenCodes.add(code)) {
        merged.add(user);
      }
    }

    for (final user in incoming) {
      final code = (user['userCode'] ?? '').toString().trim();
      if (code.isEmpty || seenCodes.add(code)) {
        merged.add(user);
      }
    }

    return merged;
  }

  Future<void> _fetchUsers({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _loadingUsers = true;
    });
    try {
      await CrashlyticsService.logAction('route_report_users_api_triggered');
      final ub = Provider.of<UserProvider>(context, listen: false);
      final token = ub.token;
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _users = [];
          _loadingUsers = false;
        });
        return;
      }
      final uri = Uri.parse('${AppConfig.baseURL}users/children').replace(
        queryParameters: {
          'date': _fmtDate(DateTime.now()),
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
      print(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final usersList = (data['data'] is List) ? data['data'] : [];
        final payload = data['payload'] as Map<String, dynamic>?;
        final pagination = payload?['pagination'] as Map<String, dynamic>?;
        final pageFromResponse = _toInt(pagination?['page'], page);
        final lastPage = _toInt(pagination?['last_page'], pageFromResponse);
        final mappedUsers = _mapUsers(usersList);
        final hasPaginationMeta =
            pagination != null && pagination['last_page'] != null;
        final hasMoreByMeta = pageFromResponse < lastPage;
        final hasMoreBySize = mappedUsers.length >= _usersPerPage;
        final hasMorePages = hasPaginationMeta ? hasMoreByMeta : hasMoreBySize;

        if (!mounted) return;
        setState(() {
          if (page == 1) {
            _users = mappedUsers;
            _allUsersForSearch = [];
            _hasLoadedAllUsersForSearch = false;
          } else {
            _users = _mergeUsersByCode(_users, mappedUsers);
          }
          _currentUsersPage = page;
          _totalUsersPages = hasMorePages ? page + 1 : page;
          _loadingUsers = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _users = [];
          _loadingUsers = false;
        });
      }
    } catch (e, stack) {
      if (!mounted) return;
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

  Future<void> _fetchAllUsersForSearch({
    bool forceRefresh = false,
    bool syncPrimaryUsers = false,
    String source = 'search',
  }) async {
    if (_isLoadingAllUsersForSearch) {
      return;
    }

    if (!forceRefresh && _hasLoadedAllUsersForSearch) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingAllUsersForSearch = true;
      if (syncPrimaryUsers) {
        _loadingUsers = true;
      }
    });

    try {
      final ub = Provider.of<UserProvider>(context, listen: false);
      final token = ub.token;
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoadingAllUsersForSearch = false;
        });
        return;
      }

      final allUsers = <Map<String, dynamic>>[];
      final seenPageSignatures = <String>{};
      int currentPage = 1;
      const int maxPagesToFetch = 200;

      print(
          '[RouteReport] [$source] Start full users preload | items_per_page=$_usersPerPage');

      while (currentPage <= maxPagesToFetch) {
        final uri = Uri.parse('${AppConfig.baseURL}users/children').replace(
          queryParameters: {
            'date': _fmtDate(DateTime.now()),
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

        print('[RouteReport] [$source] Request page=$currentPage uri=$uri');

        if (response.statusCode != 200) {
          print(
              '[RouteReport] [$source] Stop preload: HTTP ${response.statusCode} on page=$currentPage');
          if (!mounted) return;
          setState(() {
            _isLoadingAllUsersForSearch = false;
            if (syncPrimaryUsers) {
              _loadingUsers = false;
            }
          });
          return;
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final usersList = (data['data'] is List) ? data['data'] : <dynamic>[];
        final mappedPageUsers = _mapUsers(usersList);
        print(
            '[RouteReport] [$source] Page=$currentPage received=${mappedPageUsers.length} users');
        if (mappedPageUsers.isEmpty) {
          print('[RouteReport] [$source] Stop preload: empty page');
          break;
        }

        final signature = mappedPageUsers
            .map((u) => (u['userCode'] ?? '').toString())
            .join('|');
        if (signature.isNotEmpty && !seenPageSignatures.add(signature)) {
          print(
              '[RouteReport] [$source] Stop preload: repeated page signature at page=$currentPage');
          break;
        }

        allUsers.addAll(mappedPageUsers);

        final payload = data['payload'] as Map<String, dynamic>?;
        final pagination = payload?['pagination'] as Map<String, dynamic>?;
        final hasPaginationMeta =
            pagination != null && pagination['last_page'] != null;
        if (hasPaginationMeta) {
          final pageFromResponse = _toInt(pagination?['page'], currentPage);
          final lastPage = _toInt(pagination?['last_page'], pageFromResponse);
          if (pageFromResponse >= lastPage) {
            print(
                '[RouteReport] [$source] Stop preload: reached last_page=$lastPage');
            break;
          }
          currentPage = pageFromResponse + 1;
          continue;
        }

        if (mappedPageUsers.length < _usersPerPage) {
          print(
              '[RouteReport] [$source] Stop preload: received < items_per_page on page=$currentPage');
          break;
        }

        currentPage += 1;
      }

      if (!mounted) return;
      setState(() {
        final mergedUsers =
            _mergeUsersByCode(<Map<String, dynamic>>[], allUsers);
        _allUsersForSearch = mergedUsers;
        if (syncPrimaryUsers) {
          _users = mergedUsers;
          _currentUsersPage = 1;
          _totalUsersPages = 1;
          _loadingUsers = false;
        }

        // Resolve initial title from loaded users when only code is available.
        if ((_selectedUserName == null || _selectedUserName!.trim().isEmpty) &&
            _selectedUserCode.trim().isNotEmpty) {
          final match = mergedUsers.firstWhere(
            (user) =>
                (user['userCode'] ?? '').toString().trim() ==
                _selectedUserCode.trim(),
            orElse: () => <String, dynamic>{},
          );
          final resolvedName = (match['userName'] ?? '').toString().trim();
          if (resolvedName.isNotEmpty) {
            _selectedUserName = resolvedName;
          }
        }

        _hasLoadedAllUsersForSearch = true;
        _isLoadingAllUsersForSearch = false;
      });

      print(
          '[RouteReport] [$source] Full preload complete: totalUsers=${_allUsersForSearch.length}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingAllUsersForSearch = false;
        if (syncPrimaryUsers) {
          _loadingUsers = false;
        }
      });
    }
  }

  void _onUserSearchQueryChanged(String query) {
    if (query.isNotEmpty && !_hasLoadedAllUsersForSearch) {
      _fetchAllUsersForSearch();
    }
  }

  List<Map<String, dynamic>> get _usersForDropdown {
    return _hasLoadedAllUsersForSearch ? _allUsersForSearch : _users;
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

  DateTime? _tryParseDateTime(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final direct = DateTime.tryParse(text);
    if (direct != null) return direct;

    final normalized = text.replaceFirst(' ', 'T').split('.').first;
    return DateTime.tryParse(normalized);
  }

  DateTime? _tripStartDateTimeFromMap(Map<String, dynamic> trip) {
    final dynamic raw = trip['start_time'] ??
        trip['START_TIME'] ??
        trip['started_at'] ??
        trip['STARTED_AT'] ??
        trip['created_at'] ??
        trip['CREATED_AT'];
    return _tryParseDateTime(raw);
  }

  DateTime? _tripEndDateTimeFromMap(Map<String, dynamic> trip) {
    final dynamic raw = trip['end_time'] ??
        trip['END_TIME'] ??
        trip['ended_at'] ??
        trip['ENDED_AT'];
    return _tryParseDateTime(raw);
  }

  String _formatClock(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('hh:mm a').format(value);
  }

  String _formatSectionDate(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('EEEE, MMM d').format(value);
  }

  String _tripSectionKey(Map<String, dynamic> trip) {
    final start = _tripStartDateTimeFromMap(trip);
    if (start != null) {
      return DateFormat('yyyy-MM-dd').format(start);
    }
    return _tripStartDateFromMap(trip);
  }

  int _durationLabelToMinutes(String value) {
    final text = value.toLowerCase().trim();
    if (text.isEmpty || text == '-' || text.contains('no order')) {
      return 0;
    }

    final colon =
        RegExp(r'^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$').firstMatch(text);
    if (colon != null) {
      final h = int.tryParse(colon.group(1) ?? '0') ?? 0;
      final m = int.tryParse(colon.group(2) ?? '0') ?? 0;
      final s = int.tryParse(colon.group(3) ?? '0') ?? 0;
      return h * 60 + m + (s > 0 ? 1 : 0);
    }

    final hMatch = RegExp(r'(\d+)\s*h').firstMatch(text);
    final mMatch = RegExp(r'(\d+)\s*m').firstMatch(text);
    final sMatch = RegExp(r'(\d+)\s*s').firstMatch(text);

    if (hMatch != null || mMatch != null || sMatch != null) {
      final h = int.tryParse(hMatch?.group(1) ?? '0') ?? 0;
      final m = int.tryParse(mMatch?.group(1) ?? '0') ?? 0;
      final s = int.tryParse(sMatch?.group(1) ?? '0') ?? 0;
      return h * 60 + m + (s > 0 ? 1 : 0);
    }

    final directMinutes = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
    return directMinutes ?? 0;
  }

  int _detectedGapCount(String inGap, String outGap) {
    int count = 0;
    if (_durationLabelToMinutes(inGap) > 0) count += 1;
    if (_durationLabelToMinutes(outGap) > 0) count += 1;
    return count;
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
    Widget buildDateField({
      required String label,
      required DateTime value,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            height: 55,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: 9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: const Color(0xFF0D5C92)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('dd-MM-yyyy').format(value),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: Color(0xFF0D5C92),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 0,
                  child: Container(
                    color: const Color(0xFFF3F4FA),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF3F4FA),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const Text(
          //   'Filter by Date Range',
          //   style: TextStyle(
          //     fontSize: 14,
          //     fontWeight: FontWeight.bold,
          //   ),
          // ),
          // const SizedBox(height: 10),
          Row(
            children: [
              buildDateField(
                label: 'From Date',
                value: _fromDate,
                onTap: _pickFromDate,
              ),
              const SizedBox(width: 10),
              buildDateField(
                label: 'To Date',
                value: _toDate,
                onTap: _pickToDate,
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

  String _tripUserNameFromMap(Map<String, dynamic> trip) {
    final dynamic directName = trip['user_name'] ??
        trip['USER_NAME'] ??
        trip['userName'] ??
        trip['USERNAME'];
    final String directNameText = directName?.toString().trim() ?? '';
    if (directNameText.isNotEmpty) {
      return directNameText;
    }

    final String userCode = _tripUserFromMap(trip).trim();
    if (userCode.isEmpty || userCode == '-') {
      return '-';
    }

    for (final user in _users) {
      final String code = (user['userCode'] ?? '').toString().trim();
      if (code == userCode) {
        final String name = (user['userName'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          return name;
        }
      }
    }

    return userCode;
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

  Map<String, dynamic>? _firstMapValue(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    final value = _firstValue(map, keys);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
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

  String _businessKmFromMap(Map<String, dynamic> map) {
    final business = _firstValue(map, [
      'BUSINESS_KM',
      'business_km',
      'businesskm',
      'businessKM',
      'BUSINESSKM'
    ]);
    if (business == null) return '-';
    final value = double.tryParse(business.toString());
    return value == null ? '-' : '${value.toStringAsFixed(2)} km';
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
      print(uri);

      if (response.statusCode != 200) return;

      final decoded = json.decode(response.body);
      final data = decoded['data'];
      if (data is! Map) return;

      final orderTiming = _firstMapValue(Map<String, dynamic>.from(data), [
        'orderTrackingTiming',
        'order_tracking_timing',
      ]);
      if (orderTiming == null) return;

      final punchGap = _firstMapValue(orderTiming, [
        'punch_in_to_first_in_gap',
        'punchInToFirstInGap',
      ]);
      final outGap = _firstMapValue(orderTiming, [
        'last_out_to_punch_out_gap',
        'lastOutToPunchOutGap',
      ]);
      final distanceBreakdown = _firstMapValue(orderTiming, [
        'distance_breakdown',
        'distanceBreakdown',
      ]);

      String _readFormatted(Map<String, dynamic>? value) {
        if (value == null) return '-';
        final formatted = _firstValue(value, ['formatted', 'FORMATTED']);
        return formatted?.toString().trim().isNotEmpty == true
            ? formatted.toString()
            : '-';
      }

      final punchFormatted = _readFormatted(punchGap);
      final outFormatted = _readFormatted(outGap);

      final businessKm = distanceBreakdown == null
          ? '-'
          : _kmString(_firstValue(distanceBreakdown, [
              'business_km',
              'BUSINESS_KM',
              'businessKm',
            ]));

      final transitKm = distanceBreakdown == null
          ? '-'
          : _kmString(_firstValue(distanceBreakdown, [
              'transit_km',
              'TRANSIT_KM',
              'transitKm',
            ]));

      if (!mounted) return;
      setState(() {
        _gapInfoByTripId[tripId] = {
          'punchFormatted': punchFormatted,
          'outFormatted': outFormatted,
        };

        _distanceBreakdownByTripId[tripId] = {
          'BUSINESS_KM': businessKm,
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
    final token = ub.token;

    // Use selected user when available; if empty, fetch all users' trips.
    final userCd = _selectedUserCode.isNotEmpty
        ? _selectedUserCode
        : (widget.selectedUserCd?.trim() ?? '');

    final syncId = ub.syncId?.trim() ?? '';

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Missing auth token';
      });
      return;
    }

    if (!mounted) return;
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

      final Map<String, String> queryParams = <String, String>{
        'fromDate': _fmtDate(_fromDate),
        'toDate': _fmtDate(_toDate),
      };
      if (userCd.isNotEmpty) {
        queryParams['user_cd'] = userCd;
      }

      final uri = Uri.parse('${AppConfig.baseURL}location/trip').replace(
        queryParameters: queryParams,
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

        if (userCd.isNotEmpty &&
            trips.isEmpty &&
            syncId.isNotEmpty &&
            syncId != userCd) {
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

        if (!mounted) return;
        setState(() {
          _trips = trips;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to fetch trip history';
          _trips = <Map<String, dynamic>>[];
        });
      }
    } catch (e, stack) {
      if (!mounted) return;
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

  String? _normalizeSelfieUrl(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }
    return value;
  }

  String? _extractSelfieUrlFromPayload(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }

    final root = Map<String, dynamic>.from(decoded);
    final data = root['data'];

    String? readFromMap(Map<String, dynamic> map) {
      final direct = _firstValue(map, [
        'selfie_url',
        'SELFIE_URL',
        'selfieUrl',
        'url',
        'URL',
        'image_url',
        'IMAGE_URL',
        'imageUrl',
        'photo_url',
        'PHOTO_URL',
        'photoUrl',
      ]);
      final normalizedDirect = _normalizeSelfieUrl(direct);
      if (normalizedDirect != null) {
        return normalizedDirect;
      }

      final selfieMap =
          _firstMapValue(map, ['selfie', 'SELFIE', 'photo', 'PHOTO']);
      if (selfieMap != null) {
        final nested = _firstValue(selfieMap, [
          'selfie_url',
          'SELFIE_URL',
          'selfieUrl',
          'url',
          'URL',
          'image_url',
          'IMAGE_URL',
          'imageUrl',
          'photo_url',
          'PHOTO_URL',
          'photoUrl',
        ]);
        return _normalizeSelfieUrl(nested);
      }
      return null;
    }

    final rootUrl = readFromMap(root);
    if (rootUrl != null) {
      return rootUrl;
    }

    if (data is String) {
      return _normalizeSelfieUrl(data);
    }

    if (data is Map) {
      return readFromMap(Map<String, dynamic>.from(data));
    }

    return null;
  }

  Future<String?> _fetchTripSelfieUrl(int tripId) async {
    final ub = Provider.of<UserProvider>(context, listen: false);
    final token = ub.token;
    if (token == null || token.isEmpty || tripId <= 0) {
      return null;
    }

    final uri = Uri.parse('${AppConfig.baseURL}trip/$tripId/selfie');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'x-app-type': 'oms',
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    try {
      final decoded = json.decode(response.body);
      return _extractSelfieUrlFromPayload(decoded);
    } catch (_) {
      return _normalizeSelfieUrl(response.body);
    }
  }

  Future<void> _showTripSelfieViewer(String imageUrl, int tripId) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('Trip $tripId Selfie'),
          ),
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (_, __, ___) {
                    return const Text(
                      'Unable to load selfie image',
                      style: TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTripSelfie(int tripId) async {
    if (tripId <= 0) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final selfieUrl = await _fetchTripSelfieUrl(tripId);

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (selfieUrl == null || selfieUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selfie not available for this trip')),
        );
        return;
      }

      await _showTripSelfieViewer(selfieUrl, tripId);
    } catch (e, stack) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'route_report_trip_selfie_fetch_failed',
        context: {'trip_id': tripId},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load trip selfie')),
      );
    }
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = const Color(0xFF1B1D2A),
    IconData? iconOverride,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconOverride ?? icon,
                  size: 16, color: const Color(0xFF7F8599)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Color(0xFF7F8599),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              height: 1.0,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripTile(Map<String, dynamic> trip) {
    final tripId = _tripIdFromMap(trip);
    final isActive = _tripActiveFromMap(trip);
    _ensureTripGapInfo(tripId);
    final gapInfo = _gapInfoByTripId[tripId];
    final distanceBreakdown = _distanceBreakdownByTripId[tripId];
    final start = _tripStartDateTimeFromMap(trip);
    final end = _tripEndDateTimeFromMap(trip);
    final userCode = _tripUserFromMap(trip);
    final userName = _tripUserNameFromMap(trip);
    final inGapText =
        gapInfo == null ? '-' : '${gapInfo['punchFormatted'] ?? '-'}';
    final outGapText =
        gapInfo == null ? '-' : '${gapInfo['outFormatted'] ?? '-'}';
    final transitKmText = distanceBreakdown == null
        ? '-'
        : '${distanceBreakdown['transitKm'] ?? '-'}';
    final businessKmText = distanceBreakdown == null
        ? '-'
        : '${distanceBreakdown['BUSINESS_KM'] ?? '-'}';
    return GestureDetector(
      onTap: () {
        CrashlyticsService.logAction(
          'route_report_trip_opened',
          context: {'trip_id': tripId},
        );
        Get.to(
          () => RouteMapView(
            initialTripId: tripId,
            initialTripDate: start ?? DateTime.now(),
            initialUserCode: userCode.trim(),
            initialUserName: userName.trim(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7E9F2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120C1A4B),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        _formatClock(start),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1D2A),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          CupertinoIcons.arrow_right,
                          size: 20,
                        ),
                      ),
                      Text(
                        _formatClock(end),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1D2A),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFFFF4E4)
                        : const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFFFE2B9)
                          : const Color(0xFFE1E4EE),
                    ),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'ENDED',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: isActive
                          ? const Color(0xFFB46A00)
                          : const Color(0xFF7B8195),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trip ID: $tripId',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B8195),
                  ),
                ),
                Text(
                  "View Details",
                  style: TextStyle(color: Color(0xff006709)),
                ),
                GestureDetector(
                  onTap: () => _openTripSelfie(tripId),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 15,
                          color: Color(0xff4c4c4c),
                        ),
                        Text(
                          'View Selfie',
                          style: TextStyle(color: Color(0xff4c4c4c)),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE6E8F1)),
            const SizedBox(height: 14),
            Row(
              children: [
                _metricTile(
                  icon: Icons.schedule,
                  label: 'DURATION',
                  value: _durationFromMap(trip),
                ),
                const SizedBox(width: 10),
                _metricTile(
                  icon: Icons.place_outlined,
                  label: 'DISTANCE',
                  value: _distanceKmFromMap(trip),
                ),
                const SizedBox(width: 10),
                _metricTile(
                  icon: CupertinoIcons.briefcase,
                  label: 'BUSINESS',
                  value: businessKmText,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _metricTile(
                  icon: Icons.login,
                  label: 'IN GAP',
                  value: inGapText,
                ),
                const SizedBox(width: 10),
                _metricTile(
                  icon: Icons.logout,
                  label: 'OUT GAP',
                  value: outGapText,
                ),
                const SizedBox(width: 10),
                _metricTile(
                  icon: Icons.alt_route,
                  label: 'TRANSIT',
                  value: transitKmText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsList() {
    final sortedTrips = [..._trips]..sort((a, b) {
        final aStart = _tripStartDateTimeFromMap(a);
        final bStart = _tripStartDateTimeFromMap(b);
        if (aStart == null && bStart == null) return 0;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        return bStart.compareTo(aStart);
      });

    final Map<String, List<Map<String, dynamic>>> grouped =
        <String, List<Map<String, dynamic>>>{};
    for (final trip in sortedTrips) {
      final key = _tripSectionKey(trip);
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(trip);
    }

    final entries = grouped.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: entries.length,
      itemBuilder: (context, sectionIndex) {
        final dayTrips = entries[sectionIndex].value;
        final firstTripStart = dayTrips.isNotEmpty
            ? _tripStartDateTimeFromMap(dayTrips.first)
            : null;

        return Padding(
          padding: EdgeInsets.only(top: sectionIndex == 0 ? 10 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatSectionDate(firstTripStart),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1D2A),
                        ),
                      ),
                    ),
                    Text(
                      '${dayTrips.length} ${dayTrips.length == 1 ? 'TRIP' : 'TRIPS'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Color(0xFF7F8599),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < dayTrips.length; i++) ...[
                _buildTripTile(dayTrips[i]),
                // if (i == dayTrips.length - 1) const SizedBox(height: 5),
              ],
            ],
          ),
        );
      },
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
      color: Color(0xFFF3F4FA),
      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   "Filter by User",
          //   style: TextStyle(
          //     fontSize: 14,
          //     fontWeight: FontWeight.bold,
          //   ),
          // ),
          // SizedBox(height: 5),
          UserSearchDropdown(
            users: _usersForDropdown,
            selectedUserCode: _selectedUserCode,
            loading: _loadingUsers,
            hint: "Select User",
            compact: true,
            onSearchQueryChanged: _onUserSearchQueryChanged,
            onChanged: (value) {
              final profileProvider =
                  Provider.of<ProfileProvider>(context, listen: false);
              CrashlyticsService.logAction(
                'route_report_user_filter_changed',
                context: {'selected_user_cd': value ?? ''},
              );
              setState(() {
                _selectedUserCode = value ?? '';
                _selectedUserName = value == ''
                    ? (profileProvider.userName?.trim().isNotEmpty ?? false)
                        ? profileProvider.userName!.trim()
                        : null
                    : _usersForDropdown.firstWhere(
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
        // ? '{_selectedUserName}\'s Route Report'
        ? "$_selectedUserName's Route Report"
        : 'Route Report';

    return Scaffold(
      appBar: CustomAppBar(
        title: title,
      ),
      backgroundColor: const Color(0xFFF3F4FA),
      floatingActionButton: null,
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
                    : _buildTripsList(),
          ),
        ],
      ),
    );
  }
}
