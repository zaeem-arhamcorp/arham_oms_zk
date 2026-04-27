import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/constants/constants.dart';
import 'package:arham_corporation/network.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class ReferralController extends GetxController {
  var isLoading = false.obs;
  var referralCode = ''.obs;
  var playStoreLink = ''.obs;
  // selected app type for which to generate referral code
  var selectedAppType = 'oms'.obs;
  final List<String> appTypes = ['oms', 'b2c', 'pos'];

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.arhamerp.app';

  @override
  void onInit() {
    super.onInit();
  }

  Future<void> generateReferralCode({String? forAppType}) async {
    isLoading(true);
    try {
      if (await Network.isConnected()) {
        final userProvider =
            Provider.of<UserProvider>(Get.context!, listen: false);
        final token = userProvider.token;

        if (token == null || token.isEmpty) {
          AppSnackBar.showGetXCustomSnackBar(
            message: 'Authentication token not found',
          );
          return;
        }

        final appType = (forAppType ?? selectedAppType.value).trim();
        selectedAppType.value = appType;

        // Debug: log token summary and request payload
        try {
          final masked = token.length > 10
              ? '${token.substring(0, 6)}...${token.substring(token.length - 4)}'
              : token;
          print(
              '[ReferralController] Using token: $masked (len=${token.length})');
          print(
              '[ReferralController] POST ${AppConfig.generateReferralCodeURL} body: ${jsonEncode({
                'app_type': appType
              })}');
        } catch (_) {}

        final response = await http.post(
          Uri.parse(AppConfig.generateReferralCodeURL),
          headers: {
            'Authorization': 'Bearer $token',
            'authorization': 'Bearer $token',
            'x-access-token': token,
            'token': token,
            // Keep x-app-type as 'oms' for authentication; send desired app_type in body
            'x-app-type': 'oms',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'app_type': appType, 'token': token}),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);

          // The API returns { status: true, data: { code: "REF_...", play_store_link: "...", ... } }
          if (data['data'] is Map && data['data']['code'] != null) {
            referralCode.value = data['data']['code'].toString();
            // Also store the play_store_link from API
            if (data['data']['play_store_link'] != null) {
              playStoreLink.value = data['data']['play_store_link'].toString();
            }
          } else {
            AppSnackBar.showGetXCustomSnackBar(
              message: 'Failed to generate referral code',
            );
          }
        } else {
          // try to decode message for clearer feedback
          String msg =
              'Failed to generate referral code (HTTP ${response.statusCode})';
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map && decoded['message'] != null) {
              msg = decoded['message'].toString();
            }
          } catch (_) {}

          AppSnackBar.showGetXCustomSnackBar(
            message: msg,
          );
          print('[ReferralController] Error response: ${response.body}');

          // If token-related error, prompt user to re-login
          if (response.statusCode == 401 ||
              msg.toLowerCase().contains('token') ||
              msg.toLowerCase().contains('invalid')) {
            AppSnackBar.showGetXCustomSnackBar(
              message: 'Authentication failed. Please login again.',
              backgroundColor: Colors.red,
            );
          }
        }
      } else {
        AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
      }
    } catch (e, stackTrace) {
      print('[ReferralController] Exception: $e');
      print('[ReferralController] Stack trace: $stackTrace');
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Error: ${e.toString()}',
      );
    } finally {
      isLoading(false);
    }
  }

  void copyReferralCode() {
    if (referralCode.value.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: referralCode.value));
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Referral code copied to clipboard',
        backgroundColor: Colors.green,
      );
    }
  }

  void shareReferralCode() {
    if (referralCode.value.isNotEmpty) {
      final base =
          playStoreLink.value.isNotEmpty ? playStoreLink.value : playStoreUrl;
      // If server-provided link already contains a referral parameter, use as-is
      final containsRef = base.toLowerCase().contains('ref=');
      final link = containsRef
          ? base
          : () {
              final separator = base.contains('?') ? '&' : '?';
              // return '$base${separator}ref=${referralCode.value}';
              return '$base';
            }();
      final appLabel = selectedAppType.value.toUpperCase();
      final message =
          'To register on the $appLabel app, you may use the following referral code: *${referralCode.value}*\nDownload here: $link';
      Share.share(message);
    }
  }
}
