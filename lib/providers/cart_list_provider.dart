import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../helper/network_helper.dart';
import '../models/cartListModal.dart';
import '../services/cart_service.dart';
import '../services/database_helper.dart';
import '../views/loginpage.dart';

class CartListProvider extends DisposableProvider {
  final List<DatumCartList> _data = [];

  // List<DatumCartList> data2 = [];
  List<DatumCartList> get data => _data;

  void upsertLocalCartItem(DatumCartList item) {
    final existingIndex = _data.indexWhere(
      (element) => element.itemCd.toString() == item.itemCd.toString(),
    );

    if (existingIndex >= 0) {
      _data[existingIndex] = item;
    } else {
      _data.add(item);
    }

    notifyListeners();
  }

  // Future getCartItem(BuildContext context, String? partyId) async {
  //   final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
  //
  //   if (partyId == null) {
  //     _data.clear();
  //   } else {
  //     try {
  //       final http.Response response = await http.get(
  //         Uri.parse("${AppConfig.baseURL}cart?partyCd=$partyId"),
  //         headers: {
  //           "Authorization": "Bearer ${ub.token}",
  //           'x-app-type': 'oms',
  //         },
  //       );
  //       print("${AppConfig.baseURL}cart?partyCd=$partyId");
  //       print("Bearer ${ub.token}");
  //       if (response.statusCode == 200) {
  //         // data2.clear();
  //         // data2.addAll(cartListModalFromJson(response.body).data);
  //         _data.clear();
  //         _data.addAll(cartListModalFromJson(response.body).data);
  //
  //         // data2.clear();
  //       } else {
  //         ub.userSignout(context).then((value) {
  //           Get.offAll(() => LoginPage());
  //         });
  //       }
  //     } catch (e, stack) {
  //       CrashlyticsService.recordNonFatal(e, stack);
  //       //Fluttertoast.showToast(msg: "Something went wrong");
  //       AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
  //     }
  //   }
  // }

  double _effectiveRate(dynamic rate, dynamic lrate, dynamic nrate) {
    double parseValue(dynamic value) =>
        double.tryParse(value?.toString() ?? '') ?? 0.0;

    final rateValue = parseValue(rate);
    if (rateValue > 0) return rateValue;

    final lrateValue = parseValue(lrate);
    if (lrateValue > 0) return lrateValue;

    return parseValue(nrate);
  }

  double _effectiveProductRate(Map<String, dynamic> product) {
    return _effectiveRate(
      product['nrate'],
      product['srate1'],
      product['prate'],
    );
  }

  Future getCartItem(BuildContext context, String? partyId) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    if (partyId == null) {
      _data.clear();
      notifyListeners();
      return;
    }

