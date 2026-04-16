//import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'dart:io';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/constants/constants.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/models/settingmodal.dart';
import 'package:arham_corporation/network.dart';
import 'package:arham_corporation/product/ui/product_page.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/widgets/common_text.dart';
import 'package:arham_corporation/widgets/common_upload_input_dialog.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:whatsapp_share/whatsapp_share.dart';

import '../models/orderReportModal.dart';
import '../providers/party_provider.dart';
import '../widgets/pdfViewerScreen.dart';
import '../widgets/user_search_dropdown.dart';

class OrderReportScreen extends StatefulWidget {
  final String? selectedUserCd;
  final String? selectedUserName;

  const OrderReportScreen({
    Key? key,
    this.selectedUserCd,
    this.selectedUserName,
  }) : super(key: key);

  @override
  State<OrderReportScreen> createState() => _OrderReportScreenState();
}

class _OrderReportScreenState extends State<OrderReportScreen> {
  List<DatumOrder> data = [];
  bool noList = false;
  bool isBool = false;
  TextEditingController fromdateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  TextEditingController userController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = false;
  String? _selectedUserName;
  String _selectedUserCode = ''; // Tracks current dropdown selection
  bool _usersFetchInitiated = false; // Track if we've already tried to fetch
  static const int _usersPerPage = 20;

  bool isWhatsappInstalled = false;
  bool isWhatsappBussinessInstalled = false;
  bool loading = false;

  int radiocheck = 1;

  var viewRight = false;
  var addRight = false;
  var updateRight = false;
  var deleteRight = false;
  var printRight = false;

  var picker = ImagePicker();

  var proofOfDelivery = Rx<File?>(null);

  var proofOfDeliveryWeb = Rxn<Uint8List>();

  var proofOfDeliveryUrl = RxnString();

  Future<bool?> checkWhatsappInstalled() async {
    isWhatsappInstalled =
        await WhatsappShare.isInstalled(package: Package.whatsapp) ?? false;
    return null;
  }

  Future<bool?> checkWhatsappBussinessInstalled() async {
    isWhatsappBussinessInstalled =
        await WhatsappShare.isInstalled(package: Package.businessWhatsapp) ??
            false;
    return null;
  }

  getDate() async {
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    setState(() {
      data.clear();
      noList = false;
    });

    bool online = await NetworkHelper.hasInternet();

    if (online) {
      try {
        await CrashlyticsService.logAction(
          'order_report_api_triggered',
          context: {
            'party_id': party.partyid,
            'from_date': Helper.toApi(fromdateController.text),
            'to_date': Helper.toApi(toDateController.text),
            'user_code': userController.text,
            'report_type': radiocheck,
          },
        );

        final value = await Services().getOrderReport(
          context,
          party.partyid,
          Helper.toApi(fromdateController.text),
          Helper.toApi(toDateController.text),
          userController.text,
          radiocheck,
        );

        if (!mounted) return;

        setState(() {
          if (value != null) {
            data.addAll(value.data);
            if (data.isEmpty) {
              noList = true;
            }
          } else {
            noList = true;
          }
        });

        // Cache the order report for offline use (always cache)
        if (value != null) {
          try {
            await DatabaseHelper().cacheHomeData(
              'order_report',
              orderReportModalToJson(value),
            );
            print(
                "Order report cached successfully (${value.data.length} items)");
          } catch (e, stack) {
            print("Error caching order report: $e");
            await CrashlyticsService.recordNonFatal(
              e,
              stack,
              reason: 'order_report_cache_failed',
            );
          }
        }
      } catch (e, stack) {
        await CrashlyticsService.recordNonFatal(
          e,
          stack,
          reason: 'order_report_fetch_failed',
        );
        if (!mounted) return;
        setState(() {
          noList = true;
        });
      }
    } else {
      // Offline: load from cache
      try {
        final cached = await DatabaseHelper().getCachedHomeData('order_report');
        if (cached != null && cached.isNotEmpty && cached != 'null') {
          final cachedReport = orderReportModalFromJson(cached);
          setState(() {
            data.addAll(cachedReport.data);
            if (data.isEmpty) {
              noList = true;
            }
          });
        } else {
          setState(() {
            noList = true;
          });
        }
      } catch (e) {
        print("Error loading cached order report: $e");
        setState(() {
          noList = true;
        });
      }
    }
  }

  void dispose() {
    _focusNode.dispose();

    super.dispose();
  }

  @override
  void initState() {
    CrashlyticsService.setScreenName('OrderReportScreen');
    CrashlyticsService.logAction('order_report_opened');

    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    var moduleEntryAccess = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "304",
          orElse: () => Modules(),
        ) ??
        Modules();

    if (moduleEntryAccess.mODULENO == "304") {
      viewRight = moduleEntryAccess.rEADRIGHT!;
      addRight = moduleEntryAccess.wRITERIGHT!;
      updateRight = moduleEntryAccess.uPDATERIGHT!;
      deleteRight = moduleEntryAccess.dELETERIGHT!;
      printRight = moduleEntryAccess.pRINTRIGHT!;

      print('View Rights $viewRight');
      print('Add Rights $addRight');
      print('Update Rights $updateRight');
      print('Delete Rights $deleteRight');
      print('Print Rights $printRight');
    } else {
      print("Module with MODULE_NO '304' not found.");
    }

    // fromdateController.text = Helper.getDefaultFromDate();
    // toDateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());

