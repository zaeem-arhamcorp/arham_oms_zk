import 'package:arham_corporation/product/controller/cart_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../providers/profile_provider.dart';
import '../../views/shoppingCartPage.dart';
import '../controller/product_controller.dart';
import 'loading.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String partyID;
  final List<PopupMenuEntry<dynamic>> menuItem;
  final ProductController controller = Get.find();
  final CartController cartController = Get.find();

  MyAppBar(
      {super.key,
      required this.title,
      required this.partyID,
      required this.menuItem});

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    // Removed direct cartProvider reading here.

    controller.showSearch.value = true;

    // return AppBar(
    //   automaticallyImplyLeading: false,
    //   backgroundColor: const Color(0xFF2D9FD9),
    //   elevation: 6.0,
    //   title: Obx(
    //     () => AnimatedSwitcher(
    //       duration: const Duration(milliseconds: 300),
    //       child: controller.showDeptSearch.value
    //           ? _buildSearchDepartment() // Ensure Department search field appears first
    //           : controller.showSearch.value
    //               ? _buildSearchBar()
    //               : Text(
    //                   title,
    //                   key: const ValueKey("AppBarTitle"),
    //                   style: const TextStyle(
    //                     color: Colors.white,
    //                     fontSize: 20,
    //                     fontWeight: FontWeight.bold,
    //                   ),
    //                 ),
    //     ),
    //   ),
    //   actions: _shouldShowExportOptions(profile)
    //       ? [
    //     Obx(
    //           () => IconButton(
    //         onPressed: controller.toggleSearch,
    //         icon: Icon(
    //           controller.showDeptSearch.value
    //               ? Icons.search // Show search icon when department search is active
    //               : (controller.showSearch.value
    //               ? Icons.close // Show close icon if search is active
    //               : Icons.search), // Default to search icon
    //           color: Colors.white,
    //           size: 24,
    //         ),
    //       ),
    //     ),
    //
    //           // Cart Icon with Badge wrapped in a Consumer
    //           Consumer<CartProvider>(
    //             builder: (context, cartProvider, child) {
    //               return Stack(
    //                 children: [
    //                   IconButton(
    //                     onPressed: () {
    //                       Get.to(() => ShoppingCartPage(),
    //                           arguments: {'PartyID': partyID});
    //                     },
    //                     icon: const Icon(
    //                       Icons.shopping_cart,
    //                       color: Colors.white,
    //                       size: 24,
    //                     ),
    //                   ),
    //                   if (cartProvider.data.isNotEmpty)
    //                     Positioned(
    //                       right: 8,
    //                       top: 8,
    //                       child: Container(
    //                         padding: const EdgeInsets.all(2),
    //                         decoration: BoxDecoration(
    //                           color: Colors.red,
    //                           borderRadius: BorderRadius.circular(10),
    //                         ),
    //                         constraints: const BoxConstraints(
    //                           minWidth: 16,
    //                           minHeight: 16,
    //                         ),
    //                         child: Text(
    //                           '${cartProvider.data.length}',
    //                           style: const TextStyle(
    //                             color: Colors.white,
    //                             fontSize: 10,
    //                             fontWeight: FontWeight.bold,
    //                           ),
    //                           textAlign: TextAlign.center,
    //                         ),
    //                       ),
    //                     ),
    //                 ],
    //               );
    //             },
    //           ),
    //           // More Options Menu
    //           PopupMenuButton<dynamic>(
    //             icon:
    //                 const Icon(Icons.more_vert, color: Colors.white, size: 24),
    //             itemBuilder: (context) => menuItem,
    //           ),
    //         ]
    //       : [],
    // );

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF2D9FD9),
      elevation: 6.0,
      title: Obx(
        () => AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: controller.showDeptSearch.value
              ? _buildSearchDepartment()
              : controller.showSearch.value
                  ? _buildSearchBar()
                  : Text(
                      title,
                      key: const ValueKey("AppBarTitle"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
        ),
      ),
      actions: _shouldShowExportOptions(profile)
          ? [
              Obx(
                () => IconButton(
                  onPressed: controller.toggleSearch,
                  icon: Icon(
                    controller.showDeptSearch.value
                        ? Icons.search
                        : (controller.showSearch.value
                            ? Icons.close
                            : Icons.search),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),

              // Cart Icon with Badge using Obx
              Visibility(
                visible: false,
                child: Obx(
                  () => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        highlightColor: Colors.transparent,
                        onPressed: () {
                          Get.to(() => ShoppingCartPage(),
                              arguments: {'PartyID': partyID});
                        },
                        icon: const Icon(
                          Icons.shopping_cart,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      if (cartController.cartCount.value > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () {
                              Get.to(() => ShoppingCartPage(),
                                  arguments: {'PartyID': partyID});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${cartController.cartCount.value}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              Obx(
                () => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Get.to(() => ShoppingCartPage(),
                            arguments: {'PartyID': partyID});
                      },
                      icon: Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 25,
                      ),
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 4), // space between icon and text
                          Text(
                            'Cart',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero, // Remove default padding
                      ),
                    ),
                    if (cartController.cartCount.value > 0)
                      Positioned(
                        right: 25,
                        top: 5,
                        child: GestureDetector(
                          onTap: () {
                            Get.to(() => ShoppingCartPage(),
                                arguments: {'PartyID': partyID});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${cartController.cartCount.value}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // More Options Menu
              PopupMenuButton<dynamic>(
                icon:
                    const Icon(Icons.more_vert, color: Colors.white, size: 24),
                itemBuilder: (context) => menuItem,
              ),
            ]
          : [],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B82F6),
              Color(0xFF0057E7),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Widget _buildSearchBar() {
    return Container(
      width: 500,
      //padding: const EdgeInsets.symmetric(horizontal: 10.0),
      // decoration: const BoxDecoration(
      //   color: Colors.transparent,
      // ),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      margin: EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: Colors.transparent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(Get.context!).copyWith(
          textSelectionTheme: const TextSelectionThemeData(
            selectionColor: Colors.blue,
            cursorColor: Colors.white,
            selectionHandleColor: Colors.blueAccent,
          ),
        ),
        child: TextField(
          controller: controller.searchController,
          focusNode: controller.focusNode,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            // focusedBorder: UnderlineInputBorder(
            //   borderSide: BorderSide(color: Colors.white),
            // ),
            // enabledBorder: UnderlineInputBorder(
            //   borderSide: BorderSide(color: Colors.white),
            // ),
            hintText: "  Use * for multi Search ",
            hintStyle: TextStyle(color: Colors.white, fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12.0),
          ),
          onChanged: controller.searchProducts,
        ),
      ),
    );
  }

  Widget _buildSearchDepartment() {
    return Container(
      width: 500,
      //padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Theme(
        data: Theme.of(Get.context!).copyWith(
          textSelectionTheme: const TextSelectionThemeData(
            selectionColor: Colors.black,
            cursorColor: Colors.black,
            selectionHandleColor: Colors.blue,
          ),
        ),
        child: TextField(
          controller: controller.departmentController,
          focusNode: controller.departmentFocusNode,
          style: const TextStyle(color: Colors.black, fontSize: 16),
          decoration: const InputDecoration(
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
            hintText: "  Department Search ",
            hintStyle: TextStyle(color: Colors.white, fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12.0),
          ),
          //onChanged: controller.searchProducts,
          onChanged: (value) {
            controller.searchDepartments(value);
          },
        ),
      ),
    );
  }
}

bool _shouldShowExportOptions(ProfileProvider profile) {
  return profile.data?.modulesList?.any((module) => module.mODULENO == "205") ??
      false;
}

PopupMenuItem<dynamic> buildMenuItem({
  required IconData icon,
  required String text,
  bool isLoading = false,
  required VoidCallback onTap,
}) {
  return PopupMenuItem(
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    value: text,
    child: GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.blueGrey, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (isLoading) const Loading(),
        ],
      ),
    ),
  );
}
