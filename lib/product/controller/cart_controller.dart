import 'dart:developer';

import 'package:arham_corporation/helper/network_helper.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/cart_service.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/database_helper.dart';
import '../../views/loginpage.dart';

class CartController extends GetxController {
  var isCardItemLoading = <String>[].obs;
  var productLoadingStates = <String, bool>{}.obs;
  var productAddedStates = <String, bool>{}.obs;
  var cartCount = 0.obs;

  // State management for product input fields
  var productQuantities = <String, String>{}.obs;
  var productFreeQuantities = <String, String>{}.obs;
  var productRemarks = <String, String>{}.obs;

  final dio = Dio();

  Future<void> addItemToCart({
    required String partyid,
    required String itemCd,
    required String qty,
    String? otherDesc,
    String? lrate, // Fazal Changes 13-03-2025
    String? rate,
    String? remarks,
    String? nrate, // for offline storage
    String? itemName, // for offline storage
  }) async {
    if (productAddedStates[itemCd] == true) return;

    productLoadingStates[itemCd] = true;

    final bool online = await NetworkHelper.hasInternet();

    if (!online) {
      // OFFLINE: Save to local SQLite database
      try {
        double rateVal = double.tryParse(rate ?? '0') ?? 0;
        double qtyVal = double.tryParse(qty) ?? 0;
        double nrateVal = double.tryParse(nrate ?? rate ?? '0') ?? 0;
        double lrateVal = double.tryParse(lrate ?? '0') ?? 0;
        // If rate not provided or zero, try to recover from cached products
        if ((rateVal == 0 || rateVal.isNaN) &&
            (itemName == null || itemName.isEmpty)) {
          try {
            final cached = await DatabaseHelper().getCachedProducts();
            final prod = cached.firstWhere(
                (p) =>
                    (p['item_cd']?.toString() ??
                        p['ITEM_CD']?.toString() ??
                        '') ==
                    itemCd,
                orElse: () => {});
            if (prod.isNotEmpty) {
              // Prefer NRATE if available, else SRATE3, else rate
              double recovered = 0;
              final v1 = prod['nrate'] ??
                  prod['NRATE'] ??
                  prod['N.RATE'] ??
                  prod['nRATE'];
              final v2 = prod['srate3'] ??
                  prod['SRATE3'] ??
                  prod['sRATE3'] ??
                  prod['srate'];
              if (v1 != null)
                recovered = double.tryParse(v1.toString()) ?? recovered;
              if (recovered == 0 && v2 != null)
                recovered = double.tryParse(v2.toString()) ?? recovered;
              if (recovered > 0) {
                rateVal = recovered;
                nrateVal = recovered;
              }
            }
          } catch (e) {
            // ignore and fallback to 0
          }
        }

        double amount = rateVal * qtyVal;

        await CartService().addToCart(
          partyCd: partyid,
          itemCd: itemCd,
          quantity: qtyVal,
          rate: rateVal,
          nrate: nrateVal,
          lrate: lrateVal,
          amount: amount,
          otherDesc: otherDesc ?? '',
          fld5: remarks ?? '',
          itemName: itemName ?? '',
        );

        productAddedStates[itemCd] = true;
        log("Item $itemCd saved to local cart (offline)");
      } catch (e) {
        log("Error saving to local cart: $e");
        AppSnackBar.showGetXCustomSnackBar(
          message: "Failed to add item to cart",
        );
      } finally {
        productLoadingStates[itemCd] = false;
      }
      return;
    }

    // ONLINE: Save to local DB first, then POST to server
    final UserProvider userProvider =
        Provider.of<UserProvider>(Get.context!, listen: false);

    try {
      // Always save locally first (ensures cart survives connectivity loss)
      double rateVal = double.tryParse(rate ?? '0') ?? 0;
      double qtyVal = double.tryParse(qty) ?? 0;
      double nrateVal = double.tryParse(nrate ?? rate ?? '0') ?? 0;
      double lrateVal = double.tryParse(lrate ?? '0') ?? 0;
      double amount = rateVal * qtyVal;

      await CartService().addToCart(
        partyCd: partyid,
        itemCd: itemCd,
        quantity: qtyVal,
        rate: rateVal,
        nrate: nrateVal,
        lrate: lrateVal,
        amount: amount,
        otherDesc: otherDesc ?? '',
        fld5: remarks ?? '',
        itemName: itemName ?? '',
      );
      log("Item $itemCd saved to local cart (online+local)");

      // Now POST to server
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
        "moduleNo": "205"
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
      print("here add to card url " "${AppConfig.baseURL}cart");

      if (response.statusCode == 401) {
        //showToast("Session expired. Please log in again.");
        AppSnackBar.showGetXCustomSnackBar(
            message: "Session expired. Please log in again.");

        Get.offAll(() => LoginPage());
      } else {
        productAddedStates[itemCd] = true;
        log("Cart response: ${response.data}");
      }
    } catch (e) {
      log("Error in addItemToCart: $e");
      // Item is still saved locally even if server fails
      productAddedStates[itemCd] = true;
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
    productQuantities.clear();
    productFreeQuantities.clear();
    productRemarks.clear();
    update();
  }

  // Get quantity for a product
  String getQuantity(String itemCd) {
    return productQuantities[itemCd] ?? '';
  }

  // Set quantity for a product
  void setQuantity(String itemCd, String value) {
    productQuantities[itemCd] = value;
  }

  // Get free quantity for a product
  String getFreeQuantity(String itemCd) {
    return productFreeQuantities[itemCd] ?? '';
  }

  // Set free quantity for a product
  void setFreeQuantity(String itemCd, String value) {
    productFreeQuantities[itemCd] = value;
  }

  // Get remark for a product
  String getRemark(String itemCd) {
    return productRemarks[itemCd] ?? '';
  }

  // Set remark for a product
  void setRemark(String itemCd, String value) {
    productRemarks[itemCd] = value;
  }

  // Clear product input fields after adding to cart
  void clearProductInputs(String itemCd) {
    productQuantities.remove(itemCd);
    productFreeQuantities.remove(itemCd);
    productRemarks.remove(itemCd);
  }
}
