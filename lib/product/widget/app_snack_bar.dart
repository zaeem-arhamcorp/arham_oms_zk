import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../constants/constants.dart';
import '../../helper/network_helper.dart';
import '../../providers/profile_provider.dart';

class AppSnackBar {
  /// When true, `showGetXCustomSnackBar` will suppress the network
  /// connectivity snackbar if the current `ProfileProvider` reports
  /// `enableOfflineMode='Y'`. Used by `ProductsPage` to avoid showing the
  /// network message when offline mode is intentionally enabled for product
  /// browsing.
  static bool suppressNetworkSnackForProductPage = false;
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

  static Future<void> showGetXCustomSnackBar({
    required String message,
    Color backgroundColor = Colors.red,
    bool enforceNetworkMessage = true,
  }) async {
    try {
      if (enforceNetworkMessage) {
        try {
          final hasNet = await NetworkHelper.hasInternet();
          if (!hasNet) {
            // If product-page suppression is enabled AND the profile's
            // enableOfflineMode is 'Y', skip showing the network snackbar.
            final overlayContext = Get.context ?? Get.overlayContext;
            if (suppressNetworkSnackForProductPage && overlayContext != null) {
              try {
                final profile =
                    Provider.of<ProfileProvider>(overlayContext, listen: false);
                if (profile.isOfflineModeEnabled()) {
                  print(
                      '[AppSnackBar] Suppressing network snackbar for product page (offline mode enabled).');
                  return;
                }
              } catch (_) {
                // ignore and fall back to showing network message
              }
            }

            message = Constants.networkMsg;
            backgroundColor = Colors.orange;
          }
        } catch (e) {
          print('[AppSnackBar] Network check failed: $e');
        }
      }

      if (message.trim().isEmpty) {
        message = 'Something went wrong';
        backgroundColor = Colors.red;
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