    // 📡 Optimistic loading: Try API first with timeout (no pre-flight check)
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}cart?partyCd=$partyId"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        _data.clear();
        final serverItems = cartListModalFromJson(response.body).data;
        _data.addAll(serverItems);

        print(
            "[CART_PROVIDER-ONLINE] GET ${AppConfig.baseURL}cart?partyCd=$partyId");
        print('[CART_PROVIDER-ONLINE] 🌐 API RESPONSE 200:');
        print(
            '[CART_PROVIDER-ONLINE]   Items in response: ${serverItems.length}');
        for (var item in serverItems) {
          int qty = (item.quantity as num?)?.toInt() ?? 0;
          print(
              '[CART_PROVIDER-ONLINE]   - ItemCd: ${item.itemCd}, Qty: $qty, Amount: ${item.amount}');
        }

        // ✅ Update UI immediately with server data
        notifyListeners();

        // 📱 Sync server cart → local SQLite in BACKGROUND (non-blocking)
        Future.microtask(() async {
          try {
            final dbHelper = DatabaseHelper();
            print(
                '[CART_PROVIDER-SYNC] 🔄 CLEARING LOCAL DB FOR PARTY: $partyId');
            await dbHelper.clearCartForParty(partyId);

            print(
                '[CART_PROVIDER-SYNC] 📥 RE-INSERTING ${serverItems.length} ITEMS:');
            for (var item in serverItems) {
              int qty = (item.quantity as num?)?.toInt() ?? 0;
              final effectiveRate = _effectiveRate(
                item.rate,
                item.lrate,
                item.item?.nrate,
              );
              final effectiveNRate =
                  double.tryParse(item.item?.nrate?.toString() ?? '') ??
                      effectiveRate;
              print(
                  '[CART_PROVIDER-SYNC]   - Inserting ItemCd: ${item.itemCd}, Qty: $qty');
              await CartService().addToCart(
                partyCd: partyId,
                itemCd: item.itemCd?.toString() ?? '',
                quantity:
                    double.tryParse(item.quantity?.toString() ?? '0') ?? 0,
                rate: effectiveRate,
                nrate: effectiveNRate,
                lrate: double.tryParse(item.lrate?.toString() ?? '') ??
                    effectiveRate,
                amount: item.amount ?? 0,
                otherDesc: item.otherDesc?.toString() ?? '',
                fld5: item.fld5?.toString() ?? '',
                itemName: item.item?.itemName?.toString() ?? '',
                syncStatus: 'synced',
              );
            }
            print(
                '[CART_PROVIDER-SYNC] ✅ Synced ${serverItems.length} server cart items → local DB (background)');
          } catch (syncErr) {
            print(
                '[CART_PROVIDER-SYNC] ❌ Error syncing server cart to local: $syncErr');
            // Silently fail - UI already has server data
          }
        });
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      // If server fails, try loading from local DB as fallback
      try {
        final localCart = await DatabaseHelper().getCartItems(partyId: partyId);
        if (localCart.isNotEmpty) {
          _data.clear();
          final dbHelper = DatabaseHelper();
          for (var item in localCart) {
            try {
              final enriched = Map<String, dynamic>.from(item);
              final cachedProduct = await dbHelper.getCachedProductByItemCd(
                enriched['item_cd']?.toString() ?? '',
                itemName: enriched['item_name']?.toString() ?? '',
              );

              if (cachedProduct != null) {
                final fallbackRate = _effectiveRate(
                  enriched['rate'],
                  enriched['lrate'],
                  enriched['nrate'],
                );
                final cachedRate = _effectiveProductRate(cachedProduct);
                final effectiveRate =
                    fallbackRate > 0 ? fallbackRate : cachedRate;

                if (_effectiveRate(enriched['rate'], enriched['lrate'],
                        enriched['nrate']) <=
                    0) {
                  enriched['rate'] = effectiveRate;
                  enriched['lrate'] = effectiveRate;
                  enriched['nrate'] = effectiveRate;
                }

                if (((enriched['amount'] as num?)?.toDouble() ?? 0.0) <= 0) {
                  final qty = double.tryParse(
                        enriched['quantity']?.toString() ?? '0',
                      ) ??
                      0.0;
                  if (qty > 0 && effectiveRate > 0) {
                    enriched['amount'] = qty * effectiveRate;
                  }
                }

                if ((enriched['item_name']?.toString() ?? '').isEmpty) {
                  enriched['item_name'] = cachedProduct['item_name'] ?? '';
                }
              }

              _data.add(DatumCartList.fromLocal(enriched));
            } catch (_) {}
          }
          print("Loaded ${_data.length} items from local fallback");
          notifyListeners();
          return;
        }
      } catch (_) {}
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
    }
  }

  // NEW: Offline-first add to cart
  // Future<void> addToCartItem(BuildContext context, {
  //   required String productId,        // change to int if possible (see DB fix below)
  //   required int quantity,
  //   required double price,
  //   required String serverProductId,
  //   required String? partyId,
  // }) async {
  //   final bool online = await NetworkHelper.hasInternet();
  //
  //   try {
  //     // Always update local DB (optimistic + required for offline orders)
  //     await CartService().addToCart(
  //       productId: productId,
  //       quantity: quantity,
  //       price: price,
  //       serverProductId: serverProductId,
  //     );
  //
  //     if (online) {
  //       // TODO: Replace with YOUR actual server add-to-cart API call
  //       // final response = await http.post(... "${AppConfig.baseURL}cart/add" ...);
  //       // if (response.statusCode != 200) {
  //       //   // Optional: rollback local or mark as pending
  //       // }
  //       CartController cartController;
  //       try {
  //         await cartController
  //             .addItemToCart(
  //           itemCd: widget.product.itemCd,
  //           partyid: controller.selectedPartyId.value,
  //           qty: itemQty,
  //           otherDesc: selectedFreeDescription,
  //           lrate: rateController.text.trim(),
  //           rate: rateController.text.trim(),
  //           remarks: selectedRemark,
  //         )
  //             .then((value) =>
  //         {
  //           quantityController.clear(),
  //           rateController.clear(),
  //           qtyController.clear(),
  //           freeQtyController.clear(),
  //           remarkController.clear(),
  //         });
  //
  //         // Set product as added
  //         cartController.productAddedStates[widget.product.itemCd] = true;
  //
  //         // Increment cart count without triggering full rebuild
  //         cartController.cartCount.value++;
  //
  //         // Sync cart data in background without clearing states
  //         if (controller.selectedPartyId.isNotEmpty) {
  //           cart
  //               .getCartItem(
  //               Get.context!, controller.selectedPartyId.value)
  //               .then((_) {
  //             // Silently update states without triggering rebuild
  //             for (var item in cart.data) {
  //               if (!cartController.productAddedStates
  //                   .containsKey(item.itemCd)) {
  //                 cartController.productAddedStates[item.itemCd] = true;
  //               }
  //             }
  //             // Update cart count accurately
  //             cartController.cartCount.value =
  //                 cartController.productAddedStates.length;
  //
  //             print(cartController.cartCount.value);
  //
  //             // Hide keyboard
  //             FocusManager.instance.primaryFocus?.unfocus();
  //
  //             WidgetsBinding.instance.addPostFrameCallback((_) {
  //               Future.delayed(const Duration(milliseconds: 100), () {
  //                 if (Get.context != null) {
  //                   FocusScope.of(Get.context!).requestFocus(controller.focusNode);
  //                 }
  //               });
  //             });
  //           });
  //         }
  //       } catch (e) {
  //         //showToast("Error adding product: $e");
  //         AppSnackBar.showGetXCustomSnackBar(
  //             message: "Error adding product: $e");
  //       } finally {
  //         // Set loading state to false
  //         cartController.productLoadingStates[widget.product.itemCd] =
  //         false;
  //       }
  //     }
  //
  //     // Refresh list — getCartItem already knows online/offline
  //     await getCartItem(context, partyId);
  //
  //     if (!online) {
  //       AppSnackBar.showGetXCustomSnackBar(
  //         message: 'Item added to cart (offline mode)',
  //         backgroundColor: Colors.orange,
  //       );
  //     }
  //   } catch (e, stack) {
  //     CrashlyticsService.recordNonFatal(e, stack);
  //     AppSnackBar.showGetXCustomSnackBar(
  //       message: online ? 'Something went wrong' : 'Failed to add item offline',
  //     );
  //   }
  // }

// NEW: Update quantity
  Future<void> updateCartItemQuantity(BuildContext context, int cartItemId,
      int newQuantity, String? partyId) async {
    final bool online = await NetworkHelper.hasInternet();

    try {
      await CartService().updateCartItemQuantity(cartItemId, newQuantity);

      if (online) {
        // TODO: Your server update API call here
      }

      await getCartItem(context, partyId);
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
    }
  }

// NEW: Remove item
  Future<void> removeCartItem(
      BuildContext context, int cartItemId, String? partyId) async {
    final bool online = await NetworkHelper.hasInternet();

    try {
      await CartService().removeCartItem(cartItemId);

      if (online) {
        // TODO: Your server remove API call here
      }

      await getCartItem(context, partyId);
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
    }
  }

  /// Clear cart data in memory and notify listeners
  void clearData() {
    _data.clear();
    notifyListeners();
    print('[CART_PROVIDER] Cleared in-memory cart data');
  }

  @override
  disposeValues() {
    _data.clear();
    notifyListeners();
  }
}
