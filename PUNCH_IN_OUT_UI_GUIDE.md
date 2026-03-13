# Quick Integration Guide - Punch In/Out UI

This guide shows how to integrate the new employee route tracking system into your Flutter UI.

## Basic Example

### Simple Punch In Button

```dart
import 'package:arham_corporation/services/location_service.dart';
import 'package:flutter/material.dart';

class PunchInOutPage extends StatefulWidget {
  @override
  State<PunchInOutPage> createState() => _PunchInOutPageState();
}

class _PunchInOutPageState extends State<PunchInOutPage> {
  final LocationService _locationService = LocationService();
  bool _isTracking = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Check if tracking is already active on app start
    _isTracking = _locationService.isTrackingActive();
  }

  Future<void> _handlePunchIn() async {
    setState(() => _isLoading = true);

    try {
      final result = await _locationService.punchIn(
        userCd: 'EMP001', // Get from UserProvider
        syncId: 1,        // Get from UserProvider
        token: 'auth_token', // Get from UserProvider
        vouchDt: DateTime.now().toString().split(' ')[0],
        vouchTime: DateTime.now().toString().split(' ')[1],
        moduleNo: '203',
        createdBy: 'EMP001',
        remark: 'Start of day route tracking',
      );

      setState(() => _isTracking = result['tracking_started'] ?? false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Punch In successful'),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

      if (!result['success']) {
        print('[UI] Punch In Error: ${result['error']}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to punch in: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePunchOut() async {
    setState(() => _isLoading = true);

    try {
      final result = await _locationService.punchOut(
        userCd: 'EMP001',
        syncId: 1,
        token: 'auth_token',
        vouchDt: DateTime.now().toString().split(' ')[0],
        vouchTime: DateTime.now().toString().split(' ')[1],
        moduleNo: '203',
        createdBy: 'EMP001',
        remark: 'End of day',
      );

      setState(() => _isTracking = false);

      // Show sync results
      if (result['sync_stats'] != null) {
        final stats = result['sync_stats'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Punch Out: ${stats['total_synced']} locations synced',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Punch Out successful'),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to punch out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Punch In/Out')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _isTracking ? 'Tracking Active' : 'Tracking Inactive',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isTracking ? Colors.green : Colors.grey,
                      ),
                    ),
                    SizedBox(height: 16),
                    if (!_isTracking)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handlePunchIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: Text(
                          'PUNCH IN',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handlePunchOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: Text(
                          'PUNCH OUT',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    if (_isLoading)
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Using with UserProvider

For better integration with your existing UserProvider:

```dart
import 'package:provider/provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/location_service.dart';

class PunchControlWidget extends StatefulWidget {
  @override
  State<PunchControlWidget> createState() => _PunchControlWidgetState();
}

class _PunchControlWidgetState extends State<PunchControlWidget> {
  final LocationService _locationService = LocationService();
  bool _isLoading = false;

