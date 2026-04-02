import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/views/ItemWisePartyWisePurchaseReportScreen.dart';
import 'package:arham_corporation/views/narration/narration_view.dart';
import 'package:arham_corporation/views/reimbursement/get_expense_view.dart';
import 'package:arham_corporation/views/route_report_screen.dart';
import 'package:arham_corporation/views/user_selection_screen.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../providers/profile_provider.dart';
import '../../providers/user_provider.dart';
import '../About me.dart';
import '../OutStandingReportPayableScreen.dart';
import '../OutStandingReportReceivableScreen.dart';
import '../PartyWiseOutStandingReportPayableScreen.dart';
import '../PartyWiseOutStandingReportReceivableScreen.dart';
import '../UserWiseOutStandingReportScreen.dart';
import '../accountLedgerScreen.dart';
import '../itemLedgerScreen.dart';
import '../itemWisePartyWiseSaleReportScreen.dart';
import '../itemwiseSaleReportScreen.dart';
import '../loginpage.dart';
import '../orderReportScreen.dart';
import '../partyWiseReport.dart';
import '../payable_payment_settlement_page.dart';
import '../receivable_receipt_settlement_page.dart';
import '../salesRegisterReport.dart';
import '../settingsScreen.dart';
import '../stockReportScreen.dart';
import '../userScreen.dart';
import 'firm_list.dart';

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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

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
      // ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // DrawerHeader(
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //   ),
            //   child: Column(
            //     mainAxisAlignment: MainAxisAlignment.start,
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       // Adjust the position of the image
            //       Image.asset(
            //         'assets/Arham-icon.png',
            //         width: MediaQuery.of(context).size.width *
            //             0.55, // Responsive width
            //         height: MediaQuery.of(context).size.height *
            //             0.14, // Responsive height
            //       ),
            //       // Text("hello")
            //     ],
            //   ),
            // ),

            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Image.asset(
                      'assets/Arham-icon.png',
                      fit: BoxFit.contain,
                      width: MediaQuery.of(context).size.width * 0.55,
                      // Don't use full screen height here
                      height: MediaQuery.of(context).size.height *
                          0.14, // Reduce height
                    ),
                  ),
                ],
              ),
            ),

            // ListTile(
            //   leading: Icon(
            //     Icons.home,
            //     size: 30,
            //   ),
            //   title: Text(
            //     'Home',
            //     style: TextStyle(
            //       fontSize: 20,
            //     ),
            //   ),
            //   onTap: () {
            //     //Get.to(() => HomePage());
            //
            //     Get.offAll(() =>
            //         BottomnavigationBarScreen()); // FAZAL Changes 15-12-2025
            //   },
            // ),
            // ListTile(
            //   leading: Icon(
            //     Icons.widgets_outlined,
            //     size: 30,
            //   ),
            //   title: Text(
            //     'Menus',
            //     style: TextStyle(
            //       fontSize: 20,
            //     ),
            //   ),
            //   onTap: () {
            //     Get.to(() => NewMenu());
            //   },
            // ),
            //if (p.data != null && p.data!.moduleNos.contains("01"))
            // if (p.data != null &&
            //     p.data!.modulesList!.any((module) => module.mODULENO == "301" && module.rEADRIGHT == true))
            //   ListTile(
            //     leading: Icon(
            //       Icons.dashboard,
            //       size: 30,
            //     ),
            //     title: Text(
            //       'DashBoard',
            //       style: TextStyle(fontSize: 20),
            //     ),
            //     onTap: () {
            //       Get.to(() => DailyReportScreen());
            //     },
            //   ),
            if (ub.role == AppConfig.masteruser &&
                (p.data != null &&
                    p.data!.modulesList!.any((module) =>
                        module.mODULENO == "109" && module.rEADRIGHT == true)))
              ListTile(
                leading: Icon(
                  Icons.nat_rounded,
                  size: 30,
                ),
                title: Text(
                  'Narration',
                  style: TextStyle(fontSize: 20),
                ),
                onTap: () {
                  Get.to(NarrationView(), arguments: {
                    "ModuleNo": narrationModuleNo,
                    "ReadRight": narrationReadRight,
                    "WriteRight": narrationWriteRights,
                    "UpdateRight": narrationUpdateRights,
                    "DeleteRight": narrationDeleteRight,
                    "PrintRight": narrationPrintRights,
                  });
                },
              ),
            if (ub.role == AppConfig.masteruser)
              ListTile(
                leading: Icon(
                  Icons.business_sharp,
                  size: 30,
                ),
                title: Text(
                  'Firm Management',
                  style: TextStyle(fontSize: 20),
                ),
                onTap: () {
                  Get.to(() => FirmListPage());
                },
              ),
            if (ub.role == AppConfig.masteruser)
              ListTile(
                leading: Icon(
                  Icons.group,
                  size: 30,
                ),
                title: Text(
                  'User Management',
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
                onTap: () {
                  Get.to(() => UserScreen());
                },
              ),
            // ListTile(
            //   leading: Icon(
            //     Icons.account_circle,
            //     size: 30,
            //   ),
            //   title: Text(
            //     'Profile',
            //     style: TextStyle(fontSize: 20),
            //   ),
            //   onTap: () {
            //     Get.to(() => ProfilePage());
            //   },
            // ),
            if (ub.role == AppConfig.masteruser)
              ListTile(
                leading: Icon(
                  Icons.settings,
                  size: 30,
                ),
                title: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
                onTap: () {
                  Get.to(() => SettingScreen());
                },
              ),
            ListTile(
              leading: Icon(
                Icons.info_outline,
                size: 30,
              ),
              title: Text(
                'About Us',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Get.to(() => AboutPage());
              },
            ),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Colors.red,
                size: 30,
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              onTap: () {
                // Show confirmation dialog
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Logout Confirmation'),
                      content: Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            // Cancel button: Close the dialog
                            Navigator.of(context).pop();
                          },
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            // Confirm logout
                            Navigator.of(context).pop(); // Close the dialog
                            ub.userSignout(context).then((value) {
                              Get.offAll(() => LoginPage());
                            });
                          },
                          child: Text('Logout'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
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
                        "Party wise item wise Order", () {
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
                    _buildIconTextBox(Icons.account_balance, "Route Report",
                        () async {
                      // Route to UserSelectionScreen if master user or parent user with children
                      final ub =
                          Provider.of<UserProvider>(context, listen: false);
                      if (ub.role == AppConfig.masteruser) {
                        print('[NewMenu] 👑 Master user detected - showing user selection');
                        Get.to(() => const UserSelectionScreen(isMasterUser: true));
                      } else {
                        // Check if operator is a parent user
                        print('[NewMenu] 👤 Operator user detected - checking if parent');
                        final isParent = await ub.hasChildren();
                        print('[NewMenu] Parent check result: $isParent');
                        if (isParent) {
                          print('[NewMenu] ✅ Operator is a parent - showing child selection');
                          Get.to(() => const UserSelectionScreen(isMasterUser: false));
                        } else {
                          print('[NewMenu] 📊 Operator is not a parent - showing own route');
                          Get.to(() => const RouteReportScreen());
                        }
                      }
                    }, iconUrl: "assets/icons/route_report.png"),
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
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: 5),
      children: iconTextBoxes,
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
              Text(
                label,
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 1),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
