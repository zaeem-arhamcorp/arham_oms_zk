import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/company_management/firm_list.dart';
import 'package:arham_corporation/views/loginpage.dart';
import 'package:arham_corporation/views/narration/narration_view.dart';
import 'package:arham_corporation/views/settingsScreen.dart';
import 'package:arham_corporation/views/userScreen.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/dailReportListModal.dart';
import 'About me.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({Key? key}) : super(key: key);

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  DataDailyReport? data;
  bool noListparty = false;
  bool noListitem = false;
  bool noListtrangstion = false;
  bool loading = false;

  TextEditingController fromdateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  TextEditingController searchItemClt = TextEditingController();

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

  getDate() {
    var f;
    var t;
    setState(() {
      data = null;
      noListparty = false;
      noListitem = false;
      noListtrangstion = false;
      // f = DateFormat("yyyy-MM-dd")
      //     .format(DateTime.parse(fromdateController.text));
      // t = DateFormat("yyyy-MM-dd")
      //     .format(DateTime.parse(toDateController.text));
      // f = "30-03-2022";
      // t = "31-03-2023";
      f = Helper.toApi(fromdateController.text);
      t = Helper.toApi(toDateController.text);
      loading = true;
    });

    Services().getDailyReport(context, f, t).then((value) {
      if (mounted) {
        setState(() {
          if (value != null) {
            data = value.data;
            if (data!.party.isEmpty) {
              noListparty = true;
            }
            if (data!.items.isEmpty) {
              noListitem = true;
            }
            // if (data!.overview.account.isEmpty) {
            //   noListtrangstion = true;
            // }
          } else {
            setState(() {
              noListparty = true;
              noListitem = true;
              noListtrangstion = true;
            });
          }
          loading = false;
        });
      }
    });
  }

  @override
  void initState() {

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

    // fromdateController.text = Helper.getDefaultFromDate();
    // toDateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());

    fromdateController.text = Helper.toUi(Helper.getDefaultFromDate());
    toDateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));

    getDate();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final ProfileProvider p = context.watch<ProfileProvider>();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Business Statistics',
      ),
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
                      height: MediaQuery.of(context).size.height * 0.14, // Reduce height
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
                    p.data!.modulesList!
                        .any((module) => module.mODULENO == "109" && module.rEADRIGHT == true)))
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
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "From Date",
                        ),
                        SizedBox(
                          height: 5.h,
                        ),
                        TextFormField(
                          controller: fromdateController,
                          readOnly: true, // prevent keyboard
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            hintText: "Select date",
                            suffixIcon: GestureDetector(
                              onTap: () {
                                setState(() {
                                  // fromdateController.text =
                                  //     DateFormat("yyyy-MM-dd")
                                  //         .format(DateTime.now());

                                  fromdateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));
                                });
                                getDate();
                              },
                              child: Tooltip(
                                message: "Today",
                                child: Icon(Icons.today_outlined),
                              ),
                            ),
                          ),
                          onTap: () {
                            DatePicker.showDatePicker(
                              context,
                              showTitleActions: true,
                              minTime: DateTime(2000, 1, 1),
                              maxTime: DateTime(2100, 12, 31),
                              currentTime: DateTime.now(),
                              locale: LocaleType.en,
                              onConfirm: (date) {
                                setState(() {
                                  // fromdateController.text =
                                  //     DateFormat("yyyy-MM-dd").format(date);
                                  fromdateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(date));
                                });
                                getDate();
                              },
                            );
                          },
                          validator: (val) {
                            print(val);
                            return null;
                          },
                        ),
                        // DateTimePicker(
                        //   controller: fromdateController,
                        //   decoration: InputDecoration(
                        //     contentPadding: EdgeInsets.symmetric(
                        //         vertical: 10.0, horizontal: 5),
                        //     border: OutlineInputBorder(
                        //         borderRadius: BorderRadius.circular(12)),
                        //     hintText: "Select date",
                        //     suffixIcon: GestureDetector(
                        //         onTap: () {
                        //           setState(() {
                        //             fromdateController.text =
                        //                 DateFormat("yyyy-MM-dd")
                        //                     .format(DateTime.now());
                        //           });
                        //           getDate();
                        //         },
                        //         child: Tooltip(
                        //             message: "Today",
                        //             child: Icon(Icons.today_outlined))),
                        //   ),
                        //   firstDate: DateTime(-21000),
                        //   initialDate: DateTime.now(),
                        //   lastDate: DateTime.now(),
                        //   dateLabelText: 'Select Date',
                        //   onChanged: (val) {
                        //     getDate();
                        //   },
                        //   validator: (val) {
                        //     print(val);
                        //     return null;
                        //   },
                        // ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "To Date",
                        ),
                        SizedBox(
                          height: 5.h,
                        ),
                        TextFormField(
                          controller: toDateController,
                          readOnly: true, // prevent keyboard
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            hintText: "Select date",
                            suffixIcon: GestureDetector(
                              onTap: () {
                                setState(() {
                                  toDateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));
                                  // toDateController.text =
                                  //     DateFormat("yyyy-MM-dd").format(date);
                                });
                                getDate();
                              },
                              child: Tooltip(
                                message: "Today",
                                child: Icon(Icons.today_outlined),
                              ),
                            ),
                          ),
                          onTap: () {
                            DatePicker.showDatePicker(
                              context,
                              showTitleActions: true,
                              minTime: DateTime(2000, 1, 1),
                              maxTime: DateTime(2100, 12, 31),
                              currentTime: DateTime.now(),
                              locale: LocaleType.en,
                              onConfirm: (date) {
                                setState(() {
                                  toDateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(date));
                                  // toDateController.text =
                                  //     DateFormat("yyyy-MM-dd").format(date);
                                });
                                getDate();
                              },
                            );
                          },
                          validator: (val) {
                            print(val);
                            return null;
                          },
                        ),
                        // DateTimePicker(
                        //   controller: toDateController,
                        //   decoration: InputDecoration(
                        //       contentPadding: EdgeInsets.symmetric(
                        //           vertical: 10.0, horizontal: 5),
                        //       border: OutlineInputBorder(
                        //           borderRadius: BorderRadius.circular(12)),
                        //       hintText: "Select date"),
                        //   firstDate: DateTime(-21000),
                        //   initialDate: DateTime.now(),
                        //   lastDate: DateTime(21000),
                        //   dateLabelText: 'Select Date',
                        //   onChanged: (val) {
                        //     getDate();
                        //   },
                        //   validator: (val) {
                        //     print(val);
                        //     return null;
                        //   },
                        // )
                      ],
                    ),
                  )
                ],
              ),
            ),
            Divider(),
            Expanded(
              child: (noListitem == true &&
                  noListparty == true &&
                  noListtrangstion == true)
                  ? Center(
                child: Text("No Data found"),
              )
                  : data == null
                  ? Center(
                child: CircularProgressIndicator(),
              )
                  : ListView(
                children: [
                  if (data!.overview.account.isNotEmpty ||
                      data!.overview.inventory.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Company Overview",
                            style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (data!.overview.inventory.length != 0)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 8, right: 8, top: 8),
                            child: Container(
                              width: double.infinity,
                              height: 27.h,
                              color: Color(0XFF2c9ed9),
                              child: Center(
                                child: Text(
                                  "Inventory",
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ListView.builder(
                            itemCount: data!.overview.inventory.length,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              return Container(
                                padding: EdgeInsets.only(
                                    left: 10.0,
                                    right: 10.0,
                                    top: 10.0,
                                    bottom: 10.0),
                                decoration: BoxDecoration(
                                  color: index % 2 == 0
                                      ? Colors.grey[200]
                                      : Colors.white,
                                ),
                                child: Row(
                                  // mainAxisAlignment:
                                  //     MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        //"${Helper.trimValue(data!.overview.account[index].label, 30)}",
                                          data!.overview
                                              .inventory[index].label,
                                          maxLines: null,
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                              overflow:
                                              TextOverflow.visible,
                                              fontWeight:
                                              FontWeight.bold)),
                                    ),
                                    Visibility(
                                      visible:false,
                                      child: Expanded(
                                        child: Text(
                                            "(${data!.overview.inventory[index].record})",
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                                color: Colors.grey[400],
                                                fontWeight:
                                                FontWeight.bold)),
                                      ),
                                    ),
                                    Text(
                                        "(${data!.overview.inventory[index].record})",
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontWeight:
                                            FontWeight.bold)),
                                    Expanded(
                                      child: Text(
                                          "₹ ${Helper.parseNumericValue(data!.overview.inventory[index].vouchAmt)}",
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                              fontWeight:
                                              FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        if (data!.overview.account.length != 0)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 8, right: 8, top: 8),
                            child: Container(
                              width: double.infinity,
                              height: 27.h,
                              color: Color(0XFF2c9ed9),
                              child: Center(
                                child: Text(
                                  "Accounts",
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ListView.builder(
                            itemCount: data!.overview.account.length,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              // Extract the account list
                              var accountList = data!.overview.account;
        
                              // Find the index of the "Liquid Balance:" label
                              var liquidBalanceIndex =
                              accountList.indexWhere((item) =>
                              item.label == "Liquid Balance:");
        
                              // Variable to store the sum of values below the Liquid Balance label
                              double sumBelowLiquidBalance = 0.0;
                              int countBelowLiquidBalance =
                              0; // Variable to store the number of items below the Liquid Balance
        
                              // If Liquid Balance exists, sum the values of all items below it
                              if (liquidBalanceIndex != -1) {
                                var itemsBelowLiquidBalance = accountList
                                    .sublist(liquidBalanceIndex +
                                    1); // Get items after the Liquid Balance
        
                                countBelowLiquidBalance =
                                    itemsBelowLiquidBalance.length;
        
                                //TODO : Comment Fazal 03/12/2025
                                // Filter out invalid "VOUCH_AMT" values (e.g., ".") and sum the rest
                                // sumBelowLiquidBalance =
                                //     itemsBelowLiquidBalance
                                //         .where((item) =>
                                //     item.vouchAmt != ".")
                                //         .map((item) =>
                                //     double.tryParse(
                                //         item.vouchAmt) ??
                                //         0.0)
                                //         .reduce((a, b) => a + b);
        
                                sumBelowLiquidBalance =
                                    itemsBelowLiquidBalance
                                        .where((item) => item.vouchAmt != ".")
                                        .map((item) => double.tryParse(item.vouchAmt) ?? 0.0)
                                        .fold(0.0, (a, b) => a + b);
                              }
        
                              return Container(
                                padding: EdgeInsets.only(
                                    left: 10.0,
                                    right: 10.0,
                                    top: 10.0,
                                    bottom: 10.0),
                                decoration: BoxDecoration(
                                  color: index % 2 == 0
                                      ? Colors.grey[200]
                                      : Colors.white,
                                ),
                                child: Row(
                                  // mainAxisAlignment:
                                  //     MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Label display
                                    Expanded(
                                      child: Text(
                                        //data!.overview.account[index].label,
                                        data!.overview.account[index]
                                            .label
                                            .replaceAll(':', ''),
                                        maxLines: null,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                            overflow:
                                            TextOverflow.visible,
                                            fontWeight:
                                            FontWeight.bold),
                                      ),
                                    ),
                                    // Record value display
                                    Text(
                                      "${data!.overview.account[index].record != '.' ? "(${data!.overview.account[index].record})" : ""}",
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontWeight: FontWeight.bold),
                                    ),
                                    // Amount display
                                    Expanded(
                                      child: Text(
                                        "${data!.overview.account[index].vouchAmt != '.' ? '₹ ' + Helper.parseNumericValue(data!.overview.account[index].vouchAmt) : ""}",
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                            fontWeight:
                                            FontWeight.bold),
                                      ),
                                    ),
                                    //TODO: Liquid Balance: FAZAL ADD Comment 07/04/2025
                                    // Display sum below Liquid Balance when it's found
                                    if (data!.overview.account[index]
                                        .label ==
                                        "Liquid Balance:")
                                      Visibility(
                                        visible: false,
                                        child: Text(
                                          "(${countBelowLiquidBalance.toString()})",
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                              color: Colors.grey[400],
                                              fontWeight:
                                              FontWeight.bold),
                                        ),
                                      ),
                                    if (data!.overview.account[index]
                                        .label ==
                                        "Liquid Balance:")
                                      Text(
                                        "₹ ${Helper.parseNumericValue(sumBelowLiquidBalance.toStringAsFixed(2))}",
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  if (data!.party.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            elevation: 2,
                            child: Container(
                              width: double.infinity,
                              height: 27.h,
                              color: Color(0XFF2c9ed9),
                              child: Center(
                                child: Text(
                                  "Top Party",
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ListView.builder(
                              itemCount: data!.party.length,
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                return Column(
                                  children: [
                                    if (index == 0)
                                      Card(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(
                                                1),
                                            side: BorderSide(
                                                color: Colors.grey)),
                                        child: Container(
                                          color: Colors.white,
                                          child: Padding(
                                            padding:
                                            const EdgeInsets.all(
                                                8.0),
                                            child: IntrinsicHeight(
                                              child: Row(
                                                children: <Widget>[
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                      children: [
                                                        Text(
                                                          "Acc Code",
                                                          style: TextStyle(
                                                              fontSize:
                                                              12,
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  VerticalDivider(),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                      children: [
                                                        Text(
                                                          "Account Name",
                                                          style: TextStyle(
                                                              fontSize:
                                                              12,
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  VerticalDivider(),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                      children: [
                                                        Align(
                                                          alignment:
                                                          Alignment
                                                              .topRight,
                                                          child: Text(
                                                            "Amount",
                                                            style: TextStyle(
                                                                fontSize:
                                                                12,
                                                                fontWeight:
                                                                FontWeight.bold),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(1),
                                          side: BorderSide(
                                              color: Colors.grey)),
                                      child: Container(
                                        color: Colors.white,
                                        child: Padding(
                                          padding: const EdgeInsets.all(
                                              12.0),
                                          child: Column(
                                            children: [
                                              IntrinsicHeight(
                                                child: Row(
                                                  children: <Widget>[
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                        children: [
                                                          Text(
                                                            "${data!.party[index].accCd}",
                                                            style: TextStyle(
                                                                fontSize:
                                                                12,
                                                                color: Colors
                                                                    .black),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                    VerticalDivider(),
                                                    Expanded(
                                                      flex: 3,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                        children: [
                                                          Text(
                                                            "${data!.party[index].accName}",
                                                            style: TextStyle(
                                                                fontSize:
                                                                12,
                                                                color: Colors
                                                                    .black),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                    VerticalDivider(),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                        children: [
                                                          Align(
                                                            alignment:
                                                            Alignment
                                                                .topRight,
                                                            child: Text(
                                                              "${Helper.parseNumericValue(data!.party[index].vouchAmt.toString())}",
                                                              style:
                                                              TextStyle(
                                                                fontSize:
                                                                12,
                                                                color: Colors
                                                                    .green,
                                                              ),
                                                            ),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                        ],
                      ),
                    ),
                  if (data!.items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            elevation: 2,
                            child: Container(
                              width: double.infinity,
                              height: 27.h,
                              color: Color(0XFF2c9ed9),
                              child: Center(
                                child: Text(
                                  "Top Items",
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ListView.builder(
                              itemCount: data!.items.length,
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                return Column(
                                  children: [
                                    if (index == 0)
                                      Card(
                                        child: Container(
                                          color: Colors.white,
                                          child: Padding(
                                            padding:
                                            const EdgeInsets.all(
                                                8.0),
                                            child: IntrinsicHeight(
                                              child: Row(
                                                children: <Widget>[
                                                  Expanded(
                                                    child: Column(
                                                      children: [
                                                        Text(
                                                          "Item Code",
                                                          style: TextStyle(
                                                              fontSize:
                                                              12,
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  VerticalDivider(),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                      children: [
                                                        Text(
                                                          "Item Name",
                                                          style: TextStyle(
                                                              fontSize:
                                                              12,
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  VerticalDivider(),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                      children: [
                                                        Align(
                                                          alignment:
                                                          Alignment
                                                              .topRight,
                                                          child: Text(
                                                            "Amount",
                                                            style: TextStyle(
                                                                fontSize:
                                                                12,
                                                                fontWeight:
                                                                FontWeight.bold),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Card(
                                      child: Container(
                                        color: Colors.white,
                                        child: Padding(
                                          padding:
                                          const EdgeInsets.all(8),
                                          child: Column(
                                            children: [
                                              IntrinsicHeight(
                                                child: Row(
                                                  children: <Widget>[
                                                    Expanded(
                                                      child: Column(
                                                        children: [
                                                          Text(
                                                            "${data!.items[index].itemCd}",
                                                            style: TextStyle(
                                                                fontSize:
                                                                12,
                                                                color: Colors
                                                                    .black),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                    VerticalDivider(),
                                                    Expanded(
                                                      flex: 3,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                        children: [
                                                          Text(
                                                            "${data!.items[index].itemName}",
                                                            style: TextStyle(
                                                                fontSize:
                                                                12,
                                                                color: Colors
                                                                    .black),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                    VerticalDivider(),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                        children: [
                                                          Align(
                                                            alignment:
                                                            Alignment
                                                                .topRight,
                                                            child: Text(
                                                              "${Helper.parseNumericValue(data!.items[index].vouchAmt.toString())}",
                                                              style: TextStyle(
                                                                  fontSize:
                                                                  12,
                                                                  color:
                                                                  Colors.green),
                                                            ),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildInnerBox({
    required String label,
    required String record,
    required String amount,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        width: double.infinity,
        height: 52.0,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black, width: 2)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "   ($record)",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Text(
                  "₹ $amount",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),

    );
  }
}
