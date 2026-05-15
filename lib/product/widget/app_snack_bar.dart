import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/constants.dart';
import '../../helper/network_helper.dart';

class AppSnackBar {
  static void snackBarSuccessMsg(BuildContext context, String text) {
    showGetXCustomSnackBar(message: text, backgroundColor: Colors.green);
  }

  static Future<void> snackBarErrorMsg(
      BuildContext context, String text) async {
    try {
      final hasNet = await NetworkHelper.hasInternet();
      if (!hasNet) {
        showGetXCustomSnackBar(
            message: Constants.networkMsg, backgroundColor: Colors.orange);
        return;
      }
    } catch (e) {
      // If network helper fails, fall back to showing provided error
      print('[AppSnackBar] Network check failed: $e');
    }

    final messageToShow = (text.trim().isEmpty) ? 'Something went wrong' : text;
    showGetXCustomSnackBar(message: messageToShow, backgroundColor: Colors.red);
  }

  static Future<void> showGetXCustomSnackBar(
      {required String message, Color backgroundColor = Colors.red}) async {
    try {
      try {
        final hasNet = await NetworkHelper.hasInternet();
        if (!hasNet) {
          message = Constants.networkMsg;
          backgroundColor = Colors.orange;
        } else {
          if (message.trim().isEmpty) {
            message = 'Something went wrong';
            backgroundColor = Colors.red;
          }
        }
      } catch (e) {
        print('[AppSnackBar] Network check failed: $e');
      }

      final overlayContext = Get.context ?? Get.overlayContext;
      if (overlayContext == null) {
        print('[AppSnackBar] No available context for snackbar: $message');
        return;
      }

      // Safely close all snackbars
      try {
        Get.closeAllSnackbars();
      } catch (e) {
        print('[AppSnackBar] Error closing snackbars: $e');
      }

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
