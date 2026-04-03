import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'route_report_screen.dart';

class UserSelectionScreen extends StatefulWidget {
  final bool isMasterUser;

  const UserSelectionScreen({
    super.key,
    this.isMasterUser = false,
  });

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  List<Map<String, dynamic>> _childUsers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchChildUsers();
    });
  }

  Future<void> _fetchChildUsers() async {
    final ub = Provider.of<UserProvider>(context, listen: false);
    final token = ub.token;
    final role = ub.role;

    print(
        '[UserSelectionScreen] 🔍 Starting fetch - isMasterUser=${widget.isMasterUser}, role=$role');

    if (token == null || token.isEmpty) {
      print('[UserSelectionScreen] ❌ Token is missing or empty');
      setState(() {
        _error = 'Missing auth token';
        _loading = false;
      });
      return;
    }

    try {
      final uri = Uri.parse('${AppConfig.baseURL}users/children');
      print('[UserSelectionScreen] 📡 Fetching from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      ).timeout(const Duration(seconds: 10));

      print('[UserSelectionScreen] 📥 Response Status: ${response.statusCode}');
      print(
          '[UserSelectionScreen] 📋 Response Body Length: ${response.body.length} chars');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded['data'];

        print('[UserSelectionScreen] ✅ Decoded data type: ${data.runtimeType}');
        print(
            '[UserSelectionScreen] 📊 Total users in response: ${data is List ? data.length : "Not a list"}');

        if (data is List) {
          // Log each user
          for (int i = 0; i < data.length; i++) {
            final user = data[i];
            print(
                '[UserSelectionScreen] 👤 User[$i]: ${user['USER_NAME']} (CD: ${user['USER_CD']}, Parent: ${user['PARENT_USER']}, isSelf: ${user['isSelf']})');
          }

          // FRONTEND FILTERING: Only show children if not master user
          List<Map<String, dynamic>> filteredUsers = [];
          Map<String, dynamic>? selfUser;

          if (widget.isMasterUser) {
            // Master users see all users
            final allUsers = data.cast<Map<String, dynamic>>().toList();

            // Extract self user
            selfUser = allUsers.firstWhere((user) => user['isSelf'] == true,
                orElse: () => {});

            // Add self first if found
            if (selfUser.isNotEmpty) {
              filteredUsers.add(selfUser);
              print(
                  '[UserSelectionScreen] ➕ Added self at top: ${selfUser['USER_NAME']}');
            }

            // Add all other users
            final otherUsers =
                allUsers.where((user) => user['isSelf'] != true).toList();
            filteredUsers.addAll(otherUsers);

            print(
                '[UserSelectionScreen] 👑 Master mode: showing ${filteredUsers.length} total users (self at top)');
          } else {
            // Parent operators see themselves + their direct children
            final allUsers = data.cast<Map<String, dynamic>>().toList();

            // Find current user to get their code
            selfUser = allUsers.firstWhere((user) => user['isSelf'] == true,
                orElse: () => {});

            if (selfUser.isEmpty) {
              print(
                  '[UserSelectionScreen] ⚠️ Could not find current user in response');
              filteredUsers = allUsers;
            } else {
              final currentUserCode = selfUser['USER_CD'];
              print(
                  '[UserSelectionScreen] 👤 Current operator code: $currentUserCode');

              // Add self first
              filteredUsers.add(selfUser);
              print(
                  '[UserSelectionScreen] ➕ Added self at top: ${selfUser['USER_NAME']}');

              // Then add users where PARENT_USER matches current user
              final children = allUsers
                  .where((user) => user['PARENT_USER'] == currentUserCode)
                  .toList();

              filteredUsers.addAll(children);

              print(
                  '[UserSelectionScreen] 🔗 Added ${children.length} direct children');
              for (int i = 0; i < children.length; i++) {
                final user = children[i];
                print(
                    '[UserSelectionScreen] 👶 Child[$i]: ${user['USER_NAME']} (CD: ${user['USER_CD']})');
              }
            }
          }

          setState(() {
            _childUsers = filteredUsers;
            _loading = false;
          });
          print(
              '[UserSelectionScreen] ✅ Successfully loaded ${_childUsers.length} users to display');
        } else {
          print(
              '[UserSelectionScreen] ❌ Data is not a list: ${data.runtimeType}');
          setState(() {
            _error = 'Invalid response format';
            _loading = false;
          });
        }
      } else {
        print(
            '[UserSelectionScreen] ❌ API returned status ${response.statusCode}');
        setState(() {
          _error = 'Failed to fetch users: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      print('[UserSelectionScreen] ❌ Exception: $e');
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Select User',
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _fetchChildUsers();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_childUsers.isEmpty) {
      return const Center(
        child: Text('No users found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _childUsers.length,
      itemBuilder: (context, index) {
        final user = _childUsers[index];
        final userName = user['USER_NAME'] ?? 'Unknown';
        final userCd = user['USER_CD'] ?? '';
        final userType = user['USER_TYPE'] ?? '';
        final mobileNo = user['MOBILENO'] ?? '';
        final tripStatus = user['tripStatus'] ?? 'unknown';
        final isSelf = user['isSelf'] == true;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                userName[0].toUpperCase(),
              ),
            ),
            title: Text(
              '$userName ${isSelf ? "(You)" : ""}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelf ? Colors.blue : Colors.black,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User CD: $userCd'),
                Text('Mobile: $mobileNo'),
                Text(
                  'Type: ${userType == 'M' ? 'Master' : 'Operator'}',
                  style: TextStyle(
                    color: _getTripStatusColor(tripStatus),
                  ),
                ),
                Text(
                  'Trip Status: ${tripStatus.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getTripStatusColor(tripStatus),
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Get.to(
                () => RouteReportScreen(
                  selectedUserCd: userCd,
                  selectedUserName: userName,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _getTripStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'active':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
