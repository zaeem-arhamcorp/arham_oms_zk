import 'dart:async';
import 'dart:convert';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/foundation.dart';

//import 'package:fluttertoast/fluttertoast.dart';
//import 'package:geolocator/geolocator.dart' as gio;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/app_config.dart';

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
    Map bod = {
      "lat": ub.role == AppConfig.masteruser
          ? lat.toString().isNotEmpty
              ? lat.toString()
              : '0'
          : lat.toString().isNotEmpty
              ? lat.toString()
              : '0',
      "long": ub.role == AppConfig.masteruser
          ? lag.toString().isNotEmpty
              ? lag.toString()
              : '0'
          : lag.toString().isNotEmpty
          ? lag.toString()
          : '0',
      //"moduleNo": "205",
      "moduleNo": "301",
    };
    if (remarks != null) {
      isLoading = true;
      bod['remarks'] = remarks.toString();
    }
    print(bod);
    try {
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}locations"),
        body: bod,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("Location Fetched");
      print("${AppConfig.baseURL}locations");
      print(response.body);
      if (response.statusCode == 200) {
        if (remarks != null) {
          remarks = null;
          final ProfileProvider p =
              Provider.of<ProfileProvider>(Get.context!, listen: false);
          p.getProfile(Get.context!).then((value) {
            isLoading = false;
            notifyListeners();
          });
        }
        return json.decode(response.body)["data"];
      } else {}
    } catch (e) {
      print("Error in LocationProvider sendlocation ${e.toString()}");
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
