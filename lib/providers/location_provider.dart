import 'dart:async';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import 'package:provider/provider.dart';

import '../services/location_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class LocationProvider extends ChangeNotifier {
  Timer? timer;
  var remarks;
  var isLoading = false;

  void setRemarks(val) {
    isLoading = true;
    remarks = val;
    notifyListeners();
  }

  start1(BuildContext context) {
    //final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    checkServiceEnable1(context);
    if (timer != null && timer!.isActive) {
      timer!.cancel();
      timer = Timer.periodic(Duration(minutes: 15), (Timer t) {
        checkServiceEnable1(context);
      });
    } else {
      timer = Timer.periodic(Duration(minutes: 15), (Timer t) {
        checkServiceEnable1(context);
      });
    }
  }

  start(UserProvider ub) {
    checkServiceEnable(ub);

    timer?.cancel();
    timer = Timer.periodic(const Duration(minutes: 15), (Timer t) {
      checkServiceEnable(ub);
    });
  }

  double lat = 0.0;
  double lag = 0.0;
  bool enebleLocationPermission = true;

  void emptyLocation() {
    lat = 0.00000000;
    lag = 0.00000000;
    notifyListeners();
  }

  checkServiceEnable1(BuildContext context) async {
    final UserProvider ub = Provider.of<UserProvider>(context,
        listen: false); // Get UserProvider here
    determinePosition().then((_) {
      emptyLocation();
      getCurrentLocation().then((__) {
        sendLocation(ub); // Pass ub directly
      });
    }).catchError((err) {
      isLoading = false;
      // Fluttertoast.showToast(
      //   msg: "Please Enable Location Permission",
      //   toastLength: Toast.LENGTH_LONG,
      // );
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please Enable Location Permission');
      notifyListeners();
    });
  }

  checkServiceEnable(UserProvider ub) async {
    determinePosition().then((_) {
      emptyLocation();
      getCurrentLocation().then((__) {
        sendLocation(ub);
      });
    }).catchError((err) {
      isLoading = false;
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Please Enable Location Permission',
      );
      notifyListeners();
    });
  }

  changeLocationStatus(val) {
    enebleLocationPermission = val;
    // notifyListeners();
  }

  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      notifyListeners();
      enebleLocationPermission = false;
      return Future.error('Location services are disabled.');
    } else {
      await Geolocator.requestPermission();
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      enebleLocationPermission = false;
      permission = await Geolocator.requestPermission();
      // LoadingLocation = false;
      if (permission == LocationPermission.denied) {
        // LoadingLocation = false;
        enebleLocationPermission = false;
        return Future.error('Location permissions are denied');
      }
    } else {
      enebleLocationPermission = true;
      notifyListeners();
    }

    if (permission == LocationPermission.deniedForever) {
      // LoadingLocation = false;
      enebleLocationPermission = false;

      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    notifyListeners();
    //return await Geolocator.getCurrentPosition();
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      //timeLimit: Duration(seconds: 10),
    );
  }

  Future getCurrentLocation() async {
    await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      //timeLimit: Duration(seconds: 10),
    ).then((Position position) async {
      lat = position.latitude;
      lag = position.longitude;
      enebleLocationPermission = true;
    }).catchError((e) {
      // LoadingLocation = false;
      if (kDebugMode) {
        print("Exception -  base.dart - getCurrentLocation():$e");
      }
    });
    notifyListeners();
  }

  Future sendLocation(UserProvider ub) async {
    if (remarks == null) {
      // No punch action requested
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      // Use LocationService for offline-first punch-in/out
      final locationService = LocationService();
      final now = DateTime.now();
      final vouchDt = now.toString().split(' ')[0]; // YYYY-MM-DD format
      final vouchTime = now.toString().split(' ')[1]; // HH:MM:SS format

      print('[LocationProvider] 🔵 PUNCH REQUEST - Remark: ${remarks}');
      print(
          '[LocationProvider]   User: ${ub.syncId} | DateTime: $vouchDt $vouchTime');

      // Call appropriate method based on punch type
      final Map<String, dynamic> result;
      if (remarks == 'PUNCH IN') {
        // PUNCH IN: Use punchIn() which starts background tracking
        result = await locationService.punchIn(
          userCd: ub.syncId ?? '',
          vouchDt: vouchDt,
          vouchTime: vouchTime,
          remark: remarks,
          syncId: int.tryParse(ub.syncId ?? '0') ?? 0,
          moduleNo: '301',
          token: ub.token ?? '',
        );
      } else if (remarks == 'PUNCH OUT') {
        // PUNCH OUT: Use punchOut() which stops background tracking
        result = await locationService.punchOut(
          userCd: ub.syncId ?? '',
          vouchDt: vouchDt,
          vouchTime: vouchTime,
          remark: remarks,
          syncId: int.tryParse(ub.syncId ?? '0') ?? 0,
          moduleNo: '301',
          token: ub.token ?? '',
        );
      } else {
        // Fallback for other punch types
        result = await locationService.punchInOut(
          userCd: ub.syncId ?? '',
          vouchDt: vouchDt,
          vouchTime: vouchTime,
          punchType: remarks.toString(),
          remark: remarks.toString(),
          syncId: int.tryParse(ub.syncId ?? '0') ?? 0,
          moduleNo: '301',
          token: ub.token ?? '',
        );
      }

      if (result['success'] == true) {
        if (result['synced'] == true) {
          // Successful online sync
          print(
              '[LocationProvider] 🟢 RESULT: SYNCED | locId=${result['locId']} | Lat=${result['lat']}, Lng=${result['longi']}');

          // Check if background tracking was started (for PUNCH IN)
          if (result['tracking_started'] == true) {
            print(
                '[LocationProvider] ✅ Background tracking STARTED with trip_id=${result['trip_id']}');
            AppSnackBar.showGetXCustomSnackBar(
              message: '${remarks} successful. Route tracking started.',
              backgroundColor: Colors.green,
            );
          } else if (result['tracking_stopped'] == true) {
            // PUNCH OUT completed
            print('[LocationProvider] ✅ Background tracking STOPPED');
            final syncStats = result['sync_stats'] ?? {};
            final syncedCount = syncStats['tracking_synced'] ?? 0;
            final totalCount = syncStats['tracking_total'] ?? 0;
            print(
                '[LocationProvider] 📊 Sync stats: $syncedCount/$totalCount locations synced');
            AppSnackBar.showGetXCustomSnackBar(
              message: '${remarks} successful. $syncedCount locations synced.',
              backgroundColor: Colors.green,
            );
          } else {
            AppSnackBar.showGetXCustomSnackBar(
              message: '${remarks} successful',
              backgroundColor: Colors.green,
            );
          }
        } else {
          // Saved locally, will sync when online
          print(
              '[LocationProvider] 🟠 RESULT: OFFLINE | locId=${result['locId']} | Lat=${result['lat']}, Lng=${result['longi']}');
          AppSnackBar.showGetXCustomSnackBar(
            message: '${remarks} saved offline (will sync when online)',
            backgroundColor: Colors.orange,
          );
        }

        // Toggle punch state immediately so button updates right away
        final bool wasIn = remarks == 'PUNCH IN';
        remarks = null; // clear after capturing
        if (Get.context != null) {
          final ProfileProvider p =
              Provider.of<ProfileProvider>(Get.context!, listen: false);
          // Update in-memory punch state so UI reflects the change immediately
          p.setPunchState(wasIn); // true if just punched in → show Punch Out

          // Do NOT refresh the full profile immediately after punch even when
          // synced: fetching the profile can overwrite the in-memory punch
          // state with stale server data and cause the UI to revert. The app
          // now restores punch state from the local `locations` table on
          // startup, and server-driven profile refreshs should run via the
          // normal startup/sync flows.
        }
      } else {
        // Failed to punch
        print(
            '[LocationProvider] 🔴 RESULT: FAILED | Error: ${result['error']}');
        AppSnackBar.showGetXCustomSnackBar(
          message: result['error'] ?? 'Failed to punch. Please try again.',
          backgroundColor: Colors.red,
        );
      }
    } catch (e, stack) {
      print('[LocationProvider] 🔴 EXCEPTION: ${e.toString()} | Stack: $stack');
      FirebaseCrashlytics.instance.recordError(e, stack);
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Error during punch: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String formatLocation(double value) {
    // 2 decimal places
    String formatted = value.toStringAsFixed(2);

    // Split into integer and decimal parts
    List<String> parts = formatted.split('.');

    // Pad integer part to 10 digits
    String intPart = parts[0].padLeft(10, '0');

    return "$intPart.${parts[1]}";
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
