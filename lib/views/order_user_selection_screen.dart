import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'orderReportScreen.dart';

class OrderUserSelectionScreen extends StatefulWidget {
  const OrderUserSelectionScreen({
    super.key,
  });

  @override
  State<OrderUserSelectionScreen> createState() =>
      _OrderUserSelectionScreenState();
}

class _OrderUserSelectionScreenState extends State<OrderUserSelectionScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrdersAndExtractUsers();
    });
  }

  Future<void> _fetchOrdersAndExtractUsers() async {
    final ub = Provider.of<UserProvider>(context, listen: false);
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    final party = Provider.of<PartyProvider>(context, listen: false);
    final token = ub.token;

    print(
        '[OrderUserSelectionScreen] 🔍 Starting fetch to extract users from orders');
    print('[OrderUserSelectionScreen] Party ID: ${party.partyid}');
    print('[OrderUserSelectionScreen] Current User Code: ${profile.userCode}');

    if (token == null || token.isEmpty) {
      print('[OrderUserSelectionScreen] ❌ Token is missing or empty');
      setState(() {
        _error = 'Missing auth token';
        _loading = false;
      });
      return;
    }

    try {
      // Get date range - use a wider range (90 days) to capture all child users' orders
      final now = DateTime.now();
      final fromDate = now.subtract(const Duration(days: 90));
      final toDate = now;

      final fromDateStr =
          Helper.toApi(DateFormat("yyyy-MM-dd").format(fromDate));
      final toDateStr = Helper.toApi(DateFormat("yyyy-MM-dd").format(toDate));

      print(
          '[OrderUserSelectionScreen] 📅 Using date range: $fromDateStr to $toDateStr (90 days)');

      // Build query string - empty partycd should still work to get all orders
      String queryString =
          "fromDate=$fromDateStr&toDate=$toDateStr&filterOrderType=1";
      if (party.partyid.isNotEmpty) {
        queryString = "partyCd=${party.partyid}&$queryString";
      }

      final uri = Uri.parse('${AppConfig.baseURLReport}orders?$queryString');
      print('[OrderUserSelectionScreen] 📡 Fetching from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      ).timeout(const Duration(seconds: 10));

      print(
          '[OrderUserSelectionScreen] 📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded['data'];

        print(
            '[OrderUserSelectionScreen] ✅ Decoded data type: ${data.runtimeType}');
        print(
            '[OrderUserSelectionScreen] 📊 Response body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

        if (data is List && data.isNotEmpty) {
          // Log first order to see structure
          if (data.isNotEmpty) {
            print(
                '[OrderUserSelectionScreen] 🔍 First order data: ${json.encode(data[0])}');
          }

          // Extract unique users from orders
          final userMap = <String, Map<String, dynamic>>{};

          for (final order in data) {
            // Try multiple field name variations
            final userCd = order['USER_CD'] ??
                order['user_cd'] ??
                order['userCd'] ??
                order['USERCD'];

            // Check nested usermast object for user name
            String? userName =
                order['USER_NAME'] ?? order['user_name'] ?? order['userName'];

            // If not found at top level, check nested usermast object
            if ((userName == null || userName == 'Unknown') &&
                order['usermast'] is Map) {
              final usermast = order['usermast'] as Map;
              userName = usermast['USER_NAME'] ?? usermast['user_name'];
            }

            final userType = order['USER_TYPE'] ??
                order['user_type'] ??
                order['USERTYPE'] ??
                'O';

            final mobileNo =
                order['MOBILENO'] ?? order['mobileno'] ?? order['MOBNO'] ?? '';

            print(
                '[OrderUserSelectionScreen] 📋 Order - userCd: $userCd, userName: $userName');

            if (userCd != null && userCd.toString().isNotEmpty) {
              final key = userCd.toString();
              if (!userMap.containsKey(key)) {
                userMap[key] = {
                  'USER_CD': key,
                  'USER_NAME': userName?.toString() ?? 'Unknown User',
                  'USER_TYPE': userType,
                  'MOBILENO': mobileNo?.toString() ?? '',
                  'isSelf': false,
                };
                print(
                    '[OrderUserSelectionScreen] ✅ Added user: $key - ${userName}');
              }
            }
          }

          // Get current user and mark as self
          final currentUserCd = profile.userCode?.trim() ?? '';
          if (currentUserCd.isNotEmpty && userMap.containsKey(currentUserCd)) {
            userMap[currentUserCd]!['isSelf'] = true;
            print(
                '[OrderUserSelectionScreen] 🔖 Marked ${userMap[currentUserCd]!['USER_NAME']} as self');
          }

          // Convert to list, sort with self first
          List<Map<String, dynamic>> users = userMap.values.toList();
          users.sort((a, b) {
            if (a['isSelf'] == true) return -1;
            if (b['isSelf'] == true) return 1;
            return (a['USER_NAME'] as String)
                .compareTo(b['USER_NAME'] as String);
          });

          print(
              '[OrderUserSelectionScreen] ✅ Successfully extracted ${users.length} unique users:');
          for (int i = 0; i < users.length; i++) {
            final user = users[i];
            print(
                '[OrderUserSelectionScreen] 👤 User[$i]: ${user['USER_NAME']} (CD: ${user['USER_CD']}, isSelf: ${user['isSelf']})');
          }

          setState(() {
            _users = users;
            _loading = false;
          });
        } else {
          print(
              '[OrderUserSelectionScreen] ⚠️ No orders found or data is not a list');
          setState(() {
            _users = [];
            _error = 'No users found with orders in this date range';
            _loading = false;
          });
        }
      } else {
        print(
            '[OrderUserSelectionScreen] ❌ API returned status ${response.statusCode}');
        setState(() {
          _error = 'Failed to fetch orders: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      print('[OrderUserSelectionScreen] ❌ Exception: $e');
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
        title: 'Select User for Order Report',
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
                  _fetchOrdersAndExtractUsers();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Text('No users found with orders'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final userName = user['USER_NAME'] ?? 'Unknown';
        final userCd = user['USER_CD'] ?? '';
        final userType = user['USER_TYPE'] ?? '';
        final mobileNo = user['MOBILENO'] ?? '';
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
                if (mobileNo.isNotEmpty) Text('Mobile: $mobileNo'),
                Text(
                  'Type: ${userType == 'M' ? 'Master' : 'Operator'}',
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Get.to(
                () => OrderReportScreen(
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
}
