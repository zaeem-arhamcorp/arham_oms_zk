import 'dart:convert';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/generated/assets.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import 'package:arham_corporation/models/narrationModal.dart';
import 'package:arham_corporation/product/controller/cart_controller.dart';
import 'package:arham_corporation/product/controller/product_controller.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/cart_list_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:arham_corporation/services/order_tracking_service.dart';
import 'package:arham_corporation/views/orderConformationPage.dart';
import 'package:arham_corporation/views/productDetailPage.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:arham_corporation/widgets/offline_banner.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:arham_corporation/services/offline_order_service.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hive/hive.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import '../constants/constants.dart';
import '../models/cartListModal.dart';
import '../models/ordermodal.dart';
import '../models/partynameModal.dart';
import '../models/settingmodal.dart';
import '../providers/party_provider.dart';
import '../services/services.dart';

class ShoppingCartPage extends StatefulWidget {
  const ShoppingCartPage({Key? key}) : super(key: key);

  @override
  State<ShoppingCartPage> createState() => _ShoppingCartPageState();
}

class _ShoppingCartPageState extends State<ShoppingCartPage> {
  List<DatumCartList> datacart = [];
  List<DatumCartList> _originalData = [];

  //List<DatumItemWisePartyWise> data = [];

  bool noPartyName = false;
  bool nolist = false;

  // List<TextEditingController> qty = [];
  // List<TextEditingController> freeQty = [];
  // List<TextEditingController> rate = [];
  // List<TextEditingController> remarks = [];

  Map<String, TextEditingController> qty = {};
  Map<String, TextEditingController> freeQty = {};
  Map<String, TextEditingController> rate = {};
  Map<String, TextEditingController> remarks = {};

  var netAmount = "0";
  var totalFreeQty = "0";
  var totalQty = "0";

  TextEditingController orderRemarks = TextEditingController();

  List<DatumNarration> otherDescOptions = [];
  List<DatumNarration> fld5DescOptions = [];
  List<DatumNarration> narrationOptions = [];

  bool loading = false;

  deleteCartItem(cartid, itemCd) async {
    setState(() {
      loading = true;
    });

    bool online = await NetworkHelper.hasInternet();

    if (online) {
      // Online: delete from server + local
      Services()
          .deleteItemtoCart(cartid.toString(), context)
          .then((value) async {
        if (value != null) {
          AppSnackBar.showGetXCustomSnackBar(
              message: value, backgroundColor: Colors.green);

          // Also delete from local DB
          try {
            final PartyProvider party =
                Provider.of<PartyProvider>(context, listen: false);
            final ProfileProvider profile =
                Provider.of<ProfileProvider>(context, listen: false);
            String partyId = (profile.data?.profileSettings.any(
                        (e) => e.variable == 'punchInOut' && e.value == 'Y') ??
                    false)
                ? party.punchInOutPartyId
                : party.partyid;
            await DatabaseHelper()
                .deleteCartItemByItemCd(itemCd.toString(), partyId);
          } catch (e) {
            print("Error deleting local cart item: $e");
          }

          setState(() {
            loading = false;
          });
          getCart();
          CartController controller = Get.put(CartController());
          controller.removeProductLocally(itemCd);
        } else {
          setState(() {
            loading = false;
          });
          AppSnackBar.showGetXCustomSnackBar(message: "Something Went Wong");
        }
      });
    } else {
      // Offline: delete from local DB only
      try {
        final PartyProvider party =
            Provider.of<PartyProvider>(context, listen: false);
        final ProfileProvider profile =
            Provider.of<ProfileProvider>(context, listen: false);
        String partyId = (profile.data?.profileSettings
                    .any((e) => e.variable == 'punchInOut' && e.value == 'Y') ??
                false)
            ? party.punchInOutPartyId
            : party.partyid;
        await DatabaseHelper()
            .deleteCartItemByItemCd(itemCd.toString(), partyId);

        AppSnackBar.showGetXCustomSnackBar(
            message: "Item removed (offline)", backgroundColor: Colors.orange);
        setState(() {
          loading = false;
        });
        getCart();
        CartController controller = Get.put(CartController());
        controller.removeProductLocally(itemCd);
      } catch (e) {
        setState(() {
          loading = false;
        });
        AppSnackBar.showGetXCustomSnackBar(message: "Failed to remove item");
      }
    }
  }

  getOptions() {
    Services().getNarration(context, "OTHER_DESC").then((value) {
      if (value != null) {
        setState(() {
          otherDescOptions.addAll(value.map((e) => DatumNarration(
                NARR_NAME: e.NARR_NAME,
                NARR_TYPE: e.NARR_TYPE,
                SYNC_ID: e.SYNC_ID,
              )));
        });
      } else {
        print("Error: OTHER_DESC returned null.");
      }
    }).catchError((error) {
      print("Error fetching OTHER_DESC: $error");
    });

    Services().getNarration(context, "FLD5").then((value) {
      if (value != null) {
        setState(() {
          fld5DescOptions.addAll(value.map((e) => DatumNarration(
                NARR_NAME: e.NARR_NAME,
                NARR_TYPE: e.NARR_TYPE,
                SYNC_ID: e.SYNC_ID,
              )));
        });
      } else {
        print("Error: FLD5 returned null.");
      }
    }).catchError((error) {
      print("Error fetching FLD5: $error");
    });

    Services().getNarration(context, "NARRATION").then((value) {
      if (value != null) {
        setState(() {
          narrationOptions.addAll(value.map((e) => DatumNarration(
                NARR_NAME: e.NARR_NAME,
                NARR_TYPE: e.NARR_TYPE,
                SYNC_ID: e.SYNC_ID,
              )));
        });
      } else {
        print("Error: NARRATION returned null.");
      }
    }).catchError((error) {
      print("Error fetching NARRATION: $error");
    });
  }

