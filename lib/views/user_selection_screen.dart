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
  const UserSelectionScreen({super.key});

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

    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Missing auth token';
        _loading = false;
      });
      return;
    }

    try {
      final uri = Uri.parse('${AppConfig.baseURL}users/children');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded['data'];

        if (data is List) {
          setState(() {
            _childUsers = data.cast<Map<String, dynamic>>().toList();
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'Invalid response format';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to fetch users: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
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
