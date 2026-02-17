import 'dart:convert';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/personModal.dart';
import '../views/loginpage.dart';

class PersonProvider extends DisposableProvider {
  PersonModal? person;
  List<DatumPerson> personData = [];

  bool loading = false;

  changeLoading(val) {
    loading = val;
    notifyListeners();
  }

  Future getPersonList(BuildContext context, page) async {
    personData.clear();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "users?page=${page}"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(AppConfig.baseURL + "users?page=${page}");
      print("Bearer ${ub.token}");
      print(response.body);
      if (response.statusCode == 200) {
        person = personModalFromJson(response.body);
        personData.addAll(personModalFromJson(response.body).data);
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e) {
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in PersonProvider getPersonalList  ${e.toString()}");
    }
    notifyListeners();
  }

  Future addPerson(
      BuildContext context,
      String username,
      String userCd,
      String password,
      String phonenumber,
      String type,
      bool active,
      modules,
      List<String> firmID) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    List<Map<String, dynamic>> firmIds = firmID
        .map((e) => {"firmId": e})
        .toList(); // Split firmID string into individual firm IDs

    // Create JSON payload for each firm ID
    Map<String, dynamic> payload = {
      "userCd": userCd,
      "password": password,
      "userName": username,
      "userType": type,
      "mobileNo": phonenumber,
      "isLock": active.toString(),
      "modules": modules,
      "firms": firmIds
    };

    try {
      // Make HTTP POST request for each firm ID
      final http.Response response = await http.post(
        Uri.parse(AppConfig.baseURL + "users"),
        body: json.encode(payload),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          'x-app-type': 'oms',
        },
      );

      // Handle response
      print("Add Param" + payload.toString());
      print("Add Response" + response.body);

      if (response.statusCode == 201) {
        Get.back(result: 1);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"],
            backgroundColor: Colors.green);
        changeLoading(false);
        return true;
      } else {
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
      }
    } catch (e) {
      //Fluttertoast.showToast(msg: "Something went wrong for firmId: $e");
      AppSnackBar.showGetXCustomSnackBar(
          message: "Something went wrong for firmId: $e");
    }

    notifyListeners();
  }

  Future updatePerson(BuildContext context, usenname, userCd, password,
      phonenumber, type, active, modules, List<String> firmID) async {
    personData.clear();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    List<Map<String, dynamic>> firmIds = firmID
        .map((e) => {"firmId": e})
        .toList(); // Split firmID string into individual firm IDs

    // Create JSON payload for each firm ID
    Map<String, dynamic> payload = {
      "userCd": userCd,
      "password": password,
      "userName": usenname,
      "userType": type,
      "mobileNo": phonenumber,
      "isLock": active.toString(),
      "modules": modules,
      "firms": firmIds
    };

    try {
      final http.Response response = await http.put(
        Uri.parse(AppConfig.baseURL + "users"),
        body: json.encode(payload),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          'x-app-type': 'oms',
        },
      );

      print("Update Param " + payload.toString());
      print("Update Response " + response.body);

      if (response.statusCode == 200) {
        Get.back(result: 1);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"],
            backgroundColor: Colors.green);
        changeLoading(false);
        return true;
      } else {
        changeLoading(false);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
      }
    } catch (e) {
      changeLoading(false);
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in PersonProvider updatePerson  ${e.toString()}");
    }
    notifyListeners();
  }

  Future deletePerson(BuildContext context, usercd, userName) async {
    personData.clear();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    try {
      final http.Response response = await http.delete(
        Uri.parse(AppConfig.baseURL + "users/${usercd}"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.body);
      print(response.statusCode);
      if (response.statusCode == 200) {
        Get.back();
        changeLoading(false);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"] + " : " + userName,
            backgroundColor: Colors.green);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"] + userName);
        return true;
      } else {
        changeLoading(false);
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e) {
      changeLoading(false);
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in PersonProvider deletePerson  ${e.toString()}");
    }
    notifyListeners();
  }

  @override
  disposeValues() {
    personData.clear();
    loading = false;
    notifyListeners();
  }
}