  getCart() {
    setState(() {
      loading = false;
      nolist = false;
      datacart.clear();
      qty.clear();
      noPartyName = false;
      freeQty.clear();
    });
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    final CartListProvider cart =
        Provider.of<CartListProvider>(context, listen: false);

    final ProfileProvider profile =
        Provider.of<ProfileProvider>(context, listen: false);
    setState(() {
      noPartyName = false;
      // if (profile.data?.profileSettings
      //             .firstWhere((element) => element.variable == 'punchInOut')
      //             .value ==
      //         'N' &&
      //     party.party == "")
      if ((profile.data?.profileSettings
                  .any((e) => e.variable == 'punchInOut' && e.value == 'N') ??
              false) &&
          (party.party.isEmpty)) {
        print("55555555");
        noPartyName = true;
      }
      // else if (profile.data?.profileSettings
      //             .firstWhere((element) => element.variable == 'punchInOut')
      //             .value ==
      //         'Y' &&
      //     party.punchInOutParty == "")
      else if ((profile.data?.profileSettings
                  .any((e) => e.variable == 'punchInOut' && e.value == 'Y') ??
              false) &&
          (party.punchInOutParty.isEmpty)) {
        print("llllllll");
        noPartyName = true;
      } else {
        print("111111");

        cart
            .getCartItem(
                context,
                // profile.data?.profileSettings
                //             .firstWhere(
                //                 (element) => element.variable == 'punchInOut')
                //             .value ==
                //         'Y'
                profile.data?.profileSettings.any((e) =>
                            e.variable == 'punchInOut' && e.value == 'Y') ??
                        false
                    ? party.punchInOutPartyId
                    : party.partyid)
            .then((value) {
          setState(() {
            //datacart.addAll(cart.data); //TODO : FAZAL COMMENT 13/03/2025
            _originalData = cart.data; // Store the original data
            datacart = List.from(
                _originalData); // Set the displayed data to the original
            //data.addAll(value.data);
            // datacart.forEach((element) {
            //   qty.add(TextEditingController(text: element.quantity.toString()));
            //   freeQty.add(TextEditingController(
            //       text: element.otherDesc != null
            //           ? element.otherDesc.toString()
            //           : ""));
            //   if (profile.data?.profileSettings
            //               .firstWhere((element) =>
            //                   element.variable == 'editMasterRateSettings')
            //               .value ==
            //           'Y' ||
            //       profile.data?.profileSettings
            //               .firstWhere((element) =>
            //                   element.variable == 'editOperatorRateSettings')
            //               .value ==
            //           'Y') {
            //     rate.add(TextEditingController(text: element.rate.toString()));
            //   }
            //   if (profile.data?.profileSettings
            //           .firstWhere((element) =>
            //               element.variable == 'showItemWiseRemarks')
            //           .value ==
            //       'Y') {
            //     remarks.add(TextEditingController(
            //         text: element.fld5 != null ? element.fld5.toString() : ""));
            //   }
            // });

            var editMasterRate = profile.data?.profileSettings
                .firstWhere(
                  (e) => e.variable == 'editMasterRateSettings',
                  orElse: () => DatumSettings(), // Return null if not found
                )
                .value;

            var editOperatorRate = profile.data?.profileSettings
                .firstWhere(
                  (e) => e.variable == 'editOperatorRateSettings',
                  orElse: () => DatumSettings(),
                )
                .value;

            var showItemRemarks = profile.data?.profileSettings
                .firstWhere(
                  (e) => e.variable == 'showItemWiseRemarks',
                  orElse: () => DatumSettings(),
                )
                .value;

            for (var element in datacart) {
              qty[element.itemCd] =
                  TextEditingController(text: element.quantity.toString());
              freeQty[element.itemCd] =
                  TextEditingController(text: element.otherDesc ?? '');

              // if (profile.data?.profileSettings
              //             .firstWhere(
              //                 (e) => e.variable == 'editMasterRateSettings')
              //             .value ==
              //         'Y' ||
              //     profile.data?.profileSettings
              //             .firstWhere(
              //                 (e) => e.variable == 'editOperatorRateSettings')
              //             .value ==
              //         'Y') {
              //   rate[element.itemCd] =
              //       TextEditingController(text: element.rate.toString());
              // }

              if (editMasterRate == 'Y' || editOperatorRate == 'Y') {
                rate[element.itemCd] =
                    TextEditingController(text: element.rate.toString());
              }

              //TODO : lRateSetting
              // if(profile.data?.profileSettings
              //             .firstWhere(
              //                 (e) => e.variable == 'lrateSetting')
              //             .value ==
              //         'Y'){
              //     rate[element.itemCd] =
              //         TextEditingController(text: element.lrate.toString());
              // }else{
              //   if (profile.data?.profileSettings
              //       .firstWhere(
              //           (e) => e.variable == 'editMasterRateSettings')
              //       .value ==
              //       'Y' ||
              //       profile.data?.profileSettings
              //           .firstWhere(
              //               (e) => e.variable == 'editOperatorRateSettings')
              //           .value ==
              //           'Y') {
              //     rate[element.itemCd] =
              //         TextEditingController(text: element.rate.toString());
              //   }
              // }

              // if (profile.data?.profileSettings
              //         .firstWhere((e) => e.variable == 'showItemWiseRemarks')
              //         .value ==
              //     'Y') {
              //   remarks[element.itemCd] =
              //       TextEditingController(text: element.fld5 ?? '');
              // }

              if (showItemRemarks == 'Y') {
                remarks[element.itemCd] =
                    TextEditingController(text: element.fld5 ?? '');
              }
            }
            netAmount = datacart
                .fold(
                    0.0,
                    (previousValue, element) =>
                        previousValue + double.parse(element.amount.toString()))
                .toPrecision(2)
                .toString();
            // totalFreeQty = datacart
            //     .fold(
            //         0,
            //         (previousValue, element) =>
            //             previousValue + int.parse(element.otherDesc.toString()))
            //     .toString();
            totalQty = datacart.fold(0, (previousValue, element) {
              // Safely parse quantity - handle both "15" and "15.0"
              final qtyStr = element.quantity.toString().trim();
              final qtyDouble = double.tryParse(qtyStr) ?? 0.0;
              return previousValue + qtyDouble.toInt();
            }).toString();
          });
          if (datacart.isEmpty) {
            setState(() {
              //nolist = true;

              if (datacart.isEmpty) {
                nolist = true;
              } else {
                nolist = false;
              }
            });
          }
        });
      }
    });
  }

  updateitemtoCart(itemCd, qty, freeQty, rate, lrate, remarks, cid) {
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    final ProfileProvider profile =
        Provider.of<ProfileProvider>(context, listen: false);
    if (profile.YN == "Y" && party.punchInOutParty == "") {
      //Fluttertoast.showToast(msg: "Please select party first");
      AppSnackBar.showGetXCustomSnackBar(message: "Please select party first");
    } else if (profile.YN == "N" && party.party == "") {
      //Fluttertoast.showToast(msg: "Please select party first");
      AppSnackBar.showGetXCustomSnackBar(message: "Please select party first");
    } else {
      String partiID =
          Get.arguments?['PartyID']; //FAZAL ADD MyAPP BAR PASS ARGUMENT
      print(partiID);
      Services()
          .updateItemtoCart(
              //party.partyid.isEmpty ? party.partyid : partiID,
              //party.partyid,
              profile.YN == 'Y' ? party.punchInOutPartyId : party.partyid,
              itemCd,
              qty.toString(),
              freeQty.toString(),
              context,
              rate.toString(),
              lrate.toString(),
              remarks,
              cid.toString())
          .then((value) {
        if (value != null) {
          // Fluttertoast.showToast(msg: value);
          // getCart();
        } else {
          //Fluttertoast.showToast(msg: "Something Went Wong");
          AppSnackBar.showGetXCustomSnackBar(message: "Something Went Wong");
        }
      });
    }
  }

  TextEditingController searchPartyClt = TextEditingController();
  List _tempParty = [];

