import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/product/controller/cart_controller.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/cart_list_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../models/cartListModal.dart';
import '../controller/product_controller.dart';
import '../model/product_model.dart';
import '../ui/product_detail.dart';

class ProductCard extends StatefulWidget {
  final ProductItem product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController freeQtyController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();

  // List<TextEditingController> qty = [];
  // List<TextEditingController> rate = [];
  // List<TextEditingController> freeQty = [];
  // List<TextEditingController> remarks = [];

  late CartListProvider cart;
  late final ProductController controller =
      Get.isRegistered<ProductController>()
          ? Get.find<ProductController>()
          : Get.put(ProductController());

  @override
  void initState() {
    super.initState();
    // Initialize controllers with stored values from CartController
    final cartController = Get.put(CartController());
    qtyController.text = cartController.getQuantity(widget.product.itemCd);
    freeQtyController.text =
        cartController.getFreeQuantity(widget.product.itemCd);
    remarkController.text = cartController.getRemark(widget.product.itemCd);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final controller = Get.find<ProductController>();
    final profile = context.watch<ProfileProvider>();
    final cartController = Get.put(CartController());
    final CartListProvider cart = context.watch<CartListProvider>();

    final clStkValue = double.tryParse(widget.product.cStk ?? '0.0');
    final orStkValue = double.tryParse(widget.product.orStk ?? '0.0');
    final finalStkValue = clStkValue! - orStkValue!;

    Color? clStkColor;

    if (finalStkValue > 0) {
      clStkColor = Color(0xFFE8FDE1);
    } else if (finalStkValue <= 0) {
      clStkColor = Color(0xFFFBE0E0);
    }

    return GestureDetector(
      onTap: () {
        Get.to(() => ProductDetailPages(data: widget.product));
      },
      child: Card(
        elevation: 8,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        shadowColor: Colors.black.withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: clStkColor,
            // Light red
            // gradient: LinearGradient(
            //   colors: (double.tryParse(widget.product.cStk.toString()) ?? 0) > 0
            //       ? [Color(0xFFDFFFD6), Color(0xFFA7F3A1)]
            //       : [Color(0xFFFFD6D6), Color(0xFFFFA1A1)],
            // ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildInfoRows(),
              _buildDepartmentAndCodes(),
              _buildInputFieldsAndDropdowns(
                size,
                profile,
                controller,
                cartController,
                cart,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      widget.product.itemName,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ignore: unused_element
  Widget _buildInfoRows1() {
    return Column(
      children: [
        _buildRow(
          ['MRP :', widget.product.srate3],
          ['Rate :', widget.product.srate1],
          ['N.Rate :', widget.product.nrate],
        ),
        _buildRow(
          ['Cl. Stk :', widget.product.cStk],
          ['P.Order:', widget.product.orStk],
          ['Avl Stk :', widget.product.avlStk],
        ),
        _buildRow(
          ['Disc :', widget.product.sdisc],
          ['Cd% :', widget.product.sdisc1],
          ['Margin :', widget.product.frmlSrt1],
        ),
      ],
    );
  }

  Widget _buildInfoRows() {
    // Determine color for Avl Stk based on value
    final avlStkValue = double.tryParse(widget.product.avlStk ?? '');
    Color? avlStkColor;

    if (avlStkValue != null) {
      if (avlStkValue > 0) {
        avlStkColor = Colors.green.shade800;
      } else if (avlStkValue <= 0) {
        avlStkColor = Colors.red.shade800;
      }
    }

    return Column(
      children: [
        _buildRow(
          ['MRP :', widget.product.srate3],
          ['Rate :', widget.product.srate1],
          ['N.Rate :', widget.product.nrate],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _infoRow('Cl. Stk :', widget.product.cStk),
            _infoRow('P.Order:', widget.product.orStk),
            _infoRow('Avl Stk :', widget.product.avlStk,
                labelColor: avlStkColor, valueColor: avlStkColor),
          ],
        ),
        _buildRow(
          ['Disc :', widget.product.sdisc],
          ['Cd% :', widget.product.sdisc1],
          ['Margin :', widget.product.frmlSrt1],
        ),
        _buildRow(
          [
            'Exp Dt :',
            widget.product.exDt != null
                ? Helper.convertToFormat(widget.product.exDt!, 'dd-MM-yyyy')
                : '',
          ],
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildRow1(
      List<String?> data1, List<String?> data2, List<String?> data3) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _infoRow(data1[0]!, data1[1]),
        SizedBox(
          width: 5,
        ),
        _infoRow(data2[0]!, data2[1]),
        SizedBox(
          width: 5,
        ),
        _infoRow(data3[0]!, data3[1]),
        // ignore: unnecessary_null_comparison
      ].where((widget) => widget != null).cast<Widget>().toList(),
    );
  }

  Widget _buildRow(
    List<String?> data1, [
    List<String?>? data2,
    List<String?>? data3,
    Color? labelColor,
    Color? valueColor,
  ]) {
    List<Widget> rowItems = [];

    if (data1.isNotEmpty && data1[0] != null && data1[1] != null) {
      rowItems.add(_infoRow(data1[0]!, data1[1]!,
          labelColor: labelColor, valueColor: valueColor));
    }

    if (data2 != null &&
        data2.isNotEmpty &&
        data2[0] != null &&
        data2[1] != null) {
      rowItems.add(_infoRow(data2[0]!, data2[1]!,
          labelColor: labelColor, valueColor: valueColor));
    }

    if (data3 != null &&
        data3.isNotEmpty &&
        data3[0] != null &&
        data3[1] != null) {
      rowItems.add(_infoRow(data3[0]!, data3[1]!,
          labelColor: labelColor, valueColor: valueColor));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: rowItems,
    );
  }

  Widget _buildDepartmentAndCodes() {
    print("Department Name :${widget.product.deptment.deptName}");
    return Text(
      "(${widget.product.deptment.deptName}) (${widget.product.itemCd})",
      style: TextStyle(
        fontSize: 10.sp,
        color: Colors.grey.shade700,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ignore: unused_element
  Widget _buildInputFieldsAndDropdowns1(
    Size size,
    ProfileProvider profile,
    ProductController controller,
    CartController cartController,
    CartListProvider cart,
  ) {
    final quantityController = TextEditingController();
    final rateController =
        TextEditingController(text: widget.product.srate1.toString());

    String? selectedFreeDescription;
    String? selectedRemark;

    return Obx(() {
      // final isProductAdded =
      //     cartController.productAddedStates[widget.product.itemCd] == true;
      // final isLoading =
      //     cartController.productLoadingStates[widget.product.itemCd] == true;
      //
      // final isAdd =
      //     cart.data.any((element) => element.itemCd == widget.product.itemCd);

      final otherDescEntries = controller.otherDescOptions
          .map((e) => DropdownMenuEntry<String>(
                value: e.NARR_NAME,
                label: e.NARR_NAME,
              ))
          .toList();

      final remarkEntries = controller.fld5DescOptions
          .map((e) => DropdownMenuEntry<String>(
                value: e.NARR_NAME,
                label: e.NARR_NAME,
              ))
          .toList();

      final isAdded =
          cartController.productAddedStates[widget.product.itemCd] ?? false;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          //if (!(isProductAdded || isAdd))
          if (!(isAdded))
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextFormField(
                        //controller: quantityController,
                        controller: qtyController,
                        decoration: const InputDecoration(
                            hintText: 'Qty', labelText: 'Qty',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        // onChanged: (val){
                        //   controller.isKeyboardOpen.value = false;
                        // },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Flexible(
                    //   flex: 2,
                    //   child: TextFormField(
                    //     controller: TextEditingController(
                    //         text: selectedFreeDescription),
                    //     keyboardType: TextInputType.number,
                    //     decoration: InputDecoration(
                    //       labelText: 'Free',
                    //       isDense: true,
                    //       suffixIcon: PopupMenuButton<String>(
                    //         icon: const Icon(Icons.arrow_drop_down),
                    //         onSelected: (String? value) {
                    //           if (value != null) {
                    //             selectedFreeDescription = value;
                    //           }
                    //         },
                    //         itemBuilder: (context) => otherDescEntries
                    //             .map(
                    //               (e) => PopupMenuItem<String>(
                    //                 value: e.value,
                    //                 child: Text(e.label),
                    //               ),
                    //             )
                    //             .toList(),
                    //       ),
                    //     ),
                    //     onChanged: (value) {
                    //       selectedFreeDescription = value;
                    //     },
                    //   ),
                    // ),
                    Flexible(
                      flex: 2,
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Free',
                          isDense: true,
                          suffixIcon: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              icon: const Icon(Icons.arrow_drop_down),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  // Update the controller with the selected value
                                  freeQtyController.text = newValue;
                                  selectedFreeDescription = newValue;
                                }
                              },
                              items: otherDescEntries
                                  .map<DropdownMenuItem<String>>((entry) {
                                return DropdownMenuItem<String>(
                                  value: entry.value,
                                  child: Text(entry.label),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        controller: freeQtyController,
                        // Create a TextEditingController for this field
                        onChanged: (value) {
                          selectedFreeDescription = value;
                        },
                      ),
                    ),

                    const SizedBox(width: 8),
                    if (_canEditRate(profile))
                      Expanded(
                        child: TextFormField(
                          controller: rateController,
                          decoration: const InputDecoration(
                              hintText: 'Rate', labelText: 'Rate'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                if (_shouldShowRemarks(profile))
                  // Option 1: Using TextFormField with DropdownMenu

                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Remark',
                      isDense: true,
                      suffixIcon: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          icon: const Icon(Icons.arrow_drop_down),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              // Update the controller with the selected value
                              remarkController.text = newValue;
                              selectedRemark = newValue;
                            }
                          },
                          items: remarkEntries
                              .map<DropdownMenuItem<String>>((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.value,
                              child: Text(entry.label),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    controller: remarkController,
                    // Create a TextEditingController for this field
                    onChanged: (value) {
                      selectedRemark = value;
                    },
                  ),
              ],
            ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              if (controller.selectedPartyId.value.isEmpty) {
                //showToast("Please Select Party");
                AppSnackBar.showGetXCustomSnackBar(
                    message: "Please Select Party");
                return;
              }

              // Check if product is already added or loading
              if (cartController.productAddedStates[widget.product.itemCd] ==
                      true ||
                  cartController.productLoadingStates[widget.product.itemCd] ==
                      true) {
                return;
              }

              // Set loading state to true
              cartController.productLoadingStates[widget.product.itemCd] = true;

              final itemQty = quantityController.text.trim().isEmpty
                  ? "1"
                  : quantityController.text.trim();

              try {
                await cartController
                    .addItemToCart(
                      itemCd: widget.product.itemCd,
                      partyid: controller.selectedPartyId.value,
                      qty: itemQty,
                      otherDesc: selectedFreeDescription,
                      lrate: rateController.text.trim(),
                      rate: rateController.text.trim(),
                      remarks: selectedRemark,
                      nrate: widget.product.nrate?.toString(),
                      itemName: widget.product.itemName.toString(),
                    )
                    .then((value) => {
                          quantityController.clear(),
                          rateController.clear(),
                          qtyController.clear(),
                          freeQtyController.clear(),
                          remarkController.clear(),
                        });

                // Set product as added
                cartController.productAddedStates[widget.product.itemCd] = true;

                // Increment cart count without triggering full rebuild
                cartController.cartCount.value++;

                // Sync cart data in background without clearing states
                if (controller.selectedPartyId.isNotEmpty) {
                  cart
                      .getCartItem(
                          Get.context!, controller.selectedPartyId.value)
                      .then((_) {
                    // Silently update states without triggering rebuild
                    for (var item in cart.data) {
                      if (!cartController.productAddedStates
                          .containsKey(item.itemCd)) {
                        cartController.productAddedStates[item.itemCd] = true;
                      }
                    }
                    // Update cart count accurately
                    cartController.cartCount.value =
                        cartController.productAddedStates.length;

                    print(cartController.cartCount.value);

                    // Hide keyboard
                    FocusManager.instance.primaryFocus?.unfocus();

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (Get.context != null) {
                          FocusScope.of(Get.context!)
                              .requestFocus(controller.focusNode);
                        }
                      });
                    });
                  });
                }
              } catch (e) {
                //showToast("Error adding product: $e");
                AppSnackBar.showGetXCustomSnackBar(
                    message: "Error adding product: $e");
              } finally {
                // Set loading state to false
                cartController.productLoadingStates[widget.product.itemCd] =
                    false;
              }
            },
            child: Obx(() {
              // Retrieve reactive states with default values if null
              final isLoading =
                  cartController.productLoadingStates[widget.product.itemCd] ??
                      false;
              final isAdded =
                  cartController.productAddedStates[widget.product.itemCd] ??
                      false;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      isAdded ? Colors.green.shade600 : Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: isLoading
                      ? CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Text(
                          isAdded ? 'Product Added' : 'Add To Cart',
                          style:
                              TextStyle(fontSize: 14.sp, color: Colors.white),
                        ),
                ),
              );
            }),
          ),
        ],
      );
    });
  }

