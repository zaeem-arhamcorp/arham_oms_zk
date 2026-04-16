import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../helper/network_helper.dart';
import '../models/cartListModal.dart';
import 'package:http/http.dart' as http;

import '../services/cart_service.dart';
import '../services/database_helper.dart';
import '../views/loginpage.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';

class CartListProvider extends DisposableProvider {
  final List<DatumCartList> _data = [];

  // List<DatumCartList> data2 = [];
  List<DatumCartList> get data => _data;

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
  Future getCartItem(BuildContext context, String? partyId) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    if (partyId == null) {
      _data.clear();
      notifyListeners();
      return;
    }

    bool online = await NetworkHelper.hasInternet();

    if (!online) {
      // Load from local database when offline
      try {
        // Filter cart items by current party
        final localCart = await DatabaseHelper().getCartItems(partyId: partyId);
        print(
            "Loaded ${localCart.length} items from offline cart for party $partyId (before dedup)");

        _data.clear();

        // Map to track unique items by item_cd to prevent duplicates
        final Map<String, DatumCartList> uniqueItems = {};

        // Map each item with detailed error handling
        for (var item in localCart) {
          try {
            final cartItem = DatumCartList.fromLocal(item);
            final itemCd = item['item_cd'] ?? 'UNKNOWN';

            // If item already exists, update quantity instead of adding duplicate
            if (uniqueItems.containsKey(itemCd)) {
              final existing = uniqueItems[itemCd]!;
              // Update quantity by adding the quantities
              existing.quantity =
                  (existing.quantity ?? 0) + (cartItem.quantity ?? 0);
              existing.amount =
                  ((existing.amount ?? 0) + (cartItem.amount ?? 0)).toDouble();
              print("Merged duplicate item: $itemCd");
            } else {
              uniqueItems[itemCd] = cartItem;
              print("Added offline cart item: $itemCd");
            }
          } catch (itemError) {
            print(
                "Error converting cart item ${item['item_cd']}: $itemError. Item data: $item");
            // Continue with next item instead of crashing
          }
        }

        _data.addAll(uniqueItems.values);
        print("Successfully loaded ${_data.length} UNIQUE items to UI");
      } catch (e, stack) {
        print("Error loading offline cart: $e");
        print("Stack trace: $stack");
        _data.clear();
      }
      notifyListeners();
      return;
    }

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}cart?partyCd=$partyId"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        _data.clear();
        final serverItems = cartListModalFromJson(response.body).data;
        _data.addAll(serverItems);

        // Sync server cart → local SQLite so data persists if we go offline
        try {
          final dbHelper = DatabaseHelper();
          await dbHelper.clearCartForParty(partyId);
          for (var item in serverItems) {
            await CartService().addToCart(
              partyCd: partyId,
              itemCd: item.itemCd?.toString() ?? '',
              quantity: double.tryParse(item.quantity?.toString() ?? '0') ?? 0,
              rate: double.tryParse(item.rate?.toString() ?? '0') ?? 0,
              nrate: double.tryParse(item.item?.nrate?.toString() ?? '0') ?? 0,
              lrate: double.tryParse(item.lrate?.toString() ?? '0') ?? 0,
              amount: item.amount ?? 0,
              otherDesc: item.otherDesc?.toString() ?? '',
              fld5: item.fld5?.toString() ?? '',
              itemName: item.item?.itemName?.toString() ?? '',
            );
          }
          print("Synced ${serverItems.length} server cart items → local DB");
          print("SYNCED ITEMS TO LOCAL DB: \n$serverItems");
        } catch (syncErr) {
          print("Error syncing server cart to local: $syncErr");
        }

        notifyListeners();
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
          for (var item in localCart) {
            try {
              _data.add(DatumCartList.fromLocal(item));
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

  @override
  disposeValues() {
    _data.clear();
    notifyListeners();
  }
}
