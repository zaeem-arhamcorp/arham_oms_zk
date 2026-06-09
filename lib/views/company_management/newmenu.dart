import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/views/ItemWisePartyWisePurchaseReportScreen.dart';
import 'package:arham_corporation/views/item_wise_sale/views/item_wise_order_report_view.dart';
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

class _NewMenuState extends State<NewMenu> {
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

    return Scaffold(
      //backgroundColor: Color(0xFFF0F3F2),
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Menus',
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
                          module.mODULENO == "214" && module.rEADRIGHT == true))
                    _buildIconTextBox(
                        Icons.receipt_long_outlined, "Receipt Entry \n", () {
                      Get.to(() => ReceivableReceiptSettlementPage(),
                          arguments: {
                            "DeleteRight": receiptDeleteRight,
                            "ReadRight": receiptReadRight,
                          });
                    }),
                  //if (p.data != null && p.data!.moduleNos.contains("17"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "215" && module.rEADRIGHT == true))
                    _buildIconTextBox(
                        Icons.payments_outlined, "Payment Entry\n", () {
                      Get.to(() => PayablePaymentSettlementPage(), arguments: {
                        "DeleteRight": paymentDeleteRight,
                        "ReadRight": paymentReadRight,
                      });
                    }),
                  //if (p.data != null && p.data!.moduleNos.contains("12"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "312" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.shopping_bag_outlined,
                        "Party wise item wise Sale", () {
                      Get.to(() => ItemWisePartyWiseSaleReportScreen());
                    }),

                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "306" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.shopping_bag_outlined,
                        "Party wise item wise purchase", () {
                      Get.to(() => ItemWisePartyWisePurchaseReportScreen());
                    }),
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "231" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.attach_money, "Reimbursement", () {
                      Get.to(() => GetExpenseView());
                    }),
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "324" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.shopping_bag_outlined,
                        "Party wise item wise Order", () {
                      Get.to(() => ItemWisePartyWiseSaleReportView());
                    }),
                ]),
                _buildSection("Ledgers", [
                  //if (p.data != null && p.data!.moduleNos.contains("02"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "302" && module.rEADRIGHT == true))
                    _buildIconTextBox(
                        Icons.leaderboard_outlined, "Account Ledger", () {
                      Get.to(() => AccountLedgerScreen());
                    }, iconUrl: "assets/icons/Account-Ledger.png"),
                  //if (p.data != null && p.data!.moduleNos.contains("03"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "303" && module.rEADRIGHT == true))
                    _buildIconTextBox(
                        Icons.account_balance_wallet, "Item Ledger", () {
                      Get.to(() => ItemLedgerReportScreen());
                    }, iconUrl: "assets/icons/item-ledger.png"),
                ]),
                _buildSection("Outstanding", [
                  //if (p.data != null && p.data!.moduleNos.contains("07"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "307" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.receipt_long, "Receivable\n", () {
                      Get.to(() => OutStandingReportReceivableScreen());
                    }, iconUrl: "assets/icons/Receivable.png"),
                  //if (p.data != null && p.data!.moduleNos.contains("14"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "314" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.payment, "Payable\n", () {
                      Get.to(() => OutStandingReportPayableScreen());
                    }, iconUrl: "assets/icons/Payable.png"),
                  //if (p.data != null && p.data!.moduleNos.contains("10"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "310" && module.rEADRIGHT == true))
                    _buildIconTextBox(
                        Icons.account_balance, "Party Wise Receivable", () {
                      Get.to(
                          () => PartyWiseOutStandingReportReceivableScreen());
                    }, iconUrl: "assets/icons/Party-Receivable.png"),
                  //if (p.data != null && p.data!.moduleNos.contains("15"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "315" && module.rEADRIGHT == true))
                    _buildIconTextBox(
                        Icons.account_balance, "Party Wise Payable", () {
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
                    _buildIconTextBox(
                        Icons.account_balance, "User Wise Party Wise", () {
                      Get.to(() => UserWiseOutStandingReportScreen());
                    }, iconUrl: "assets/icons/User-Outstanding.png"),
                ]),
                _buildSection("Reports", [
                  //if (p.data != null && p.data!.moduleNos.contains("04"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "304" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.account_balance, "Order Report",
                        () {
                      Get.to(() => OrderReportScreen(),
                          arguments: {"OrderPrint Right": orderPrintRight});
                    }, iconUrl: "assets/icons/order-report.png"),
                  //if (p.data != null && p.data!.moduleNos.contains("05"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "305" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.payment, "Stock Report", () {
                      Get.to(() => StockReportScreen());
                    }, iconUrl: "assets/icons/stock-report.png"),
                  //if (p.data != null && p.data!.moduleNos.contains("08"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "308" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.account_balance, "Item Wise Sale",
                        () {
                      Get.to(() => ItemWiseSaleReportScreen());
                    }, iconUrl: "assets/icons/item-wise-sale.png"),
                  //if (p.data != null && p.data!.moduleNos.contains("09"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "309" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.account_balance, "Party Wise Sale ",
                        () {
                      Get.to(() => PartyWiseReportScreen());
                    }, iconUrl: "assets/icons/party-wise-sale.png"),
                  //if (p.data != null && p.data!.moduleNos.contains("13"))
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "313" && module.rEADRIGHT == true))
                    _buildIconTextBox(
                        Icons.account_balance, "Sales Register Report", () {
                      Get.to(() => SalesRegisterReportScreen());
                    }, iconUrl: "assets/icons/Sales-Register.png"),
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "321" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.account_balance, "Route Summary",
                        () {
                      Get.to(() => const RouteReportScreen());
                    }, iconUrl: "assets/icons/route_report_icon.png"),
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "321" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.account_balance, "Route Report",
                        () {
                      Get.to(() => const RouteMapView());
                    }, iconUrl: "assets/icons/route_report.png"),
                  if (p.data != null &&
                      p.data!.modulesList!.any((module) =>
                          module.mODULENO == "325" && module.rEADRIGHT == true))
                    _buildIconTextBox(Icons.account_balance, "Item Wise Order",
                        () {
                      Get.to(() => ItemWiseOrderReportView());
                    }, iconUrl: "assets/icons/item-wise-sale.png"),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> iconTextBoxes) {
    if (iconTextBoxes.isEmpty)
      return SizedBox.shrink(); // Return empty widget if no iconTextBoxes

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        _buildIconTextWrap(iconTextBoxes),
        Divider(color: Colors.black), // Add divider after the section
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    double screenWidth = MediaQuery.of(context).size.width;
    double horizontalMargin = screenWidth * 0.05; // 5% of screen width

    return Container(
      alignment: Alignment.centerLeft,
      margin: EdgeInsets.only(top: 8.0, bottom: 8, left: horizontalMargin),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
      ),
    );
  }

  Widget _buildIconTextWrap(List<Widget> iconTextBoxes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.75,
      ),
      itemCount: iconTextBoxes.length,
      itemBuilder: (context, index) => iconTextBoxes[index],
    );
  }

  Widget _buildIconTextBox(IconData icon, String label, VoidCallback onTap,
      {String? iconUrl}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        child: IconTextBox(
          icon: icon,
          label: label,
          iconUrl: iconUrl,
        ),
      ),
    );
  }
}

class IconTextBox extends StatelessWidget {
  final IconData? icon;
  final String? iconUrl;
  final String label;

  IconTextBox({this.icon, this.iconUrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double iconSize =
            constraints.maxWidth * 0.4; // Adjust the multiplier as needed
        double fontSize =
            constraints.maxWidth * 0.1; // Adjust the multiplier as needed

        return Container(
          padding: EdgeInsets.all(1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(iconSize * 0.25),
                // Adjust padding relative to icon size
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: iconUrl != null
                    ? Image.asset(
                        iconUrl!,
                        width: iconSize,
                        height: iconSize,
                      )
                    : Icon(
                        icon,
                        size: iconSize,
                        color: Colors.black,
                      ),
              ),
              SizedBox(height: 3),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
