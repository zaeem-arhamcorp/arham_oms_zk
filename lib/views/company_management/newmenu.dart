import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/views/ItemWisePartyWisePurchaseReportScreen.dart';
import 'package:arham_corporation/views/item_wise_sale/views/item_wise_order_report_view.dart';
import 'package:arham_corporation/views/menu/widgets/menu_grid_tile.dart';
import 'package:arham_corporation/views/menu/widgets/menu_grid_view.dart';
import 'package:arham_corporation/views/menu/widgets/menu_list_tile.dart';
import 'package:arham_corporation/views/menu/widgets/menu_list_view.dart';
import 'package:arham_corporation/views/party_wise_item_wise_order/views/item_wise_party_wise_sale_report_view.dart';
import 'package:arham_corporation/views/reimbursement/get_expense_view.dart';
import 'package:arham_corporation/views/route%20timeline/route_map_view.dart';
import 'package:arham_corporation/views/route_report_screen.dart';
// import 'package:arham_corporation/views/user_selection_screen.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../providers/profile_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common_app_drawer.dart';
import '../OutStandingReportPayableScreen.dart';
import '../OutStandingReportReceivableScreen.dart';
import '../PartyWiseOutStandingReportPayableScreen.dart';
import '../PartyWiseOutStandingReportReceivableScreen.dart';
import '../UserWiseOutStandingReportScreen.dart';
import '../accountLedgerScreen.dart';
import '../itemLedgerScreen.dart';
import '../itemWisePartyWiseSaleReportScreen.dart';
import '../itemwiseSaleReportScreen.dart';
import '../orderReportScreen.dart';
import '../partyWiseReport.dart';
import '../payable_payment_settlement_page.dart';
import '../receivable_receipt_settlement_page.dart';
import '../salesRegisterReport.dart';
import '../stockReportScreen.dart';

class NewMenu extends StatefulWidget {
  const NewMenu({super.key});

  @override
  State<NewMenu> createState() => _NewMenuState();
}

enum MenuViewType {
  grid,
  list,
}

class _NewMenuState extends State<NewMenu> {
  MenuViewType _viewType = MenuViewType.grid;
  final Map<String, bool> _expandedSections = {};

  bool receiptDeleteRight = false;
  bool receiptReadRight = false;
  bool receiptPrintRight = false;
  bool paymentDeleteRight = false;
  bool paymentReadRight = false;
  bool orderDeleteRight = false;
  bool orderPrintRight = false;

  String narrationModuleNo = '';
  bool narrationReadRight = false;
  bool narrationWriteRights = false;
  bool narrationUpdateRights = false;
  bool narrationDeleteRight = false;
  bool narrationPrintRights = false;

  late ProfileProvider _profileProvider;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final ProfileProvider p = _profileProvider;

    // var receiptEntryModule =
    // p.data!.modulesList!.firstWhere((module) => module.mODULENO == "214");
    // receiptDeleteRight = receiptEntryModule.dELETERIGHT!;
    //
    // print("Receipt Delete :" + receiptDeleteRight.toString());

    // var paymentEntryModule =
    // p.data!.modulesList!.firstWhere((module) => module.mODULENO == "215");
    // paymentDeleteRight = paymentEntryModule.dELETERIGHT!;
    //
    // print("Payment Delete :" + paymentDeleteRight.toString());