    // Use 90-day range to capture all hierarchy orders (parent + children)
    final now = DateTime.now();
    final fromDate = now.subtract(const Duration(days: 90));
    fromdateController.text =
        Helper.toUi(DateFormat("yyyy-MM-dd").format(fromDate));
    toDateController.text =
        Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));

    // If selectedUserCd is provided (from user selection screen), use it
    if (widget.selectedUserCd != null && widget.selectedUserCd!.isNotEmpty) {
      userController.text = widget.selectedUserCd!;
      _selectedUserCode = widget.selectedUserCd!;
    }

    getDate();
    _fetchUsers();
    checkWhatsappInstalled();
    checkWhatsappBussinessInstalled();
    _focusNode.requestFocus();
    super.initState();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersFetchInitiated = true;
    });

    try {
      final UserProvider userProvider =
          Provider.of<UserProvider>(context, listen: false);

      final String token = userProvider.token ?? '';
      await CrashlyticsService.logAction('order_report_users_api_triggered');
      print(
          '_fetchUsers: Fetching paginated users from ${AppConfig.childrenURL} with token: ${token.substring(0, 20)}...');

      final allUsers = <Map<String, dynamic>>[];
      final seenUserCodes = <String>{};
      int currentPage = 1;
      int lastPage = 1;

      do {
        final uri = Uri.parse(AppConfig.childrenURL).replace(
          queryParameters: {
            'page': currentPage.toString(),
            'items_per_page': _usersPerPage.toString(),
          },
        );

        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'x-app-type': 'oms',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));

        print(
            '_fetchUsers: page=$currentPage status=${response.statusCode} uri=$uri');

        if (response.statusCode != 200) {
          throw Exception(
              'Failed to fetch users page $currentPage: HTTP ${response.statusCode}');
        }

        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final users = (jsonResponse['data'] as List?) ?? const [];
        final payload = jsonResponse['payload'] as Map<String, dynamic>?;
        final pagination = payload?['pagination'] as Map<String, dynamic>?;

        final pageFromResponse =
            int.tryParse((pagination?['page'] ?? currentPage).toString()) ??
                currentPage;
        lastPage =
            int.tryParse((pagination?['last_page'] ?? 1).toString()) ?? 1;

        print(
            '_fetchUsers: page=$pageFromResponse fetched=${users.length} lastPage=$lastPage');

        for (final rawUser in users) {
          if (rawUser is! Map) {
            continue;
          }

          final user = Map<String, dynamic>.from(rawUser);
          final userCode =
              (user['USER_CD'] ?? user['userCode'] ?? '').toString().trim();
          final userName =
              (user['USER_NAME'] ?? user['userName'] ?? '').toString().trim();
          final phone =
              (user['MOBILENO'] ?? user['phone'] ?? '').toString().trim();

          if (userCode.isEmpty || !seenUserCodes.add(userCode)) {
            continue;
          }

          allUsers.add({
            'userCode': userCode,
            'userName': userName,
            'phone': phone,
          });
        }

        currentPage = pageFromResponse + 1;
      } while (currentPage <= lastPage);

      if (!mounted) {
        return;
      }

      setState(() {
        _users = allUsers;
        _loadingUsers = false;
      });

      print('_fetchUsers: State updated with ${_users.length} users');
    } catch (e, stack) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingUsers = false;
      });
      print('Error fetching users: $e');
      await CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'order_report_users_fetch_failed',
      );
    }
  }

  /* Deprecated - using UserSearchDropdown widget instead
  List<DropdownMenuItem<String>> _buildUserDropdownItems() {
    // Trigger fetch on first dropdown open if users not yet fetched
    if (_users.isEmpty && !_loadingUsers && !_usersFetchInitiated) {
      print('First dropdown open - triggering user fetch');
      _usersFetchInitiated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchUsers();
      });
    }

    List<DropdownMenuItem<String>> items = [
      DropdownMenuItem<String>(
        value: '',
        child: Text("All Users"),
      ),
    ];

    if (_loadingUsers) {
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  "Loading users...",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    items.addAll(
      _users
          .map((user) => DropdownMenuItem<String>(
                value: user['userCode'] ?? '',
                child: Text(user['userName'] ?? user['userCode'] ?? ''),
              ))
          .toList(),
    );

    return items;
  }
  */

  TextEditingController searchPartyClt = TextEditingController();
  FocusNode _focusNode = FocusNode();

  List _tempParty = [];

  showMenu() {
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    pp.getpartyname(context);
    return showModalBottomSheet(
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(25.0),
          ),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            top: false,
            child: Consumer<PartyProvider>(
              builder: (context, party, child) {
                return StatefulBuilder(
                    builder: (context, StateSetter setStatee) {
                  return Padding(
                    padding: MediaQuery.of(context).viewInsets,
                    child: Container(
                      height: 450,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 20.0, bottom: 14.0, top: 20.0),
                                child: Text("Select Party:",
                                    style: TextStyle(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CupertinoSearchTextField(
                                    controller: searchPartyClt,
                                    focusNode: _focusNode,
                                    onChanged: (value) {
                                      //4
                                      setStatee(() {
                                        _tempParty = Helper.buildSearchList(
                                            value, party);
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
                                        itemCount: (_tempParty.length > 0)
                                            ? _tempParty.length
                                            : party.data.length,
                                        itemBuilder: (builder, index) {
                                          return InkWell(
                                            onTap: () async {
                                              await party.changeParty(
                                                  (_tempParty.length > 0)
                                                      ? _tempParty[index]
                                                          .accName
                                                      : party
                                                          .data[index].accName,
                                                  (_tempParty.length > 0)
                                                      ? _tempParty[index].accCd
                                                      : party.data[index].accCd,
                                                  context);

                                              Get.back();
                                              print(party.data[index].accName +
                                                  " ${party.data[index].accCd}");
                                              getDate();
                                            },
                                            child: (_tempParty.length > 0)
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
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final PartyProvider party = context.watch<PartyProvider>();
    final UserProvider ub = context.watch<UserProvider>();
    final ProfileProvider profile = context.watch<ProfileProvider>();

    // If selectedUserName provided, show it; otherwise show "Order Report"
    final title = widget.selectedUserName != null
        ? '${widget.selectedUserName}\'s Order Report'
        : 'Order Report';

    return WillPopScope(
      onWillPop: () async {
        Get.back(result: true);
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        appBar: CustomAppBar(
          title: title,
          actions: [
            if (printRight)
              PopupMenuButton<dynamic>(
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<dynamic>>[
                  if (printRight)
                    PopupMenuItem(
                      value: 0,
                      child: Text('Export PDF'),
                      onTap: () {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getOrderExportFile(
                                context,
                                party.partyid,
                                fromdateController.text,
                                toDateController.text,
                                userController.text,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            setState(() {
                              loading = false;
                            });
                            Get.to(() => PdfViewerScreen(
                                pdfUrl: value,
                                fileName:
                                    "Order Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}"));
                          } else {
                            setState(() {
                              loading = false;
                            });
                          }
                        });
                      },
                    ),
                  if (printRight)
                    PopupMenuItem(
                      value: 0,
                      child: Text('Export PDF With Item'),
                      onTap: () {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getOrderExportFileItem(
                                context,
                                party.partyid,
                                fromdateController.text,
                                toDateController.text,
                                userController.text,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            setState(() {
                              loading = false;
                            });
                            Get.to(() => PdfViewerScreen(
                                pdfUrl: value,
                                fileName:
                                    "Order Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}"));
                          } else {
                            setState(() {
                              loading = false;
                            });
                          }
                        });
                      },
                    ),
                  if (printRight)
                    PopupMenuItem(
                      value: 1,
                      child: Text('Export Excel'),
                      onTap: () {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getOrderExportFile(
                                context,
                                party.partyid,
                                fromdateController.text,
                                toDateController.text,
                                userController.text,
                                "excel")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Order Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
                                    "Excel file has been downloaded")
                                .then((value) => {
                                      setState(() {
                                        loading = false;
                                      })
                                    });
                          } else {
                            setState(() {
                              loading = false;
                            });
                          }
                        });
                      },
                    ),
                  if (isWhatsappInstalled && printRight)
                    PopupMenuItem(
                      value: 1,
                      child: Text('Whatsapp Share'),
                      onTap: () {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getOrderExportFile(
                                context,
                                party.partyid,
                                fromdateController.text,
                                toDateController.text,
                                userController.text,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Order Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
                                    "Pdf file has been downloaded")
                                .then((value) async {
                              setState(() {
                                loading = false;
                              });
                              if (value != null)
                                await WhatsappShare.shareFile(
                                        phone: "91",
                                        filePath: [value],
                                        package: Package.whatsapp)
                                    .catchError((err) {
                                  print(err);
                                  return false;
                                });
                            });
                          } else {
                            setState(() {
                              loading = false;
                            });
                          }
                        });
                      },
                    ),
                  if (isWhatsappBussinessInstalled && printRight)
                    PopupMenuItem(
                      value: 1,
                      child: Text('Whatsapp \nBussiness Share'),
                      onTap: () {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getOrderExportFile(
                                context,
                                party.partyid,
                                fromdateController.text,
                                toDateController.text,
                                userController.text,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Order Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
                                    "Pdf file has been downloaded")
                                .then((value) async {
                              setState(() {
                                loading = false;
                              });
                              if (value != null)
                                await WhatsappShare.shareFile(
                                        phone: "91",
                                        filePath: [value],
                                        package: Package.businessWhatsapp)
                                    .catchError((err) {
                                  print(err);
                                  return false;
                                });
                            });
                          } else {
                            setState(() {
                              loading = false;
                            });
                          }
                        });
                      },
                    ),
                ],
              )
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5.0, vertical: 5.0),
                    child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                            side: BorderSide(
                              color: Colors.grey,
                            )),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: TextButton(
                            onPressed: () => showMenu(),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              splashFactory: NoSplash
                                  .splashFactory, // Disable splash effect
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  Icons.search,
                                  color: Colors.black,
                                  size: 24,
                                ),
                                Expanded(
                                  child: Text(
                                    Provider.of<PartyProvider>(context)
                                            .party
                                            .isEmpty
                                        ? 'Search Party (Name, Phone Number, City, Area)' // Default text
                                        : ' ${Helper.trimValue(Provider.of<PartyProvider>(context).party, 80)}', // Party name
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(color: Colors.black),
                                    textAlign: TextAlign
                                        .start, // Ensure the text is LTR
                                  ),
                                ),
                                if (Provider.of<PartyProvider>(context)
                                    .party
                                    .isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      party.clearParty();
                                      party.clearPunchInOutParty();
                                      getDate();
                                    },
                                    child: Icon(
                                      Icons.cancel,
                                      color: Colors.black,
                                      size: 24,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )),
                  ),
                  // if (ub.role == AppConfig.masteruser)
                  //   Padding(
                  //     padding:
                  //         const EdgeInsets.only(left: 10.0, right: 10.0, bottom: 6.0),
                  //     child: Row(
                  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //       children: [
                  //         Text('User: ${Helper.trimValue(userController.text, 25)} '),
                  //         Row(
                  //           children: [
                  //             TextButton(
                  //                 onPressed: showMenu,
                  //                 child: Text("Change"),
                  //                 style: TextButton.styleFrom(
                  //                     padding: EdgeInsets.zero,
                  //                     minimumSize: Size(50, 30),
                  //                     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  //                     alignment: Alignment.centerLeft)),
                  //             SizedBox(
                  //               width: 2.0,
                  //             ),
                  //             GestureDetector(
                  //                 onTap: () {
                  //                   userController.clear();
                  //                   getDate();
                  //                 },
                  //                 child: Icon(
                  //                   Icons.close,
                  //                   size: 18,
                  //                 )),
                  //           ],
                  //         )
                  //       ],
                  //     ),
                  //   ),
                  Visibility(
                    visible: !(profile.data?.profileSettings.any((e) =>
                            e.variable == 'omsWithoutErpSync' &&
                            e.value == 'Y') ??
                        false),
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 5.0, top: 5.0, bottom: 5.0),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              Radio(
                                visualDensity: const VisualDensity(
                                    horizontal: VisualDensity.minimumDensity,
                                    vertical: VisualDensity.minimumDensity),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                value: 1,
                                groupValue: radiocheck,
                                onChanged: (val) {
                                  setState(() {
                                    radiocheck = val!;
                                  });
                                  getDate();
                                },
                              ),
                              Text(
                                "All ",
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Radio(
                                  visualDensity: const VisualDensity(
                                      horizontal: VisualDensity.minimumDensity,
                                      vertical: VisualDensity.minimumDensity),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  value: 2,
                                  groupValue: radiocheck,
                                  onChanged: (val) {
                                    setState(() {
                                      radiocheck = val!;
                                    });
                                    getDate();
                                  }),
                              Text(
                                "Pending Orders ",
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Radio(
                                  visualDensity: const VisualDensity(
                                      horizontal: VisualDensity.minimumDensity,
                                      vertical: VisualDensity.minimumDensity),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  value: 3,
                                  groupValue: radiocheck,
                                  onChanged: (val) {
                                    setState(() {
                                      radiocheck = val!;
                                    });
                                    getDate();
                                  }),
                              Text(
                                "Synced Orders ",
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Radio(
                                  visualDensity: const VisualDensity(
                                      horizontal: VisualDensity.minimumDensity,
                                      vertical: VisualDensity.minimumDensity),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  value: 4,
                                  groupValue: radiocheck,
                                  onChanged: (val) {
                                    setState(() {
                                      radiocheck = val!;
                                    });
                                    getDate();
                                  }),
                              Text(
                                "Billed Orders ",
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Padding(
                  //   padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  //   child: Row(
                  //     children: [
                  //       Expanded(
                  //         child: Column(
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           children: [
                  //             Text(
                  //               "From Date",
                  //             ),
                  //             SizedBox(
                  //               height: 5.h,
                  //             ),
                  //             DateTimePicker(
                  //               controller: fromdateController,
                  //               decoration: InputDecoration(
                  //                 contentPadding: EdgeInsets.symmetric(
                  //                     vertical: 10.0, horizontal: 5),
                  //                 border: OutlineInputBorder(
                  //                     borderRadius: BorderRadius.circular(12)),
                  //                 hintText: "Select date",
                  //                 suffixIcon: GestureDetector(
                  //                     onTap: () {
                  //                       setState(() {
                  //                         fromdateController.text =
                  //                             DateFormat("yyyy-MM-dd")
                  //                                 .format(DateTime.now());
                  //                       });
                  //                       getDate();
                  //                     },
                  //                     child: Tooltip(
                  //                         message: "Today",
                  //                         child: Icon(Icons.today_outlined))),
                  //               ),
                  //               firstDate: DateTime(-21000),
                  //               initialDate: DateTime.now(),
                  //               lastDate: DateTime.now(),
                  //               dateLabelText: 'Select Date',
                  //               onChanged: (val) {
                  //                 getDate();
                  //               },
                  //               validator: (val) {
                  //                 print(val);
                  //                 return null;
                  //               },
                  //               onSaved: (val) {},
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //       SizedBox(
                  //         width: 10,
                  //       ),
                  //       Expanded(
                  //         child: Column(
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           children: [
                  //             Text(
                  //               "To Date",
                  //             ),
                  //             SizedBox(
                  //               height: 5.h,
                  //             ),
                  //             DateTimePicker(
                  //               controller: toDateController,
                  //               decoration: InputDecoration(
                  //                   contentPadding: EdgeInsets.symmetric(
                  //                       vertical: 10.0, horizontal: 5),
                  //                   border: OutlineInputBorder(
                  //                       borderRadius: BorderRadius.circular(12)),
                  //                   hintText: "Select date"),
                  //               firstDate: DateTime(-21000),
                  //               initialDate: DateTime.now(),
                  //               lastDate: DateTime(21000),
                  //               dateLabelText: 'Select Date',
                  //               onChanged: (val) {
                  //                 getDate();
                  //               },
                  //               validator: (val) {
                  //                 print(val);
                  //                 return null;
                  //               },
                  //               onSaved: (val) {},
                  //             )
                  //           ],
                  //         ),
                  //       )
                  //     ],
                  //   ),
                  // ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Row(
                      children: [
                        // ------------------- FROM DATE -------------------
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("From Date"),
                              SizedBox(height: 5.h),
                              TextFormField(
                                controller: fromdateController,
                                readOnly: true,
                                // prevent manual typing
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 10.0, horizontal: 5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  hintText: "Select date",
                                  suffixIcon: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        // fromdateController.text =
                                        //     DateFormat("yyyy-MM-dd")
                                        //         .format(DateTime.now());

                                        fromdateController.text = Helper.toUi(
                                            DateFormat("yyyy-MM-dd")
                                                .format(DateTime.now()));
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
                                    // safe range
                                    maxTime: DateTime.now(),
                                    currentTime: DateTime.now(),
                                    locale: LocaleType.en,
                                    onConfirm: (date) {
                                      setState(() {
                                        // fromdateController.text =
                                        //     DateFormat("yyyy-MM-dd").format(date);
                                        fromdateController.text = Helper.toUi(
                                            DateFormat("yyyy-MM-dd")
                                                .format(date));
                                      });
                                      getDate();
                                    },
                                  );
                                },
                                validator: (val) {
                                  print(val);
                                  return null;
                                },
                                onSaved: (val) {},
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: 10),

                        // ------------------- TO DATE -------------------
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("To Date"),
                              SizedBox(height: 5.h),
                              TextFormField(
                                controller: toDateController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 10.0, horizontal: 5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  hintText: "Select date",
                                ),
                                onTap: () {
                                  DatePicker.showDatePicker(
                                    context,
                                    showTitleActions: true,
                                    minTime: DateTime(2000, 1, 1),
                                    // safe range
                                    maxTime: DateTime(2100, 12, 31),
                                    currentTime: DateTime.now(),
                                    locale: LocaleType.en,
                                    onConfirm: (date) {
                                      setState(() {
                                        toDateController.text = Helper.toUi(
                                            DateFormat("yyyy-MM-dd")
                                                .format(date));
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
                                onSaved: (val) {},
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ------------------- USER DROPDOWN -------------------
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Filter by User"),
                        SizedBox(height: 5.h),
                        UserSearchDropdown(
                          users: _users,
                          selectedUserCode: _selectedUserCode.isEmpty
                              ? null
                              : _selectedUserCode,
                          loading: _loadingUsers,
                          hint: "Select User",
                          onChanged: (value) {
                            CrashlyticsService.logAction(
                              'order_report_user_filter_changed',
                              context: {'selected_user_cd': value ?? ''},
                            );
                            print('User selected: $value');
                            setState(() {
                              _selectedUserCode = value ?? '';
                              userController.text = value ?? '';
                              _selectedUserName = value == '' || value == null
                                  ? 'All Users'
                                  : _users.firstWhere(
                                      (user) => user['userCode'] == value,
                                      orElse: () => {'userName': 'Unknown'},
                                    )['userName'];
                            });
                            print('Calling getDate from user selection');
                            getDate();
                          },
                        ),
                      ],
                    ),
                  ),
                  Divider(),
                  Expanded(
                    child: noList == true
                        ? Center(
                            child: Text("No Data Found"),
                          )
                        : data.isEmpty
                            ? Center(
                                child: CircularProgressIndicator(),
                              )
                            : ListView.builder(
                                itemCount: data.length,
                                shrinkWrap: true,
                                itemBuilder: (context, index) {
                                  return Card(
                                    color: Colors.white,
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: Container(
                                        decoration:
                                            BoxDecoration(color: Colors.white),
                                        child: ExpansionTile(
                                          shape: Border(),
                                          collapsedShape: Border(),
                                          expandedAlignment: Alignment.topLeft,
                                          childrenPadding: EdgeInsets.only(
                                              left: 20,
                                              right: 20,
                                              top: 15,
                                              bottom: 20),
                                          title: Column(
                                            children: [
                                              Row(
                                                children: <Widget>[
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Order No:",
                                                          textAlign:
                                                              TextAlign.start,
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.black),
                                                        ),
                                                        Text(
                                                          "${data[index].orderNo ?? ""}",
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Order Amt:",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        Text(
                                                          "${data[index].orderAmt ?? ""}",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Bill No:",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        Text(
                                                          "${data[index].billNo ?? ""}",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Bill Dt:",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        Text(
                                                          Helper.convertToFormat(
                                                              "${data[index].billDt ?? ""}",
                                                              'dd-MM-yy'),
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Bill Amt:",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        Text(
                                                          "${data[index].netAmt ?? ""}",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 10.0),
                                                child: Row(
                                                  children: <Widget>[
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "Order Date:",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          ),
                                                          Text(
                                                            Helper.convertToFormat(
                                                                "${data[index].vouchDt ?? ""}",
                                                                'dd-MM-yy'),
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "Party:",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          ),
                                                          Text(
                                                            "${Helper.trimValue(data[index].account.accName, 14)}",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                    // if (profile.data
                                                    //         ?.profileSettings
                                                    //         .firstWhere((element) =>
                                                    //             element
                                                    //                 .variable ==
                                                    //             'orderReportMastUser')
                                                    //         .value ==
                                                    //     'Y')
                                                    if (profile.data
                                                            ?.profileSettings
                                                            .firstWhere(
                                                              (element) =>
                                                                  element
                                                                      .variable ==
                                                                  'orderReportMastUser',
                                                              orElse: () =>
                                                                  DatumSettings(), // return null if not found
                                                            )
                                                            .value ==
                                                        'Y')
                                                      Expanded(
                                                        flex: 2,
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              "User:",
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black,
                                                              ),
                                                            ),
                                                            Text(
                                                              "${Helper.trimValue(data[index].user.userName, 14)}",
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey),
                                                            )
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          children: [
                                            Column(children: [
                                              Column(
                                                children: [
                                                  // Header Rows
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 4,
                                                        child: Text(
                                                            "Item Name:",
                                                            style: TextStyle(
                                                                fontSize: 12.0),
                                                            textAlign: TextAlign
                                                                .start),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text("Remarks:",
                                                            style: TextStyle(
                                                                fontSize: 12.0),
                                                            textAlign: TextAlign
                                                                .start),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 4,
                                                        child: Text(
                                                            "Batch/MRP:",
                                                            style: TextStyle(
                                                                fontSize: 12.0),
                                                            textAlign: TextAlign
                                                                .start),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          "Rate:",
                                                          style: TextStyle(
                                                              fontSize: 12.0),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text("Quantity:",
                                                            style: TextStyle(
                                                                fontSize: 12.0),
                                                            textAlign: TextAlign
                                                                .center),
                                                      ),
                                                      if (profile.data !=
                                                              null &&
                                                          profile.data!
                                                              .modulesList!
                                                              .any((module) =>
                                                                  module
                                                                      .mODULENO ==
                                                                  "205"))
                                                        Expanded(
                                                          flex: 2,
                                                          child: Text(
                                                              "Free Qty:",
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      12.0),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center),
                                                        ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text("Amount:",
                                                            style: TextStyle(
                                                                fontSize: 12.0),
                                                            textAlign: TextAlign
                                                                .center),
                                                      ),
                                                    ],
                                                  ),

                                                  // Data Rows
                                                  Padding(
                                                    padding: EdgeInsets.only(
                                                        top: 8.0),
                                                    child: Column(
                                                      children: List.generate(
                                                          data[index]
                                                              .ordritms
                                                              .length, (i) {
                                                        return Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  flex: 4,
                                                                  child: Text(
                                                                      "${data[index].ordritms[i].item.itemName}",
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .start),
                                                                ),
                                                                Expanded(
                                                                  flex: 2,
                                                                  child: Text(
                                                                      "${data[index].ordritms[i].fld5}",
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .start),
                                                                ),
                                                              ],
                                                            ),
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  flex: 4,
                                                                  child: Text(
                                                                      "${data[index].ordritms[i].item.lastSize}",
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .start),
                                                                ),
                                                                Expanded(
                                                                  flex: 2,
                                                                  child: Text(
                                                                      //"${(data[index].ordritms[i].lRate.isEmpty || data[index].ordritms[i].lRate == '0.00') ? data[index].ordritms[i].rate : data[index].ordritms[i].lRate}",
                                                                      data[index]
                                                                          .ordritms[
                                                                              i]
                                                                          .rate
                                                                          .toString(),
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center),
                                                                ),
                                                                Expanded(
                                                                  flex: 2,
                                                                  child: Text(
                                                                      "${data[index].ordritms[i].quantity.toString()}",
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center),
                                                                ),
                                                                if (profile.data !=
                                                                        null &&
                                                                    profile
                                                                        .data!
                                                                        .modulesList!
                                                                        .any((module) =>
                                                                            module.mODULENO ==
                                                                            "205"))
                                                                  Expanded(
                                                                    flex: 2,
                                                                    child: Text(
                                                                        "${data[index].ordritms[i].otherDesc.toString()}",
                                                                        style: TextStyle(
                                                                            color: Colors
                                                                                .grey,
                                                                            fontSize:
                                                                                12.0),
                                                                        textAlign:
                                                                            TextAlign.center),
                                                                  ),
                                                                Expanded(
                                                                  flex: 2,
                                                                  child: Text(
                                                                      Helper.parseNumericValue(data[
                                                                              index]
                                                                          .ordritms[
                                                                              i]
                                                                          .amount
                                                                          .toString()),
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center),
                                                                ),
                                                              ],
                                                            ),
                                                            SizedBox(
                                                                height: 7.0),
                                                            if (i ==
                                                                data[index]
                                                                        .ordritms
                                                                        .length -
                                                                    1)
                                                              Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                        "${data[index].narration.toString()}"),
                                                                  ),
                                                                ],
                                                              ),
                                                            Divider(
                                                                height: 8.0,
                                                                thickness: 1.0),
                                                          ],
                                                        );
                                                      }),
                                                    ),
                                                  )
                                                ],
                                              ),
                                              Row(
                                                // mainAxisAlignment:
                                                //     MainAxisAlignment.end,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  if (data[index].imgUrl !=
                                                              null &&
                                                          data[index].imgUrl !=
                                                              '' /*&&
                                                      profile.userCode ==
                                                          data[index]
                                                              .user
                                                              .userCd*/
                                                      )
                                                    IconButton(
                                                        onPressed: () {
                                                          showImagePreviewDialog(
                                                            context: context,
                                                            imageUrl:
                                                                data[index]
                                                                    .imgUrl,
                                                          );
                                                        },
                                                        icon: Icon(
                                                            Icons.visibility)),
                                                  // if (data[index].imgUrl ==
                                                  //     null &&
                                                  //     data[index].imgUrl ==
                                                  //         '' &&
                                                  //     profile.userCode ==
                                                  //         data[index]
                                                  //             .user
                                                  //             .userCd)
                                                  // Container(
                                                  //   child: profile.userCode ==
                                                  //           data[index]
                                                  //               .user
                                                  //               .userCd
                                                  //       ? IconButton(
                                                  //           onPressed: () {
                                                  //             // _openUploadDialog(
                                                  //             //   context:
                                                  //             //       context,
                                                  //             //   oId: data[index]
                                                  //             //       .oId.toString(),
                                                  //             // );
                                                  //
                                                  //             if (data[index]
                                                  //                     .imgUrl
                                                  //                     .toString()
                                                  //                     .isNotEmpty &&
                                                  //                 data[index]
                                                  //                         .imgUrl !=
                                                  //                     null) {
                                                  //               showDialog(
                                                  //                 context:
                                                  //                     context,
                                                  //                 builder:
                                                  //                     (BuildContext
                                                  //                         context) {
                                                  //                   return AlertDialog(
                                                  //                     title: Text(
                                                  //                         'Replace Image'),
                                                  //                     content: Text(
                                                  //                         'Are you sure you want to replace image?'),
                                                  //                     actions: [
                                                  //                       TextButton(
                                                  //                         onPressed:
                                                  //                             () {
                                                  //                           Get.back();
                                                  //                         },
                                                  //                         child:
                                                  //                             Text('No'),
                                                  //                       ),
                                                  //                       TextButton(
                                                  //                         onPressed:
                                                  //                             () {
                                                  //                           Get.back();
                                                  //                           final TextEditingController
                                                  //                               remarksController =
                                                  //                               TextEditingController();
                                                  //
                                                  //                           showDialog(
                                                  //                             context: context,
                                                  //                             barrierDismissible: false,
                                                  //                             builder: (_) => CommonUploadInputDialog(
                                                  //                               title: "Upload Proof",
                                                  //                               message: "Please upload delivery proof for Order ID: ${data[index].oId}.",
                                                  //                               controllerValue: remarksController,
                                                  //                               isLoading: false.obs,
                                                  //                               fileRx: proofOfDelivery,
                                                  //                               webFileRx: proofOfDeliveryWeb,
                                                  //                               onUploadTap: () => pickImage('proofOfDelivery'),
                                                  //                               onDeleteTap: () => removeImage('proofOfDelivery'),
                                                  //                               onSubmit: () async {
                                                  //                                 if (proofOfDelivery.value == null && proofOfDeliveryWeb.value == null) {
                                                  //                                   AppSnackBar.showGetXCustomSnackBar(message: "Please upload image");
                                                  //                                   return;
                                                  //                                 }
                                                  //
                                                  //                                 await insertOrUpdateOrder(
                                                  //                                   data[index].oId.toString(),
                                                  //                                   "",
                                                  //                                   remarksController.text,
                                                  //                                 ).then((_) {
                                                  //                                   removeImage('proofOfDelivery');
                                                  //
                                                  //                                   Get.back();
                                                  //                                 });
                                                  //                               },
                                                  //                               onCancel: () {
                                                  //                                 removeImage('proofOfDelivery');
                                                  //                                 remarksController.clear();
                                                  //                                 Get.back();
                                                  //                               },
                                                  //                             ),
                                                  //                           );
                                                  //                         },
                                                  //                         child:
                                                  //                             Text('Yes'),
                                                  //                       ),
                                                  //                     ],
                                                  //                   );
                                                  //                 },
                                                  //               );
                                                  //             } else {
                                                  //               final TextEditingController
                                                  //                   remarksController =
                                                  //                   TextEditingController();
                                                  //
                                                  //               showDialog(
                                                  //                 context:
                                                  //                     context,
                                                  //                 barrierDismissible:
                                                  //                     false,
                                                  //                 builder: (_) =>
                                                  //                     CommonUploadInputDialog(
                                                  //                   title:
                                                  //                       "Upload Proof",
                                                  //                   message:
                                                  //                       "Please upload delivery proof for Order ID: ${data[index].oId}.",
                                                  //                   controllerValue:
                                                  //                       remarksController,
                                                  //                   isLoading:
                                                  //                       false
                                                  //                           .obs,
                                                  //                   fileRx:
                                                  //                       proofOfDelivery,
                                                  //                   webFileRx:
                                                  //                       proofOfDeliveryWeb,
                                                  //                   onUploadTap: () =>
                                                  //                       pickImage(
                                                  //                           'proofOfDelivery'),
                                                  //                   onDeleteTap: () =>
                                                  //                       removeImage(
                                                  //                           'proofOfDelivery'),
                                                  //                   onSubmit:
                                                  //                       () async {
                                                  //                     if (proofOfDelivery.value ==
                                                  //                             null &&
                                                  //                         proofOfDeliveryWeb.value ==
                                                  //                             null) {
                                                  //                       AppSnackBar.showGetXCustomSnackBar(
                                                  //                           message:
                                                  //                               "Please upload image");
                                                  //                       return;
                                                  //                     }
                                                  //
                                                  //                     await insertOrUpdateOrder(
                                                  //                       data[index]
                                                  //                           .oId
                                                  //                           .toString(),
                                                  //                       "",
                                                  //                       remarksController
                                                  //                           .text,
                                                  //                     ).then(
                                                  //                         (_) {
                                                  //                       removeImage(
                                                  //                           'proofOfDelivery');
                                                  //
                                                  //                       Get.back();
                                                  //                     });
                                                  //                   },
                                                  //                   onCancel:
                                                  //                       () {
                                                  //                     removeImage(
                                                  //                         'proofOfDelivery');
                                                  //                     remarksController
                                                  //                         .clear();
                                                  //                     Get.back();
                                                  //                   },
                                                  //                 ),
                                                  //               );
                                                  //             }
                                                  //           },
                                                  //           icon: Icon(Icons
                                                  //               .attach_file))
                                                  //       : Container(),
                                                  // ),
                                                  IconButton(
                                                      onPressed: () {
                                                        // _openUploadDialog(
                                                        //   context:
                                                        //       context,
                                                        //   oId: data[index]
                                                        //       .oId.toString(),
                                                        // );

                                                        if (data[index]
                                                                .imgUrl
                                                                .toString()
                                                                .isNotEmpty &&
                                                            data[index]
                                                                    .imgUrl !=
                                                                null) {
                                                          showDialog(
                                                            context: context,
                                                            builder:
                                                                (BuildContext
                                                                    context) {
                                                              return AlertDialog(
                                                                title: Text(
                                                                    'Replace Image'),
                                                                content: Text(
                                                                    'Are you sure you want to replace image?'),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed:
                                                                        () {
                                                                      Get.back();
                                                                    },
                                                                    child: Text(
                                                                        'No'),
                                                                  ),
                                                                  TextButton(
                                                                    onPressed:
                                                                        () {
                                                                      Get.back();
                                                                      final TextEditingController
                                                                          remarksController =
                                                                          TextEditingController();

                                                                      showDialog(
                                                                        context:
                                                                            context,
                                                                        barrierDismissible:
                                                                            false,
                                                                        builder:
                                                                            (_) =>
                                                                                CommonUploadInputDialog(
                                                                          title:
                                                                              "Upload Proof",
                                                                          message:
                                                                              "Please upload delivery proof for Order ID: ${data[index].oId}.",
                                                                          controllerValue:
                                                                              remarksController,
                                                                          isLoading:
                                                                              false.obs,
                                                                          fileRx:
                                                                              proofOfDelivery,
                                                                          webFileRx:
                                                                              proofOfDeliveryWeb,
                                                                          onUploadTap: () =>
                                                                              pickImage('proofOfDelivery'),
                                                                          onDeleteTap: () =>
                                                                              removeImage('proofOfDelivery'),
                                                                          onSubmit:
                                                                              () async {
                                                                            if (proofOfDelivery.value == null &&
                                                                                proofOfDeliveryWeb.value == null) {
                                                                              AppSnackBar.showGetXCustomSnackBar(message: "Please upload image");
                                                                              return;
                                                                            }

                                                                            await insertOrUpdateOrder(
                                                                              data[index].oId.toString(),
                                                                              "",
                                                                              remarksController.text,
                                                                            ).then((_) {
                                                                              removeImage('proofOfDelivery');

                                                                              Get.back();
                                                                            });
                                                                          },
                                                                          onCancel:
                                                                              () {
                                                                            removeImage('proofOfDelivery');
                                                                            remarksController.clear();
                                                                            Get.back();
                                                                          },
                                                                        ),
                                                                      );
                                                                    },
                                                                    child: Text(
                                                                        'Yes'),
                                                                  ),
                                                                ],
                                                              );
                                                            },
                                                          );
                                                        } else {
                                                          final TextEditingController
                                                              remarksController =
                                                              TextEditingController();

                                                          showDialog(
                                                            context: context,
                                                            barrierDismissible:
                                                                false,
                                                            builder: (_) =>
                                                                CommonUploadInputDialog(
                                                              title:
                                                                  "Upload Proof",
                                                              message:
                                                                  "Please upload delivery proof for Order ID: ${data[index].oId}.",
                                                              controllerValue:
                                                                  remarksController,
                                                              isLoading:
                                                                  false.obs,
                                                              fileRx:
                                                                  proofOfDelivery,
                                                              webFileRx:
                                                                  proofOfDeliveryWeb,
                                                              onUploadTap: () =>
                                                                  pickImage(
                                                                      'proofOfDelivery'),
                                                              onDeleteTap: () =>
                                                                  removeImage(
                                                                      'proofOfDelivery'),
                                                              onSubmit:
                                                                  () async {
                                                                if (proofOfDelivery
                                                                            .value ==
                                                                        null &&
                                                                    proofOfDeliveryWeb
                                                                            .value ==
                                                                        null) {
                                                                  AppSnackBar
                                                                      .showGetXCustomSnackBar(
                                                                          message:
                                                                              "Please upload image");
                                                                  return;
                                                                }

                                                                await insertOrUpdateOrder(
                                                                  data[index]
                                                                      .oId
                                                                      .toString(),
                                                                  "",
                                                                  remarksController
                                                                      .text,
                                                                ).then((_) {
                                                                  removeImage(
                                                                      'proofOfDelivery');

                                                                  Get.back();
                                                                });
                                                              },
                                                              onCancel: () {
                                                                removeImage(
                                                                    'proofOfDelivery');
                                                                remarksController
                                                                    .clear();
                                                                Get.back();
                                                              },
                                                            ),
                                                          );
                                                        }
                                                      },
                                                      icon: Icon(
                                                          Icons.attach_file)),
                                                  // if (data[index].imgUrl ==
                                                  //     null &&
                                                  //     data[index].imgUrl ==
                                                  //         '' &&
                                                  //     profile.userCode ==
                                                  //         data[index]
                                                  //             .user
                                                  //             .userCd)
                                                  Container(
                                                    child: (profile.userCode ==
                                                                data[index]
                                                                    .user
                                                                    .userCd ||
                                                            (profile.data
                                                                    ?.profileSettings
                                                                    .any((e) =>
                                                                        e.variable ==
                                                                            'omsWithoutErpSync' &&
                                                                        e.value ==
                                                                            'Y') ??
                                                                false))
                                                        ? IconButton(
                                                            onPressed: () {
                                                              Services()
                                                                  .updateOrder(
                                                                      data[index]
                                                                          .oId,
                                                                      context,
                                                                      stockist: data[
                                                                              index]
                                                                          .account
                                                                          .accCd
                                                                          .toString())
                                                                  .then(
                                                                      (value) async {
                                                                print(
                                                                    '[OrderReport] updateOrder response: $value');
                                                                if (value !=
                                                                    null) {
                                                                  // New response format with success flag
                                                                  if (value[
                                                                          'success'] ==
                                                                      false) {
                                                                    // Order cannot be edited - show error and don't navigate
                                                                    AppSnackBar.showGetXCustomSnackBar(
                                                                        message:
                                                                            value['message'] ??
                                                                                'Order cannot be edited',
                                                                        backgroundColor:
                                                                            Colors.red);
                                                                    return;
                                                                  }

                                                                  // Order can be edited - show success and navigate
                                                                  AppSnackBar.showGetXCustomSnackBar(
                                                                      message:
                                                                          value[
                                                                              'message'],
                                                                      backgroundColor:
                                                                          Colors
                                                                              .green);

                                                                  final PartyProvider
                                                                      partyProvider =
                                                                      Provider.of<
                                                                              PartyProvider>(
                                                                          context,
                                                                          listen:
                                                                              false);
                                                                  final ProfileProvider
                                                                      profileProvider =
                                                                      Provider.of<
                                                                              ProfileProvider>(
                                                                          context,
                                                                          listen:
                                                                              false);
                                                                  final orderPartyName =
                                                                      data[index]
                                                                          .account
                                                                          .accName;
                                                                  final orderPartyId =
                                                                      data[index]
                                                                          .account
                                                                          .accCd;

                                                                  partyProvider.changeParty(
                                                                      orderPartyName,
                                                                      orderPartyId,
                                                                      context);
                                                                  if (profileProvider
                                                                          .YN ==
                                                                      'Y') {
                                                                    await partyProvider.changePunchInOutParty(
                                                                        orderPartyName,
                                                                        orderPartyId,
                                                                        context);
                                                                  }

                                                                  Get.to(
                                                                    () =>
                                                                        ProductsPage(),
                                                                  )?.then(
                                                                      (result) {
                                                                    if (result ==
                                                                        true) {
                                                                      final PartyProvider
                                                                          party =
                                                                          Provider.of<PartyProvider>(
                                                                              context,
                                                                              listen: false);
                                                                      if (party
                                                                              .partyid !=
                                                                          "") {
                                                                        getDate();
                                                                      } else {
                                                                        setState(
                                                                            () {
                                                                          data.clear();
                                                                        });
                                                                      }
                                                                    }
                                                                  });
                                                                } else if (value !=
                                                                    null) {
                                                                  // Old response format (String) - treat as success
                                                                  final message = value
                                                                          is String
                                                                      ? value
                                                                      : value[
                                                                          'message'];
                                                                  AppSnackBar.showGetXCustomSnackBar(
                                                                      message:
                                                                          message,
                                                                      backgroundColor:
                                                                          Colors
                                                                              .green);

                                                                  final PartyProvider
                                                                      partyProvider =
                                                                      Provider.of<
                                                                              PartyProvider>(
                                                                          context,
                                                                          listen:
                                                                              false);
                                                                  final ProfileProvider
                                                                      profileProvider =
                                                                      Provider.of<
                                                                              ProfileProvider>(
                                                                          context,
                                                                          listen:
                                                                              false);
                                                                  final orderPartyName =
                                                                      data[index]
                                                                          .account
                                                                          .accName;
                                                                  final orderPartyId =
                                                                      data[index]
                                                                          .account
                                                                          .accCd;

                                                                  partyProvider.changeParty(
                                                                      orderPartyName,
                                                                      orderPartyId,
                                                                      context);
                                                                  if (profileProvider
                                                                          .YN ==
                                                                      'Y') {
                                                                    await partyProvider.changePunchInOutParty(
                                                                        orderPartyName,
                                                                        orderPartyId,
                                                                        context);
                                                                  }

                                                                  Get.to(
                                                                    () =>
                                                                        ProductsPage(),
                                                                  )?.then(
                                                                      (result) {
                                                                    if (result ==
                                                                        true) {
                                                                      final PartyProvider
                                                                          party =
                                                                          Provider.of<PartyProvider>(
                                                                              context,
                                                                              listen: false);
                                                                      if (party
                                                                              .partyid !=
                                                                          "") {
                                                                        getDate();
                                                                      } else {
                                                                        setState(
                                                                            () {
                                                                          data.clear();
                                                                        });
                                                                      }
                                                                    }
                                                                  });
                                                                }
                                                              });
                                                            },
                                                            icon: Icon(Icons
                                                                .edit_outlined))
                                                        : Container(),
                                                  ),
                                                  // if (data[index].imgUrl ==
                                                  //     null &&
                                                  //     data[index].imgUrl ==
                                                  //         '' &&
                                                  //     profile.userCode ==
                                                  //         data[index]
                                                  //             .user
                                                  //             .userCd)
                                                  Container(
                                                    child: profile.userCode ==
                                                            data[index]
                                                                .user
                                                                .userCd
                                                        ? IconButton(
                                                            onPressed: () {
                                                              fromdateController
                                                                      .text =
                                                                  Helper.convertToFormat(
                                                                      "${data[index].vouchDt ?? ""}",
                                                                      'dd-MM-yyyy');
                                                              toDateController
                                                                      .text =
                                                                  Helper.convertToFormat(
                                                                      "${data[index].vouchDt ?? ""}",
                                                                      'dd-MM-yyyy');

                                                              setState(() {
                                                                loading = true;
                                                              });
                                                              Services()
                                                                  .getOrderExportFileItem(
                                                                      context,
                                                                      party
                                                                          .partyid,
                                                                      fromdateController
                                                                          .text,
                                                                      toDateController
                                                                          .text,
                                                                      userController
                                                                          .text,
                                                                      "pdf")
                                                                  .then(
                                                                      (value) {
                                                                if (value !=
                                                                    null) {
                                                                  setState(() {
                                                                    loading =
                                                                        false;
                                                                  });
                                                                  Get.to(() => PdfViewerScreen(
                                                                      pdfUrl:
                                                                          value,
                                                                      fileName:
                                                                          "Order Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}"));
                                                                } else {
                                                                  setState(() {
                                                                    loading =
                                                                        false;
                                                                  });
                                                                }
                                                              });
                                                            },
                                                            icon: Icon(
                                                                Icons.share))
                                                        : Container(),
                                                  ),
                                                  // if (data[index].imgUrl ==
                                                  //     null &&
                                                  //     data[index].imgUrl ==
                                                  //         '' &&
                                                  //     profile.userCode ==
                                                  //         data[index]
                                                  //             .user
                                                  //             .userCd)
                                                  Container(
                                                    child: (profile.userCode ==
                                                                data[index]
                                                                    .user
                                                                    .userCd ||
                                                            (profile.data
                                                                    ?.profileSettings
                                                                    .any((e) =>
                                                                        e.variable ==
                                                                            'omsWithoutErpSync' &&
                                                                        e.value ==
                                                                            'Y') ??
                                                                false))
                                                        ? IconButton(
                                                            onPressed: () {
                                                              showDialog(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (BuildContext
                                                                        context) {
                                                                  return AlertDialog(
                                                                    title: Text(
                                                                        'Delete Confirmation'),
                                                                    content: Text(
                                                                        'Are you sure you want to delete order?'),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed:
                                                                            () {
                                                                          // Cancel button: Close the dialog
                                                                          Navigator.pop(
                                                                              context);
                                                                        },
                                                                        child: Text(
                                                                            'No'),
                                                                      ),
                                                                      TextButton(
                                                                        onPressed:
                                                                            () {
                                                                          // Confirm logout
                                                                          Services()
                                                                              .deleteOrder(data[index].oId, context)
                                                                              .then((value) {
                                                                            if (value !=
                                                                                null) {
                                                                              // Fluttertoast
                                                                              //     .showToast(
                                                                              //         msg:
                                                                              //             value);
                                                                              Navigator.pop(context);

                                                                              AppSnackBar.showGetXCustomSnackBar(message: value, backgroundColor: Colors.green);

                                                                              getDate();
                                                                            }
                                                                          });
                                                                        },
                                                                        child: Text(
                                                                            'Yes'),
                                                                      ),
                                                                    ],
                                                                  );
                                                                },
                                                              );

                                                              // Services()
                                                              //     .deleteOrder(
                                                              //         data[index]
                                                              //             .oId,
                                                              //         context)
                                                              //     .then((value) {
                                                              //   if (value !=
                                                              //       null) {
                                                              //     // Fluttertoast
                                                              //     //     .showToast(
                                                              //     //         msg:
                                                              //     //             value);
                                                              //     AppSnackBar
                                                              //         .showGetXCustomSnackBar(
                                                              //             message:
                                                              //                 value);
                                                              //
                                                              //     getDate();
                                                              //   }
                                                              // });
                                                            },
                                                            icon: Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              color: Colors.red,
                                                            ))
                                                        : Container(),
                                                  )
                                                ],
                                              )
                                            ]),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                  ),
                ],
              ),
              Visibility(
                  visible: loading,
                  child: Container(
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    decoration:
                        BoxDecoration(color: Colors.grey.withOpacity(0.5)),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ))
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  bool _canEditRate(ProfileProvider profile) {
    return profile.data?.profileSettings.any((element) =>
            (element.variable == 'editMasterRateSettings' &&
                element.value == 'Y') ||
            (element.variable == 'editOperatorRateSettings' &&
                element.value == 'Y')) ??
        false;
  }

  // ignore: unused_element
  bool _shouldShowRemarks(ProfileProvider profile) {
    return profile.data?.profileSettings.any((element) =>
            element.variable == 'showItemWiseRemarks' &&
            element.value == 'Y') ??
        false;
  }

  Future<void> pickImage(String type) async {
    Get.bottomSheet(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Capture from Camera'),
              onTap: () async {
                Navigator.pop(Get.context!);
                final XFile? image =
                    await picker.pickImage(source: ImageSource.camera);
                _setImage(type, image);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo),
              title: Text('Select from Gallery'),
              onTap: () async {
                Navigator.pop(Get.context!);
                final XFile? image =
                    await picker.pickImage(source: ImageSource.gallery);
                _setImage(type, image);
              },
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(Get.context!).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  void _setImage(String type, XFile? image) {
    if (image != null) {
      final file = File(image.path);
      switch (type) {
        case 'proofOfDelivery':
          proofOfDelivery.value = file;
          proofOfDeliveryUrl.value = '';
      }
    }
  }

  void removeImage(String type) {
    switch (type) {
      case 'proofOfDelivery':
        proofOfDelivery.value = null;
        proofOfDeliveryWeb.value = null;
        proofOfDeliveryUrl.value = '';
    }
  }

  Widget _buildUploadTileViewMobileWithWeb(
    String title,
    Rx<File?> fileRx,
    Rxn<Uint8List> webFileRx,
    RxnString urlRx,
    VoidCallback onTap,
    VoidCallback onDelete,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommonText(text: title, fontWeight: FontWeight.w700)
            .paddingOnly(top: 10, bottom: 10),
        Obx(() {
          final file = fileRx.value;
          final webFile = webFileRx.value;
          final url = urlRx.value;

          Widget imageWidget;

          if (kIsWeb && webFile != null) {
            imageWidget = Stack(
              children: [
                Positioned.fill(
                  child: Image.memory(webFile, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Icon(Icons.cancel, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ),
              ],
            );
          } else if (!kIsWeb && file != null) {
            imageWidget = Stack(
              children: [
                Positioned.fill(
                  child: Image.file(file, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Icon(Icons.cancel, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ),
              ],
            );
          } else if (url != null && url.isNotEmpty) {
            imageWidget = Stack(
              children: [
                Positioned.fill(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Icon(Icons.cancel, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ),
              ],
            );
          } else {
            imageWidget = Center(child: CommonText(text: "Tap to upload"));
          }

          return InkWell(
            onTap: onTap,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageWidget,
            ),
          );
        }),
      ],
    );
  }

  Future<void> insertOrUpdateOrder(
    String oId,
    String type,
    String remarks,
  ) async {
    final UserProvider ub =
        Provider.of<UserProvider>(Get.context!, listen: false);

    try {
      if (!await Network.isConnected()) {
        AppSnackBar.showGetXCustomSnackBar(
          message: Constants.networkMsg,
        );
        return;
      }

      // ✅ Validate token
      if (ub.token == null || ub.token!.isEmpty) {
        AppSnackBar.showGetXCustomSnackBar(
          message: "Session expired. Please login again.",
        );
        return;
      }

      final bool isUpdate = type == "U";
      final uri = Uri.parse(AppConfig.transactionUploadImageURL);

      final request = http.MultipartRequest(isUpdate ? 'PUT' : 'POST', uri);

      // ✅ DO NOT set Content-Type manually
      request.headers.addAll({
        'x-app-type': 'oms',
        'Authorization': "Bearer ${ub.token!}", // now non-null
      });

      debugPrint("Headers: ${request.headers}");

      // ✅ Add Fields
      final Map<String, String> fields = {
        "remark": remarks,
        "oId": oId,
        "moduleNo": "304",
      };

      fields.forEach((key, value) {
        if (value.isNotEmpty) {
          request.fields[key] = value;
        }
      });

      debugPrint("Fields: ${request.fields}");

      // ✅ File upload helper
      Future<void> addFile({
        required Uint8List bytes,
        required String fileName,
        required String fieldName,
        required String mimeType,
      }) async {
        final typeSplit = mimeType.split('/');

        request.files.add(
          http.MultipartFile.fromBytes(
            fieldName,
            bytes,
            filename: fileName,
            contentType: http.MediaType(typeSplit[0], typeSplit[1]),
          ),
        );

        debugPrint("📎 Attached $fieldName: $fileName ($mimeType)");
      }

      // ✅ Attach Image (Web)
      if (kIsWeb && proofOfDeliveryWeb.value != null) {
        await addFile(
          bytes: proofOfDeliveryWeb.value!,
          fileName: 'payment_qr.png',
          fieldName: 'image',
          mimeType: 'image/png',
        );
      }

      // ✅ Attach Image (Mobile)
      if (!kIsWeb &&
          proofOfDelivery.value != null &&
          await File(proofOfDelivery.value!.path).exists()) {
        final file = File(proofOfDelivery.value!.path);
        final bytes = await file.readAsBytes();
        final mimeType =
            lookupMimeType(file.path) ?? 'application/octet-stream';

        await addFile(
          bytes: bytes,
          fileName: p.basename(file.path),
          fieldName: 'image',
          mimeType: mimeType,
        );
      }

      // ✅ Send Request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("Response Status: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        getDate();
      } else {
        AppSnackBar.showGetXCustomSnackBar(
          message:
              'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}',
        );
      }
    } catch (e, stack) {
      await CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'order_report_upload_failed',
      );
      AppSnackBar.showGetXCustomSnackBar(
        message: e.toString(),
      );
    }
  }

  void showImagePreviewDialog({
    required BuildContext context,
    required String imageUrl,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            /// Image
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 60,
                    ),
                  );
                },
              ),
            ),

            /// Close Button
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  void _openUploadDialog({
    required BuildContext context,
    required String oId,
  }) {
    final TextEditingController remarksController = TextEditingController();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Title
                Text(
                  "Upload Proof With Order ID: $oId",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),

                /// Image Upload Tile
                _buildUploadTileViewMobileWithWeb(
                  "Proof Of Delivery",
                  proofOfDelivery,
                  proofOfDeliveryWeb,
                  proofOfDeliveryUrl,
                  () => pickImage('proofOfDelivery'),
                  () => removeImage('proofOfDelivery'),
                ),

                const SizedBox(height: 15),

                /// Remarks Field
                const Text(
                  "Remarks",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 5),

                TextFormField(
                  controller: remarksController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Enter remarks",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    /// Cancel Button
                    TextButton(
                      onPressed: () {
                        removeImage('proofOfDelivery');
                        Get.back();
                      },
                      child: const Text("Cancel"),
                    ),

                    const SizedBox(width: 10),

                    /// Submit Button
                    ElevatedButton(
                      onPressed: () async {
                        if (proofOfDelivery.value == null &&
                            proofOfDeliveryWeb.value == null) {
                          AppSnackBar.showGetXCustomSnackBar(
                            message: "Please upload image",
                          );
                          return;
                        }

                        await insertOrUpdateOrder(
                          oId,
                          "", // Insert
                          remarksController.text.trim(),
                        ).then((_) {
                          removeImage('proofOfDelivery');

                          Get.back();
                        });
                      },
                      child: const Text("Submit"),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// POST /account-image

// omsWithoutErpSync
