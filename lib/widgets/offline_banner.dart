import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:arham_corporation/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({Key? key}) : super(key: key);

  @override
  _OfflineBannerState createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  int _pendingOrdersCount = 0;
  int _failedOrdersCount = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkPendingOrders();
  }

  Future<void> _checkPendingOrders() async {
    try {
      final pendingOrders = await DatabaseHelper().getPendingOrders();
      final failedOrders = pendingOrders
          .where((order) => (order['sync_attempts'] as int? ?? 0) > 0)
          .toList();

      if (mounted) {
        setState(() {
          _pendingOrdersCount = pendingOrders.length;
          _failedOrdersCount = failedOrders.length;
        });
      }
    } catch (e) {
      print('[OfflineBanner] Error checking pending orders: $e');
    }
  }

  Future<void> _syncOrders() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.token != null) {
        final result = await SyncService().syncOrders(userProvider.token!);
        await _checkPendingOrders(); // Refresh count

        if (mounted) {
          final msg = result['synced'] == 0 &&
                  result['failed'] == 0 &&
                  result['skipped'] == 0
              ? 'No pending orders to sync'
              : 'Synced: ${result['synced']}, Failed: ${result['failed']}, Skipped: ${result['skipped']}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), duration: Duration(seconds: 3)),
          );
        }
      }
    } catch (e) {
      print("[OfflineBanner] Manual sync failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sync failed: $e'), duration: Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingOrdersCount == 0) {
      return SizedBox.shrink();
    }

    String message;
    Color bannerColor;

    if (_failedOrdersCount > 0) {
      message =
          '$_pendingOrdersCount order(s) pending sync ($_failedOrdersCount failed)';
      bannerColor = Colors.red.shade100;
    } else {
      message = '$_pendingOrdersCount order(s) pending sync';
      bannerColor = Colors.orange.shade100;
    }

    return Container(
      color: bannerColor,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(_failedOrdersCount > 0 ? Icons.error : Icons.cloud_off,
              color: _failedOrdersCount > 0
                  ? Colors.red.shade800
                  : Colors.orange.shade800),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: _failedOrdersCount > 0
                      ? Colors.red.shade800
                      : Colors.orange.shade800),
            ),
          ),
          _isSyncing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _failedOrdersCount > 0
                            ? Colors.red.shade800
                            : Colors.orange.shade800),
                  ),
                )
              : TextButton(
                  onPressed: _syncOrders,
                  child: Text(
                    'SYNC NOW',
                    style: TextStyle(
                        color: _failedOrdersCount > 0
                            ? Colors.red.shade800
                            : Colors.orange.shade800,
                        fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
    );
  }
}
