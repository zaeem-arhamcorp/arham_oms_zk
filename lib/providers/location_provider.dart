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
import 'package:shared_preferences/shared_preferences.dart';

import '../services/location_service.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';

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

  Future<bool> sendLocation(UserProvider ub, {ProfileProvider? profile}) async {
    if (remarks == null) {
      return false;
    }

    isLoading = true;
    notifyListeners();

    try {
      bool isContinuousTracking = true;
      if (profile != null) {
        try {
          final setting = profile.data?.profileSettings.firstWhere(
            (e) => e.variable == 'continuousLocationTracking',
          );
          isContinuousTracking = (setting?.value ?? 'Y') == 'Y';
        } catch (_) {
          isContinuousTracking = true;
        }
      }

      print(
          '[LocationProvider] 📍 Tracking mode: ${isContinuousTracking ? "CONTINUOUS" : "ON-DEMAND"}');
      final locationService = LocationService();
      final now = DateTime.now();
      final vouchDt = now.toString().split(' ')[0];
      final vouchTime = now.toString().split(' ')[1];
      final sp = await SharedPreferences.getInstance();
      final actualUserCd = sp.getString('UserCode') ?? '';
      final firmSyncId = int.tryParse(ub.syncId ?? '0') ?? 0;

      print('[LocationProvider] 🔵 PUNCH REQUEST - Remark: ${remarks}');
      print(
          '[LocationProvider]   USER_CD: $actualUserCd | SYNC_ID: $firmSyncId | DateTime: $vouchDt $vouchTime');

      if (actualUserCd.isEmpty || firmSyncId <= 0) {
        throw Exception('Missing USER_CD or SYNC_ID for punch operation');
      }

      final Map<String, dynamic> result;
      if (remarks == 'PUNCH IN') {
        result = await locationService.punchIn(
          userCd: actualUserCd,
          vouchDt: vouchDt,
          vouchTime: vouchTime,
          remark: remarks,
          syncId: firmSyncId,
          moduleNo: '301',
          token: ub.token ?? '',
          continuousLocationTracking: isContinuousTracking,
        );
      } else if (remarks == 'PUNCH OUT') {
        result = await locationService.punchOut(
          userCd: actualUserCd,
          vouchDt: vouchDt,
          vouchTime: vouchTime,
          remark: remarks,
          syncId: firmSyncId,
          moduleNo: '301',
          token: ub.token ?? '',
          continuousLocationTracking: isContinuousTracking,
        );
      } else {
        result = await locationService.punchInOut(
          userCd: actualUserCd,
          vouchDt: vouchDt,
          vouchTime: vouchTime,
          punchType: remarks.toString(),
          remark: remarks.toString(),
          syncId: firmSyncId,
          moduleNo: '301',
          token: ub.token ?? '',
        );
      }

      if (result['success'] == true) {
        if (result['synced'] == true) {
          print(
              '[LocationProvider] 🟢 RESULT: SYNCED | locId=${result['locId']} | Lat=${result['lat']}, Lng=${result['longi']}');

          if (result['tracking_started'] == true) {
            print(
                '[LocationProvider] ✅ Background tracking STARTED with trip_id=${result['trip_id']}');
            AppSnackBar.showGetXCustomSnackBar(
              message: '${remarks} successful. Route tracking started.',
              backgroundColor: Colors.green,
            );
          } else if (result['tracking_stopped'] == true) {
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
          print(
              '[LocationProvider] 🟠 RESULT: OFFLINE | locId=${result['locId']} | Lat=${result['lat']}, Lng=${result['longi']}');
          AppSnackBar.showGetXCustomSnackBar(
            message: '${remarks} saved offline (will sync when online)',
            backgroundColor: Colors.orange,
          );
        }

        final bool wasIn = remarks == 'PUNCH IN';
        remarks = null;
        if (Get.context != null) {
          final ProfileProvider p =
              Provider.of<ProfileProvider>(Get.context!, listen: false);
          p.setPunchState(wasIn);
        }

        return true;
      }

      print('[LocationProvider] 🔴 RESULT: FAILED | Error: ${result['error']}');
      AppSnackBar.showGetXCustomSnackBar(
        message: result['error'] ?? 'Failed to punch. Please try again.',
        backgroundColor: Colors.red,
      );
      return false;
    } catch (e, stack) {
      print('[LocationProvider] 🔴 EXCEPTION: ${e.toString()} | Stack: $stack');
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Error during punch: ${e.toString()}',
        backgroundColor: Colors.red,
      );
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String formatLocation(double value) {
    String formatted = value.toStringAsFixed(2);
    List<String> parts = formatted.split('.');
    String intPart = parts[0].padLeft(10, '0');
    return "$intPart.${parts[1]}";
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