    var narrationEntryModule = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "109",
          orElse: () => Modules(), // Default value in case not found
        ) ??
        Modules(); // Ensure that we get a default value if any part is null

    if (narrationEntryModule.mODULENO == "109") {
      narrationModuleNo = narrationEntryModule.mODULENO!;
      narrationReadRight = narrationEntryModule.rEADRIGHT!;
      narrationWriteRights = narrationEntryModule.wRITERIGHT!;
      narrationUpdateRights = narrationEntryModule.uPDATERIGHT!;
      narrationDeleteRight = narrationEntryModule.dELETERIGHT!;
      narrationPrintRights = narrationEntryModule.pRINTRIGHT!;
    } else {
      print("Module with mODULENO '109' not found.");
    }

    var receiptEntryModule = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "214",
          orElse: () => Modules(), // Default value in case not found
        ) ??
        Modules(); // Ensure that we get a default value if any part is null

    if (receiptEntryModule.mODULENO == "214") {
      receiptDeleteRight = receiptEntryModule.dELETERIGHT!;
      receiptReadRight = receiptEntryModule.rEADRIGHT!;
      receiptPrintRight = receiptEntryModule.pRINTRIGHT!;
      print("Receipt Delete: " + receiptDeleteRight.toString());
      print("Receipt Red: " + receiptReadRight.toString());
      print("Receipt Print: " + receiptPrintRight.toString());
    } else {
      print("Module with mODULENO '214' not found.");
    }

    var orderReportModule = p.data?.modulesList?.firstWhere(
            (module) => module.mODULENO == "304",
            orElse: () => Modules()) ??
        Modules();
    if (orderReportModule.mODULENO == "304") {
      orderPrintRight = orderReportModule.pRINTRIGHT!;
      print("Order Print :" + orderPrintRight.toString());
    } else {
      print("Module with mODULENO '304' not found.");
    }

    var paymentEntryModule = p.data?.modulesList?.firstWhere(
            (module) => module.mODULENO == "215",
            orElse: () =>
                Modules() // Provide a default instance of the `Module` class
            ) ??
        Modules();

    if (paymentEntryModule.mODULENO == "215") {
      paymentDeleteRight = paymentEntryModule.dELETERIGHT!;
      paymentReadRight = paymentEntryModule.rEADRIGHT!;
      print("Payment Delete: " + paymentDeleteRight.toString());
    } else {
      print("Module with mODULENO '215' not found.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProfileProvider p = context.watch<ProfileProvider>();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    //var specificModule = p.data!.modulesList!.firstWhere((module) => module.mODULENO == "214");
    //var deleteRight = specificModule.dELETERIGHT;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Scaffold(
        // backgroundColor: Color(0xFFF0F3F2),
        // backgroundColor: Colors.white30,
        backgroundColor: Colors.white,
        appBar: CustomAppBar(
          title: 'Menus',
          actions: [
            IconButton(
              icon: Icon(
                _viewType == MenuViewType.grid
                    ? Icons.view_list
                    : Icons.grid_view_rounded,
              ),
              onPressed: () {
                setState(() {
                  _viewType = _viewType == MenuViewType.grid
                      ? MenuViewType.list
                      : MenuViewType.grid;
                });
              },
            ),
          ],
        ),
        // appBar: AppBar(
        //   title: Text(
        //     'Menus',
        //     style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        //   ),
        drawer: CommonAppDrawer(
          narrationModuleNo: narrationModuleNo,
          narrationReadRight: narrationReadRight,
          narrationWriteRights: narrationWriteRights,
          narrationUpdateRights: narrationUpdateRights,
          narrationDeleteRight: narrationDeleteRight,
          narrationPrintRights: narrationPrintRights,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  _buildSection("Transaction", [
                    //if (p.data != null && p.data!.moduleNos.contains("16"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "214" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.receipt_long_outlined,
                          Colors.green, "Receipt Entry \n", () {
                        Get.to(() => ReceivableReceiptSettlementPage(),
                            arguments: {
                              "DeleteRight": receiptDeleteRight,
                              "ReadRight": receiptReadRight,
                            });
                      }),
                    //if (p.data != null && p.data!.moduleNos.contains("17"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "215" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.payments_outlined, Colors.blue,
                          "Payment Entry\n", () {
                        Get.to(() => PayablePaymentSettlementPage(),
                            arguments: {
                              "DeleteRight": paymentDeleteRight,
                              "ReadRight": paymentReadRight,
                            });
                      }),
                    //if (p.data != null && p.data!.moduleNos.contains("12"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "312" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.add_shopping_cart, Colors.orange,
                          "Party wise item wise Sale", () {
                        Get.to(() => ItemWisePartyWiseSaleReportScreen());
                      }),

                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "306" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(
                          Icons.add_shopping_cart,
                          Colors.deepPurple,
                          "Party wise item wise purchase", () {
                        Get.to(() => ItemWisePartyWisePurchaseReportScreen());
                      }),
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "231" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(
                          Icons.attach_money, Colors.teal, "Reimbursement", () {
                        Get.to(() => GetExpenseView());
                      }),
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "324" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.add_shopping_cart, Colors.pink,
                          "Party wise item wise Order", () {
                        Get.to(() => ItemWisePartyWiseSaleReportView());
                      }),
                  ]),
                  _buildSection("Ledgers", [
                    //if (p.data != null && p.data!.moduleNos.contains("02"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "302" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.leaderboard_outlined,
                          Colors.deepPurple, "Account Ledger", () {
                        Get.to(() => AccountLedgerScreen());
                      }, iconUrl: "assets/icons/Account-Ledger.png"),
                    //if (p.data != null && p.data!.moduleNos.contains("03"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "303" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.account_balance_wallet,
                          Colors.blue, "Item Ledger", () {
                        Get.to(() => ItemLedgerReportScreen());
                      }, iconUrl: "assets/icons/item-ledger.png"),
                  ]),
                  _buildSection("Outstanding", [
                    //if (p.data != null && p.data!.moduleNos.contains("07"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "307" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(
                          Icons.receipt_long, Colors.green, "Receivable\n", () {
                        Get.to(() => OutStandingReportReceivableScreen());
                      }, iconUrl: "assets/icons/Receivable.png"),
                    //if (p.data != null && p.data!.moduleNos.contains("14"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "314" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.payment, Colors.pink, "Payable\n",
                          () {
                        Get.to(() => OutStandingReportPayableScreen());
                      }, iconUrl: "assets/icons/Payable.png"),
                    //if (p.data != null && p.data!.moduleNos.contains("10"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "310" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.account_balance, Colors.orange,
                          "Party Wise Receivable", () {
                        Get.to(
                            () => PartyWiseOutStandingReportReceivableScreen());
                      }, iconUrl: "assets/icons/Party-Receivable.png"),
                    //if (p.data != null && p.data!.moduleNos.contains("15"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "315" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.account_balance,
                          Colors.deepPurple, "Party Wise Payable", () {
                        Get.to(() => PartyWiseOutStandingReportPayableScreen());
                      }, iconUrl: "assets/icons/Party-Payable.png"),
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "311" &&
                            module.rEADRIGHT == true) &&
                        ub.role == AppConfig.masteruser &&
                        p.data?.profileSettings
                                .firstWhere((element) =>
                                    element.variable == 'showUserLinkData')
                                .value ==
                            "Y")
                      _buildIconTextBox(Icons.account_balance, Colors.teal,
                          "User Wise Party Wise", () {
                        Get.to(() => UserWiseOutStandingReportScreen());
                      }, iconUrl: "assets/icons/User-Outstanding.png"),
                  ]),
                  _buildSection("Reports", [
                    //if (p.data != null && p.data!.moduleNos.contains("04"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "304" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(
                          Icons.account_balance, Colors.blue, "Order Report",
                          () {
                        Get.to(() => OrderReportScreen(),
                            arguments: {"OrderPrint Right": orderPrintRight});
                      }, iconUrl: "assets/icons/order-report.png"),
                    //if (p.data != null && p.data!.moduleNos.contains("05"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "305" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(
                          Icons.payment, Colors.orange, "Stock Report", () {
                        Get.to(() => StockReportScreen());
                      }, iconUrl: "assets/icons/stock-report.png"),
                    //if (p.data != null && p.data!.moduleNos.contains("08"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "308" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(
                          Icons.account_balance, Colors.green, "Item Wise Sale",
                          () {
                        Get.to(() => ItemWiseSaleReportScreen());
                      }, iconUrl: "assets/icons/item-wise-sale.png"),
                    //if (p.data != null && p.data!.moduleNos.contains("09"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "309" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.account_balance, Colors.pink,
                          "Party Wise Sale ", () {
                        Get.to(() => PartyWiseReportScreen());
                      }, iconUrl: "assets/icons/party-wise-sale.png"),
                    //if (p.data != null && p.data!.moduleNos.contains("13"))
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "313" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.account_balance, Colors.blue,
                          "Sales Register Report", () {
                        Get.to(() => SalesRegisterReportScreen());
                      }, iconUrl: "assets/icons/Sales-Register.png"),
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "321" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.account_balance,
                          Colors.deepPurple, "Route Summary", () {
                        Get.to(() => const RouteReportScreen());
                      }, iconUrl: "assets/icons/route_report_icon.png"),
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "321" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(
                          Icons.account_balance, Colors.brown, "Route Report",
                          () {
                        Get.to(() => const RouteMapView());
                      }, iconUrl: "assets/icons/route_report.png"),
                    if (p.data != null &&
                        p.data!.modulesList!.any((module) =>
                            module.mODULENO == "325" &&
                            module.rEADRIGHT == true))
                      _buildIconTextBox(Icons.account_balance, Colors.orange,
                          "Item Wise Order", () {
                        Get.to(() => ItemWiseOrderReportView());
                      }, iconUrl: "assets/icons/item-wise-sale.png"),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> iconTextBoxes) {
    if (iconTextBoxes.isEmpty)
      return SizedBox.shrink(); // Return empty widget if no iconTextBoxes

    final bool isExpanded = _expandedSections[title] ?? false;

    final List<Widget> visibleItems =
        isExpanded ? iconTextBoxes : iconTextBoxes.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title,
          iconTextBoxes.length > 3,
        ),

        // _buildIconTextWrap(iconTextBoxes),
        _viewType == MenuViewType.grid
            ? MenuGridView(items: visibleItems)
            : MenuListView(items: visibleItems),
        SizedBox(
          height: 10,
        ),
        _viewType == MenuViewType.grid
            ? Divider(
                color: Colors.grey[200],
                height: 0.5,
              ) // Add divider after the section
            : SizedBox.shrink(),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool showViewAll) {
    double screenWidth = MediaQuery.of(context).size.width;
    double horizontalMargin = screenWidth * 0.03; // 5% of screen width

    final bool isExpanded = _expandedSections[title] ?? false;

    return Container(
      alignment: Alignment.centerLeft,
      margin: EdgeInsets.only(top: 8.0, bottom: 0, left: horizontalMargin),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          if (showViewAll)
            TextButton(
              onPressed: () {
                setState(() {
                  _expandedSections[title] = !isExpanded;
                });
              },
              child: Text(
                isExpanded ? "View Less" : "View All",
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget _buildIconTextWrap(List<Widget> iconTextBoxes) {
  //   return GridView.builder(
  //     shrinkWrap: true,
  //     physics: NeverScrollableScrollPhysics(),
  //     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //       crossAxisCount: 2,
  //       crossAxisSpacing: 5,
  //       mainAxisSpacing: 5,
  //       childAspectRatio: 2,
  //     ),
  //     itemCount: iconTextBoxes.length,
  //     itemBuilder: (context, index) => iconTextBoxes[index],
  //   );
  // }

  Widget _buildIconTextBox(
    IconData icon,
    Color iconColor,
    String label,
    VoidCallback onTap, {
    String? iconUrl,
  }) {
    if (_viewType == MenuViewType.list) {
      return MenuListTile(
        icon: icon,
        iconColor: iconColor,
        iconUrl: iconUrl,
        label: label,
        onTap: onTap,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        child: MenuGridTile(
          icon: icon,
          iconColor: iconColor,
          // iconColor: Color(0xFF0057E7),
          label: label,
          iconUrl: iconUrl,
        ),
      ),
    );
  }
}