  Future<void> _doPunchIn(UserProvider userProvider) async {
    if (userProvider.token == null || userProvider.token!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final result = await _locationService.punchIn(
        userCd: userProvider.userCode ?? '',
        syncId: int.tryParse(userProvider.syncId ?? '0') ?? 0,
        token: userProvider.token!,
        vouchDt: now.toIso8601String().split('T')[0],
        vouchTime: now.toIso8601String().split('T')[1].split('.')[0],
        moduleNo: '203',
        createdBy: userProvider.userCode ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Punch In successful'),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Punch In failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _doPunchOut(UserProvider userProvider) async {
    if (userProvider.token == null || userProvider.token!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final result = await _locationService.punchOut(
        userCd: userProvider.userCode ?? '',
        syncId: int.tryParse(userProvider.syncId ?? '0') ?? 0,
        token: userProvider.token!,
        vouchDt: now.toIso8601String().split('T')[0],
        vouchTime: now.toIso8601String().split('T')[1].split('.')[0],
        moduleNo: '203',
        createdBy: userProvider.userCode ?? '',
      );

      if (mounted) {
        // Show sync summary
        if (result['sync_stats'] != null) {
          final stats = result['sync_stats'];
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Punch Out Summary'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location tracking data synced:'),
                  Text('  • ${stats['total_synced']} locations synced'),
                  Text('  • ${stats['total_failed']} locations failed'),
                  SizedBox(height: 12),
                  Text('Breakdown:'),
                  Text('  • ${stats['tracking_synced']} GPS tracking records'),
                  Text('  • ${stats['punch_synced']} punch records'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Punch Out successful'),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Punch Out failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final isTracking = _locationService.isTrackingActive();

        return Column(
          children: [
            Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Route Tracking',
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 8),
                            Text(
                              isTracking ? '🟢 Active' : '⚫ Inactive',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isTracking ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if (!isTracking)
                          ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _doPunchIn(userProvider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: Text('PUNCH IN'),
                          )
                        else
                          ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _doPunchOut(userProvider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: Text('PUNCH OUT'),
                          ),
                      ],
                    ),
                    if (_isLoading)
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
```

## With Statistics Display

Show user how much location data has been collected and synced:

```dart
class LocationTrackingStats extends StatefulWidget {
  @override
  State<LocationTrackingStats> createState() => _LocationTrackingStatsState();
}

class _LocationTrackingStatsState extends State<LocationTrackingStats> {
  final LocationService _locationService = LocationService();
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Refresh stats every 30 seconds while tracking
    _updateTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _locationService.getTrackingStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final stats = snapshot.data!;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Data',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatTile(
                      label: 'Total',
                      value: stats['tracking_total'] ?? 0,
                    ),
                    _StatTile(
                      label: 'Synced',
                      value: stats['tracking_synced'] ?? 0,
                      color: Colors.green,
                    ),
                    _StatTile(
                      label: 'Pending',
                      value: stats['tracking_unsynced'] ?? 0,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
```

## Error Handling in UI

Best practice for handling errors gracefully:

```dart
Future<void> _handlePunchWithErrorHandling(UserProvider userProvider) async {
  try {
    final now = DateTime.now();
    final result = await _locationService.punchIn(
      userCd: userProvider.userCode ?? '',
      syncId: int.tryParse(userProvider.syncId ?? '0') ?? 0,
      token: userProvider.token!,
      vouchDt: now.toIso8601String().split('T')[0],
      vouchTime: now.toIso8601String().split('T')[1].split('.')[0],
      moduleNo: '203',
      createdBy: userProvider.userCode ?? '',
    );

    if (!result['success']) {
      // Handle specific error cases
      final error = result['error']?.toString() ?? 'Unknown error';

      if (error.contains('internet') || error.contains('offline')) {
        _showErrorDialog(
          'No Internet',
          'Punch In requires an active internet connection.\n\nPlease check your network and try again.',
        );
      } else if (error.contains('permission') || error.contains('location')) {
        _showErrorDialog(
          'Location Permission Denied',
          'This app needs location permission to punch in.\n\nPlease enable location in settings.',
          actions: [
            TextButton(
              onPressed: () => openAppSettings(),
              child: Text('OPEN SETTINGS'),
            ),
          ],
        );
      } else {
        _showErrorDialog('Punch In Failed', error);
      }
      return;
    }

    if (result['tracking_started'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Punch recorded but background tracking failed. '
            'Please check location permissions.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Punch In successful. Route tracking started.'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    _showErrorDialog('Error', 'Failed to punch in: $e');
  }
}

void _showErrorDialog(
  String title,
  String message, {
  List<Widget> actions = const [],
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        ...actions,
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

## Integration in Existing Screen

If you have an existing attendance or dashboard screen:

```dart
class DashboardPage extends StatefulWidget {
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: ListView(
        children: [
          // Your existing widgets...

          // Add punch control
          PunchControlWidget(),

          // Add tracking stats
          LocationTrackingStats(),

          // Your other widgets...
        ],
      ),
    );
  }
}
```

## Testing the Integration

Test checklist for your UI:

1. Punch In Button:
   - [ ] Shows when offline → Displays error message
   - [ ] Shows when online → Punch succeeds, button changes to Punch Out
   - [ ] Loading state shows during operation
   - [ ] Success message displayed

2. Punch Out Button:
   - [ ] Shows when tracking is active
   - [ ] Shows offline error if no internet
   - [ ] Shows sync summary with location counts
   - [ ] Button changes back to Punch In after success

3. Tracking Stats:
   - [ ] Updates every 30 seconds while tracking
   - [ ] Shows correct location count
   - [ ] Shows pending vs synced count

4. Error Cases:
   - [ ] No internet → User-friendly error message
   - [ ] Permission denied → Suggests enabling in settings
   - [ ] Service failure → User knows what went wrong

Happy integrating! 🚀
