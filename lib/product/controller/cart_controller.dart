import 'dart:developer';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../providers/user_provider.dart';
import '../../views/loginpage.dart';

class CartController extends GetxController {
  var isCardItemLoading = <String>[].obs;
  var productLoadingStates = <String, bool>{}.obs;
  var productAddedStates = <String, bool>{}.obs;
  var cartCount = 0.obs;

  final dio = Dio();

  Future<void> addItemToCart({
    required String partyid,
    required String itemCd,
    required String qty,
    String? otherDesc,
    String? lrate,// Fazal Changes 13-03-2025
    String? rate,
    String? remarks,
  }) async {
    if (productAddedStates[itemCd] == true) return;

    productLoadingStates[itemCd] = true;

    final UserProvider userProvider =
        Provider.of<UserProvider>(Get.context!, listen: false);

    try {
      final requestBody = {
        "partyCd": partyid,
        "itemCd": itemCd,
        "qty": qty,
        //if(lrate!=null && lrate.toString().isNotEmpty) "lrate": lrate,// Fazal Changes 13-03-2025
        "lrate": rate,
        if (otherDesc != null && otherDesc.trim().isNotEmpty)
          "otherDesc": otherDesc,
        if (remarks != null && remarks.trim().isNotEmpty) "fld5": remarks,
        if (rate != null && rate.trim().isNotEmpty) "rate": rate,
        "moduleNo":"205"
      };


      final response = await dio.post(
        "${AppConfig.baseURL}cart",
        data: requestBody,
        options: Options(
          headers: {
            "Authorization": "Bearer ${userProvider.token}",
            'x-app-type': 'oms',
          },
        ),
      );
      log(">>>>>>>>>> $requestBody");
      if (kDebugMode) {
        print("here add to card url ""${AppConfig.baseURL}cart");
      }

      if (response.statusCode == 401) {
        //showToast("Session expired. Please log in again.");
        AppSnackBar.showGetXCustomSnackBar(message: "Session expired. Please log in again.");

        Get.offAll(() => LoginPage());
      } else {
        productAddedStates[itemCd] = true;
        log("Cart response: ${response.data}");
      }
    } catch (e) {
      log("Error in addItemToCart: $e");
    } finally {
      productLoadingStates[itemCd] = false;
    }
  }

  void removeProductLocally(String itemCd) {
    if (productAddedStates.containsKey(itemCd)) {
      productAddedStates.remove(itemCd); // Remove the product from the list
      productAddedStates.refresh();
      update(); // Notify listeners
    }
  }

  void clearCartState() {
    productAddedStates.clear();
    productLoadingStates.clear();
    update();
  }
}
