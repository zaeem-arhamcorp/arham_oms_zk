import 'dart:convert';
import 'dart:io';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/personModal.dart';
import '../views/loginpage.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';

class PersonProvider extends DisposableProvider {
  PersonModal? person;
  List<DatumPerson> personData = [];

  bool loading = false;

  Future<bool> _uploadUserImage(
      BuildContext context, String userCd, String imagePath) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    final String imageUploadUrl = AppConfig.baseURL + "users/image";

    print("[AddUser][ImageUpload] Start");
    print("[AddUser][ImageUpload] API URL: $imageUploadUrl");
    print("[AddUser][ImageUpload] userCd: $userCd");
    print("[AddUser][ImageUpload] imagePath: $imagePath");

    if (ub.token == null || ub.token!.isEmpty) {
      print("[AddUser][ImageUpload] Skipped: token missing");
      return false;
    }

    try {
      final File file = File(imagePath);
      if (!await file.exists()) {
        print("[AddUser][ImageUpload] Skipped: file does not exist");
        return false;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(imageUploadUrl),
      )
        ..headers['Authorization'] = 'Bearer ${ub.token}'
        ..headers['x-app-type'] = 'oms'
        ..fields['userCd'] = userCd;

      final bytes = await file.readAsBytes();
      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      final typeSplit = mimeType.split('/');

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: p.basename(file.path),
          contentType: http.MediaType(typeSplit[0], typeSplit[1]),
        ),
      );

      print("[AddUser][ImageUpload] Calling API now...");

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      print(
          "[AddUser][ImageUpload] Response status: ${streamedResponse.statusCode}");
      print("[AddUser][ImageUpload] Response body: $responseBody");

      if (streamedResponse.statusCode >= 200 &&
          streamedResponse.statusCode < 300) {
        print("[AddUser][ImageUpload] Success");
        return true;
      }

      print(
          "User image upload failed ${streamedResponse.statusCode} : $responseBody");
      return false;
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      print("Error in PersonProvider _uploadUserImage ${e.toString()}");
      return false;
    }
  }

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
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
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
      List<String> firmID,
      String email,
      {String? imagePath}) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    final String addUserUrl = AppConfig.baseURL + "users";
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
      "emailID": email,
      "isLock": active,
      "modules": modules,
      "firms": firmIds
    };

    try {
      // Make HTTP POST request for each firm ID
      print("[AddUser] Flow started");
      print("[AddUser] API URL: $addUserUrl");
      print("[AddUser] userCd: $userCd");
      print(
          "[AddUser] image selected: ${imagePath != null && imagePath.trim().isNotEmpty}");

      final http.Response response = await http.post(
        Uri.parse(addUserUrl),
        body: json.encode(payload),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          'x-app-type': 'oms',
        },
      );

      // Handle response
      print("Add Param" + payload.toString());
      print("[AddUser] Response status: ${response.statusCode}");
      print("Add Response" + response.body);

      if (response.statusCode == 201) {
        bool imageUploaded = true;
        if (imagePath != null && imagePath.trim().isNotEmpty) {
          print("[AddUser] users/image call will be triggered");
          imageUploaded =
              await _uploadUserImage(context, userCd, imagePath.trim());
        } else {
          print("[AddUser] users/image skipped: no image selected");
        }

        Get.back(result: 1);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: imageUploaded
                ? json.decode(response.body)["message"]
                : "${json.decode(response.body)["message"]} (Image upload failed)",
            backgroundColor: imageUploaded ? Colors.green : Colors.orange);
        changeLoading(false);
        return true;
      } else {
        print("[AddUser] users API failed");
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      print("[AddUser] Exception: ${e.toString()}");
      //Fluttertoast.showToast(msg: "Something went wrong for firmId: $e");
      AppSnackBar.showGetXCustomSnackBar(
          message: "Something went wrong for firmId: $e");
    }

    notifyListeners();
  }

  Future updatePerson(BuildContext context, usenname, userCd, password,
      phonenumber, type, active, modules, List<String> firmID, String email,
      {String? imagePath}) async {
    personData.clear();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    final String updateUserUrl = AppConfig.baseURL + "users";
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
      "emailID": email,
      "isLock": active,
      "modules": modules,
      "firms": firmIds
    };

    try {
      print("[UpdateUser] Flow started");
      print("[UpdateUser] API URL: $updateUserUrl");
      print("[UpdateUser] userCd: $userCd");
      print(
          "[UpdateUser] image selected: ${imagePath != null && imagePath.trim().isNotEmpty}");

      final http.Response response = await http.put(
        Uri.parse(updateUserUrl),
        body: json.encode(payload),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          'x-app-type': 'oms',
        },
      );

      print("Update Param " + payload.toString());
      print("[UpdateUser] Response status: ${response.statusCode}");
      print("Update Response " + response.body);

      if (response.statusCode == 200) {
        bool imageUploaded = true;
        if (imagePath != null && imagePath.trim().isNotEmpty) {
          print("[UpdateUser] users/image call will be triggered");
          imageUploaded =
              await _uploadUserImage(context, userCd, imagePath.trim());
        } else {
          print("[UpdateUser] users/image skipped: no image selected");
        }

        Get.back(result: 1);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: imageUploaded
                ? json.decode(response.body)["message"]
                : "${json.decode(response.body)["message"]} (Image upload failed)",
            backgroundColor: imageUploaded ? Colors.green : Colors.orange);
        changeLoading(false);
        return true;
      } else {
        print("[UpdateUser] users API failed");
        changeLoading(false);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      print("[UpdateUser] Exception: ${e.toString()}");
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
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
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
