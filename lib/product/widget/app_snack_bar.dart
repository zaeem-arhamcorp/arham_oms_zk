import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppSnackBar {
  static void snackBarSuccessMsg(BuildContext context, String text) {
    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
        text,
        style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 16,
            color: Colors.white),
      ),
      elevation: 6.0,
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.green,
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () {},
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static void snackBarErrorMsg(BuildContext context, String text) {
    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
        text,
        style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 16,
            color: Colors.white),
      ),
      elevation: 6.0,
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.red,
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () {},
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static void showGetXCustomSnackBar(
      {required String message, Color backgroundColor = Colors.red}) {
    // Close previous snackbars (prevents stacking)
    Get.closeAllSnackbars();

    Get.showSnackbar(
      GetSnackBar(
        message: message,
        backgroundColor: backgroundColor,
        snackPosition: SnackPosition.TOP,
        //snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.only(top: 56.0,left: 16.0,right: 16.0,bottom: 16.0),
        duration: const Duration(seconds: 2),
        borderRadius: 5,
      ),
    );
  }
}
