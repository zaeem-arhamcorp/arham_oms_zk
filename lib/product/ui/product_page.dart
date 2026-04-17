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
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../models/productModal.dart';
import '../../providers/cart_list_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/database_helper.dart';
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
  bool _isOrderProcessing = false; // Prevent multiple clicks on order buttons
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

  /// Check if continuous location tracking is enabled in settings
  bool _isContinuousLocationTrackingEnabled(ProfileProvider profile) {
    try {
      final setting = profile.data?.profileSettings.firstWhere(
        (e) => e.variable == 'continuousLocationTracking',
      );
      return (setting?.value ?? 'Y') == 'Y';
    } catch (e) {
      // Setting not found, default to continuous tracking (Y)
      return true;
    }
  }

  /// Get fresh location via Geolocator for on-demand tracking
  /// Used for START_ORDER, END_ORDER, PUNCH IN/OUT when continuous tracking disabled
  Future<Map<String, String>> _getFreshLocationForOrder(
    ProfileProvider profile,
    PartyProvider party,
    String activityType,
  ) async {
    var lat = "0";
    var long = "0";

    try {
      print(
          '[LOCATION] 📍 Fetching fresh location via Geolocator for $activityType...');

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        print('[LOCATION] ⚠️ Location permission permanently denied');
        return {'lat': '0', 'long': '0'};
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      lat = position.latitude.toString();
      long = position.longitude.toString();

      // Store in on-demand table
      try {
        final partyId =
            profile.YN == "Y" ? party.punchInOutPartyId : party.partyid;
        final db = DatabaseHelper();
        await db.insertOnDemandLocation(
          partyId: partyId,
          latitude: position.latitude,
          longitude: position.longitude,
          activityType: activityType,
        );
        print(
            '[LOCATION] ✅ On-demand location stored: lat=$lat, lng=$long, activity=$activityType');
      } catch (storageErr) {
        print('[LOCATION] ⚠️ Error storing on-demand location: $storageErr');
      }
    } catch (e) {
      print(
          '[LOCATION] ⚠️ Error fetching fresh location: $e, using default (0, 0)');
    }

    return {'lat': lat, 'long': long};
  }

  /// Get location based on tracking preference for orders
  Future<Map<String, String>> _getLocationForOrder(
    ProfileProvider profile,
    PartyProvider party,
    String activityType,
  ) async {
    var lat = "0";
    var long = "0";

    try {
      final isContinuous = _isContinuousLocationTrackingEnabled(profile);
      print(
          '[LOCATION] Tracking mode: ${isContinuous ? "CONTINUOUS (40-sec)" : "ON-DEMAND (Geolocator)"}');

      if (isContinuous) {
        // ⚡ INSTANT: Get location from 40-second tracking table
        try {
          final db = DatabaseHelper();
          final latestLocData = await db.getLatestLocation();

          if (latestLocData != null) {
            lat = (latestLocData['latitude'] ?? 0.0).toString();
            long = (latestLocData['longitude'] ?? 0.0).toString();
            print('[LOCATION] 📍 Continuous tracking: lat=$lat, lng=$long');
          } else {
            print(
                '[LOCATION] ⚠️ No continuous tracking data, using default (0, 0)');
          }
        } catch (e) {
          print('[LOCATION] ⚠️ Error fetching continuous location: $e');
        }
      } else {
        // 📍 ON-DEMAND: Get fresh location via Geolocator
        final locationData =
            await _getFreshLocationForOrder(profile, party, activityType);
        lat = locationData['lat'] ?? "0";
        long = locationData['long'] ?? "0";
      }
    } catch (e) {
      print('[LOCATION] ⚠️ Unexpected error in _getLocationForOrder: $e');
    }

    return {'lat': lat, 'long': long};
  }

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

      // Ensure latest settings are merged into ProfileProvider before deciding
      // stockist visibility/requirement.
      await profile.loadSettings(context);
      if (!mounted) return;

      final isStockistEnabled = _isStockistUserLinkEnabled(profile);

      // Restore persisted stockist only when user setting allows stockist link.
      if (isStockistEnabled) {
        await controller.restoreStockistSelection();
      } else {
        await controller.clearStockistSelection();
        controller.stockists.clear();
        controller.hasStockistAccess.value = false;
      }

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
        cartController.update(); // Ensure UI rebuilds with new cart count
      }

      // Refresh stockists only when stockist link is enabled for this user.
      if (isStockistEnabled) {
        controller.fetchStockists(groupCd: '136');
      }

      // Initialize filteredDepartments by copying contents from deptment
      controller.filteredDepartments.assignAll(controller.deptment);
    });
  }

  Timer? timer;

  bool _isStockistUserLinkEnabled(ProfileProvider profile) {
    final settings = profile.data?.profileSettings;
    if (settings == null || settings.isEmpty) {
      return true;
    }

    final stockistSetting = settings.firstWhereOrNull(
      (e) =>
          (e.variable?.toString().trim().toLowerCase() ?? '') ==
          'showstockistuserlink',
    );

    if (stockistSetting == null) {
      return true;
    }

    final normalizedValue =
        stockistSetting.value?.toString().trim().toUpperCase() ?? '';
    return normalizedValue != 'N' &&
        normalizedValue != '0' &&
        normalizedValue != 'FALSE';
  }

  bool _requiresStockistSelection(ProfileProvider profile) {
    if (!_isStockistUserLinkEnabled(profile)) {
      return false;
    }

    final hasStockistOptions =
        controller.hasStockistAccess.value || controller.stockists.isNotEmpty;

    return hasStockistOptions && controller.selectedStockistId.value.isEmpty;
  }

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
                      // if (profile.data!.profileSettings.any((e) =>
                      //     e.variable == 'showStockistUserLink' &&
                      //     e.value == 'Y'))
                      _buildStockistHeader(),
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
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Label for the party header
        const Padding(
          padding: EdgeInsets.only(left: 5.0),
          child: Text(
            'Party :',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
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

          return Expanded(
            child: Text(
              Helper.trimValue(partyName, 35),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          );
        }),

        // Dynamic action button based on state
        if (profile.YN == "Y")
          profile.ACC_NAME.isEmpty && profile.ACC_CD.isEmpty
              ? TextButton(
                  onPressed: _isOrderProcessing
                      ? null
                      : () {
                          // ⚡ Prevent multiple clicks
                          if (_isOrderProcessing) return;

                          // Validation 1: Check if punched in
                          if (profile.data?.isPunchIn != true) {
                            AppSnackBar.showGetXCustomSnackBar(
                                message: 'Please Punch In');
                            return;
                          }

                          // Validation 2: Check if stockist is required but not selected
                          if (_requiresStockistSelection(profile)) {
                            AppSnackBar.showGetXCustomSnackBar(
                                message: 'Please Select Stockist');
                            return;
                          }

                          // All validations passed - show party menu
                          showMenu();
                        },
                  child: _isOrderProcessing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text("Processing..."),
                          ],
                        )
                      : const Text("Start Order"),
                )
              : TextButton(
                  onPressed: _isOrderProcessing
                      ? null
                      : () async {
                          // ⚡ Prevent multiple clicks
                          if (_isOrderProcessing) return;

                          setState(() {
                            _isOrderProcessing = true;
                          });

                          print('[END_ORDER] ⚡ Immediate: End order clicked');

                          try {
                            // ⚡⚡⚡ Call API immediately (uses cached location)
                            await party.startEndOrder(
                              profile.ACC_NAME,
                              profile.ACC_CD,
                              context,
                              "3",
                              id: 1,
                            );

                            print('[END_ORDER] ✅ Order ended successfully');

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

                            // 📦 Background: Fetch products (non-blocking)
                            print(
                                '[END_ORDER] 📦 Background: Fetching products...');
                            Future.microtask(() async {
                              if (!mounted)
                                return; // ✅ Guard: widget might be disposed
                              try {
                                await controller.fetchProductsFromAPI();
                                print(
                                    '[END_ORDER] ✅ Background: Products fetched');

                                setState(() {
                                  isLoading = false;
                                });

                                if (controller.selectedPartyId.isNotEmpty) {
                                  cartController.productAddedStates.clear();
                                  await cart.getCartItem(Get.context!,
                                      controller.selectedPartyId.value);

                                  for (var item in cart.data) {
                                    cartController
                                        .productAddedStates[item.itemCd] = true;
                                  }

                                  cartController.update();

                                  cartController.cartCount.value =
                                      cartController.productAddedStates.length;
                                  cartController
                                      .update(); // Ensure UI rebuilds with new count
                                } else {
                                  cartController.cartCount.value = 0;
                                  cartController.update(); // Ensure UI rebuilds
                                }
                              } catch (e) {
                                print('[END_ORDER] ❌ Background error: $e');
                                setState(() {
                                  isLoading = false;
                                });
                              }
                            });
                          } catch (e) {
                            print('[END_ORDER] ❌ Error: $e');
                            AppSnackBar.showGetXCustomSnackBar(
                                message: "Error: $e");
                          } finally {
                            setState(() {
                              _isOrderProcessing = false;
                            });
                          }
                        },
                  child: _isOrderProcessing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text("Processing..."),
                          ],
                        )
                      : const Text("End Order"),
                )
        else
          TextButton(
            onPressed: () {
              if (_requiresStockistSelection(profile)) {
                AppSnackBar.showGetXCustomSnackBar(
                    message: 'Please Select Stockist');
                return;
              }
              showMenu();
            },
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

  /// **Stockist Header Widget** - Shows stockist selection when groupCd=136 is available
  Widget _buildStockistHeader() {
    return Obx(() {
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final hasStockistAccess = controller.hasStockistAccess.value;
      final isStockistLoading = controller.isStockistLoading.value;
      final selectedStockistName = controller.selectedStockistName.value;

      if (!_isStockistUserLinkEnabled(profile)) {
        return const SizedBox.shrink();
      }

      final shouldHide = (!hasStockistAccess &&
          !isStockistLoading &&
          selectedStockistName.isEmpty);

      if (shouldHide) {
        return const SizedBox.shrink();
      }

      return Column(
        children: [
          Container(
            // padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 5.0),
                  child: Text(
                    'Stockist :',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedStockistName.isNotEmpty
                        ? selectedStockistName
                        : 'Select Stockist',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedStockistName.isEmpty
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),
                if (selectedStockistName.isNotEmpty)
                  // TextButton(
                  //   onPressed: () async {
                  //     await controller.clearStockistSelection();
                  //   },
                  //   child: const Text('Unselect', style: TextStyle(color: Colors.red)),
                  // ),
                  GestureDetector(
                    onTap: () async {
                      await controller.clearStockistSelection();
                    },
                    child: Icon(
                      Icons.close,
                      color: Colors.red,
                    ),
                  ),
                SizedBox(
                  width: 10,
                ),
                TextButton(
                  onPressed: () {
                    showStockistMenu();
                  },
                  child: const Text('Select'),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  void showStockistMenu() {
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    if (!_isStockistUserLinkEnabled(profile)) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Obx(() {
          if (controller.isStockistLoading.value) {
            return SizedBox(
              height: 200,
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (controller.stockists.isEmpty) {
            return SizedBox(
              height: 200,
              child: const Center(child: Text('No stockists available')),
            );
          }

          return SizedBox(
            height: 450,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(left: 20.0, top: 20.0, bottom: 10),
                  child: Text(
                    "Select Stockist:",
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.stockists.length,
                    itemBuilder: (context, index) {
                      final stockist = controller.stockists[index];
                      final name = stockist.accName;
                      final code = stockist.accCd;

                      return InkWell(
                        onTap: () async {
                          controller.selectedStockistName.value = name;
                          controller.selectedStockistId.value = code;
                          controller.selectedStockistMobile.value =
                              stockist.mobile;
                          await controller.saveStockistSelection();
                          Navigator.pop(context);
                          print(
                              '[Product] Selected Stockist: $name ($code), Mobile: ${stockist.mobile}');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code: $code',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (stockist.accAddress.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 14, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              stockist.accAddress,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (stockist.mobile.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone,
                                              size: 14, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Text(
                                            stockist.mobile,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (stockist.lat != null &&
                                        stockist.long != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined,
                                              size: 14, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${stockist.lat}, ${stockist.long}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle_outline,
                                color:
                                    controller.selectedStockistId.value == code
                                        ? Colors.blue
                                        : Colors.grey.shade300,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  /// Show dialog to select stockist

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

  Future<void> showMenu() async {
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    final CartListProvider cart =
        Provider.of<CartListProvider>(context, listen: false);
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    if (_requiresStockistSelection(p)) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Please Select Stockist');
      return;
    }

    // Capture page-level context BEFORE the bottom sheet opens
    final BuildContext pageContext = context;

    // Show bottom sheet immediately
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
                // Load parties inside the sheet if not loaded yet
                if (party.data.isEmpty && !party.nolistParty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await pp.getPartyNameProductPage(context);
                    await pp.sortPartiesByDistance();
                    setStatee(() {});
                  });
                }

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
                                // Add Account button (Module 102)
                                if (p.data?.modulesList != null &&
                                    p.data!.modulesList!.any((module) =>
                                        module.mODULENO == "102" &&
                                        (module.wRITERIGHT == true ||
                                            module.uPDATERIGHT == true)))
                                  TextButton(
                                    onPressed: () async {
                                      final accName = await Get.to(
                                        () => const AccountScreen(),
                                        binding: AccountBindings(),
                                      );

                                      if (accName != null &&
                                          accName is String) {
                                        //  STEP 1: Refresh party list (VERY IMPORTANT)
                                        await pp.getPartyNameProductPage(
                                            pageContext);

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
                                          onTap: _isOrderProcessing
                                              ? null
                                              : () async {
                                                  // ⚡ Prevent multiple clicks
                                                  if (_isOrderProcessing)
                                                    return;

                                                  setState(() {
                                                    _isOrderProcessing = true;
                                                  });

                                                  print(
                                                      '[START_ORDER] ⚡ Immediate: Party selected from list');

                                                  // Close the bottom sheet
                                                  Navigator.pop(context);

                                                  try {
                                                    final selectedParty =
                                                        (_tempParty.isNotEmpty)
                                                            ? _tempParty[index]
                                                            : party.data[index];

                                                    controller.selectedPartyName
                                                            .value =
                                                        selectedParty.accName;
                                                    controller.selectedPartyId
                                                            .value =
                                                        selectedParty.accCd;

                                                    print(
                                                        '[START_ORDER] 📝 Party selected: ${selectedParty.accName} (${selectedParty.accCd})');

                                                    // ⚡⚡⚡ API call immediately (no dialog!)
                                                    final isPunchInOutEnabled = p
                                                            .data
                                                            ?.profileSettings
                                                            .any((e) =>
                                                                e.variable ==
                                                                    'punchInOut' &&
                                                                e.value ==
                                                                    'Y') ??
                                                        false;

                                                    if (isPunchInOutEnabled) {
                                                      final LocationProvider
                                                          lp = Provider.of<
                                                                  LocationProvider>(
                                                              pageContext,
                                                              listen: false);
                                                      if (lp.enebleLocationPermission ==
                                                          true) {
                                                        print(
                                                            '[START_ORDER] 🚀 Starting punch-in order (immediate)');
                                                        await party
                                                            .changePunchInOutParty(
                                                                selectedParty
                                                                    .accName,
                                                                selectedParty
                                                                    .accCd,
                                                                isProductPage:
                                                                    true,
                                                                type: "1",
                                                                pageContext);
                                                      } else {
                                                        AppSnackBar
                                                            .showGetXCustomSnackBar(
                                                                message:
                                                                    "Please Enable Location Permission");
                                                        return;
                                                      }
                                                    } else {
                                                      print(
                                                          '[START_ORDER] 🚀 Starting regular order (immediate)');
                                                      await party.changeParty(
                                                          selectedParty.accName,
                                                          selectedParty.accCd,
                                                          pageContext);
                                                    }

                                                    print(
                                                        '[START_ORDER] ✅ Start order API completed');

                                                    // Update UI immediately
                                                    setState(() {
                                                      dataProduct.clear();
                                                      isLoading = true;
                                                      qty.clear();
                                                      freeQty.clear();
                                                    });

                                                    print(
                                                        '[START_ORDER] 📦 Background: Fetching products...');
                                                    // 📦 Background: Fetch products and cart (non-blocking)
                                                    Future.microtask(() async {
                                                      if (!mounted)
                                                        return; // ✅ Guard: widget might be disposed
                                                      try {
                                                        await controller
                                                            .fetchProductsFromAPI();
                                                        print(
                                                            '[START_ORDER] ✅ Background: Products fetched');

                                                        if (controller
                                                            .selectedPartyId
                                                            .isNotEmpty) {
                                                          cartController
                                                              .productAddedStates
                                                              .clear();

                                                          await cart.getCartItem(
                                                              pageContext,
                                                              controller
                                                                  .selectedPartyId
                                                                  .value);

                                                          for (var item
                                                              in cart.data) {
                                                            cartController
                                                                    .productAddedStates[
                                                                item.itemCd] = true;
                                                          }

                                                          cartController
                                                              .update();

                                                          cartController
                                                                  .cartCount
                                                                  .value =
                                                              cartController
                                                                  .productAddedStates
                                                                  .length;
                                                          print(
                                                              '[START_ORDER] ✅ Background: Cart updated');
                                                        }

                                                        setState(() {
                                                          isLoading = false;
                                                        });
                                                      } catch (e) {
                                                        print(
                                                            '[START_ORDER] ❌ Background error: $e');
                                                        setState(() {
                                                          isLoading = false;
                                                        });
                                                      }
                                                    });
                                                  } catch (e) {
                                                    print(
                                                        '[START_ORDER] ❌ Error: $e');
                                                    AppSnackBar
                                                        .showGetXCustomSnackBar(
                                                            message:
                                                                "Error: $e");
                                                  } finally {
                                                    setState(() {
                                                      _isOrderProcessing =
                                                          false;
                                                    });
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

          print('[START_ORDER] ⚡ Immediate: Party selected - $selectedParty');

          // ⚡⚡⚡ Start order processing immediately (uses cached location)
          try {
            final isPunchInOutEnabled = profileProvider.data?.profileSettings
                    .any((setting) =>
                        setting.variable == 'punchInOut' &&
                        setting.value == 'Y') ??
                false;

            if (isPunchInOutEnabled) {
              final locationProvider =
                  Provider.of<LocationProvider>(context, listen: false);

              if (locationProvider.enebleLocationPermission) {
                print('[START_ORDER] 🚀 Starting punch-in order (immediate)');
                await partyProvider.changePunchInOutParty(
                  selectedParty.accName,
                  selectedParty.accCd,
                  isProductPage: true,
                  type: "1",
                  context,
                );
              } else {
                AppSnackBar.showGetXCustomSnackBar(
                    message: "Please Enable Location Permission");
                return;
              }
            } else {
              print('[START_ORDER] 🚀 Starting regular order (immediate)');
              await partyProvider.changeParty(
                selectedParty.accName,
                selectedParty.accCd,
                context,
              );
            }

            print('[START_ORDER] ✅ Start order API completed');

            // Update UI immediately
            setState(() {
              dataProduct.clear();
              isLoading = true;
              qty.clear();
              freeQty.clear();
            });

            print('[START_ORDER] 📦 Background: Fetching products...');
            // 📦 Background: Fetch products and cart (non-blocking)
            Future.microtask(() async {
              try {
                await controller.fetchProductsFromAPI();
                print('[START_ORDER] ✅ Background: Products fetched');

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
                  cartController.update(); // Ensure UI rebuilds with new count
                  print('[START_ORDER] ✅ Background: Cart updated');
                }

                setState(() {
                  isLoading = false;
                });
              } catch (e) {
                print('[START_ORDER] ❌ Background error: $e');
                setState(() {
                  isLoading = false;
                });
              }
            });
          } catch (e) {
            print('[START_ORDER] ❌ Error: $e');
            AppSnackBar.showGetXCustomSnackBar(message: "Error: $e");
          }
        } catch (e) {
          log("Error selecting party: $e");
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

// GET {{base_url}}/products/party?groupCd=136
