import 'dart:async';
import 'dart:developer';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/views/loginpage.dart';
import 'package:flutter/cupertino.dart';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';

class ApiServices {
  Future<http.Response?> getData(String uri,
      {String? tocken, required BuildContext context}) async {
    var url = AppConfig.baseURL + uri;
    print(AppConfig.baseURL + uri);
    try {
      http.Response response = await http.get(Uri.parse(url), headers: {
        "Authorization": "${tocken ?? ""}",
      });
      print(response.body);
      if (response.statusCode == 200) {
        return response;
      } else {
        Provider.of<UserProvider>(context, listen: false)
            .userSignout(context)
            .then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e) {
      print("Error in getData ${uri} ${e.toString()}");
    }
    return null;
  }

  Future<http.Response?> postData(String uri, dynamic body,
      {bool? header, he, required BuildContext context}) async {
    print(AppConfig.baseURL + uri);
    print(body);
    log(he.toString());
    try {
      http.Response response =
          await http.post(Uri.parse(AppConfig.baseURL + uri),
              body: (body),
              headers: header != null
                  ? {
                      "Authorization": "Bearer " + he,
                      'x-app-type': 'oms',
                    }
                  : null);
      print(AppConfig.baseURL + uri);
      print(response.statusCode);
      log("Log Token " + he);
      log("Log Error " + response.body);
      if (response.statusCode == 200) {
        return response;
      } else {
        Provider.of<UserProvider>(context, listen: false)
            .userSignout(context)
            .then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e) {
      print("Error in postData ${uri} ${e.toString()}");
      return null;
    }
    return null;
  }
}