  Widget _buildInputFieldsAndDropdowns(
    Size size,
    ProfileProvider profile,
    ProductController controller,
    CartController cartController,
    CartListProvider cart,
  ) {
    // Initialize controllers with stored values from CartController
    final quantityController = TextEditingController(
      text: cartController.getQuantity(widget.product.itemCd),
    );
    final rateController = TextEditingController(
      text: (widget.product.nrate != null && widget.product.nrate!.isNotEmpty)
          ? widget.product.nrate
          : widget.product.srate1.toString(),
    );

    String? selectedFreeDescription =
        cartController.getFreeQuantity(widget.product.itemCd);
    String? selectedRemark = cartController.getRemark(widget.product.itemCd);

    return Obx(() {
      final isLoading =
          cartController.productLoadingStates[widget.product.itemCd] == true;
      final isAdded =
          cartController.productAddedStates[widget.product.itemCd] == true;

      final otherDescEntries = controller.otherDescOptions
          .map((e) => DropdownMenuEntry<String>(
                value: e.NARR_NAME,
                label: e.NARR_NAME,
              ))
          .toList();

      final remarkEntries = controller.fld5DescOptions
          .map((e) => DropdownMenuEntry<String>(
                value: e.NARR_NAME,
                label: e.NARR_NAME,
              ))
          .toList();

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isAdded) // Show only if not added
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: quantityController,
                        decoration: const InputDecoration(
                            hintText: 'Qty', labelText: 'Qty'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          cartController.setQuantity(
                              widget.product.itemCd, value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 2,
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Free',
                          isDense: true,
                          suffixIcon: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              icon: const Icon(Icons.arrow_drop_down),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  freeQtyController.text = newValue;
                                  selectedFreeDescription = newValue;
                                  cartController.setFreeQuantity(
                                      widget.product.itemCd, newValue);
                                }
                              },
                              items: otherDescEntries.map((entry) {
                                return DropdownMenuItem<String>(
                                  value: entry.value,
                                  child: Text(entry.label),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        controller: freeQtyController,
                        onChanged: (value) {
                          selectedFreeDescription = value;
                          cartController.setFreeQuantity(
                              widget.product.itemCd, value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_canEditRate(profile))
                      Expanded(
                        child: TextFormField(
                          controller: rateController,
                          decoration: const InputDecoration(
                              hintText: 'Rate', labelText: 'Rate'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      // onTap: () async {
                      //   if (controller.selectedPartyId.value.isEmpty) {
                      //     AppSnackBar.showGetXCustomSnackBar(
                      //         message: "Please Select Party");
                      //     return;
                      //   }
                      //
                      //   if (isLoading || isAdded) return;
                      //
                      //   cartController
                      //       .productLoadingStates[widget.product.itemCd] = true;
                      //
                      //   final itemQty = quantityController.text.trim().isEmpty
                      //       ? "1"
                      //       : quantityController.text.trim();
                      //
                      //   try {
                      //     await cartController.addItemToCart(
                      //       itemCd: widget.product.itemCd,
                      //       partyid: controller.selectedPartyId.value,
                      //       qty: itemQty,
                      //       otherDesc: selectedFreeDescription,
                      //       lrate: rateController.text.trim(),
                      //       rate: rateController.text.trim(),
                      //       remarks: selectedRemark,
                      //     );
                      //
                      //     // ✅ Mark only this product as added
                      //     cartController
                      //         .productAddedStates[widget.product.itemCd] = true;
                      //
                      //     quantityController.clear();
                      //     rateController.clear();
                      //     freeQtyController.clear();
                      //     qtyController.clear();
                      //     remarkController.clear();
                      //
                      //     cartController.cartCount.value =
                      //         cartController.productAddedStates.length;
                      //   } catch (e) {
                      //     AppSnackBar.showGetXCustomSnackBar(
                      //         message: "Error adding product: $e");
                      //   } finally {
                      //     cartController
                      //             .productLoadingStates[widget.product.itemCd] =
                      //         false;
                      //   }
                      // },

                      onTap: () async {
                        if (controller.selectedPartyId.value.isEmpty) {
                          AppSnackBar.showGetXCustomSnackBar(
                              message: "Please Select Party");
                          return;
                        }

                        // Prevent multiple clicks
                        if (cartController.productAddedStates[
                                    widget.product.itemCd] ==
                                true ||
                            cartController.productLoadingStates[
                                    widget.product.itemCd] ==
                                true) {
                          return;
                        }

                        final qtyText = quantityController.text.trim();
                        final freeText = freeQtyController.text.trim();
                        final settingOn = _shouldShowQty1(profile);

                        // -----------------------------------
                        // 1️⃣ GET Qty using logic
                        // -----------------------------------
                        final itemQty =
                            _getItemQty(profile, quantityController);

                        // -----------------------------------
                        // 2️⃣ VALIDATION WHEN SETTING OFF
                        // -----------------------------------
                        if (!settingOn) {
                          if (qtyText.isEmpty && freeText.isEmpty) {
                            AppSnackBar.showGetXCustomSnackBar(
                                message: "Please Enter Quantity");
                            return;
                          }
                        }

                        // -----------------------------------
                        // 3️⃣ FINAL QTY TO SEND
                        // -----------------------------------
                        String finalQty;

                        if (settingOn) {
                          // Setting ON → itemQty returns "1" or user qty
                          finalQty = itemQty;
                        } else {
                          // Setting OFF → freeQty can allow qty=0
                          if (qtyText.isEmpty && freeText.isNotEmpty) {
                            finalQty = "0"; // freeQty entered → qty = 0
                          } else {
                            finalQty = qtyText.isEmpty ? "0" : qtyText;
                          }
                        }

                        // -----------------------------------
                        // SET LOADING
                        // -----------------------------------
                        cartController
                            .productLoadingStates[widget.product.itemCd] = true;

                        try {
                          await cartController
                              .addItemToCart(
                                itemCd: widget.product.itemCd,
                                partyid: controller.selectedPartyId.value,
                                qty: finalQty,
                                otherDesc: selectedFreeDescription,
                                lrate: rateController.text.trim(),
                                rate: rateController.text.trim(),
                                remarks: selectedRemark,
                                nrate: widget.product.nrate?.toString(),
                                itemName: widget.product.itemName.toString(),
                              )
                              .then((value) => {
                                    quantityController.clear(),
                                    rateController.clear(),
                                    qtyController.clear(),
                                    freeQtyController.clear(),
                                    remarkController.clear(),
                                    // Clear stored values in CartController
                                    cartController.clearProductInputs(
                                        widget.product.itemCd),
                                  });

                          // Mark this product as added immediately
                          cartController
                              .productAddedStates[widget.product.itemCd] = true;

                          // Increment cart count without triggering full rebuild
                          cartController.cartCount.value++;

                          // Sync cart data in background without clearing states
                          if (controller.selectedPartyId.isNotEmpty) {
                            cart
                                .getCartItem(Get.context!,
                                    controller.selectedPartyId.value)
                                .then((_) {
                              // Silently update states without triggering rebuild
                              for (var item in cart.data) {
                                if (!cartController.productAddedStates
                                    .containsKey(item.itemCd)) {
                                  cartController
                                      .productAddedStates[item.itemCd] = true;
                                }
                              }
                              // Update cart count accurately
                              cartController.cartCount.value =
                                  cartController.productAddedStates.length;

                              // Hide keyboard
                              FocusManager.instance.primaryFocus?.unfocus();

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                Future.delayed(
                                    const Duration(milliseconds: 100), () {
                                  if (Get.context != null) {
                                    FocusScope.of(Get.context!)
                                        .requestFocus(controller.focusNode);
                                  }
                                });
                              });
                            });
                          }
                        } catch (e) {
                          AppSnackBar.showGetXCustomSnackBar(
                              message: "Error adding product: $e");
                        } finally {
                          cartController
                                  .productLoadingStates[widget.product.itemCd] =
                              false;
                        }
                      },

                      // onTap: () async {
                      //   if (controller.selectedPartyId.value.isEmpty) {
                      //     AppSnackBar.showGetXCustomSnackBar(
                      //         message: "Please Select Party");
                      //     return;
                      //   }
                      //
                      //   // Prevent multiple clicks
                      //   if (cartController.productAddedStates[
                      //               widget.product.itemCd] ==
                      //           true ||
                      //       cartController.productLoadingStates[
                      //               widget.product.itemCd] ==
                      //           true) {
                      //     return;
                      //   }
                      //
                      //   // Get qty using setting logic
                      //   final itemQty =
                      //       _getItemQty(profile, quantityController);
                      //
                      //   // ❌ If addtocartdef1 = N and qty empty → show message
                      //   if (itemQty.isEmpty) {
                      //     AppSnackBar.showGetXCustomSnackBar(
                      //         message: "Please Enter Quantity");
                      //     return;
                      //   }
                      //
                      //   // Set loading
                      //   cartController
                      //       .productLoadingStates[widget.product.itemCd] = true;
                      //
                      //   try {
                      //     await cartController
                      //         .addItemToCart(
                      //           itemCd: widget.product.itemCd,
                      //           partyid: controller.selectedPartyId.value,
                      //           qty: itemQty,
                      //           otherDesc: selectedFreeDescription,
                      //           lrate: rateController.text.trim(),
                      //           rate: rateController.text.trim(),
                      //           remarks: selectedRemark,
                      //         )
                      //         .then((value) => {
                      //               quantityController.clear(),
                      //               rateController.clear(),
                      //               qtyController.clear(),
                      //               freeQtyController.clear(),
                      //               remarkController.clear(),
                      //             });
                      //
                      //     cartController
                      //         .productAddedStates[widget.product.itemCd] = true;
                      //
                      //     if (controller.selectedPartyId.isNotEmpty) {
                      //       cartController.productAddedStates.clear();
                      //
                      //       await cart.getCartItem(
                      //           Get.context, controller.selectedPartyId.value);
                      //
                      //       for (var item in cart.data) {
                      //         cartController.productAddedStates[item.itemCd] =
                      //             true;
                      //       }
                      //
                      //       cartController.update();
                      //       cartController.cartCount.value =
                      //           cartController.productAddedStates.length;
                      //     }
                      //   } catch (e) {
                      //     AppSnackBar.showGetXCustomSnackBar(
                      //         message: "Error adding product: $e");
                      //   } finally {
                      //     cartController
                      //             .productLoadingStates[widget.product.itemCd] =
                      //         false;
                      //   }
                      // },

                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isAdded
                              ? Colors.green.shade600
                              : Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: isLoading
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                )
                              : Text(
                                  isAdded ? 'Product Added' : 'Add To Cart',
                                  style: TextStyle(
                                      fontSize: 14.sp, color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_shouldShowRemarks(profile))
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Remark',
                      isDense: true,
                      suffixIcon: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          icon: const Icon(Icons.arrow_drop_down),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              remarkController.text = newValue;
                              selectedRemark = newValue;
                              cartController.setRemark(
                                  widget.product.itemCd, newValue);
                            }
                          },
                          items: remarkEntries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.value,
                              child: Text(entry.label),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    controller: remarkController,
                    onChanged: (value) {
                      selectedRemark = value;
                      cartController.setRemark(widget.product.itemCd, value);
                    },
                  ),
              ],
            ),
          if (isAdded) ...[
            const SizedBox(height: 5),
            Builder(builder: (_) {
              final matchedItem = cart.data.firstWhere(
                (element) => element.itemCd == widget.product.itemCd,
                orElse: () => DatumCartList(itemCd: ''),
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (matchedItem.quantity != null)
                    Row(
                      children: [
                        Text(
                          'Qty : ',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '${matchedItem.quantity}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  if (matchedItem.otherDesc != null)
                    SizedBox(
                      width: 10,
                    ),
                  if (matchedItem.otherDesc != null)
                    Row(
                      children: [
                        Text(
                          'Free Qty : ',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '${matchedItem.otherDesc}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                ],
              );
            }),
          ],
          if (isAdded) // Show green added button when already added
            SizedBox(
              height: 5,
            ),
          if (isAdded) // Show green added button when already added
            Text(
              'Item Already In Cart',
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.pink),
            ),
        ],
      );
    });
  }

  Widget _infoRow(String label, String? value,
      {Color? labelColor, Color? valueColor}) {
    if (value == null || value.trim().isEmpty) return SizedBox.shrink();

    return Flexible(
      child: Row(
        children: [
          Flexible(
            child: Text(
              '$label ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.sp,
                color: labelColor ?? Colors.black54,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 12.sp,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  bool _canEditRate(ProfileProvider profile) {
    return profile.data?.profileSettings.any((element) =>
            (element.variable == 'editMasterRateSettings' &&
                element.value == 'Y') ||
            (element.variable == 'editOperatorRateSettings' &&
                element.value == 'Y')) ??
        false;
  }

  bool _shouldShowRemarks(ProfileProvider profile) {
    return profile.data?.profileSettings.any((element) =>
            element.variable == 'showItemWiseRemarks' &&
            element.value == 'Y') ??
        false;
  }

  bool _shouldShowQty1(ProfileProvider profile) {
    return profile.data?.profileSettings.any((element) =>
            element.variable == 'addtocartdef1' && element.value == 'Y') ??
        false;
  }

  String _getItemQty(
      ProfileProvider profile, TextEditingController qtyController) {
    final useDefaultQty =
        _shouldShowQty1(profile); // true when addtocartdef1 = ‘Y’

    print('defult qty setting $useDefaultQty');

    final qtyText = qtyController.text.trim();

    if (qtyText.isEmpty) {
      if (useDefaultQty) {
        print('call qty 1');
        return "1"; // Default Qty = 1
      } else {
        print('call qty empty');
        return ""; // Return empty → we will handle validation
      }
    }

    return qtyText; // User entered qty
  }
}
