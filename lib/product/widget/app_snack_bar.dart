import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppSnackBar {
  static void snackBarSuccessMsg(BuildContext context, String text) {
    showGetXCustomSnackBar(message: text, backgroundColor: Colors.green);
  }

  static void snackBarErrorMsg(BuildContext context, String text) {
    showGetXCustomSnackBar(message: text, backgroundColor: Colors.red);
  }

  static void showGetXCustomSnackBar(
      {required String message, Color backgroundColor = Colors.red}) {
    try {
      final overlayContext = Get.context ?? Get.overlayContext;
      if (overlayContext == null) {
        print('[AppSnackBar] No available context for snackbar: $message');
        return;
      }

      Get.closeAllSnackbars();
      Get.showSnackbar(
        GetSnackBar(
          message: message,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(12),
          borderRadius: 10,
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 2),
          messageText: Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      );
    } catch (e) {
      // Fallback: If GetX snackbar fails, log the message
      print('[AppSnackBar] ❌ Error showing snackbar: $e');
      print('[AppSnackBar] Message was: $message');
    }
  }
}
