import 'dart:async';
import 'dart:developer';

import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/product/widget/order_loading_dialog.dart';
import 'package:arham_corporation/product/widget/product_card.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
//import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../models/productModal.dart';
import '../../providers/cart_list_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/services.dart';
import '../../views/party_managment/bindings/account_bindings.dart';
import '../../views/party_managment/screens/account_screen.dart';
import '../../widgets/pdfViewerScreen.dart';
import '../controller/cart_controller.dart';
import '../controller/product_controller.dart';
import '../widget/app_bar.dart';
import '../widget/chip_widget.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final ProductController controller = Get.isRegistered<ProductController>()
      ? Get.find<ProductController>()
      : Get.put(ProductController());
  final CartController cartController = Get.isRegistered<CartController>()
      ? Get.find<CartController>()
      : Get.put(CartController());

  String? deptCd;

  bool isLoading = true;
  List<DatumProduct> dataProduct = [];

  List<TextEditingController> qty = [];
  List<TextEditingController> rate = [];
  List<TextEditingController> freeQty = [];
  List<TextEditingController> remarks = [];

  late CartListProvider cart;

  var viewRight = false;
  var addRight = false;
  var updateRight = false;
  var deleteRight = false;
  var printRight = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    var moduleEntryAccess = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "205",
          orElse: () => Modules(),
        ) ??
        Modules();
    if (moduleEntryAccess.mODULENO == "205") {
      viewRight = moduleEntryAccess.rEADRIGHT!;
      addRight = moduleEntryAccess.wRITERIGHT!;
      updateRight = moduleEntryAccess.uPDATERIGHT!;
      deleteRight = moduleEntryAccess.dELETERIGHT!;
      printRight = moduleEntryAccess.pRINTRIGHT!;
    } else {}

    super.initState();

    cart = Provider.of<CartListProvider>(context, listen: false);

    // if (controller.selectedPartyId.value.isNotEmpty)
    //   cart.getCartItem(Get.context, controller.selectedPartyId.value);

    _focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final party = Provider.of<PartyProvider>(context, listen: false);

      controller.selectedPartyName.value = Helper.trimValue(
          profile.YN == 'Y' ? party.punchInOutParty : party.party, 25);
      controller.selectedPartyId.value = Helper.trimValue(
          profile.YN == 'Y' ? party.punchInOutPartyId : party.partyid, 25);

      if (controller.selectedPartyId.value.isNotEmpty) {
        cartController.productAddedStates.clear(); // Clear previous state

        await cart.getCartItem(Get.context!, controller.selectedPartyId.value);

        // Update state based on fetched cart data
        for (var item in cart.data) {
          cartController.productAddedStates[item.itemCd] = true;
        }

        cartController.update();

        cartController.cartCount.value =
            cartController.productAddedStates.length;
      }
    });

    // Initialize filteredDepartments by copying contents from deptment
    controller.filteredDepartments.assignAll(controller.deptment);
  }

  Timer? timer;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return WillPopScope(
      onWillPop: () async {
        Get.back(result: true);
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true, // <-- this must be true
        appBar: MyAppBar(
          title: 'Products',
          partyID: controller.selectedPartyId.value,
          menuItem: [
            if (printRight)
              buildMenuItem(
                icon: Icons.picture_as_pdf,
                text: 'Export Item PDF',
                isLoading: controller.isDownloadingExportPdf.value,
                onTap: () async {
                  controller.isDownloadingExportPdf.value = true;

                  try {
                    final pdfUrl = await Services().getProductExportFile(
                      Get.context!,
                      controller.searchController.text.trim(),
                      controller.selectedChip.value,
                    );

                    if (pdfUrl != null) {
                      log("Product PDF Export Successful: $pdfUrl");

                      Get.to(() => PdfViewerScreen(
                            pdfUrl: pdfUrl,
                            fileName: DateTime.now().toString(),
                          ));
                    } else {
                      log("No Product PDF file returned.");
                    }
                  } catch (error) {
                    log("Error retrieving Product PDF file: $error");
                  } finally {
                    controller.isDownloadingExportPdf.value = false;
                  }
                },
              ),
            //if(printRight)
            buildMenuItem(
              icon: Icons.search,
              text: 'Department Search',
              onTap: () async {
                setState(() {
                  controller.searchController.clear();
                  // Toggle department search without clearing the loaded departments
                  controller.showDeptSearch.value =
                      !controller.showDeptSearch.value;
                  controller.showSearch.value = false;
                });
                Get.back();
              },
            ),
            if (printRight)
              buildMenuItem(
                icon: Icons.file_download,
                text: 'Export Party PDF',
                isLoading: controller.isDownloadingPartyExportPdf.value,
                onTap: () async {
                  controller.isDownloadingPartyExportPdf.value = true;

                  try {
                    final pdfUrl =
                        await Services().getPartyExportFile(Get.context!);

                    if (pdfUrl != null) {
                      log("Party PDF Export Successful: $pdfUrl");

                      Get.to(() => PdfViewerScreen(
                            pdfUrl: pdfUrl,
                            fileName: DateTime.now().toString(),
                          ));
                    } else {
                      log("No Party PDF file returned.");
                    }
                  } catch (error) {
                    log("Error retrieving Party PDF file: $error");
                  } finally {
                    controller.isDownloadingPartyExportPdf.value = false;
                  }
                },
              ),
          ],
        ),
        body: SafeArea(
          child: profile.data != null &&
                  profile.data!.modulesList!
                      .any((module) => module.mODULENO == "205")
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPartyHeader(profile),
                      _buildChipSelector(),
                      Expanded(child: _buildProductList()),
                    ],
                  ),
                )
              : _buildPermissionDeniedMessage(),
        ),
      ),
    );
  }

  /// **Party Header Widget**
  Widget _buildPartyHeader(ProfileProvider profile) {
    // Get the current PartyProvider instance from the context
    final party = context.watch<PartyProvider>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label for the party header
        const Padding(
          padding: EdgeInsets.only(left: 5.0),
          child: Text(
            'Party:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 2),
        // Party name with reactive updates
        Obx(() {
          final punchValue = profile.data?.profileSettings
                  .firstWhereOrNull((e) => e.variable == 'punchInOut')
                  ?.value ??
              'N';

          String partyName = controller.selectedPartyName.value.isNotEmpty
              ? controller.selectedPartyName.value
              : punchValue == 'Y'
                  ? party.punchInOutParty
                  : party.party;

          // String partyName = controller.selectedPartyName.value.isNotEmpty
          //     ? controller.selectedPartyName.value
          //     : profile.data?.profileSettings
          //                 .firstWhere(
          //                     (element) => element.variable == 'punchInOut')
          //                 .value ==
          //             'Y'
          //         ? party.punchInOutParty
          //         : party.party;

          // String a = Helper.trimValue(
          //     profile.data?.profileSettings
          //                 .firstWhere(
          //                     (element) => element.variable == 'punchInOut')
          //                 .value ==
          //             'Y'
          //         ? party.punchInOutParty
          //         : party.party,
          //     25);

          // controller.selectedPartyName.value = Helper.trimValue(
          //     profile.data?.profileSettings
          //                 .firstWhere(
          //                     (element) => element.variable == 'punchInOut')
          //                 .value ==
          //             'Y'
          //         ? party.punchInOutParty
          //         : party.party,
          //     25);
          // controller.selectedPartyId.value = Helper.trimValue(
          //     profile.data?.profileSettings
          //                 .firstWhere(
          //                     (element) => element.variable == 'punchInOut')
          //                 .value ==
          //             'Y'
          //         ? party.punchInOutPartyId
          //         : party.partyid,
          //     25);

          final isPunchEnabled = profile.data?.profileSettings
                  .firstWhereOrNull((e) => e.variable == 'punchInOut')
                  ?.value ==
              'Y';

          controller.selectedPartyName.value = Helper.trimValue(
              isPunchEnabled ? party.punchInOutParty : party.party, 25);

          controller.selectedPartyId.value = Helper.trimValue(
              isPunchEnabled ? party.punchInOutPartyId : party.partyid, 25);

          return Flexible(
            child: Text(
              Helper.trimValue(partyName, 35),
              //Helper.trimValue(a, 35),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          );
        }),
        // Dynamic action button based on state
        if (profile.YN == "Y")
          profile.ACC_NAME.isEmpty && profile.ACC_CD.isEmpty
              ? TextButton(
                  onPressed: profile.data?.isPunchIn == true
                      ? showMenu
                      : () {
                          AppSnackBar.showGetXCustomSnackBar(
                              message: 'Please Punch In');

                          //Fluttertoast.showToast(msg: "Please Punch In");
                        },
                  child: const Text("Start Order"),
                )
              : TextButton(
                  onPressed: () async {
                    // Show loading dialog
                    OrderLoadingDialog.show(
                      context: context,
                      action: "Ending",
                    );

                    try {
                      await party.startEndOrder(
                        profile.ACC_NAME,
                        profile.ACC_CD,
                        context,
                        "3",
                        id: 1,
                      );

                      // Dismiss the loading dialog
                      OrderLoadingDialog.dismiss(context);

                      // Clear the selected party name
                      controller.selectedPartyName.value = '';
                      controller.selectedPartyId.value = '';

                      // Reset state
                      setState(() {
                        dataProduct.clear();
                        isLoading = true;
                        qty.clear();
                        freeQty.clear();
                      });

                      // Clear cart
                      cartController.productAddedStates.clear();

                      // Refresh products
                      await controller.fetchProductsFromAPI();

                      setState(() {
                        isLoading = false;
                      });

                      if (controller.selectedPartyId.isNotEmpty) {
                        cartController.productAddedStates
                            .clear(); // Clear previous state

                        await cart.getCartItem(
                            Get.context!, controller.selectedPartyId.value);

                        // Update state based on fetched cart data
                        for (var item in cart.data) {
                          cartController.productAddedStates[item.itemCd] = true;
                        }

                        cartController.update();

                        cartController.cartCount.value =
                            cartController.productAddedStates.length;
                      } else {
                        cartController.cartCount.value = 0;
                      }
                    } catch (e) {
                      // Dismiss the loading dialog even on error
                      OrderLoadingDialog.dismiss(context);
                      //showToast("Error: $e");
                      AppSnackBar.showGetXCustomSnackBar(message: "Error: $e");
                    }
                  },
                  child: const Text("End Order"),
                )
        else
          TextButton(
            onPressed: showMenu,
            child: const Text("Change"),
          ),
      ],
    );
  }

  /// **Chip Selector Widget**
  // ignore: unused_element
  Widget _buildChipSelector1() {
    return Obx(() {
      if (controller.isDpLoading.value) return const LinearProgressIndicator();

      return SizedBox(
        height: 45,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: controller.deptment.length,
          separatorBuilder: (_, __) => const SizedBox(width: 5),
          itemBuilder: (context, index) {
            final department = controller.deptment[index];

            return Obx(
              () => SelectableChip(
                label: department.deptName,
                isSelected: controller.selectedChip.value == department.deptCd,
                onSelected: (bool selected) {
                  controller
                      .toggleChipSelection(selected ? department.deptCd : '');
                  log("Selected Department Code: ${controller.selectedChip.value}");
                },
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildChipSelector() {
    return Obx(() {
      if (controller.isDpLoading.value) return const LinearProgressIndicator();

      return SizedBox(
        height: 45,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: controller.filteredDepartments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 5),
          itemBuilder: (context, index) {
            final department = controller.filteredDepartments[index];

            return Obx(
              () => SelectableChip(
                label: department.deptName,
                isSelected: controller.selectedChip.value == department.deptCd,
                onSelected: (bool selected) {
                  controller
                      .toggleChipSelection(selected ? department.deptCd : '');
                  //controller.showDeptSearch.value = false; // Hide search after selection
                  log("Selected Department Code: ${controller.selectedChip.value}");
                },
              ),
            );
          },
        ),
      );
    });
  }

  /// **Product List Widget**
  ///
  Widget _buildProductList() {
    // ScrollController _scrollController = ScrollController();
    //
    // // Listen for scroll events to hide the keyboard
    // _scrollController.addListener(() {
    //   // Hide keyboard on any scroll direction (up or down)
    //   //if(controller.isKeyboardOpen.value){
    //   FocusScope.of(context).unfocus();
    //   //controller.isKeyboardOpen.value =  false;
    //   //}
    // });

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.filteredProducts.isEmpty) {
        return const Center(
          child: Text("No products available.",
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        );
      }

      return ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        //controller: _scrollController, // Attach the scroll controller here
        itemCount: controller.filteredProducts.length,
        shrinkWrap: true,
        //clipBehavior: Clip.none,
        itemBuilder: (context, index) {
          // var isadd = cart.data.any(
          //         (element) =>
          //     element.itemCd ==
          //         controller.filteredProducts[index].itemCd);

          return ProductCard(
            product: controller.filteredProducts[index],
          );
        },
      );
    });
  }

  /// **Permission Denied Message**
  Widget _buildPermissionDeniedMessage() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "You do not have permission to access the Order Entry. Please upgrade your subscription.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  TextEditingController searchPartyClt = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List _tempParty = [];

  void showMenu1() {
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    // Fetch party data once and store the Future
    final Future<void> partyDataFuture = pp.getPartyNameProductPage(context);

    // Use the Future to show the menu after data is loaded
    partyDataFuture.then((_) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
        ),
        builder: (BuildContext context) {
          return Consumer<PartyProvider>(
            builder: (context, party, child) {
              return StatefulBuilder(
                builder: (context, setState) {
                  return Padding(
                    padding: MediaQuery.of(context).viewInsets,
                    child: SizedBox(
                      height: 450,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSearchField(setState, party),
                          _buildPartyList(setState, p, party),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    });
  }

  void showMenu() {
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    final CartListProvider cart =
        Provider.of<CartListProvider>(context, listen: false);
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);
    // Capture page-level context BEFORE the bottom sheet opens
    final BuildContext pageContext = context;
    pp.getPartyNameProductPage(context);
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
          return Consumer<PartyProvider>(
            builder: (context, party, child) {
              return StatefulBuilder(builder: (context, StateSetter setStatee) {
                return Padding(
                  padding: MediaQuery.of(context).viewInsets,
                  child: SizedBox(
                    height: 450,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 20.0, bottom: 5.0, top: 20.0),
                                  child: Text("Select Party:",
                                      style: TextStyle(
                                          fontSize: 20.0,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8)),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final accName = await Get.to(
                                      () => const AccountScreen(),
                                      binding: AccountBindings(),
                                    );

                                    if (accName != null && accName is String) {
                                      //  STEP 1: Refresh party list (VERY IMPORTANT)
                                      await pp
                                          .getPartyNameProductPage(pageContext);

                                      //  STEP 2: Rebuild bottom sheet UI
                                      setStatee(() {});

                                      //  STEP 3: (Optional) Update selected values
                                      controller.selectedPartyName.value =
                                          accName;
                                      controller.selectedPartyId.value = '';
                                    }
                                  },
                                  child: const Text('Add Account'),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CupertinoSearchTextField(
                                  controller: searchPartyClt,
                                  onChanged: (value) {
                                    //4
                                    setStatee(() {
                                      _tempParty =
                                          Helper.buildSearchList(value, party);
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
                                      itemCount: (_tempParty.isNotEmpty)
                                          ? _tempParty.length
                                          : party.data.length,
                                      itemBuilder: (builder, index) {
                                        return InkWell(
                                          onTap: () async {
                                            // Close the bottom sheet first
                                            // Navigator.pop(context);
                                            //
                                            // // Wait for bottom sheet to fully close, then show loader
                                            // await Future.delayed(const Duration(milliseconds: 300));
                                            // OrderLoadingDialog.show(
                                            //   context: pageContext,
                                            //   action: "Starting",
                                            // );
                                            Navigator.pop(context);

                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              OrderLoadingDialog.show(
                                                context: pageContext,
                                                action: "Starting",
                                              );
                                            });

                                            try {
                                              if (p.data?.profileSettings.any(
                                                      (e) =>
                                                          e.variable ==
                                                              'punchInOut' &&
                                                          e.value == 'Y') ==
                                                  true) {
                                                final LocationProvider lp =
                                                    Provider.of<
                                                            LocationProvider>(
                                                        pageContext,
                                                        listen: false);
                                                if (lp.enebleLocationPermission ==
                                                    true) {
                                                  await party
                                                      .changePunchInOutParty(
                                                          (_tempParty
                                                                  .isNotEmpty)
                                                              ? _tempParty[
                                                                      index]
                                                                  .accName
                                                              : party
                                                                  .data[index]
                                                                  .accName,
                                                          (_tempParty
                                                                  .isNotEmpty)
                                                              ? _tempParty[
                                                                      index]
                                                                  .accCd
                                                              : party
                                                                  .data[index]
                                                                  .accCd,
                                                          isProductPage: true,
                                                          type: "1",
                                                          pageContext);

                                                  if (_tempParty.isNotEmpty) {
                                                    controller.selectedPartyName
                                                            .value =
                                                        _tempParty[index]
                                                            .accName;
                                                    controller.selectedPartyId
                                                            .value =
                                                        _tempParty[index].accCd;
                                                  } else {
                                                    controller.selectedPartyName
                                                            .value =
                                                        party.data[index]
                                                            .accName;
                                                    controller.selectedPartyId
                                                            .value =
                                                        party.data[index].accCd;
                                                  }

                                                  log("Selected Party Name: ${controller.selectedPartyName.value}");
                                                  log("Selected Party ID: ${controller.selectedPartyId.value}");
                                                } else {
                                                  OrderLoadingDialog.dismiss(
                                                      pageContext);
                                                  AppSnackBar
                                                      .showGetXCustomSnackBar(
                                                          message:
                                                              "Please Enable Location Permission");
                                                  return;
                                                }
                                              } else {
                                                await party.changeParty(
                                                    (_tempParty.isNotEmpty)
                                                        ? _tempParty[index]
                                                            .accName
                                                        : party.data[index]
                                                            .accName,
                                                    (_tempParty.isNotEmpty)
                                                        ? _tempParty[index]
                                                            .accCd
                                                        : party
                                                            .data[index].accCd,
                                                    pageContext);

                                                if (_tempParty.isNotEmpty) {
                                                  controller.selectedPartyName
                                                          .value =
                                                      _tempParty[index].accName;
                                                  controller.selectedPartyId
                                                          .value =
                                                      _tempParty[index].accCd;
                                                } else {
                                                  controller.selectedPartyName
                                                          .value =
                                                      party.data[index].accName;
                                                  controller.selectedPartyId
                                                          .value =
                                                      party.data[index].accCd;
                                                }
                                              }

                                              setState(() {
                                                dataProduct.clear();
                                                isLoading = true;
                                                qty.clear();
                                                freeQty.clear();
                                              });

                                              await controller
                                                  .fetchProductsFromAPI();

                                              if (controller
                                                  .selectedPartyId.isNotEmpty) {
                                                cartController
                                                    .productAddedStates
                                                    .clear();

                                                await cart.getCartItem(
                                                    pageContext,
                                                    controller
                                                        .selectedPartyId.value);

                                                for (var item in cart.data) {
                                                  cartController
                                                          .productAddedStates[
                                                      item.itemCd] = true;
                                                }

                                                cartController.update();

                                                cartController.cartCount.value =
                                                    cartController
                                                        .productAddedStates
                                                        .length;
                                              }

                                              OrderLoadingDialog.dismiss(
                                                  pageContext);
                                            } catch (e) {
                                              OrderLoadingDialog.dismiss(
                                                  pageContext);
                                              AppSnackBar
                                                  .showGetXCustomSnackBar(
                                                      message: "Error: $e");
                                            }
                                          },
                                          child: (_tempParty.isNotEmpty)
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
          );
        });
  }

// Build Search Field
  Widget _buildSearchField(StateSetter setState, PartyProvider party) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20.0, bottom: 5.0, top: 20.0),
          child: const Text(
            "Select Party:",
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CupertinoSearchTextField(
            controller: searchPartyClt,
            focusNode: _focusNode,
            onChanged: (value) {
              setState(() {
                _tempParty = Helper.buildSearchList(value, party);
              });
            },
          ),
        ),
      ],
    );
  }

// Build Party List
  Widget _buildPartyList(
      StateSetter setState, ProfileProvider profile, PartyProvider party) {
    return Expanded(
      child: party.nolistParty
          ? const Center(child: Text("No List"))
          : party.data.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _tempParty.isNotEmpty
                      ? _tempParty.length
                      : party.data.length,
                  itemBuilder: (context, index) {
                    return _buildPartyListItem(setState, profile, party, index);
                  },
                ),
    );
  }

// Build Individual Party List Item
  Widget _buildPartyListItem(StateSetter setState,
      ProfileProvider profileProvider, PartyProvider partyProvider, int index) {
    return GestureDetector(
      onTap: () async {
        try {
          final selectedParty = _tempParty.isNotEmpty
              ? _tempParty[index]
              : partyProvider.data[index];

          controller.selectedPartyName.value = selectedParty.accName;
          controller.selectedPartyId.value = selectedParty.accCd;

          log("Selected Party Name: ${controller.selectedPartyName.value}");
          log("Selected Party ID: ${controller.selectedPartyId.value}");

          // Close the bottom sheet
          Navigator.pop(context);

          // Wait for bottom sheet to fully close
          await Future.delayed(const Duration(milliseconds: 500));

          // Show loader - use the main app BuildContext
          final mainContext = Get.context;
          if (mainContext != null && mainContext.mounted) {
            log("📍 About to show loader");
            OrderLoadingDialog.show(
              context: mainContext,
              action: "Starting",
            );

            log("✅ Loader show() called");
          } else {
            log("❌ Main context is null or not mounted");
          }

          final isPunchInOutEnabled = profileProvider.data?.profileSettings.any(
                  (setting) =>
                      setting.variable == 'punchInOut' &&
                      setting.value == 'Y') ??
              false;

          if (isPunchInOutEnabled) {
            final locationProvider =
                Provider.of<LocationProvider>(context, listen: false);

            if (locationProvider.enebleLocationPermission) {
              await partyProvider.changePunchInOutParty(
                selectedParty.accName,
                selectedParty.accCd,
                isProductPage: true,
                type: "1",
                context,
              );
            } else {
              OrderLoadingDialog.dismiss(Get.context!);
              AppSnackBar.showGetXCustomSnackBar(
                  message: "Please Enable Location Permission");
              return;
            }
          } else {
            await partyProvider.changeParty(
              selectedParty.accName,
              selectedParty.accCd,
              context,
            );
          }

          // Fetch products
          setState(() {
            dataProduct.clear();
            isLoading = true;
            qty.clear();
            freeQty.clear();
          });

          await controller.fetchProductsFromAPI();

          // Update cart
          if (controller.selectedPartyId.isNotEmpty) {
            cartController.productAddedStates.clear();
            await cart.getCartItem(
                Get.context!, controller.selectedPartyId.value);

            for (var item in cart.data) {
              cartController.productAddedStates[item.itemCd] = true;
            }

            cartController.update();
            cartController.cartCount.value =
                cartController.productAddedStates.length;
          }

          // Dismiss loader
          OrderLoadingDialog.dismiss(Get.context!);
          log("⏹️  Loader dismissed");
        } catch (e) {
          log("Error selecting party: $e");
          OrderLoadingDialog.dismiss(Get.context!);
          AppSnackBar.showGetXCustomSnackBar(message: "Error: $e");
        }
      },
      child: Helper.showPartyBottomSheetWithSearch(
        index,
        _tempParty.isNotEmpty ? _tempParty : partyProvider.data,
      ),
    );
  }
}