  showMenu() {
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);
    pp.getpartyname(context);
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(25.0),
          ),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            top: false,
            child: Consumer<PartyProvider>(
              builder: (context, party, child) {
                return StatefulBuilder(
                    builder: (context, StateSetter setStatee) {
                  return Padding(
                    padding: MediaQuery.of(context).viewInsets,
                    child: Container(
                      height: 450,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 20.0, bottom: 14.0, top: 20.0),
                                child: Text("Select Party:",
                                    style: TextStyle(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CupertinoSearchTextField(
                                    controller: searchPartyClt,
                                    onChanged: (value) {
                                      //4
                                      setStatee(() {
                                        _tempParty = Helper.buildSearchList(
                                            value, party);
                                      });
                                    }),
                              ),
                            ],
                          ),
                          Expanded(
                            child: party.nolistParty == true
                                ? Center(
                                    child: Text("No List"),
                                  )
                                : party.data.isEmpty
                                    ? Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : ListView.builder(
                                        itemCount: (_tempParty.length > 0)
                                            ? _tempParty.length
                                            : party.data.length,
                                        itemBuilder: (builder, index) {
                                          return InkWell(
                                            onTap: () async {
                                              if (p.data?.profileSettings
                                                      .firstWhere((element) =>
                                                          element.variable ==
                                                          'punchInOut')
                                                      .value ==
                                                  'Y') {
                                                await party
                                                    .changePunchInOutParty(
                                                        (_tempParty.length > 0)
                                                            ? _tempParty[index]
                                                                .accName
                                                            : party.data[index]
                                                                .accName,
                                                        (_tempParty.length > 0)
                                                            ? _tempParty[index]
                                                                .accCd
                                                            : party.data[index]
                                                                .accCd,
                                                        context);
                                              } else {
                                                await party.changeParty(
                                                    (_tempParty.length > 0)
                                                        ? _tempParty[index]
                                                            .accName
                                                        : party.data[index]
                                                            .accName,
                                                    (_tempParty.length > 0)
                                                        ? _tempParty[index]
                                                            .accCd
                                                        : party
                                                            .data[index].accCd,
                                                    context);
                                              }
                                              Get.back();
                                              getCart();
                                            },
                                            child: (_tempParty.length > 0)
                                                ? Helper
                                                    .showPartyBottomSheetWithSearch(
                                                        index, _tempParty)
                                                : Helper
                                                    .showPartyBottomSheetWithSearch(
                                                        index, party.data),
                                          );
                                        }),
                          )
                        ],
                      ),
                    ),
                  );
                });
              },
            ),
          );
        });
  }

  Ordermodal? orders;
  List<OrderItm> ordersItems = [];
  TextEditingController searchItemClt = TextEditingController();
  FocusNode _focusNode = FocusNode(); // Create a focus node for the text field

  late CartListProvider cart;

  late final ProductController controller =
      Get.isRegistered<ProductController>()
          ? Get.find<ProductController>()
          : Get.put(ProductController());
  late final CartController cartController = Get.isRegistered<CartController>()
      ? Get.find<CartController>()
      : Get.put(CartController());

  void calculateNetAmount() {
    // Ensure all amounts are summed up correctly as doubles
    double total = datacart.fold(0.0,
        (sum, item) => sum + (item.amount ?? 0.0)); // Safely sum the amounts
    setState(() {
      netAmount =
          total.toStringAsFixed(2); // Convert total to String for display
    });
  }

  @override
  void dispose() {
    searchItemClt
        .dispose(); // Dispose the controller when the widget is disposed
    _focusNode.dispose(); // Dispose the focus node
    super.dispose();
  }

  void searchData(String searchValue) {
    if (searchValue.isEmpty) {
      // Reset the data if search is cleared
      setState(() {
        datacart = List.from(_originalData); // Show all data again
      });
    } else {
      // Filter the data based on search value
      setState(() {
        datacart = _originalData.where((product) {
          return product.itemCd
                  .toLowerCase()
                  .contains(searchValue.toLowerCase()) ||
              product.item!.itemName
                  .toLowerCase()
                  .contains(searchValue.toLowerCase());
        }).toList();
      });
    }
  }

  @override
  void initState() {
    cart = Provider.of<CartListProvider>(context, listen: false);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // When focus is gained, set selection to the end (so the cursor is at the end of the text)
        //searchClt.selection =
        //    TextSelection.collapsed(offset: searchClt.text.length);

        searchItemClt.selection = TextSelection(
            baseOffset: 0, extentOffset: searchItemClt.text.length);
      }
    });

    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    _tempParty = Helper.buildSearchList("Cart Item", party);

    // if (p.data?.profileSettings
    //             .firstWhere((element) => element.variable == 'punchInOut')
    //             .value ==
    //         'N' &&
    //     party.party != "") {
    //   getCart();
    //   getOptions();
    // } else if (p.data?.profileSettings
    //             .firstWhere((element) => element.variable == 'punchInOut')
    //             .value ==
    //         'Y' &&
    //     party.punchInOutParty != "") {
    //   getCart();
    //   getOptions();
    // }

    if ((p.data?.profileSettings
                .any((e) => e.variable == 'punchInOut' && e.value == 'N') ??
            false) &&
        (party.party.isNotEmpty)) {
      getCart();
      getOptions();
    } else if ((p.data?.profileSettings
                .any((e) => e.variable == 'punchInOut' && e.value == 'Y') ??
            false) &&
        (party.punchInOutParty.isNotEmpty)) {
      getCart();
      getOptions();
    } else {
      print('call this way');
      getCart();
      getOptions();
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final PartyProvider party = context.watch<PartyProvider>();
    final ProfileProvider profile =
        Provider.of<ProfileProvider>(context, listen: false);
    return WillPopScope(
      onWillPop: () async {
        // final CartProvider cart = Provider.of<CartProvider>(context, listen: false);
        // ProductController controller = Get.put(ProductController());
        // if (controller.selectedPartyId.value.isNotEmpty) {
        //   print("Fetching cart items before leaving...");
        //   await cart.getCartItem(context, controller.selectedPartyId.value);
        // }

        //Get.back(result: true); // This will send 'true' as a result

        if (controller.selectedPartyId.isNotEmpty) {
          cartController.productAddedStates.clear(); // Clear previous state

          await cart.getCartItem(
              Get.context!, controller.selectedPartyId.value);

          // Update state based on fetched cart data
          for (var item in cart.data) {
            cartController.productAddedStates[item.itemCd] = true;
          }

          cartController.update();

          cartController.cartCount.value =
              cartController.productAddedStates.length;

          print(cartController.cartCount.value);
        }

        return true; // Allows back navigation
      },
      child: Scaffold(
        bottomNavigationBar: SafeArea(
          top: false,
          //bottom: true,
          child: Container(
            padding: EdgeInsets.only(
                top: 10.h, left: 15.h, bottom: 10.h, right: 15.h),
            height: 120.h,
            width: size.width,
            decoration: BoxDecoration(
              color: Colors.white,
              //color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),

              //Additional add
              // Top border only
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE0E0E0), // light grey
                  width: 1,
                ),
              ),

              //Additional add
              // Shadow coming from top (not bottom)
              // boxShadow: const [
              //   BoxShadow(
              //     color: Colors.black12,
              //     blurRadius: 8,
              //     spreadRadius: 0,
              //     offset: Offset(0, -2), // shadow upwards
              //   ),
              // ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Approx Value (${datacart.length} item) ($totalQty Qty)",
                  style:
                      TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500),
                ),
                SizedBox(
                  height: 5.h,
                ),
                Text(
                  "Rs.$netAmount",
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownMenu<dynamic>(
                      width: 215.w,
                      controller: orderRemarks,
                      requestFocusOnTap: true,
                      enableFilter: true,
                      label: const Text('Remarks'),
                      dropdownMenuEntries: narrationOptions
                          .map((e) => DropdownMenuEntry<dynamic>(
                              value: e.NARR_NAME, label: e.NARR_NAME))
                          .toList(),
                      inputDecorationTheme: const InputDecorationTheme(
                        isDense: true,
                      ),
                      enableSearch: true,
                      onSelected: (value) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                    ),
                    // Container(
                    //   width: 205.w,
                    //   child: TextFormField(
                    //     keyboardType: TextInputType.text,
                    //     maxLength: 80,
                    //     decoration: InputDecoration(
                    //       label: Text("Remarks"),
                    //       counterText: "",
                    //       isDense: true,
                    //       contentPadding: EdgeInsets.symmetric(vertical: 1.0),
                    //     ),
                    //     controller: orderRemarks,
                    //   ),
                    // ),
                    SizedBox(
                      width: 25.w,
                    ),
                    GestureDetector(
                      onTap: () {
                        if (datacart.length != 0) {
                          setState(() {
                            loading = true;
                          });
                          //TODO : Comment Update Qty At Time Logic
                          // for (var i = 0; i < datacart.length; i++) {
                          //   var tempRate = '';
                          //   var tempRemarks = '';
                          //
                          //   if (profile.data?.profileSettings
                          //               .firstWhere((element) =>
                          //                   element.variable ==
                          //                   'editMasterRateSettings')
                          //               .value ==
                          //           'Y' ||
                          //       profile.data?.profileSettings
                          //               .firstWhere((element) =>
                          //                   element.variable ==
                          //                   'editOperatorRateSettings')
                          //               .value ==
                          //           'Y') {
                          //     tempRate = rate[i].text;
                          //   }
                          //
                          //   if (profile.data?.profileSettings
                          //           .firstWhere((element) =>
                          //               element.variable ==
                          //               'showItemWiseRemarks')
                          //           .value ==
                          //       'Y') {
                          //     tempRemarks = remarks[i].text;
                          //   }
                          //   updateitemtoCart(
                          //       datacart[i].itemCd,
                          //       qty[i].text.toString(),
                          //       freeQty[i].text.toString(),
                          //       // tempRate.isEmpty
                          //       //     ? datacart[i].lrate
                          //       //     : tempRate,//FAZAL CHANGES 12/03/2025
                          //       tempRate,
                          //       datacart[i].lrate != null
                          //           ? datacart[i].lrate
                          //           : '',
                          //       tempRemarks,
                          //       datacart[i].cId);
                          // }
                          datacart.forEach((element) {
                            // ordersItems.add(OrderItm(
                            //     itemCd: element.itemCd,
                            //     //qty: int.parse(element.quantity.toString()),
                            //     qty: (double.tryParse(element.quantity
                            //                 .toString()) ??
                            //             0)
                            //         .toInt(),
                            //     rate:
                            //         double.parse(element.rate.toString()),
                            //     amt: double.parse(
                            //         element.amount.toString()),
                            //     otherDesc: element.otherDesc,
                            //     nrate: double.parse(
                            //         element.item!.nrate.toString())));
                            ordersItems.add(OrderItm(
                              itemCd: element.itemCd,
                              qty: toDouble(element.quantity).toInt(),
                              rate: toDouble(element.rate),
                              amt: toDouble(element.amount),
                              otherDesc: element.otherDesc,
                              nrate: toDouble(element.item?.nrate),
                            ));
                            orders = Ordermodal(
                                partyCd: party.partyid,
                                netAmt: netAmount,
                                orderItm: ordersItems);
                          });
                          var f = ordermodalToJson(orders!);
                          // print(f);
                          _handelAddOrder(f);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.only(left: 10.w, right: 10.w),
                        height: 40.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Color(0xff0A98FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Order Now",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.white,
        appBar: CustomAppBar(
          title: "Shopping Cart",
        ),
        // appBar: AppBar(
        //   elevation: 0,
        //   backgroundColor: Colors.white,
        //   iconTheme: IconThemeData(color: Colors.black),
        //   title: Text(
        //     "Shopping Cart",
        //     style: TextStyle(color: Colors.black),
        //   ),
        // ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Stack(
              children: [
                Container(
                  padding:
                      //EdgeInsets.only(left: 10, right: 10, top: 0, bottom: 120),
                      EdgeInsets.only(left: 10, right: 10, top: 0, bottom: 0),
                  height: size.height,
                  width: size.width,
                  child: Column(
                    children: [
                      OfflineBanner(), // Add offline banner at the top
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Flexible(
                            //   child: Text(
                            //       'Party: ${Helper.trimValue(profile.data?.profileSettings.firstWhere((element) => element.variable == 'punchInOut').value == 'Y' ? party.punchInOutParty : party.party, 25)} '),
                            // ),

                            Flexible(
                              child: Text(
                                'Party: ${Helper.trimValue(
                                  profile.data?.profileSettings
                                              .firstWhere(
                                                (e) =>
                                                    e.variable == 'punchInOut',
                                                orElse: () => DatumSettings(
                                                    variable: '', value: ''),
                                              )
                                              .value ==
                                          'Y'
                                      ? party.punchInOutParty
                                      : party.party,
                                  25,
                                )}',
                              ),
                            ),

                            if (profile.YN == "N")
                              if (profile.ACC_CD == "" &&
                                  profile.ACC_NAME == "")
                                TextButton(
                                    onPressed: showMenu, child: Text("Change"))
                          ],
                        ),
                      ),

                      // IntrinsicHeight(
                      //   child: Row(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //     children: [
                      //       Row(
                      //         children: [
                      //           Icon(Icons.location_on),
                      //           SizedBox(
                      //             width: 5,
                      //           ),
                      //           Column(
                      //             crossAxisAlignment: CrossAxisAlignment.start,
                      //             children: [
                      //               Text.rich(
                      //                 TextSpan(
                      //                     text: "Delivering to : ",
                      //                     style: TextStyle(
                      //                         color: Colors.grey, fontSize: 15.sp),
                      //                     children: [
                      //                       TextSpan(
                      //                         text: "Mick ,308512",
                      //                         style: TextStyle(color: Colors.black),
                      //                       ),
                      //                     ]),
                      //               ),
                      //               Text(
                      //                 "New Gota,Ahmedabad",
                      //                 style: TextStyle(fontSize: 11, color: Colors.grey),
                      //               )
                      //             ],
                      //           ),
                      //         ],
                      //       ),
                      //       Material(
                      //         borderRadius: BorderRadius.circular(8),
                      //         elevation: 5,
                      //         child: Container(
                      //           padding: EdgeInsets.only(left: 5, right: 5),
                      //           alignment: Alignment.center,
                      //           decoration: BoxDecoration(
                      //               color: Color(0xffFFAE37),
                      //               borderRadius: BorderRadius.circular(8)),
                      //           child: Text("Change"),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),

                      CupertinoSearchTextField(
                        controller: searchItemClt,
                        focusNode: _focusNode,
                        onChanged: (value) {
                          searchData(value); // Trigger search on every change
                        },
                        onSuffixTap: () {
                          _focusNode.unfocus(); // Dismiss the keyboard
                          searchItemClt.clear(); // Clear the text field
                          setState(() {
                            datacart = List.from(_originalData);
                          });
                        },
                      ),

                      SizedBox(
                        height: 10,
                      ),
                      Expanded(
                          child:
                              (/*profile.data?.profileSettings
                                              .firstWhere((element) =>
                                                  element.variable ==
                                                  'punchInOut')
                                              .value ==
                                          'Y' &&
                                      party.punchInOutParty == ""*/
                                      (profile.data?.profileSettings.any((e) =>
                                                  e.variable == 'punchInOut' &&
                                                  e.value == 'Y') ??
                                              false) &&
                                          (party.punchInOutParty.isEmpty))
                                  ? Center(
                                      child: Text("Please Select Party First"),
                                    )
                                  : (/*profile.data?.profileSettings
                                                  .firstWhere((element) =>
                                                      element.variable ==
                                                      'punchInOut')
                                                  .value ==
                                              'N' &&
                                          party.party == ""*/
                                          (profile.data?.profileSettings.any(
                                                      (e) =>
                                                          e.variable ==
                                                              'punchInOut' &&
                                                          e.value == 'N') ??
                                                  false) &&
                                              (party.party.isEmpty))
                                      ? Center(
                                          child:
                                              Text("Please Select Party First"),
                                        )
                                      : nolist == true
                                          ? Center(child: Text("No Item Found"))
                                          : datacart.isEmpty &&
                                                  searchItemClt.text.isEmpty
                                              ? Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                )
                                              : Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 0.0),
                                                  //bottom: 35.0),
                                                  child: ListView.builder(
                                                    keyboardDismissBehavior:
                                                        ScrollViewKeyboardDismissBehavior
                                                            .onDrag,
                                                    itemCount: datacart.length,
                                                    shrinkWrap: true,
                                                    itemBuilder:
                                                        (context, index) {
                                                      final showRate = profile
                                                              .data
                                                              ?.profileSettings
                                                              .firstWhere(
                                                                (element) =>
                                                                    element.variable ==
                                                                        'editMasterRateSettings' ||
                                                                    element.variable ==
                                                                        'editOperatorRateSettings',
                                                                orElse: () =>
                                                                    DatumSettings(
                                                                        variable:
                                                                            '',
                                                                        value:
                                                                            'N'),
                                                              )
                                                              .value ==
                                                          'Y';

                                                      // final showRemarks = profile
                                                      //     .data
                                                      //     ?.profileSettings
                                                      //     .firstWhere((element) =>
                                                      // element.variable ==
                                                      //     'showItemWiseRemarks')
                                                      //     .value ==
                                                      //     'Y';

                                                      final showRemarks = profile
                                                              .data
                                                              ?.profileSettings
                                                              .firstWhere(
                                                                (e) =>
                                                                    e.variable ==
                                                                    'showItemWiseRemarks',
                                                                orElse: () =>
                                                                    DatumSettings(
                                                                        variable:
                                                                            '',
                                                                        value:
                                                                            'N'),
                                                              )
                                                              .value ==
                                                          'Y';

                                                      final item =
                                                          datacart[index];
                                                      final itemCd =
                                                          item.itemCd;

                                                      TextEditingController
                                                          qtyController =
                                                          qty[itemCd]!;
                                                      TextEditingController
                                                          freeQtyController =
                                                          freeQty[itemCd]!;
                                                      TextEditingController?
                                                          rateController =
                                                          rate[itemCd];
                                                      TextEditingController?
                                                          remarksController =
                                                          remarks[itemCd];

                                                      var product =
                                                          datacart[index].item;
                                                      // var itemImage =
                                                      //     product?.itemImage;
                                                      // var itemImg = itemImage
                                                      //     ?.itemImg.first;
                                                      var itemImage =
                                                          product?.itemImage;

                                                      var itemImg = (itemImage !=
                                                                  null &&
                                                              itemImage.itemImg
                                                                  .isNotEmpty)
                                                          ? itemImage
                                                              .itemImg.first
                                                          : null;

                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 5),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 5,
                                                                  right: 5,
                                                                  top: 8,
                                                                  bottom: 8),
                                                          decoration:
                                                              BoxDecoration(
                                                            gradient:
                                                                LinearGradient(
                                                              colors: [
                                                                Color(
                                                                    0xffFAD9F1),
                                                                Color(
                                                                    0xffF3C0AD),
                                                              ],
                                                            ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        5),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              GestureDetector(
                                                                onTap: () {
                                                                  if (product !=
                                                                      null) {
                                                                    Get.to(() =>
                                                                        ProductDetailPage(
                                                                            data:
                                                                                product));
                                                                  }
                                                                },
                                                                child:
                                                                    Container(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                            .grey[
                                                                        200],
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(6),
                                                                    border: Border
                                                                        .all(),
                                                                  ),
                                                                  height: 50,
                                                                  width: 50,
                                                                  child: itemImg ==
                                                                          null
                                                                      ? Image.asset(
                                                                          Assets
                                                                              .assetsNopreview,
                                                                          fit: BoxFit
                                                                              .cover)
                                                                      : Image.network(
                                                                          itemImg,
                                                                          fit: BoxFit
                                                                              .cover),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                  width: 10.w),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      children: [
                                                                        Expanded(
                                                                          child:
                                                                              GestureDetector(
                                                                            onTap:
                                                                                () {
                                                                              if (product != null) {
                                                                                Get.to(() => ProductDetailPage(data: product));
                                                                              }
                                                                            },
                                                                            child:
                                                                                Text(
                                                                              "${datacart[index].itemCd} ( MRP : ${datacart[index].rate ?? datacart[index].item?.nrate ?? 0.0})",
                                                                              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.normal),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        GestureDetector(
                                                                          onTap:
                                                                              () {
                                                                            if (datacart[index].cId !=
                                                                                null) {
                                                                              deleteCartItem(datacart[index].cId, datacart[index].itemCd);
                                                                            }
                                                                          },
                                                                          child:
                                                                              Icon(Icons.delete),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        if (product !=
                                                                            null) {
                                                                          Get.to(() =>
                                                                              ProductDetailPage(data: product));
                                                                        }
                                                                      },
                                                                      child:
                                                                          Text(
                                                                        "${datacart[index].item?.itemName ?? 'Unknown Product'}",
                                                                        maxLines:
                                                                            2,
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12.sp,
                                                                            fontWeight: FontWeight.normal),
                                                                      ),
                                                                    ),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        if (product !=
                                                                            null) {
                                                                          Get.to(() =>
                                                                              ProductDetailPage(data: product));
                                                                        }
                                                                      },
                                                                      child:
                                                                          Text(
                                                                        "Amt : ${Helper.parseNumericValue(datacart[index].amount.toString())}",
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                14.sp,
                                                                            fontWeight: FontWeight.bold),
                                                                      ),
                                                                    ),
                                                                    Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .end,
                                                                      children: [
                                                                        // Qty Field
                                                                        Flexible(
                                                                          flex:
                                                                              1.5.toInt(),
                                                                          child:
                                                                              TextFormField(
                                                                            controller:
                                                                                qtyController,
                                                                            decoration:
                                                                                const InputDecoration(
                                                                              hintText: 'Enter Qty',
                                                                              labelText: 'Enter Qty',
                                                                            ),
                                                                            keyboardType:
                                                                                TextInputType.number,
                                                                            onChanged:
                                                                                (value) {
                                                                              double? quantity = double.tryParse(value);
                                                                              if (quantity != null && quantity > 0) {
                                                                                final lrateSetting = profile.data?.profileSettings.firstWhere(
                                                                                  (element) => element.variable == 'lrateSetting',
                                                                                  orElse: () => DatumSettings(variable: 'lrateSetting', value: 'N'),
                                                                                );

                                                                                double price = 0.0;
                                                                                if (lrateSetting?.value == 'Y') {
                                                                                  price = double.tryParse(item.lrate.toString()) ?? 0.0;
                                                                                } else {
                                                                                  price = double.tryParse(item.rate.toString()) ?? 0.0;
                                                                                }

                                                                                double amount = quantity * price;

                                                                                setState(() {
                                                                                  item.amount = amount;
                                                                                  item.quantity = quantity.toString();
                                                                                  calculateNetAmount();
                                                                                });

                                                                                cartController.setQuantity(
                                                                                  item.itemCd,
                                                                                  value,
                                                                                );

                                                                                updateitemtoCart(
                                                                                  item.itemCd,
                                                                                  qtyController.text,
                                                                                  freeQtyController.text,
                                                                                  rateController?.text ?? '',
                                                                                  item.lrate ?? '',
                                                                                  remarksController?.text ?? '',
                                                                                  item.cId,
                                                                                );
                                                                              }
                                                                            },

                                                                            // onChanged: (value) {
                                                                            //   double? quantity = double.tryParse(value);
                                                                            //
                                                                            //   if (quantity != null && quantity > 0) {
                                                                            //     // Use itemCd to find correct index in datacart
                                                                            //     String itemCd = filteredList[index].itemCd; // Use filtered/search list if applicable
                                                                            //     int actualIndex = datacart.indexWhere((item) => item.itemCd == itemCd);
                                                                            //
                                                                            //     if (actualIndex == -1) return; // Item not found, exit safely
                                                                            //
                                                                            //     double price = double.tryParse(datacart[actualIndex].rate.toString()) ?? 0.0;
                                                                            //     double amount = quantity * price;
                                                                            //
                                                                            //     setState(() {
                                                                            //       datacart[actualIndex].amount = amount;
                                                                            //       datacart[actualIndex].quantity = quantity.toString();
                                                                            //       calculateNetAmount();
                                                                            //     });
                                                                            //
                                                                            //     print("Updated Qty for ItemCd $itemCd: ${datacart[actualIndex].quantity}");
                                                                            //     print("Updated Amount: ${datacart[actualIndex].amount}");
                                                                            //     print("Net Amount: $netAmount");
                                                                            //
                                                                            //     var tempRate = '';
                                                                            //     var tempRemarks = '';
                                                                            //
                                                                            //     if (profile.data?.profileSettings.firstWhere((element) => element.variable == 'editMasterRateSettings').value == 'Y' ||
                                                                            //         profile.data?.profileSettings.firstWhere((element) => element.variable == 'editOperatorRateSettings').value == 'Y') {
                                                                            //       tempRate = rate[index].text;
                                                                            //     }
                                                                            //
                                                                            //     if (profile.data?.profileSettings.firstWhere((element) => element.variable == 'showItemWiseRemarks').value == 'Y') {
                                                                            //       tempRemarks = remarks[index].text;
                                                                            //     }
                                                                            //
                                                                            //     updateitemtoCart(
                                                                            //       datacart[actualIndex].itemCd,
                                                                            //       qty[index].text,
                                                                            //       freeQty[index].text,
                                                                            //       tempRate,
                                                                            //       datacart[actualIndex].lrate ?? '',
                                                                            //       tempRemarks,
                                                                            //       datacart[actualIndex].cId,
                                                                            //     );
                                                                            //   }
                                                                            // }
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                8),

                                                                        // Free Dropdown
                                                                        Flexible(
                                                                          flex:
                                                                              2.5.toInt(),
                                                                          child:
                                                                              TextFormField(
                                                                            controller:
                                                                                freeQtyController,
                                                                            decoration:
                                                                                InputDecoration(
                                                                              labelText: 'Free',
                                                                              isDense: true,
                                                                              suffixIcon: DropdownButtonHideUnderline(
                                                                                child: DropdownButton<String>(
                                                                                  icon: const Icon(Icons.arrow_drop_down),
                                                                                  onChanged: (String? newValue) {
                                                                                    if (newValue != null) {
                                                                                      freeQtyController.text = newValue;

                                                                                      setState(() {
                                                                                        item.otherDesc = newValue;
                                                                                      });

                                                                                      cartController.setFreeQuantity(
                                                                                        item.itemCd,
                                                                                        newValue,
                                                                                      );

                                                                                      updateitemtoCart(
                                                                                        item.itemCd,
                                                                                        qtyController.text,
                                                                                        newValue,
                                                                                        rateController?.text ?? '',
                                                                                        item.lrate ?? '',
                                                                                        remarksController?.text ?? '',
                                                                                        item.cId,
                                                                                      );
                                                                                    }
                                                                                  },
                                                                                  items: otherDescOptions
                                                                                      .map((e) => DropdownMenuItem<String>(
                                                                                            value: e.NARR_NAME,
                                                                                            child: Text(e.NARR_NAME),
                                                                                          ))
                                                                                      .toList(),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            onChanged:
                                                                                (value) {
                                                                              setState(() {
                                                                                item.otherDesc = value;
                                                                              });

                                                                              cartController.setFreeQuantity(
                                                                                item.itemCd,
                                                                                value,
                                                                              );

                                                                              updateitemtoCart(
                                                                                item.itemCd,
                                                                                qtyController.text,
                                                                                freeQtyController.text,
                                                                                rateController?.text ?? '',
                                                                                item.lrate ?? '',
                                                                                remarksController?.text ?? '',
                                                                                item.cId,
                                                                              );
                                                                            },
                                                                          ),
                                                                        ),

                                                                        // Spacer before Rate field (if needed)
                                                                        if (showRate)
                                                                          const SizedBox(
                                                                              width: 8),

                                                                        // Rate Field (conditionally shown)
                                                                        if (showRate)

                                                                          // Flexible(
                                                                          //   flex:
                                                                          //       1.5.toInt(),
                                                                          //   child:
                                                                          //       TextFormField(
                                                                          //     controller:
                                                                          //         rateController,
                                                                          //     decoration:
                                                                          //         const InputDecoration(
                                                                          //       hintText: 'Rate',
                                                                          //       labelText: 'Rate',
                                                                          //     ),
                                                                          //     keyboardType:
                                                                          //         TextInputType.number,
                                                                          //   ),
                                                                          // ),

                                                                          Flexible(
                                                                            flex:
                                                                                1.5.toInt(),
                                                                            child:
                                                                                TextFormField(
                                                                              controller: rateController,
                                                                              decoration: const InputDecoration(
                                                                                hintText: 'Rate',
                                                                                labelText: 'Rate',
                                                                              ),
                                                                              keyboardType: TextInputType.number,
                                                                              onChanged: (value) {
                                                                                double? rate = double.tryParse(value);
                                                                                double? quantity = double.tryParse(qtyController.text);

                                                                                if (rate != null && quantity != null && quantity > 0) {
                                                                                  double amount = rate * quantity;

                                                                                  setState(() {
                                                                                    item.rate = rate.toString();
                                                                                    item.amount = amount;
                                                                                    calculateNetAmount();
                                                                                  });

                                                                                  updateitemtoCart(
                                                                                    item.itemCd,
                                                                                    qtyController.text,
                                                                                    freeQtyController.text,
                                                                                    rateController?.text ?? '',
                                                                                    item.lrate ?? '',
                                                                                    remarksController?.text ?? '',
                                                                                    item.cId,
                                                                                  );
                                                                                }
                                                                              },
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                    if (showRemarks)
                                                                      Padding(
                                                                        padding:
                                                                            EdgeInsets.only(bottom: 4.h),
                                                                        child: DropdownMenu<
                                                                            dynamic>(
                                                                          width:
                                                                              size.width - 200,
                                                                          controller:
                                                                              remarksController,
                                                                          requestFocusOnTap:
                                                                              true,
                                                                          enableFilter:
                                                                              true,
                                                                          label:
                                                                              const Text('Remarks'),
                                                                          dropdownMenuEntries: fld5DescOptions
                                                                              .map((e) => DropdownMenuEntry<dynamic>(
                                                                                    value: e.NARR_NAME,
                                                                                    label: e.NARR_NAME,
                                                                                  ))
                                                                              .toList(),
                                                                          inputDecorationTheme:
                                                                              const InputDecorationTheme(
                                                                            isDense:
                                                                                true,
                                                                          ),
                                                                          enableSearch:
                                                                              true,
                                                                          onSelected:
                                                                              (value) {
                                                                            FocusManager.instance.primaryFocus?.unfocus();

                                                                            if (value !=
                                                                                null) {
                                                                              cartController.setRemark(
                                                                                item.itemCd,
                                                                                value.toString(),
                                                                              );

                                                                              updateitemtoCart(
                                                                                item.itemCd,
                                                                                qtyController.text,
                                                                                freeQtyController.text,
                                                                                rateController?.text ?? '',
                                                                                item.lrate ?? '',
                                                                                value.toString(),
                                                                                item.cId,
                                                                              );
                                                                            }
                                                                          },
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ))
                    ],
                  ),
                ),
                Visibility(
                    visible: loading,
                    child: Container(
                      height: size.height,
                      width: size.width,
                      decoration:
                          BoxDecoration(color: Colors.grey.withOpacity(0.5)),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ))
              ],
            ),
          ),
        ),
      ),
    );
  }

  double toDouble(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  final orderAddHive1 = Hive.box<Ordermodal>(Constants.addOrder);

  DatumPartyname? _findPartyById(List<DatumPartyname> parties, String partyId) {
    for (final p in parties) {
      if (p.accCd.toString() == partyId.toString()) {
        return p;
      }
    }
    return null;
  }

  String _preferredContact(String? whatsappNo, String? phoneNo) {
    final wa = (whatsappNo ?? '').trim();
    if (wa.isNotEmpty) return wa;
    return (phoneNo ?? '').trim();
  }

  String _toWaMePhone(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    while (digits.startsWith('0') && digits.length > 10) {
      digits = digits.substring(1);
    }
    if (digits.startsWith('00') && digits.length > 2) {
      digits = digits.substring(2);
    }
    if (digits.length == 10) {
      digits = '91$digits';
    }
    return digits;
  }

  Future<Map<String, String>?> _getStockistContact() async {
    final selectedStockistId = controller.selectedStockistId.value.trim();
    final selectedStockistName = controller.selectedStockistName.value.trim();

    if (selectedStockistId.isEmpty && selectedStockistName.isEmpty) {
      return null;
    }

    DatumPartyname? stockist = _findPartyById(
      controller.stockists,
      selectedStockistId,
    );

    if (stockist == null && selectedStockistId.isNotEmpty) {
      try {
        await controller.fetchStockists(groupCd: '136');
        stockist = _findPartyById(controller.stockists, selectedStockistId);
      } catch (e) {
        print('[Order Share] Failed to refresh stockists: $e');
      }
    }

    final wa = (stockist?.whNo ?? '').trim();
    final mobile =
        (stockist?.mobile ?? controller.selectedStockistMobile.value).trim();
    final preferred = _preferredContact(wa, mobile);

    return {
      'name': stockist?.accName ?? selectedStockistName,
      'wa': wa,
      'phone': mobile,
      'preferred': preferred,
      'wame': _toWaMePhone(preferred),
    };
  }

  Future<String?> _buildOrderReportUrl(String partyId) async {
    if (partyId.trim().isEmpty) return null;
    final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
    return Services().getOrderExportFileItem(
      context,
      partyId,
      today,
      today,
      null,
      'pdf',
    );
  }

  Future<void> _savePendingOrderSharePayloadIfPossible({
    required String partyId,
    required String partyName,
  }) async {
    final PartyProvider partyProvider =
        Provider.of<PartyProvider>(context, listen: false);

    final selectedParty = _findPartyById(partyProvider.data, partyId);
    final partyPreferred = _preferredContact(
      selectedParty?.whNo,
      selectedParty?.mobile,
    );
    final partyContact = <String, String>{
      'name': selectedParty?.accName ?? partyName,
      'wa': (selectedParty?.whNo ?? '').trim(),
      'phone': (selectedParty?.mobile ?? '').trim(),
      'preferred': partyPreferred,
      'wame': _toWaMePhone(partyPreferred),
    };

    final stockistContact = await _getStockistContact();

    final hasAnyRecipient = (partyContact['wame'] ?? '').isNotEmpty ||
        ((stockistContact?['wame'] ?? '').isNotEmpty);

    if (!hasAnyRecipient) {
      print('[Order Share] Skipping share popup: no recipient numbers');
      print(
          '[Order Share] DEBUG - Party: whNo=${selectedParty?.whNo}, mobile=${selectedParty?.mobile}');
      print(
          '[Order Share] DEBUG - Stockist: whNo=${stockistContact?['wa']}, mobile=${stockistContact?['phone']}');
      return;
    }

    final reportUrl = await _buildOrderReportUrl(partyId);
    if (reportUrl == null || reportUrl.trim().isEmpty) {
      print('[Order Share] Report url is empty, skipping pending payload save');
      print('[Order Share] DEBUG: partyId=$partyId, reportUrl=$reportUrl');
      return;
    }
    print('[Order Share] DEBUG: reportUrl=$reportUrl');

    final payload = <String, dynamic>{
      'reportUrl': reportUrl,
      'partyName': partyContact['name'] ?? 'Party',
      'partyNumber': partyContact['wame'] ?? '',
      'partyDisplayNumber': partyContact['preferred'] ?? '',
      'stockistName': stockistContact?['name'] ?? 'Stockist',
      'stockistNumber': stockistContact?['wame'] ?? '',
      'stockistDisplayNumber': stockistContact?['preferred'] ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_order_share_payload', jsonEncode(payload));
    print('[Order Share] Pending share payload saved for homepage');
  }

  _handelAddOrder(items) async {
    bool result = await InternetConnectionChecker.instance.hasConnection;

    // Check if offline license limit is already hit before placing another order
    if (!result) {
      try {
        final ProfileProvider profile =
            Provider.of<ProfileProvider>(context, listen: false);
        int syncId = 0;
        final profileSyncId = profile.data?.syncId;
        if (profileSyncId is int) {
          syncId = profileSyncId;
        } else if (profileSyncId is String) {
          syncId = int.tryParse(profileSyncId) ?? 0;
        }

        if (syncId > 0) {
          final db = DatabaseHelper();
          final licenseInfo = await db.getLicenseInfo(syncId);

          if (licenseInfo != null) {
            final serverOrderCount = licenseInfo['orderCount'] as int? ?? 0;
            final maxOrders = licenseInfo['maxOrders'] as int? ?? 0;
            final offlineOrderCount =
                licenseInfo['offline_order_count'] as int? ?? 0;
            final totalOrders = serverOrderCount + offlineOrderCount;

            // If limit already hit, prevent order placement
            if (totalOrders >= maxOrders && maxOrders > 0) {
              AppSnackBar.showGetXCustomSnackBar(
                message:
                    'Order limit reached. Sync your data now to continue placing orders.',
                backgroundColor: Colors.red,
              );
              return;
            }
          }
        }
      } catch (e) {
        print('[OFFLINE_ORDER] Error checking limit before order: $e');
      }
    }

    setState(() {
      loading = true;
    });
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    final ProfileProvider profile =
        Provider.of<ProfileProvider>(context, listen: false);
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    if (result == true) {
      var lat = "";
      var long = "";
      await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        //timeLimit: Duration(seconds: 10),
      ).then((Position position) {
        lat = position.latitude.toString();
        long = position.longitude.toString();
      }).whenComplete(() async {
        print(party.punchInOutPartyId);
        print(party.partyid);
        await Services()
            .addOrder(
                profile.YN == "Y" ? party.punchInOutPartyId : party.partyid,
                ub.role == AppConfig.masteruser
                    ? lat.isNotEmpty
                        ? lat
                        : '0'
                    : lat.isNotEmpty
                        ? lat
                        : '0',
                ub.role == AppConfig.masteruser
                    ? long.isNotEmpty
                        ? long
                        : '0'
                    : long.isNotEmpty
                        ? long
                        : '0',
                context,
                orderRemarks.text)
            .then((value) async {
          if (value != null) {
            //Fluttertoast.showToast(msg: value);
            AppSnackBar.showGetXCustomSnackBar(
                message: value, backgroundColor: Colors.green);

            // Order placed successfully: clear stockist selection for next order.
            await controller.clearStockistSelection();

            final selectedPartyId =
                profile.YN == "Y" ? party.punchInOutPartyId : party.partyid;
            final selectedPartyName =
                profile.YN == "Y" ? party.punchInOutParty : party.party;

            try {
              await _savePendingOrderSharePayloadIfPossible(
                partyId: selectedPartyId,
                partyName: selectedPartyName,
              );
            } catch (e, stack) {
              CrashlyticsService.recordNonFatal(e, stack);
              print('[Order Share] Failed to show share popup: $e');
            }

            getCart();
            setState(() {
              loading = false;
            });
            Get.to(() => OrderConformationPage());
          } else {
            setState(() {
              loading = false;
            });
          }
        });
      });
    } else {
      // OFFLINE ORDER HANDLING - NEW FUNCTIONALITY
      try {
        var lat = "0";
        var long = "0";

        // Try to get location even offline (might work with GPS)
        try {
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ).then((Position position) {
            lat = position.latitude.toString();
            long = position.longitude.toString();
          });
        } catch (e) {
          print("Could not get location offline: $e");
          // Continue with default coordinates
        }

        // Calculate total amount from cart
        double totalAmount = double.parse(netAmount);

        // Get party ID
        String partyId =
            profile.YN == "Y" ? party.punchInOutPartyId : party.partyid;

        // Get syncId from profile or UserProvider (profile.data might be null offline)
        int syncId = 0;
        final profileSyncId = profile.data?.syncId;
        if (profileSyncId is int) {
          syncId = profileSyncId;
        } else if (profileSyncId is String) {
          syncId = int.tryParse(profileSyncId) ?? 0;
        }
        if (syncId == 0 && ub.syncId != null) {
          syncId = int.tryParse(ub.syncId ?? '0') ?? 0;
        }

        // Save order offline
        OfflineOrderService offlineService = OfflineOrderService();
        int orderId = await offlineService.saveOrderOffline(
          partyId: partyId,
          totalAmount: totalAmount,
          latitude: double.parse(lat),
          longitude: double.parse(long),
          syncId: syncId,
          remarks: orderRemarks.text,
        );

        AppSnackBar.showGetXCustomSnackBar(
          message: "Order saved offline! Will sync when online.",
          backgroundColor: Colors.orange,
        );

        // CRITICAL: Create PLACE ORDER tracking record IMMEDIATELY (type=2)
        // This ensures the tracking record is created with the order's actual placement time
        // Instead of waiting for sync (which would create it later with wrong sequence)
        try {
          final OrderTrackingService orderTrackSvc = OrderTrackingService();
          final DateTime orderPlacementTime = DateTime.now();

          print(
              '[ShoppingCart] Creating PLACE ORDER tracking (type=2) immediately...');
          print('[ShoppingCart]   Party: $partyId | Location: ($lat, $long)');
          print('[ShoppingCart]   Order placement time: $orderPlacementTime');

          await orderTrackSvc.startEndOrder(
            accCd: partyId,
            latitude: double.parse(lat),
            longitude: double.parse(long),
            type: "2", // Type 2 = ORDER PLACED
            oId: null, // We don't have server ID yet, will be null for offline
            token: ub.token.toString(),
            moduleNo: "205",
            syncId: syncId,
            userCd: ub.syncId ?? "",
            isEndOrder: null, // Neutral for order placement
            orderDateTime:
                orderPlacementTime, // Use current time as placement time
          );

          print(
              '[ShoppingCart] PLACE ORDER tracking created at placement time');
        } catch (e) {
          print(
              '[ShoppingCart] Warning: Could not create PLACE ORDER tracking: $e');
          // Continue anyway - order was saved, tracking is secondary
        }

        // Check for license limit warning and store it for home screen display (like online behavior)
        bool isLimitHit = false;
        try {
          final offlineService = OfflineOrderService();
          final warningMsg =
              await offlineService.getOfflineLicenseWarning(syncId);

          if (warningMsg != null && warningMsg.isNotEmpty) {
            print(
                '[OFFLINE_ORDER] Setting pending warning to display on home screen: $warningMsg');

            // Check if limit is EXACTLY hit
            if (warningMsg.contains('LIMIT_HIT:')) {
              print(
                  '[OFFLINE_ORDER] EXACT LIMIT HIT - showing popup and resetting count');
              isLimitHit = true;

              // Show popup immediately
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: Text('Order Limit Reached'),
                      content: Text(
                          'Sync your data now or your order data might be lost'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          child: Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              }

              // Reset offline_order_count to 0 for next sync cycle
              try {
                final db = DatabaseHelper();
                await db.resetOfflineOrderCount(syncId);
                print('[OFFLINE_ORDER] Reset offline_order_count to 0');
              } catch (e) {
                print(
                    '[OFFLINE_ORDER] Warning: Could not reset offline_order_count: $e');
              }
            } else {
              // Store other warnings for home screen display
              profile.setPendingWarning(warningMsg);
            }
          }
        } catch (e) {
          print('[OFFLINE_ORDER] Error checking license warning: $e');
        }

        // Order saved successfully - no post-save license check needed
        // Blacklisting will be handled AFTER sync when server confirms limit exceeded
        print(
            '[OFFLINE_ORDER] Order saved locally (will be synced when online)');

        // Offline order is also a successful placement: clear stockist selection.
        await controller.clearStockistSelection();

        // Clear cart UI
        getCart();

        setState(() {
          loading = false;
        });

        // Navigate to confirmation page with offline flag
        Get.to(() => OrderConformationPage(),
            arguments: {'offline': true, 'orderId': orderId});
      } catch (e, stack) {
        CrashlyticsService.recordNonFatal(e, stack);

        final errorMsg = e.toString();

        // Show generic error message
        print('[OFFLINE_ORDER] Error saving offline order: $errorMsg');

        AppSnackBar.showGetXCustomSnackBar(
          message: 'Failed to save order. Please try again.',
          backgroundColor: Colors.red,
        );

        setState(() {
          loading = false;
        });
      }
    }
  }
}
