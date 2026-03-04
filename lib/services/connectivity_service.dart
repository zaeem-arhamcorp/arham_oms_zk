import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:arham_corporation/services/sync_service.dart';
import 'package:arham_corporation/providers/user_provider.dart';
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

  void initialize(BuildContext context) {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
          (List<ConnectivityResult> results) async {

        if (!results.contains(ConnectivityResult.none)) {
          // We have connectivity
          if (_wasOffline) {
            await _syncPendingOrders(context);
            _wasOffline = false;
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
    // _connectivity.checkConnectivity().then((result) {
    //   _wasOffline = result == ConnectivityResult.none;
    // });
  }

  Future<void> _syncPendingOrders(BuildContext context) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.token != null && userProvider.token!.isNotEmpty) {
        await _syncService.syncOrders(userProvider.token!);
        print("Auto-synced pending orders on connectivity restore");
      }
    } catch (e) {
      print("Failed to auto-sync orders: $e");
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
