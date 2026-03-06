import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:arham_corporation/services/sync_service.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final SyncService _syncService = SyncService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasOffline = false;
  bool _isSyncing = false;

  void initialize(BuildContext context) {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        if (!results.contains(ConnectivityResult.none)) {
          // Network interface available — verify real internet before syncing
          if (_wasOffline && !_isSyncing) {
            // Double-check with actual internet ping
            final hasNet = await NetworkHelper.hasInternet();
            if (hasNet) {
              await _syncPendingOrders(context);
              _wasOffline = false;
            }
          }
        } else {
          _wasOffline = true;
        }
      },
    );

    // Check initial connectivity
    _connectivity.checkConnectivity().then((results) {
      _wasOffline = results.contains(ConnectivityResult.none);
    });
  }

  Future<void> _syncPendingOrders(BuildContext context) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.token != null && userProvider.token!.isNotEmpty) {
        print(
            "[ConnectivityService] 🟢 INTERNET RESTORED - Starting auto-sync...");

        // Sync pending cart items first
        final cartResult =
            await _syncService.syncCartToServer(userProvider.token!);
        print("[ConnectivityService] ✅ Cart: $cartResult items synced");

        // Sync pending orders
        final result = await _syncService.syncOrders(userProvider.token!);
        print(
            "[ConnectivityService] ✅ Orders: ${result['synced']} synced, ${result['failed']} failed");

        // Sync pending location data (punch-in/punch-out)
        final locationResult =
            await _syncService.syncLocations(userProvider.token!);
        print(
            "[ConnectivityService] ✅ Locations: ${locationResult['synced']} synced, ${locationResult['failed']} failed");

        // Sync pending order tracking data (start/end order)
        final trackingResult =
            await _syncService.syncOrderTrackings(userProvider.token!);
        print(
            "[ConnectivityService] ✅ Order Tracking: ${trackingResult['synced']} synced, ${trackingResult['failed']} failed");

        if ((result['synced'] ?? 0) > 0 ||
            (locationResult['synced'] ?? 0) > 0 ||
            (trackingResult['synced'] ?? 0) > 0) {
          print(
              "[ConnectivityService] 🎉 All offline data synced successfully!");
        }
      }
    } catch (e) {
      print("[ConnectivityService] ❌ Auto-sync failed: $e");
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
