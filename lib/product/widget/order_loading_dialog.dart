import 'package:flutter/material.dart';
import 'dart:developer' as developer;

class OrderLoadingDialog {
  /// Show a loading dialog while starting/ending an order
  static void show({
    required BuildContext context,
    required String action, // "Starting" or "Ending"
  }) {
    developer.log("📍 SHOWING DIALOG: $action Order");
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        developer.log("✅ DIALOG BUILDER CALLED");
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 5,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$action Order",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                  strokeWidth: 4,
                ),
                const SizedBox(height: 16),
                Text(
                  "Please wait...",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      developer.log("🔙 DIALOG DISMISSED");
    });
  }

  /// Dismiss the loading dialog
  static void dismiss(BuildContext context) {
    developer.log("⏹️  DISMISSING DIALOG");
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      developer.log("❌ Error dismissing dialog: $e");
    }
  }
}
