import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:url_launcher/url_launcher.dart';

class UpdatePageScreen extends StatefulWidget {
  const UpdatePageScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<UpdatePageScreen> createState() => _UpdatePageScreenState();
}

class _UpdatePageScreenState extends State<UpdatePageScreen> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image.asset("assets/update.gif"),
                const Text(
                  'A new version is available!',
                  style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w600),
                ),
                const SizedBox(
                  height: 16.0,
                ),
                const Text(
                  'Please update your application?',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w400),
                ),
                SizedBox(
                  height: 20.h,
                ),
                FilledButton(
                    onPressed: () {
                      if (Platform.isAndroid || Platform.isIOS) {
                        final appId = Platform.isAndroid
                            ? 'com.arhamerp.app'
                            : '6476415122';
                        final url = Uri.parse(
                          Platform.isAndroid
                              ? "market://details?id=$appId"
                              : "https://apps.apple.com/app/id$appId",
                        );
                        launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        Get.showSnackbar(GetSnackBar(
                          title: "Error",
                          message: "Update is not available",
                          snackPosition: SnackPosition.TOP,
                          duration: Duration(milliseconds: 3000),
                        ));
                      }
                    },
                    child: Text("Update Now"))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
