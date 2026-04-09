import 'dart:convert';

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
  GoogleMapController? _mapController;
  static const LatLng _defaultCenter = LatLng(23.0225, 72.5714);

  // Users state
  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = false;
  String? _usersError;

  // Selected user and timeline state
  Map<String, dynamic>? _selectedUser;
  List<Map<String, String>> _timelineData = [];
  bool _loadingTimeline = false;
  DateTime _selectedTimelineDate = DateTime.now();

  // Search state
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUsers();
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
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
      final uri = Uri.parse('${AppConfig.baseURL}users/children');
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

        // Map users with initial data
        List<Map<String, dynamic>> usersWithData =
            List<Map<String, dynamic>>.from(
          usersList.map((user) {
            final userCode = user['USER_CD'] ?? '';
            final userName = (user['USER_NAME'] ?? '').trim();
            final phone = (user['MOBILENO'] ?? '').trim();
            final photoUrl = (user['PHOTO_URL'] ?? '').trim();
            final status = (user['STATUS'] ?? 'active').trim().toLowerCase();
            return {
              'userCode': userCode,
              'userName': userName,
              'phone': phone,
              'photoUrl': photoUrl,
              'status': status,
              'punchInTime': '', // Will be populated by trip fetch
            };
          }),
        );

        // Set users data and fetch punch-in times from latest trips
        setState(() {
          _users = usersWithData;
        });

        // Fetch latest trip for each user to get punch-in time
        final ub = Provider.of<UserProvider>(context, listen: false);
        final token = ub.token;
        for (var user in _users) {
          _fetchLatestTripForUser(user['userCode'], token);
        }

        setState(() {
          _loadingUsers = false;
        });
      } else {
        setState(() {
          _users = [];
          _loadingUsers = false;
          _usersError = 'Failed to load users: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _users = [];
        _loadingUsers = false;
        _usersError = 'Error: $e';
      });
      print('[RouteMapView] Error fetching users: $e');
    }
  }

  Future<void> _fetchTimelineForUser(String userCode, DateTime date) async {
    setState(() {
      _loadingTimeline = true;
    });
    try {
      // Format date as YYYY-MM-DD
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // TODO: Replace with actual API endpoint when available
      // For now, using static data as placeholder
      print(
          '[RouteMapView] Fetching timeline for user: $userCode, date: $dateStr');

      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Static data for now - will be replaced with API call
      setState(() {
        _timelineData = [
          {
            "date": "Apr 09",
            "time": "10:30 AM",
            "title": "Nevil Pharma",
            "subtitle": "Visited client",
          },
          {
            "date": "Apr 09",
            "time": "01:15 PM",
            "title": "Nevil Pharma",
            "subtitle": "Meeting done",
          },
          {
            "date": "Apr 09",
            "time": "04:45 PM",
            "title": "Nevil Pharma",
            "subtitle": "Follow-up activity",
          },
        ];
        _loadingTimeline = false;
      });
    } catch (e) {
      setState(() {
        _timelineData = [];
        _loadingTimeline = false;
      });
      print('[RouteMapView] Error fetching timeline: $e');
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUser = user;
      _selectedTimelineDate = DateTime.now();
    });
    _fetchTimelineForUser(user['userCode'], DateTime.now());
  }

  void _clearSelectedUser() {
    setState(() {
      _selectedUser = null;
      _timelineData = [];
    });
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
        _fetchTimelineForUser(_selectedUser!['userCode'], picked);
      }
    }
  }

  void _callUser(String phoneNumber) {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    launchUrl(uri).catchError((e) {
      print('[RouteMapView] Error launching call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch call')),
      );
    });
  }

  Future<void> _fetchLatestTripForUser(String userCode, String? token) async {
    if (userCode.isEmpty || token == null || token.isEmpty) {
      return;
    }
    try {
      // Fetch trips only for today
      final now = DateTime.now();
      final todayDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final uri = Uri.parse('${AppConfig.baseURL}location/trip').replace(
        queryParameters: {
          'fromDate': todayDate,
          'toDate': todayDate,
          'user_cd': userCode,
        },
      );

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

        if (trips.isNotEmpty) {
          // Get the most recent trip (first in the list)
          final latestTrip = trips.first;
          final startTime = latestTrip['start_time'] ??
              latestTrip['START_TIME'] ??
              latestTrip['started_at'] ??
              latestTrip['STARTED_AT'] ??
              '';

          // Update the user's punchInTime
          setState(() {
            final userIndex =
                _users.indexWhere((u) => u['userCode'] == userCode);
            if (userIndex >= 0) {
              _users[userIndex]['punchInTime'] = startTime;
            }
          });

          print('[RouteMapView] Fetched today\'s trip for $userCode: startTime="$startTime"');
        } else {
          print('[RouteMapView] No trips today for $userCode - marking as absent');
          // Explicitly set punchInTime to empty if no trips today
          setState(() {
            final userIndex =
                _users.indexWhere((u) => u['userCode'] == userCode);
            if (userIndex >= 0) {
              _users[userIndex]['punchInTime'] = '';
            }
          });
        }
      }
    } catch (e) {
      print('[RouteMapView] Error fetching today\'s trip for $userCode: $e');
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

  List<Map<String, dynamic>> _getFilteredUsers() {
    if (_searchQuery.isEmpty) {
      return _users;
    }
    return _users
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

            // Bottom Sheet (Foreground - anchored at bottom)
            Align(
              alignment: Alignment.bottomCenter,
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: _isSearching ? 0.45 : 0.35,
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        _searchQuery = '';
                      }
                    });
                  },
                  icon: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    color: Colors.black,
                  ),
                ),
                if (filteredUsers.isNotEmpty)
                  Chip(
                    label: Text('${filteredUsers.length}'),
                    backgroundColor: Colors.blue.withOpacity(0.2),
                  ),
              ],
            ),
          ),
          // Search Bar (shown when searching)
          if (_isSearching)
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
                autofocus: true,
              ),
            ),
          const Divider(),
          // Users List
          Expanded(
            child: _buildUsersList(scrollController, filteredUsers),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(
    ScrollController scrollController,
    List<Map<String, dynamic>> users,
  ) {
    if (_loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_usersError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_usersError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Text('No child users found'),
      );
    }

    if (users.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Text('No users found for "$_searchQuery"'),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final punchInTimeStr = user['punchInTime']?.toString().trim() ?? '';
    final isAbsent = punchInTimeStr.isEmpty || 
        punchInTimeStr == 'null' || 
        punchInTimeStr.toLowerCase() == 'null';
    final timeAgo = isAbsent ? 'Absent' : _calculateTimeAgo(punchInTimeStr);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        onTap: () => _selectUser(user),
        leading: CircleAvatar(
          backgroundImage: user['photoUrl'].toString().isNotEmpty
              ? NetworkImage(user['photoUrl'])
              : null,
          child: user['photoUrl'].toString().isEmpty
              ? Text(user['userName'][0].toUpperCase())
              : null,
        ),
        title: Text(user['userName']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['phone']),
            Text(
              isAbsent ? 'Absent' : 'Punched in $timeAgo',
              style: TextStyle(
                color: isAbsent ? Colors.red : Colors.green,
                fontWeight: isAbsent ? FontWeight.bold : FontWeight.normal,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button and date picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage:
                      _selectedUser?['photoUrl'].toString().isNotEmpty == true
                          ? NetworkImage(_selectedUser!['photoUrl'])
                          : null,
                  child: _selectedUser?['photoUrl'].toString().isEmpty == true
                      ? Text(_selectedUser!['userName'][0].toUpperCase())
                      : null,
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
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelectedUser,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          // Timeline List
          Expanded(
            child: _loadingTimeline
                ? const Center(child: CircularProgressIndicator())
                : _timelineData.isEmpty
                    ? const Center(
                        child: Text('No activities for this date'),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _timelineData.length,
                        itemBuilder: (context, index) {
                          final item = _timelineData[index];
                          return CommonTimelineTile(
                            date: item["date"]!,
                            time: item["time"]!,
                            title: item["title"]!,
                            subtitle: item["subtitle"]!,
                            isFirst: index == 0,
                            isLast: index == _timelineData.length - 1,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
