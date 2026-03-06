import 'dart:convert';
import 'dart:developer';

import 'package:arham_corporation/helper/network_helper.dart';
import 'package:arham_corporation/helper/notification_services.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/location_provider.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:arham_corporation/views/About%20me.dart';
import 'package:arham_corporation/views/change_password/change_password_view.dart';
import 'package:arham_corporation/views/settingsScreen.dart';
import 'package:arham_corporation/views/userScreen.dart';
import 'package:flutter/material.dart';
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/dashboardmodal.dart';
import 'package:arham_corporation/providers/global.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/loginpage.dart';
import 'package:arham_corporation/views/orderReportScreen.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../providers/item_list_provider.dart';
import '../services/authservices.dart';
import '../services/services.dart';
import '../services/offline_caching_service.dart';
import 'package:http/http.dart' as http;

import '../widgets/bottomnavebar.dart';
import 'company_management/firm_list.dart';
import 'narration/narration_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DashboardModal? data;
  bool nolist = false;

  getDashboarddata() async {
    setState(() {
      data = null;
      nolist = false;
    });

    bool online = await NetworkHelper.hasInternet();

    if (online) {
      Services().getDashboarddata(context).then((value) async {
        if (value != null) {
          setState(() {
            data = value;
            if (data!.data.labelData.transaction.isEmpty) {
              nolist = true;
            }
          });

          // Cache dashboard data for offline use (always cache valid data)
          try {
            await DatabaseHelper().cacheHomeData(
              'dashboard',
              dashboardModalToJson(value),
            );
            print("Dashboard cached successfully");
          } catch (e) {
            print("Error caching dashboard data: $e");
          }
        } else {
          setState(() {
            nolist = true;
          });
        }
      });
    } else {
      // Offline: load from cache
      try {
        final cached = await DatabaseHelper().getCachedHomeData('dashboard');
        if (cached != null && cached.isNotEmpty && cached != 'null') {
          final cachedData = dashboardModalFromJson(cached);
          setState(() {
            data = cachedData;
            if (data!.data.labelData.transaction.isEmpty) {
              nolist = true;
            }
          });
        } else {
          setState(() {
            nolist = true;
          });
        }
      } catch (e) {
        print("Error loading cached dashboard: $e");
        setState(() {
          nolist = true;
        });
      }
    }
  }

  List<Map<String, dynamic>> firmList = [];
  int? selectedSyncId; // Stores the selected sync ID
  String? selectedFirmName; // Stores the selected firm name
  bool isLoading = true;

  String narrationModuleNo = '';
  bool narrationReadRight = false;
  bool narrationWriteRights = false;
  bool narrationUpdateRights = false;
  bool narrationDeleteRight = false;
  bool narrationPrintRights = false;

  @override
  void initState() {
    //fetchData();
    notification();

    loadData();
    getDashboarddata();

    // Show any pending order-limit warning received from the last order API call.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      if (profile.pendingWarning != null &&
          profile.pendingWarning!.isNotEmpty) {
        AppSnackBar.showGetXCustomSnackBar(
          message: profile.pendingWarning!,
          backgroundColor: Colors.orange,
        );
        profile.clearPendingWarning();
      }
    });

    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

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

    super.initState();
  }

  void notification() async {
    await NotificationService().requestNotificationPermission();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
    // TODO: implement setState
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final UserProvider ub = context.watch<UserProvider>();
    final ProfileProvider p = context.watch<ProfileProvider>();
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    final Global global = context.watch<Global>();
    final LocationProvider location = context.watch<LocationProvider>();
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          iconTheme: const IconThemeData(
            color: Colors.white, // 👈 makes drawer/menu icon white
          ),
          title: GestureDetector(
              onTap: () {
                log(ub.token.toString());
              },
              //child: Text(p.data != null
              //    ? Helper.trimValue(p.data!.compName.toString(), 30)
              //    : "")
              // child: PopupMenuButton<int>(
              //   child: Container(
              //     child: Row(
              //       mainAxisAlignment: MainAxisAlignment.start,
              //       children: [
              //         Flexible(
              //           child: Text(
              //             ub.syncName ?? "No Name",
              //             maxLines: 1,
              //             textAlign: TextAlign.center,
              //             style: TextStyle(
              //                 color: Colors.white, fontWeight: FontWeight.w800),
              //           ),
              //         ),
              //         SizedBox(
              //           width: 10,
              //         ),
              //         Container(
              //             width: 20,
              //             height: 30,
              //             decoration: BoxDecoration(
              //               borderRadius: BorderRadius.circular(8),
              //               color: Colors.lightBlue.shade100,
              //             ),
              //             child: Row(
              //               children: [
              //                 Icon(
              //                   Icons.keyboard_double_arrow_down_rounded,
              //                   color: Color(0XFF2c9ed9),
              //                   size: 20,
              //                 )
              //               ],
              //             ))
              //       ],
              //     ),
              //   ),
              //   onSelected: (int? newValue) {
              //     setState(() {
              //       selectedSyncId = newValue;
              //
              //       selectedFirmName = firmList.firstWhere(
              //         (firm) => firm['syncId'] == newValue,
              //         orElse: () => {'firmName': 'Unknown'},
              //       )['firmName'];
              //
              //       final UserProvider ub =
              //           Provider.of<UserProvider>(context, listen: false);
              //
              //       ub.saveSyncId(newValue.toString());
              //       ub.saveSyncName(selectedFirmName);
              //
              //       final PartyProvider party =
              //       Provider.of<PartyProvider>(context,
              //           listen: false);
              //       party.clearParty();
              //       party.clearPunchInOutParty();
              //
              //       // Fluttertoast.showToast(
              //       //     msg: 'Please wait, loading firm data...');
              //
              //       AppSnackBar.showGetXCustomSnackBar(message:'Please wait, loading firm data...',backgroundColor: Colors.green);
              //
              //       Authservices()
              //           .fetchlogin(
              //               selectedSyncId.toString(), ub.token!, context)
              //           .then((value) {
              //         if (value != null) {
              //           ub
              //               .saveUserData(value["role"] ?? "", value["token"])
              //               .then((value) {
              //             ub.setSignIn().then((value) {
              //               context.read<LocationProvider>().start(context);
              //               context.read<PartyProvider>().getpartyname(context);
              //               context.read<ItemListProvider>().getItems(context);
              //               context
              //                   .read<ProfileProvider>()
              //                   .getProfile(context)
              //                   .then((value) {
              //                 Get.offAll(() => BottomnavigationBarScreen());
              //               });
              //             });
              //           });
              //         }
              //       });
              //     });
              //   },
              //   itemBuilder: (BuildContext context) {
              //     return firmList.map((firm) {
              //       return PopupMenuItem<int>(
              //         value: firm['syncId'],
              //         child: Text(
              //           firm['firmName'],
              //           style: TextStyle(fontSize: 18.0),
              //         ),
              //       );
              //     }).toList();
              //   },
              // )

              child: PopupMenuButton<int>(
                constraints: BoxConstraints(
                  minWidth:
                      MediaQuery.of(context).size.width, // Set desired width
                ),
                //offset: Offset(0, 50),
                child: Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          ub.syncName ?? "No Name",
                          maxLines: 1,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 30,
                      ),
                      // Container(
                      //     width: 20,
                      //     height: 30,
                      //     decoration: BoxDecoration(
                      //       borderRadius: BorderRadius.circular(8),
                      //       color: Colors.lightBlue.shade100,
                      //     ),
                      //     child: Row(
                      //       children: [
                      //         Icon(
                      //           Icons.keyboard_double_arrow_down_rounded,
                      //           color: Color(0XFF2c9ed9),
                      //           size: 20,
                      //         )
                      //       ],
                      //     ))
                    ],
                  ),
                ),
                onSelected: (int? newValue) {
                  setState(() {
                    selectedSyncId = newValue;

                    selectedFirmName = firmList.firstWhere(
                      (firm) => firm['syncId'] == newValue,
                      orElse: () => {'firmName': 'Unknown'},
                    )['firmName'];

                    final UserProvider ub =
                        Provider.of<UserProvider>(context, listen: false);

                    ub.saveSyncId(newValue.toString());
                    ub.saveSyncName(selectedFirmName);

                    final PartyProvider party =
                        Provider.of<PartyProvider>(context, listen: false);
                    party.clearParty();
                    party.clearPunchInOutParty();

                    // Fluttertoast.showToast(
                    //     msg: 'Please wait, loading firm data...');

                    AppSnackBar.showGetXCustomSnackBar(
                        message: 'Please wait, loading firm data...',
                        backgroundColor: Colors.green);

                    AuthServices()
                        .changeFirmLogin(
                            selectedSyncId.toString(), ub.token!, context)
                        .then((value) {
                      if (value != null) {
                        ub
                            .saveUserData(value["role"] ?? "", value["token"])
                            .then((value) {
                          ub.setSignIn().then((value) {
                            final locationProvider =
                                Provider.of<LocationProvider>(context,
                                    listen: false);
                            final userProvider = Provider.of<UserProvider>(
                                context,
                                listen: false);
                            locationProvider.start(userProvider);
                            //context.read<LocationProvider>().start(context);
                            context.read<PartyProvider>().getpartyname(context);
                            context.read<ItemListProvider>().getItems(context);
                            context
                                .read<ProfileProvider>()
                                .getProfile(context)
                                .then((value) {
                              // Load settings after profile is loaded
                              context
                                  .read<ProfileProvider>()
                                  .loadSettings(context);

                              Get.offAll(() => BottomnavigationBarScreen());
                            });
                          });
                        });
                      }
                    });
                  });
                },
                itemBuilder: (BuildContext context) {
                  return firmList.map((firm) {
                    return PopupMenuItem<int>(
                      value: firm['syncId'],
                      child: Text(
                        firm['firmName'],
                        style: TextStyle(fontSize: 18.0),
                      ),
                    );
                  }).toList();
                },
              )),
          centerTitle: false,
          // actions: [
          //   // GO OFFLINE Button - Cache all data manually
          //   Padding(
          //     padding: const EdgeInsets.only(right: 8.0),
          //     child: Tooltip(
          //       message: 'Download data for offline use',
          //       child: GestureDetector(
          //         onTap: () {
          //           _showOfflineCachingDialog();
          //         },
          //         child: Container(
          //           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          //           decoration: BoxDecoration(
          //             color: Colors.white.withOpacity(0.2),
          //             borderRadius: BorderRadius.circular(6),
          //             border: Border.all(color: Colors.white, width: 1),
          //           ),
          //           child: Row(
          //             mainAxisSize: MainAxisSize.min,
          //             children: [
          //               Icon(Icons.cloud_download,
          //                   color: Colors.white, size: 18),
          //               SizedBox(width: 6),
          //               Text(
          //                 'GO OFFLINE',
          //                 style: TextStyle(
          //                   color: Colors.white,
          //                   fontSize: 12,
          //                   fontWeight: FontWeight.w600,
          //                 ),
          //               ),
          //             ],
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          //
          //   // Logout Icon (Hidden by Visibility)
          //   Visibility(
          //     visible: false, // Change to true if needed
          //     child: Padding(
          //       padding: const EdgeInsets.only(right: 12.0),
          //       child: GestureDetector(
          //         onTap: () {
          //           ub.userSignout(context).then((value) {
          //             Get.offAll(() => LoginPage());
          //           });
          //         },
          //         child: Icon(Icons.logout),
          //       ),
          //     ),
          //   ),
          //
          //   // Show a Loading Spinner (While Fetching Data)
          //   isLoading
          //       ? CircularProgressIndicator(
          //           color: Colors.white,
          //           strokeWidth: 2.0,
          //         )
          //       : SizedBox(
          //           width: 0.1,
          //         ),
          // ],
        ),
        drawer: Drawer(
          backgroundColor: Colors.white,
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

              // FAZAL Changes 15-12-2025
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
              //     Get.offAll(() =>
              //         BottomnavigationBarScreen()); // FAZAL Changes 14-02-2025
              //   },
              // ),
              // ADD : FAZAL Changes 15-12-2025
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
              // if (p.data?.modulesList != null &&
              //     p.data!.modulesList!.any((module) =>
              //         module.mODULENO == "301" &&
              //         module.rEADRIGHT == true))
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
                          module.mODULENO == "109" &&
                          module.rEADRIGHT == true)))
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
                  Icons.cloud_download,
                  size: 30,
                ),
                title: Text(
                  'Go Offline',
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
                onTap: () {
                  _showOfflineCachingDialog();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.key,
                  size: 30,
                ),
                title: Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
                onTap: () {
                  Get.to(() => ChangePasswordView());
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: size.height,
                width: size.width,
              ),
              Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 20, bottom: 5, top: 10),
                    child: Row(
                      children: [
                        Text(
                          _getGreetingMessage(),
                          style: TextStyle(
                              fontSize: 16.0, color: Color(0XFF2c9ed9)),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          // p.userName!.toString() +
                          //     " (" +
                          //     p.userCode!.toString() +
                          //     ")", // User Name + User Code
                          p.userName.toString(), // User Name + User Code
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Row(
                      children: [
                        Text(
                          'Total Orders : ',
                          style:
                              TextStyle(fontSize: 16, color: Color(0XFF2c9ed9)),
                        ),
                        Text(
                          "  ₹ ${data != null ? Helper.parseNumericValue(data!.data.labelData.totalSales.toString()) : 0}",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Define a common size for the boxes

                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      elevation: 20,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: Container(
                        padding: EdgeInsets.all(10),
                        // Add padding for better spacing
                        child: Column(
                          children: [
                            // Header Row with Title and Date
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(10.0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              flex: 2,
                                              child: Text(
                                                "Today Order",
                                                style: TextStyle(
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .width *
                                                          0.045,
                                                  color: Colors.grey.shade700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Flexible(
                                              flex: 3,
                                              child: Text(
                                                DateFormat('d- MMM -yyyy')
                                                    .format(DateTime.now()),
                                                style: TextStyle(
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .width *
                                                          0.045,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.grey.shade700,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.01),
                                        Row(
                                          children: [
                                            Text(
                                              "₹ ",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w600,
                                                fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.035,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                "${data != null ? Helper.parseNumericValue(data!.data.labelData.today.toString()) : 0}",
                                                style: TextStyle(
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .width *
                                                          0.05,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                                height: MediaQuery.of(context).size.height *
                                    0.02), // Spacing between sections

                            // Row for "This Week" and "This Month" cards
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // "This Week" Card
                                Flexible(
                                  child: Card(
                                    elevation: 20,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15)),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.42,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.12,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 15),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(10.0)),
                                        color: Color(0xFFE2EEFD),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "This Week",
                                            style: TextStyle(
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.04,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Text(
                                                "₹ ",
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .width *
                                                          0.04,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  "${data != null ? Helper.parseNumericValue(data!.data.labelData.week.toString()) : 0}",
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.04,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                    width: MediaQuery.of(context).size.width *
                                        0.02), // Horizontal spacing

                                // "This Month" Card
                                Flexible(
                                  child: Card(
                                    elevation: 20,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15)),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.42,
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.12,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 15),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(10.0)),
                                        color: Color(0xFFF9E8EE),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "This Month",
                                            style: TextStyle(
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.04,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Text(
                                                "₹ ",
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .width *
                                                          0.04,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  "${data != null ? Helper.parseNumericValue(data!.data.labelData.month.toString()) : 0}",
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.04,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: Container(
                      width: double.infinity,
                      height: 450.0,
                      child: Padding(
                        padding: const EdgeInsets.only(
                            top: 0, left: 8, right: 8, bottom: 0),
                        child: Card(
                          elevation: 20,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: EdgeInsets.only(
                                top: 15.h, left: 10, right: 10, bottom: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                //TODO : COMMENT 16/11/2024
                                Container(
                                  child: p.data != null &&
                                          DateTime(
                                                      int.parse(p.data!.license!
                                                          .licEndDate
                                                          .toString()
                                                          .split("-")[0]),
                                                      int.parse(p.data!.license!
                                                          .licEndDate
                                                          .toString()
                                                          .split("-")[1]),
                                                      int.parse(p.data!.license!
                                                          .licEndDate
                                                          .toString()
                                                          .split("-")[2]))
                                                  .difference(DateTime.now())
                                                  .inDays <=
                                              30 &&
                                          ub.role == AppConfig.masteruser
                                      ? Padding(
                                          padding:
                                              EdgeInsets.only(bottom: 14.0),
                                          child: GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title:
                                                        Text('License Expire'),
                                                    content:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                              "Firm Information",
                                                              style: TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                          SizedBox(height: 10),
                                                          Text(
                                                              "Firm Name: ${ub.syncName}"),
                                                          SizedBox(height: 10),
                                                          Text(
                                                              "License Start Date: ${p.data!.license!.licStartDate.toString()}"),
                                                          SizedBox(height: 10),
                                                          Text(
                                                              "License Expiry Date: ${p.data!.license!.licEndDate.toString()}"),
                                                          SizedBox(height: 10),
                                                          Text(
                                                              "Contact: +91 917391 9797"),
                                                          SizedBox(height: 5),
                                                          Divider(
                                                            height: 1,
                                                            color: Colors.red,
                                                          ),
                                                          SizedBox(height: 10),
                                                          Text(
                                                              "Email: info@arhamerp.com"),
                                                          SizedBox(height: 20),
                                                          Center(
                                                            child:
                                                                ElevatedButton(
                                                              onPressed: () {
                                                                Get.back();
                                                              },
                                                              child: Text(
                                                                  "Renew License"),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    /*actions: <Widget>[
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop(); // Close the dialog
                                                        },
                                                        child: Text('OK'),
                                                      ),
                                                    ],*/
                                                  );
                                                },
                                              );
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                  color: Color(0XFFFF6263)
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.all(
                                                          Radius.circular(
                                                              15.w))),
                                              height: 50.h,
                                              width: double.infinity,
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 10.h),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.info_outline,
                                                      color: Colors.red,
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                          left: 5.w),
                                                      child: Text(
                                                        "Your License is expiring in ${DateTime(int.parse(p.data!.license!.licEndDate.toString().split("-")[0]), int.parse(p.data!.license!.licEndDate.toString().split("-")[1]), int.parse(p.data!.license!.licEndDate.toString().split("-")[2])).difference(DateTime.now()).inDays} days.",
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Container(),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 14.0),
                                      child: Text(
                                          "${data != null ? "${data!.data.label}:" : ""}",
                                          style: TextStyle(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8)),
                                    ),
                                    // if (p.data?.profileSettings
                                    //             .firstWhere((element) =>
                                    //                 element.variable ==
                                    //                 'punchInOut')
                                    //             .value ==
                                    //         'Y' &&
                                    //     location.isLoading == false)

                                    if ((p.data?.profileSettings.any((e) =>
                                                e.variable == 'punchInOut' &&
                                                e.value == 'Y') ??
                                            false) &&
                                        location.isLoading == false)
                                      ElevatedButton(
                                        onPressed: () {
                                          if (p.data?.isPunchIn == true) {
                                            // setState(() {});
                                            location.setRemarks("PUNCH OUT");
                                          } else {
                                            location.setRemarks("PUNCH IN");
                                          }

                                          final userProvider =
                                              Provider.of<UserProvider>(context,
                                                  listen: false);
                                          location
                                              .checkServiceEnable(userProvider);
                                          //location.checkServiceEnable(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              p.data?.isPunchIn == true
                                                  ? Colors.red
                                                  : Colors.green,
                                        ),
                                        child: Text(
                                            p.data?.isPunchIn == true ? "Punch Out" : "Punch IN", style: TextStyle(color: Colors.white),),
                                      ),
                                    // if (p.data?.profileSettings
                                    //             .firstWhere((element) =>
                                    //                 element.variable ==
                                    //                 'punchInOut')
                                    //             .value ==
                                    //         'Y' &&
                                    //     location.isLoading == true)

                                    if ((p.data?.profileSettings.any((e) =>
                                                e.variable == 'punchInOut' &&
                                                e.value == 'Y') ??
                                            false) &&
                                        location.isLoading == true)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 15.0),
                                        child: SizedBox(
                                            height: 20.0,
                                            width: 20.0,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3.0,
                                            )),
                                      )
                                  ],
                                ),
                                Expanded(
                                  child: nolist == true
                                      ? Center(
                                          child: Text("No List"),
                                        )
                                      : data == null
                                          ? Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : ListView.builder(
                                              itemCount: data!.data.labelData
                                                  .transaction.length,
                                              itemBuilder: (context, index) {
                                                final item = data!
                                                    .data
                                                    .labelData
                                                    .transaction[index];

                                                return GestureDetector(
                                                  onTap: () async {
                                                    if (p.data != null &&
                                                        p.data!.modulesList!
                                                            .any((module) =>
                                                                module.mODULENO ==
                                                                    "304" &&
                                                                module.rEADRIGHT ==
                                                                    true)) {
                                                      await global
                                                          .changePartyname(
                                                              item.name);
                                                      await party.changeParty(
                                                          item.name,
                                                          item.accCd,
                                                          context);

                                                      Get.to(() =>
                                                              OrderReportScreen())
                                                          ?.then((result) {
                                                        if (result == true) {
                                                          final party = Provider
                                                              .of<PartyProvider>(
                                                                  context,
                                                                  listen:
                                                                      false);
                                                          if (party.partyid
                                                              .isNotEmpty) {
                                                            getDashboarddata();
                                                          }
                                                        }
                                                      });
                                                    } else {
                                                      AppSnackBar
                                                          .showGetXCustomSnackBar(
                                                              message:
                                                                  'There is nothing to do.');
                                                    }
                                                  },
                                                  child: Card(
                                                    elevation: 4,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              10),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          /// INDEX CIRCLE (CENTER LEFT)
                                                          Container(
                                                            width: 24,
                                                            height: 24,
                                                            alignment: Alignment
                                                                .center,
                                                            decoration:
                                                                const BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: Color(
                                                                  0XFF2c9ed9),
                                                            ),
                                                            child: Text(
                                                              "${index + 1}",
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),

                                                          const SizedBox(
                                                              width: 16),

                                                          /// NAME + MOBILE
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Text(
                                                                  item.name
                                                                      .toTitleCase(),
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                                const SizedBox(
                                                                    height: 4),
                                                                Text(
                                                                  item.mobile,
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          12),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          const SizedBox(
                                                              width: 10),

                                                          /// AMOUNT + DATE
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end,
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                "₹ ${Helper.parseNumericValue(item.amount.toString())}",
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 4),
                                                              Text(
                                                                Helper
                                                                    .convertToFormat(
                                                                  item.orderDate
                                                                      .toString(),
                                                                  'dd-MM-yyyy',
                                                                ),
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            12),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            )

                                  // ListView.builder(
                                  //             itemCount: data!.data.labelData
                                  //                 .transaction.length,
                                  //             itemBuilder: (builder, index) {
                                  //               return GestureDetector(
                                  //                   onTap: () async {
                                  //                     if (p.data != null &&
                                  //                         p.data!.modulesList!
                                  //                             .any((module) =>
                                  //                                 module
                                  //                                     .mODULENO ==
                                  //                                 "304")) {
                                  //                       await global
                                  //                           .changePartyname(
                                  //                               data!
                                  //                                   .data
                                  //                                   .labelData
                                  //                                   .transaction[
                                  //                                       index]
                                  //                                   .name);
                                  //                       await party.changeParty(
                                  //                           data!
                                  //                               .data
                                  //                               .labelData
                                  //                               .transaction[
                                  //                                   index]
                                  //                               .name,
                                  //                           data!
                                  //                               .data
                                  //                               .labelData
                                  //                               .transaction[
                                  //                                   index]
                                  //                               .accCd,
                                  //                           context);
                                  //                       // Get.to(() =>
                                  //                       //     OrderReportScreen());
                                  //
                                  //                       Get.to(() =>
                                  //                               OrderReportScreen())
                                  //                           ?.then((result) {
                                  //                         if (result == true) {
                                  //                           final PartyProvider
                                  //                               party =
                                  //                               Provider.of<
                                  //                                       PartyProvider>(
                                  //                                   context,
                                  //                                   listen:
                                  //                                       false);
                                  //                           if (party.partyid !=
                                  //                               "") {
                                  //                             getDashboarddata();
                                  //                           } else {}
                                  //                         }
                                  //                       });
                                  //                     }
                                  //                   },
                                  //                   child: Card(
                                  //                       elevation: 4,
                                  //                       shape:
                                  //                           RoundedRectangleBorder(
                                  //                         borderRadius:
                                  //                             BorderRadius
                                  //                                 .circular(6),
                                  //                       ),
                                  //                       child: Padding(
                                  //                           padding:
                                  //                               const EdgeInsets
                                  //                                   .all(8.0),
                                  //                           child: Row(
                                  //                             mainAxisAlignment:
                                  //                                 MainAxisAlignment
                                  //                                     .start,
                                  //                             children: [
                                  //                               // Leading widget
                                  //                               Padding(
                                  //                                 padding:
                                  //                                     const EdgeInsets
                                  //                                         .only(
                                  //                                         bottom:
                                  //                                             13),
                                  //                                 child: Column(
                                  //                                   children: [
                                  //                                     Stack(
                                  //                                       alignment:
                                  //                                           Alignment.center,
                                  //                                       children: [
                                  //                                         // Circle decoration
                                  //                                         Container(
                                  //                                           width:
                                  //                                               30.0,
                                  //                                           // Diameter of the circle
                                  //                                           height:
                                  //                                               30.0,
                                  //                                           decoration: BoxDecoration(
                                  //                                               shape: BoxShape.circle,
                                  //                                               color: Color(0XFF2c9ed9) // Circle color
                                  //                                               ),
                                  //                                         ),
                                  //                                         // Text inside the circle
                                  //                                         Text(
                                  //                                           "${index + 1}",
                                  //                                           style:
                                  //                                               TextStyle(
                                  //                                             fontSize: 14,
                                  //                                             fontWeight: FontWeight.bold,
                                  //                                             color: Colors.white, // Text color
                                  //                                           ),
                                  //                                         ),
                                  //                                       ],
                                  //                                     ),
                                  //                                     // Your existing text below the circle
                                  //                                   ],
                                  //                                 ),
                                  //                               ),
                                  //                               SizedBox(
                                  //                                   width: 20),
                                  //                               // Spacer between leading and title
                                  //
                                  //                               // Expanded widget to allow title and subtitle to share available space
                                  //                               Expanded(
                                  //                                 child: Column(
                                  //                                   crossAxisAlignment:
                                  //                                       CrossAxisAlignment
                                  //                                           .start,
                                  //                                   children: [
                                  //                                     // Title
                                  //                                     Text(
                                  //                                       data!
                                  //                                           .data
                                  //                                           .labelData
                                  //                                           .transaction[index]
                                  //                                           .name
                                  //                                           .toTitleCase(),
                                  //                                       style:
                                  //                                           TextStyle(
                                  //                                         fontSize:
                                  //                                             14,
                                  //                                         fontWeight:
                                  //                                             FontWeight.bold,
                                  //                                         letterSpacing:
                                  //                                             0.5,
                                  //                                       ),
                                  //                                       overflow:
                                  //                                           TextOverflow.ellipsis, // Prevents overflow
                                  //                                     ),
                                  //                                     SizedBox(
                                  //                                       height:
                                  //                                           5,
                                  //                                     ),
                                  //                                     // Subtitle
                                  //                                     Text(
                                  //                                       data!
                                  //                                           .data
                                  //                                           .labelData
                                  //                                           .transaction[index]
                                  //                                           .mobile,
                                  //                                       style: TextStyle(
                                  //                                           fontSize:
                                  //                                               12),
                                  //                                       overflow:
                                  //                                           TextOverflow.ellipsis, // Prevents overflow
                                  //                                     ),
                                  //                                   ],
                                  //                                 ),
                                  //                               ),
                                  //                               SizedBox(
                                  //                                   width: 8),
                                  //                               // Spacer between title and trailing
                                  //
                                  //                               // Trailing widget
                                  //                               Column(
                                  //                                 children: [
                                  //                                   Text(
                                  //                                     "₹ ${Helper.parseNumericValue(data!.data.labelData.transaction[index].amount.toString())}",
                                  //                                     style: TextStyle(
                                  //                                         fontWeight: FontWeight
                                  //                                             .bold,
                                  //                                         fontSize:
                                  //                                             14,
                                  //                                         color:
                                  //                                             Colors.green),
                                  //                                   ),
                                  //                                   SizedBox(
                                  //                                     height: 5,
                                  //                                   ),
                                  //                                   Text(
                                  //                                     Helper.convertToFormat(
                                  //                                         data!
                                  //                                             .data
                                  //                                             .labelData
                                  //                                             .transaction[index]
                                  //                                             .orderDate
                                  //                                             .toString(),
                                  //                                         'dd-MM-yyyy'),
                                  //                                     style: TextStyle(
                                  //                                         fontSize:
                                  //                                             12),
                                  //                                     overflow:
                                  //                                         TextOverflow
                                  //                                             .ellipsis, // Prevents overflow
                                  //                                   ),
                                  //                                 ],
                                  //                               ),
                                  //                             ],
                                  //                           ))));
                                  //             })
                                  ,
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  Future<void> loadData() async {
    // Fetch firm list (simulating API call or other data source)
    fetchData();

    // Fetch stored syncId from SharedPreferences
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    await ub.getSyncId();
    String? storedSyncId = ub.syncId;

    setState(() {
      isLoading = false;
      if (storedSyncId != null) {
        selectedSyncId = int.tryParse(storedSyncId);

        // Set the selectedFirmName based on syncId
        if (selectedSyncId != null) {
          final firm = firmList.firstWhere(
            (firm) => firm['syncId'] == selectedSyncId,
            orElse: () => {},
          );
          selectedFirmName = firm.isNotEmpty ? firm['firmName'] : null;
        }
      }
    });
  }

  Future<void> fetchData() async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    final url =
        Uri.parse(AppConfig.baseURL + 'firm'); // Replace with your API URL

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${ub.token!}",
          'x-app-type': 'oms',
        },
      );

      print("Dashboard Firm Data " + response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> firms = data['data'];

        // Parse each entry to a map with firm name and sync ID
        setState(() {
          firmList = firms.map((item) {
            return {
              "firmName":
                  item['FIRM_NAME']?.replaceAll(RegExp(r'[\r\n]'), '') ??
                      'Unnamed Firm',
              "syncId": item['SYNC_ID'],
            };
          }).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    } else if (hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
    }
  }

  /// Show offline caching dialog with progress
  void _showOfflineCachingDialog() {
    bool isCaching = false;
    String cachingStatus = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.cloud_download, color: Color(0xFF2c9ed9)),
                  SizedBox(width: 8),
                  Text('Go Offline'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCaching)
                    Text(
                      'Download all masters for offline use?',
                      style: TextStyle(fontSize: 14),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF2c9ed9),
                            ),
                            SizedBox(height: 16),
                            Text(
                              cachingStatus.isNotEmpty
                                  ? cachingStatus
                                  : 'Preparing...',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[700]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
              actions: [
                if (!isCaching)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text('CANCEL'),
                  ),
                if (!isCaching)
                  ElevatedButton(
                    onPressed: () async {
                      setDialogState(() {
                        isCaching = true;
                        cachingStatus = 'Caching profile...';
                      });

                      try {
                        final bool success =
                            await OfflineCachingService.cacheAllDataForOffline(
                                context);

                        if (mounted) {
                          setDialogState(() {
                            isCaching = false;
                            cachingStatus =
                                success ? 'Cache completed!' : 'Cache failed!';
                          });

                          // Show final result
                          await Future.delayed(Duration(milliseconds: 500));

                          if (mounted) {
                            Navigator.of(dialogContext).pop();
                            AppSnackBar.showGetXCustomSnackBar(
                              message: success
                                  ? 'All data cached successfully! You can now work offline.'
                                  : 'Some data failed to cache. Check logs.',
                              backgroundColor:
                                  success ? Colors.green : Colors.orange,
                            );
                          }
                        }
                      } catch (e) {
                        print('Error during offline caching: $e');
                        if (mounted) {
                          setDialogState(() {
                            isCaching = false;
                          });
                          Navigator.of(dialogContext).pop();
                          AppSnackBar.showGetXCustomSnackBar(
                            message: 'Error caching data: $e',
                            backgroundColor: Colors.red,
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2c9ed9),
                    ),
                    child: Text(
                      'START',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                if (isCaching)
                  TextButton(
                    onPressed: null, // Disabled while caching
                    child: Text('Please wait...'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

extension StringCasingExtension on String {
  String toTitleCase() {
    if (isEmpty) return this; // If the string is empty, return it as is.

    return split(' ').map((word) {
      if (word.isNotEmpty) {
        // If the word contains a hyphen, split by the hyphen, capitalize each part, and join them back
        if (word.contains('-')) {
          return word
              .split('-')
              .map((part) => part.isNotEmpty
                  ? '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}'
                  : '')
              .join('-');
        } else {
          return word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : ''; // Check to avoid accessing an empty word.
        }
      } else {
        return ''; // Handle empty words (multiple spaces).
      }
    }).join(' ');
  }
}

// extension StringCasingExtension on String {
//   String toTitleCase() {
//     if (isEmpty) return this;
//     return split(' ').map((word) {
//       if (word.isNotEmpty) {
//         // If the word contains a hyphen, split by the hyphen, capitalize each part, and join them back
//         if (word.contains('-')) {
//           return word
//               .split('-')
//               .map((part) =>
//                   '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
//               .join('-');
//         } else {
//           return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
//         }
//       } else {
//         return ''; // Handle empty words (multiple spaces)
//       }
//     }).join(' ');
//   }
// }
