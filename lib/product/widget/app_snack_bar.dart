import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppSnackBar {
  static void snackBarSuccessMsg(BuildContext context, String text) {
    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
        text,
        style: TextStyle(
            fontWeight: FontWeight.w400, fontSize: 16, color: Colors.white),
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
            fontWeight: FontWeight.w400, fontSize: 16, color: Colors.white),
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
    try {
      // Close previous snackbars (prevents stacking) - wrapped in try-catch for safety
      Get.closeAllSnackbars();
    } catch (e) {
      // GetX framework might not be fully initialized yet
      print('[AppSnackBar] Warning: Could not close previous snackbars: $e');
    }

    try {
      Get.showSnackbar(
        GetSnackBar(
          message: message,
          backgroundColor: backgroundColor,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.only(
              top: 56.0, left: 16.0, right: 16.0, bottom: 16.0),
          duration: const Duration(seconds: 2),
          borderRadius: 5,
        ),
      );
    } catch (e) {
      // Fallback: If GetX snackbar fails, log the message
      print('[AppSnackBar] ❌ Error showing snackbar: $e');
      print('[AppSnackBar] Message was: $message');
    }
  }
}
