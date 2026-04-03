import 'package:arham_corporation/views/PartyWiseOutStandingReportPayableScreen.dart';
import 'package:arham_corporation/views/UserWiseOutStandingReportScreen.dart';
import 'package:arham_corporation/views/company_management/firm_list.dart';
import 'package:arham_corporation/views/payable_payment_settlement_page.dart';
import 'package:arham_corporation/views/receivable_receipt_settlement_page.dart';
import 'package:arham_corporation/views/salesRegisterReport.dart';
import 'package:flutter/material.dart';
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/views/OutStandingReportReceivableScreen.dart';
import 'package:arham_corporation/views/PartyWiseOutStandingReportReceivableScreen.dart';
import 'package:arham_corporation/views/loginpage.dart';
import 'package:arham_corporation/views/partyWiseReport.dart';
import 'package:arham_corporation/views/settingsScreen.dart';
import 'package:arham_corporation/views/stockReportScreen.dart';
import 'package:arham_corporation/views/userScreen.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import 'OutStandingReportPayableScreen.dart';
import 'accountLedgerScreen.dart';
import 'itemLedgerScreen.dart';
import 'itemWisePartyWiseSaleReportScreen.dart';
import 'itemwiseSaleReportScreen.dart';
import 'orderReportScreen.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

class MenusPage extends StatefulWidget {
  const MenusPage({Key? key}) : super(key: key);

  @override
  State<MenusPage> createState() => _MenusPageState();
}

