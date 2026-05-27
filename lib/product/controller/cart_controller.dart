import 'dart:developer';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/providers/cart_list_provider.dart';
import 'package:arham_corporation/services/cart_service.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/cartListModal.dart';
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

  void _syncLocalCartItem({
    required String partyid,
    required String itemCd,
    required String qty,
    String? otherDesc,
    String? lrate,
    String? rate,
    String? nrate,
    String? remarks,
  }) {
    final context = Get.context;
    if (context == null) return;

    final cartProvider = Provider.of<CartListProvider>(context, listen: false);
    final quantityValue = double.tryParse(qty) ?? 0;
    final rateValue = double.tryParse((rate ?? '').trim()) ?? 0;
    final lrateValue = double.tryParse((lrate ?? '').trim()) ?? 0;
    final effectiveRate = rateValue > 0 ? rateValue : lrateValue;

    cartProvider.upsertLocalCartItem(
      DatumCartList(
        partyCd: partyid,
        itemCd: itemCd,
        quantity: quantityValue,
        otherDesc: (otherDesc != null && otherDesc.trim().isNotEmpty)
            ? otherDesc.trim()
            : null,
        rate: rateValue > 0 ? rateValue : null,
        lrate: lrateValue > 0 ? lrateValue : null,
        nrate: double.tryParse((nrate ?? '').trim()) ?? effectiveRate,
        amount: effectiveRate * quantityValue,
        fld5: (remarks != null && remarks.trim().isNotEmpty)
            ? remarks.trim()
            : null,
      ),
    );
  }

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
    String? stockist, // New field for stockist
  }) async {
    if (productAddedStates[itemCd] == true) return;

    productLoadingStates[itemCd] = true;

    final UserProvider userProvider =
        Provider.of<UserProvider>(Get.context!, listen: false);

    // Build request body
    final requestBody = {
      "partyCd": partyid,
      "itemCd": itemCd,
      "qty": qty,
      "lrate": lrate,
      if (otherDesc != null && otherDesc.trim().isNotEmpty)
        "otherDesc": otherDesc,
      if (remarks != null && remarks.trim().isNotEmpty) "fld5": remarks,
      if (rate != null && rate.trim().isNotEmpty) "rate": rate,
      if ((rate == null || rate.trim().isEmpty) &&
          nrate != null &&
          nrate.trim().isNotEmpty)
        "rate": nrate,
      if (stockist != null && stockist.trim().isNotEmpty) "stockist": stockist,
      "moduleNo": "205"
    };

    try {
      // ⚡⚡⚡ IMMEDIATE API CALL (no internet check - save 5 seconds!)
      // Just try the API, catch network errors gracefully
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
        AppSnackBar.showGetXCustomSnackBar(
            message: "Session expired. Please log in again.");
        Get.offAll(() => LoginPage());
        productLoadingStates[itemCd] = false;
        return;
      }

      // ✅ Update UI immediately on API success
      productAddedStates[itemCd] = true;
      _syncLocalCartItem(
        partyid: partyid,
        itemCd: itemCd,
        qty: qty,
        otherDesc: otherDesc,
        lrate: lrate,
        rate: rate,
        nrate: nrate,
        remarks: remarks,
      );
      log("Cart response: ${response.data}");

      // 📱 NOW save to local DB in background (non-blocking)
      Future.microtask(() async {
        try {
          double rateVal = double.tryParse((rate ?? '').trim()) ?? 0;
          if (rateVal <= 0) {
            rateVal = double.tryParse((lrate ?? '').trim()) ?? 0;
          }
          if (rateVal <= 0) {
            rateVal = double.tryParse((nrate ?? '').trim()) ?? 0;
          }
          double qtyVal = double.tryParse(qty) ?? 0;
          var nrateVal = double.tryParse(nrate ?? rate ?? '0') ?? 0;
          double lrateVal = double.tryParse(lrate ?? '0') ?? 0;
          double amount = rateVal * qtyVal;

          print(
              '[OFFLINE_DB] Starting background local DB save for item: $itemCd');
          print('[OFFLINE_DB] Qty: $qtyVal, Rate: $rateVal, Amount: $amount');

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
            stockist: stockist ?? '',
            syncStatus: 'synced',
          );
          print(
              '[OFFLINE_DB] ✅ Item $itemCd successfully saved to local DB (ONLINE mode)');
          log("Item $itemCd saved to local cart (background)");
        } catch (e) {
          print('[OFFLINE_DB] ❌ Background DB save failed for $itemCd: $e');
          log("Background DB save failed for $itemCd: $e");
          // Silently fail - item is already on server
        }
      });
    } on DioException catch (dioError) {
      // Check if this is an authentication error
      if (dioError.response?.statusCode == 401) {
        AppSnackBar.showGetXCustomSnackBar(
            message: "Session expired. Please log in again.");
        Get.offAll(() => LoginPage());
        productLoadingStates[itemCd] = false;
        return;
      }

      // NETWORK ERROR: Fall back to offline mode
      // Catch all network-related errors (connection, timeout, unreachable, etc.)
      final isNetworkError =
          dioError.type == DioExceptionType.connectionTimeout ||
              dioError.type == DioExceptionType.receiveTimeout ||
              dioError.type == DioExceptionType.sendTimeout ||
              dioError.type == DioExceptionType.connectionError ||
              dioError.type == DioExceptionType.unknown ||
              dioError.message?.toLowerCase().contains('connection') == true ||
              dioError.message?.toLowerCase().contains('network') == true ||
              dioError.message?.toLowerCase().contains('unreachable') == true;

      if (isNetworkError) {
        print(
            '[OFFLINE_DB] ⚠️ Network error detected, switching to offline mode: ${dioError.message}');
        log("Network error, saving offline: $dioError");

        // Save to local DB instead
        try {
          double rateVal = double.tryParse((rate ?? '').trim()) ?? 0;
          if (rateVal <= 0) {
            rateVal = double.tryParse((lrate ?? '').trim()) ?? 0;
          }
          if (rateVal <= 0) {
            rateVal = double.tryParse((nrate ?? '').trim()) ?? 0;
          }
          double qtyVal = double.tryParse(qty) ?? 0;
          var nrateVal = double.tryParse(nrate ?? rate ?? '0') ?? 0;
          double lrateVal = double.tryParse(lrate ?? '0') ?? 0;
          double amount = rateVal * qtyVal;

          print(
              '[OFFLINE_DB] Saving to local DB in OFFLINE mode for item: $itemCd');
          print('[OFFLINE_DB] Qty: $qtyVal, Rate: $rateVal, Amount: $amount');

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
            stockist: stockist ?? '',
            syncStatus: 'pending',
          );

          productAddedStates[itemCd] = true;
          _syncLocalCartItem(
            partyid: partyid,
            itemCd: itemCd,
            qty: qty,
            otherDesc: otherDesc,
            lrate: lrate,
            rate: rate,
            nrate: nrate,
            remarks: remarks,
          );
          print(
              '[OFFLINE_DB] ✅ Item $itemCd successfully saved to local DB (OFFLINE mode)');
          AppSnackBar.showGetXCustomSnackBar(
            message: "Item added (offline - will sync)",
            backgroundColor: Colors.orange,
            enforceNetworkMessage: false,
          );
          log("Item $itemCd saved to local cart (offline fallback)");
        } catch (e) {
          print('[OFFLINE_DB] ❌ Failed to save offline: $e');
          log("Error saving to local cart: $e");
          AppSnackBar.showGetXCustomSnackBar(
            message: "Failed to add item to cart",
            enforceNetworkMessage: false,
          );
        }
      } else {
        // Other DIO error (not network related)
        log("DIO Error in addItemToCart: $dioError");
        AppSnackBar.showGetXCustomSnackBar(
          message: "Failed to add item to cart: ${dioError.message}",
          enforceNetworkMessage: false,
        );
      }
    } catch (e) {
      // Generic error
      log("Error in addItemToCart: $e");
      AppSnackBar.showGetXCustomSnackBar(
        message: "Failed to add item to cart",
        enforceNetworkMessage: false,
      );
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
