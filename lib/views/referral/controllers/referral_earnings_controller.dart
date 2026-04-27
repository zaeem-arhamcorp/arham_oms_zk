import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/constants/constants.dart';
import 'package:arham_corporation/network.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/referral/models/referral_claim_reward_model.dart';
import 'package:arham_corporation/views/referral/models/referral_earnings_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class ReferralEarningsController extends GetxController {
  var isLoading = false.obs;
  var isClaimLoading = false.obs;
  var earningsResponse = Rxn<ReferralEarningsResponse>();

  Future<void> fetchReferralEarnings() async {
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

        final earningsURL = AppConfig.referralEarningsUrl;

        final response = await http.get(
          Uri.parse(earningsURL),
          headers: {
            'Authorization': 'Bearer $token',
            'authorization': 'Bearer $token',
            'x-access-token': token,
            'token': token,
            'x-app-type': 'oms',
            'Accept': 'application/json',
          },
        );

        print(earningsURL);
        print(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          earningsResponse.value = ReferralEarningsResponse.fromJson(decoded);
        } else {
          String msg = 'Failed to load referral earnings';
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map && decoded['message'] != null) {
              msg = decoded['message'].toString();
            }
          } catch (_) {}

          AppSnackBar.showGetXCustomSnackBar(message: msg);
        }
      } else {
        AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
      }
    } catch (e) {
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Error: ${e.toString()}',
      );
    } finally {
      isLoading(false);
    }
  }

  Future<ReferralClaimRewardResponse?> claimReward({
    required String amount,
    required String paymentMethod,
  }) async {
    isClaimLoading(true);
    try {
      if (await Network.isConnected()) {
        final userProvider =
            Provider.of<UserProvider>(Get.context!, listen: false);
        final token = userProvider.token;

        if (token == null || token.isEmpty) {
          AppSnackBar.showGetXCustomSnackBar(
            message: 'Authentication token not found',
          );
          return null;
        }

        final claimURL = AppConfig.claimReferralRewardUrl;
        final request = ReferralClaimRewardRequest(
          amount: amount,
          paymentMethod: paymentMethod,
        );

        final response = await http.post(
          Uri.parse(claimURL),
          headers: {
            'Authorization': 'Bearer $token',
            'authorization': 'Bearer $token',
            'x-access-token': token,
            'token': token,
            'x-app-type': 'oms',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(request.toJson()),
        );

        print(claimURL);
        print(response.body);

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final claimResponse = ReferralClaimRewardResponse.fromJson(decoded);

        AppSnackBar.showGetXCustomSnackBar(
          message: claimResponse.message,
          backgroundColor:
              claimResponse.status ? Get.theme.colorScheme.primary : Colors.red,
        );

        if (claimResponse.status) {
          await fetchReferralEarnings();
        }

        return claimResponse;
      }

      AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
    } catch (e) {
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Error: ${e.toString()}',
      );
    } finally {
      isClaimLoading(false);
    }

    return null;
  }
}