class _MenusPageState extends State<MenusPage> {
  @override
  Widget build(BuildContext context) {
    final ProfileProvider p = context.watch<ProfileProvider>();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            Visibility(
              visible: false,
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                    onTap: () {
                      ub.userSignout(context).then((value) {
                        Get.offAll(() => LoginPage());
                      });
                    },
                    child: Icon(Icons.logout)),
              ),
            ),
          ],
          title: Text("Menus"),
        ),
        body: GridView.count(
          crossAxisCount: 3,
          children: [
            if (p.data != null && p.data!.moduleNos.contains("04"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Order Report",
                  onTap: () {
                    Get.to(() => OrderReportScreen());
                  },
                  iconUrl: "assets/icons/order_approve.png",
                ),
              ),
            if (p.data != null && p.data!.moduleNos.contains("02"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Account Ledger",
                  onTap: () {
                    print("sdkfk");
                    Get.to(() => AccountLedgerScreen());
                  },
                  iconUrl: "assets/icons/account_ledger.png",
                ),
              ),
            if (p.data != null && p.data!.moduleNos.contains("07"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Outstanding Receivable",
                  onTap: () {
                    Get.to(() => OutStandingReportReceivableScreen());
                  },
                  iconUrl: "assets/icons/outstanding.png",
                ),
              ),
            if (p.data != null &&
                p.data!.moduleNos.contains(
                    "14")) // TODO : THIS LINE USE FOR CHECK HIDE & SHOW MENU
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Outstanding Payable",
                  onTap: () {
                    Get.to(() => OutStandingReportPayableScreen());
                  },
                  icon: Icons.payment, // IconData
                ),
              ),
            if (p.data != null && p.data!.moduleNos.contains("10"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Party Wise Outstanding Receivable",
                  onTap: () {
                    Get.to(() => PartyWiseOutStandingReportReceivableScreen());
                  },
                  iconUrl: "assets/icons/outstanding.png",
                ),
              ),
            if (p.data != null && p.data!.moduleNos.contains("15"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Party Wise Outstanding Payable",
                  onTap: () {
                    Get.to(() => PartyWiseOutStandingReportPayableScreen());
                  },
                  iconUrl: "assets/icons/outstanding.png",
                ),
              ),
            if (p.data != null &&
                p.data!.moduleNos.contains("11") &&
                ub.role == AppConfig.masteruser &&
                p.data?.profileSettings
                        .firstWhere(
                            (element) => element.variable == 'showUserLinkData')
                        .value ==
                    "Y")
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "User Wise Party Wise Outstanding",
                  onTap: () {
                    Get.to(() => UserWiseOutStandingReportScreen());
                  },
                  iconUrl: "assets/icons/outstanding.png",
                ),
              ),
            if (p.data != null && p.data!.moduleNos.contains("05"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Stock Report",
                  onTap: () {
                    Get.to(() => StockReportScreen());
                  },
                  iconUrl: "assets/icons/stock-report.png",
                ),
              ),
            if (p.data != null && p.data!.moduleNos.contains("08"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Item Wise Sale",
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return ItemWiseSaleReportScreen();
                    }));
                  },
                  iconUrl: "assets/icons/item-wise-sale.png",
                ),
              ),
            if (p.data != null && p.data!.moduleNos.contains("12"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Party Wise Item Wise Sale",
                  onTap: () {
                    Get.to(() => ItemWisePartyWiseSaleReportScreen());
                  },
                  iconUrl: "assets/icons/party-wise-item-wise-sale.png",
                ),
              ),
            if (p.data != null && p.data!.moduleNos.contains("09"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Party Wise Sale",
                  onTap: () {
                    Get.to(() => PartyWiseReportScreen());
                  },
                  iconUrl: "assets/icons/party-wise-sale.png",
                ),
              ),
            if (p.data != null && p.data!.moduleNos.contains("01"))
              if (p.data != null && p.data!.moduleNos.contains("03"))
                Card(
                  elevation: 8,
                  child: MenuContainer(
                    title: "Item Ledger",
                    onTap: () {
                      Get.to(() => ItemLedgerReportScreen());
                    },
                    iconUrl: "assets/icons/item-ledger.png",
                  ),
                ),
            if (p.data != null && p.data!.moduleNos.contains("13"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Sales Register Report",
                  onTap: () {
                    Get.to(() => SalesRegisterReportScreen());
                  },
                  iconUrl: "assets/icons/stock-report.png",
                ),
              ),
            if (ub.role == AppConfig.masteruser)
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Setting",
                  onTap: () {
                    Get.to(() => SettingScreen());
                  },
                  icon: Icons.settings_outlined,
                ),
              ),
            if (ub.role == AppConfig.masteruser)
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Users",
                  onTap: () {
                    Get.to(() => UserScreen());
                  },
                  iconUrl: "assets/icons/users.png",
                ),
              ),
            if (p.data != null && p.data!.moduleNos.contains("16"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Receipt",
                  onTap: () {
                    Get.to(() => ReceivableReceiptSettlementPage());
                  },
                  icon: Icons.receipt, // IconData
                ),
              ),
            if (p.data != null && p.data!.moduleNos.contains("17"))
              Card(
                elevation: 8,
                child: MenuContainer(
                  title: "Payment",
                  onTap: () {
                    Get.to(() => PayablePaymentSettlementPage());
                  },
                  icon: Icons.payment, // IconData
                ),
              ),
            Card(
              elevation: 8,
              child: MenuContainer(
                title: "Firm",
                onTap: () {
                  Get.to(() => FirmListPage());
                },
                icon: Icons.business, // IconData
              ),
            ),
            // if (p.data != null && p.data!.moduleNos.contains("03"))
            //   MenuContainer(
            //     title: "Bill",
            //     onTap: () {
            //       Get.to(() => BillScreen());
            //     },
            //     iconUrl: "assets/icons/order_approve.png",
            //   ),
          ],
        ));
  }
}

class MenuContainer extends StatelessWidget {
  const MenuContainer(
      {super.key,
      required this.title,
      required this.onTap,
      this.iconUrl,
      this.icon});

  final String title;
  final IconData? icon;
  final String? iconUrl;
  final GestureTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 5.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 100.0,
          height: 100.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon == null)
                Image.asset(
                  '${iconUrl}',
                  width: 35.0,
                )
              else
                Icon(icon, size: 30.0, color: Colors.black),
              SizedBox(
                height: 10,
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.w, color: Color(0XFF2c70ba)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
