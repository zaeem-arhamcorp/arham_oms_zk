import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:arham_corporation/widgets/pdfViewerScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_share/whatsapp_share.dart';

import '../models/accountLeagerReportModal.dart';
import '../providers/global.dart';
import '../providers/party_provider.dart';

class AccountLedgerScreen extends StatefulWidget {
  const AccountLedgerScreen({Key? key}) : super(key: key);

  @override
  State<AccountLedgerScreen> createState() => _AccountLedgerScreenState();
}

class _AccountLedgerScreenState extends State<AccountLedgerScreen> {
  List<DatumAccountLeager> data = [];
  bool noList = true;

  List<Detail> detailData = [];
  List<BillWiseDetail> billWisedetailData = [];
  bool detailDataLoading = false;

  TextEditingController fromdateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();

  double closingBalance = 0.00;
  double drAmtTotal = 0.00;
  double crAmtTotal = 0.00;

  List<ExpansionTileController> expansionController = [];
  int openTileIndex = -1;

  bool isWhatsappInstalled = false;
  bool isWhatsappBussinessInstalled = false;
  bool loading = false;

  var viewRight = false;
  var addRight = false;
  var updateRight = false;
  var deleteRight = false;
  var printRight = false;

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

  getDate() {
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    setState(() {
      data.clear();
      expansionController.clear();
      closingBalance = 0.00;
      drAmtTotal = 0.00;
      crAmtTotal = 0.00;
      noList = false;
      loading = true;
    });
    print(fromdateController.text);
    print(toDateController.text);

    Services()
        .getAccountLeagerReport(context, Helper.toApi(fromdateController.text),
        Helper.toApi(toDateController.text), party.partyid)
        .then((value) {
      setState(() {
        if (value != null) {
          data.addAll(value.data);
          if (value.data.isNotEmpty) {
            data.forEach(
                (e) => expansionController.add(ExpansionTileController()));

            drAmtTotal = value.data
                .fold(
                    0.00,
                    (previousValue, element) =>
                        previousValue + double.parse(element.drAmt.toString()))
                .toPrecision(2);

            crAmtTotal = value.data
                .fold(
                    0.00,
                    (previousValue, element) =>
                        previousValue + double.parse(element.crAmt.toString()))
                .toPrecision(2);

            print(drAmtTotal);
            print(crAmtTotal);

            closingBalance = drAmtTotal - crAmtTotal;

            print(closingBalance);
          }

          if (data.isEmpty) {
            setState(() {
              noList = true;
            });
          }
        } else {
          setState(() {
            noList = true;
          });
        }
        setState(() {
          loading = false;
        });
      });
    });
  }

  getDetailData(partyCd, bookCd, vouchDt, vouchNo) {
    detailData.clear();

    Services()
        .getAccountLeagerDetailReport(context, Helper.toApi(fromdateController.text),
        Helper.toApi(toDateController.text), partyCd, Helper.toApi(vouchDt), bookCd, vouchNo)
        .then((value) {
      setState(() {
        if (value != null) {
          detailData.addAll(value.data);
        }
      });
    }).whenComplete(() {
      setState(() {
        detailDataLoading = false;
      });
    });
  }

  getBillWiseDetailData(partyCd, vouchDt, bookCd, vouchNo) {
    billWisedetailData.clear();
    Services()
        .getAccountLeagerBillWiseDetailReport(
            context, partyCd, Helper.toApi(vouchDt), bookCd, vouchNo)
        .then((value) {
      setState(() {
        if (value != null) {
          billWisedetailData.addAll(value.data);
        }
      });
    }).whenComplete(() {
      setState(() {
        detailDataLoading = false;
      });
    });
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
          (module) => module.mODULENO == "302",
          orElse: () => Modules(),
        ) ??
        Modules();

    if (moduleEntryAccess.mODULENO == "302") {
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
      print("Module with MODULE_NO '302' not found.");
    }

    // fromdateController.text = Helper.getDefaultFromDate();
    // print('From Date : ${fromdateController.text}');
    // toDateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());

    fromdateController.text = Helper.toUi(Helper.getDefaultFromDate());
    toDateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));

    checkWhatsappInstalled();
    checkWhatsappBussinessInstalled();
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    if (party.party != "") {
      getDate();
    }
    super.initState();
    _focusNode.requestFocus();
  }

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
                  final Global global = context.watch<Global>();
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
                                              await global.changePartyname(
                                                  (_tempParty.length > 0)
                                                      ? _tempParty[index]
                                                          .accName
                                                      : party
                                                          .data[index].accName);
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: "Account Ledger Report",
        actions: [
          if (printRight)
            PopupMenuButton<dynamic>(
              itemBuilder: (BuildContext context) => <PopupMenuEntry<dynamic>>[
                if (printRight)
                  PopupMenuItem(
                    value: 0,
                    child: Text('Export PDF'),
                    onTap: () {
                      if (party.partyid.isEmpty || party.party.isEmpty) {
                        AppSnackBar.showGetXCustomSnackBar(
                            message: 'Please select party');
                      } else {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getAccountLeagerExportFile(
                                context,
                                Helper.toApi(fromdateController.text),
                            Helper.toApi(toDateController.text),
                                party.partyid,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            setState(() {
                              loading = false;
                            });
                            Get.to(() => PdfViewerScreen(
                                pdfUrl: value,
                                fileName:
                                    "Account Ledger Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}"));
                          } else {
                            setState(() {
                              loading = false;
                            });
                          }
                        });
                      }
                    },
                  ),
                if (printRight)
                  PopupMenuItem(
                    value: 1,
                    child: Text('Export Excel'),
                    onTap: () {
                      if (party.partyid.isEmpty || party.party.isEmpty) {
                        AppSnackBar.showGetXCustomSnackBar(
                            message: 'Please select party');
                      } else {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getAccountLeagerExportFile(
                                context,
                            Helper.toApi(fromdateController.text),
                            Helper.toApi(toDateController.text),
                                party.partyid,
                                "excel")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Account Ledger Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                      }
                    },
                  ),
                if (isWhatsappInstalled && printRight)
                  PopupMenuItem(
                    value: 1,
                    child: Text('Whatsapp Share'),
                    onTap: () {
                      if (party.partyid.isEmpty || party.party.isEmpty) {
                        AppSnackBar.showGetXCustomSnackBar(
                            message: 'Please select party');
                      } else {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getAccountLeagerExportFile(
                                context,
                            Helper.toApi(fromdateController.text),
                            Helper.toApi(toDateController.text),
                                party.partyid,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Account Ledger Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                      }
                    },
                  ),
                if (isWhatsappBussinessInstalled && printRight)
                  PopupMenuItem(
                    value: 1,
                    child: Text('Whatsapp \nBussiness Share'),
                    onTap: () {
                      if (party.partyid.isEmpty || party.party.isEmpty) {
                        AppSnackBar.showGetXCustomSnackBar(
                            message: 'Please select party');
                      } else {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getAccountLeagerExportFile(
                                context,
                            Helper.toApi(fromdateController.text),
                            Helper.toApi(toDateController.text),
                                party.partyid,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Account Ledger Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                      }
                    },
                  ),
              ],
            )
        ],
      ),
      persistentFooterButtons: [
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Closing Balance: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Flexible(
                  child: Text(
                      "₹${Helper.parseNumericValue(closingBalance.toString())} ${closingBalance < 0 ? "Cr" : "Dr"}",
                      maxLines: null,
                      style: TextStyle(overflow: TextOverflow.visible)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Row(
                //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          "Dr Amt: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Flexible(
                          child: Text(
                              "₹${Helper.parseNumericValue(drAmtTotal.toString())}",
                              maxLines: null,
                              style: TextStyle(overflow: TextOverflow.visible)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          "Cr Amt: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Flexible(
                          child: Text(
                              "₹${Helper.parseNumericValue(crAmtTotal.toString())}",
                              maxLines: null,
                              style: TextStyle(overflow: TextOverflow.visible)),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        )
      ],
      body: SafeArea(
        child: Stack(children: [
          Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5.0, vertical: 5.0),
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
                          splashFactory:
                              NoSplash.splashFactory, // Disable splash effect
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
                                textAlign:
                                    TextAlign.start, // Ensure the text is LTR
                              ),
                            ),
                            if (Provider.of<PartyProvider>(context)
                                .party
                                .isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  final party = Provider.of<PartyProvider>(
                                      context,
                                      listen: false);
                                  party.clearParty();
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
              //                     borderRadius: BorderRadius.circular(5)),
              //                 hintText: "Select date",
              //                 suffixIcon: GestureDetector(
              //                     onTap: () {
              //                       if (party.party != "") {
              //                         setState(() {
              //                           fromdateController.text =
              //                               DateFormat("yyyy-MM-dd")
              //                                   .format(DateTime.now());
              //                         });
              //                         getDate();
              //                       } else {
              //                         AppSnackBar.showGetXCustomSnackBar(
              //                             message: "Please Select the Party");
              //                         // Fluttertoast.showToast(
              //                         //     msg: "Please Select the Party");
              //                       }
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
              //                 if (party.party != "") {
              //                   getDate();
              //                 }
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
              //                       borderRadius: BorderRadius.circular(5)),
              //                   hintText: "Select date"),
              //               firstDate: DateTime(-21000),
              //               initialDate: DateTime.now(),
              //               lastDate: DateTime(21000),
              //               dateLabelText: 'Select Date',
              //               onChanged: (val) {
              //                 if (party.party != "") {
              //                   getDate();
              //                 }
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
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              hintText: "Select date",
                              suffixIcon: GestureDetector(
                                onTap: () {
                                  if (party.party != "") {
                                    setState(() {
                                      // fromdateController.text =
                                      //     DateFormat("yyyy-MM-dd")
                                      //         .format(DateTime.now());

                                      fromdateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));
                                    });
                                    getDate();
                                  } else {
                                    AppSnackBar.showGetXCustomSnackBar(
                                        message: "Please Select the Party");
                                    // Fluttertoast.showToast(
                                    //     msg: "Please Select the Party");
                                  }
                                },
                                child: Tooltip(
                                  message: "Today",
                                  child: Icon(Icons.today_outlined),
                                ),
                              ),
                            ),
                            onTap: () {
                              if (party.party.isNotEmpty) {
                                DatePicker.showDatePicker(
                                  context,
                                  showTitleActions: true,
                                  minTime: DateTime(2000, 1, 1),
                                  maxTime: DateTime.now(),
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
                              }
                            },
                            validator: (val) {
                              print(val);
                              return null;
                            },
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
                                borderRadius: BorderRadius.circular(5),
                              ),
                              hintText: "Select date",
                            ),
                            onTap: () {
                              if (party.party.isNotEmpty) {
                                DatePicker.showDatePicker(
                                  context,
                                  showTitleActions: true,
                                  minTime: DateTime(2000, 1, 1),
                                  maxTime: DateTime(2100, 12, 31),
                                  currentTime: DateTime.now(),
                                  locale: LocaleType.en,
                                  onConfirm: (date) {
                                    setState(() {
                                      // toDateController.text =
                                      //     DateFormat("yyyy-MM-dd").format(date);

                                      toDateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(date));

                                    });
                                    getDate();
                                  },
                                );
                              }
                            },
                            validator: (val) {
                              print(val);
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(),
              Expanded(
                child: party.party == ""
                    ? Center(
                        child: Text("Please Select Party First"),
                      )
                    : noList == true
                        ? Center(
                            child: Text("No Data Found"),
                          )
                        : ListView.builder(
                            itemCount: data.length,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 5.0),
                                child: Container(
                                  decoration:
                                      BoxDecoration(color: Colors.white),
                                  child: Card(
                                    elevation: 2,
                                    child: ExpansionTile(
                                        controller: expansionController[index],
                                        expandedAlignment: Alignment.topLeft,
                                        childrenPadding: EdgeInsets.only(
                                            left: 20,
                                            right: 20,
                                            top: 15,
                                            bottom: 15),
                                        title: Column(
                                          children: [
                                            Row(
                                              children: <Widget>[
                                                Expanded(
                                                  flex: 2,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "Vouch Date",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.black),
                                                      ),
                                                      Text(
                                                        Helper.toUi("${data[index].vouchDt}")
                                                        ,
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey),
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
                                                        "BK",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.black),
                                                      ),
                                                      Text(
                                                        "${data[index].bookCd}",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey),
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
                                                        "Bill No",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.black),
                                                      ),
                                                      Text(
                                                        "${data[index].billno}",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                    flex: 2,
                                                    child: Column(
                                                      children: [
                                                        Text("Dr Amt",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black)),
                                                        Text(
                                                          "${data[index].drAmt}",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
                                                        )
                                                      ],
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                    )),
                                                Expanded(
                                                    flex: 2,
                                                    child: Column(
                                                      children: [
                                                        Text("Cr Amt",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black)),
                                                        Text(
                                                          "${data[index].crAmt}",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
                                                        )
                                                      ],
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                    )),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "Acc Name",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.black),
                                                      ),
                                                      Text(
                                                        "${data[index].accName}",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                    flex: 2,
                                                    child: Column(
                                                      children: [
                                                        Text("Narration",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black)),
                                                        Text(
                                                          "${data[index].narration}",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
                                                        )
                                                      ],
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                    )),
                                                Expanded(
                                                    flex: 2,
                                                    child: Column(
                                                      children: [
                                                        Text("Closing Bal",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black)),
                                                        Text(
                                                          "${Helper.parseNumericValue(data[index].clBal.toString())}",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                          ),
                                                        )
                                                      ],
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                    )),
                                              ],
                                            ),
                                          ],
                                        ),
                                        onExpansionChanged: (val) {
                                          setState(() {
                                            if (openTileIndex != -1 &&
                                                openTileIndex != index) {
                                              expansionController[openTileIndex]
                                                  .collapse();
                                            }
                                            openTileIndex = index;
                                          });

                                          if (val == true) {
                                            setState(() {
                                              detailDataLoading = true;
                                            });
                                            if (data[index].bookCd == "RC" ||
                                                data[index].bookCd == "PY" ||
                                                data[index].bookCd == "IC" ||
                                                data[index].bookCd == "EP") {
                                              getBillWiseDetailData(
                                                  data[index].partyCd,
                                                  data[index].vouchDt,
                                                  data[index].bookCd,
                                                  data[index].vouchNo);
                                            } else {
                                              getDetailData(
                                                  data[index].partyCd,
                                                  data[index].bookCd,
                                                  data[index].vouchDt,
                                                  data[index].vouchNo);
                                            }
                                          } else {
                                            setState(() {
                                              detailData = [];
                                            });
                                          }
                                        },
                                        children: [
                                          if (detailDataLoading == true)
                                            Text("Loading....")
                                          else if (data[index].bookCd == "RC" ||
                                              data[index].bookCd == "PY" ||
                                              data[index].bookCd == "IC" ||
                                              data[index].bookCd == "EP")
                                            Column(children: [
                                              Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                          child: Text(
                                                        "Book Cd",
                                                        style: TextStyle(
                                                            fontSize: 12.0),
                                                      )),
                                                      Expanded(
                                                          child: Text(
                                                        "Vouch Dt",
                                                        style: TextStyle(
                                                            fontSize: 12.0),
                                                      )),
                                                      Expanded(
                                                          child: Text(
                                                        "Bill No",
                                                        style: TextStyle(
                                                            fontSize: 12.0),
                                                      )),
                                                      Expanded(
                                                          child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                right: 15.0),
                                                        child: Align(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: Text(
                                                            "Bill Amt",
                                                            style: TextStyle(
                                                                fontSize: 12.0),
                                                          ),
                                                        ),
                                                      )),
                                                      Expanded(
                                                          child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                right: 15.0),
                                                        child: Align(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: Text(
                                                            "Bill Paid Amt",
                                                            style: TextStyle(
                                                                fontSize: 12.0),
                                                          ),
                                                        ),
                                                      )),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              Padding(
                                                  padding:
                                                      EdgeInsets.only(top: 8.0),
                                                  child: ListView.builder(
                                                      physics:
                                                          NeverScrollableScrollPhysics(),
                                                      itemCount:
                                                          billWisedetailData
                                                              .length,
                                                      shrinkWrap: true,
                                                      itemBuilder:
                                                          (context, index) {
                                                        return Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                    child: Text(
                                                                  "${billWisedetailData[index].blBookCd}",
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .grey,
                                                                      fontSize:
                                                                          12.0),
                                                                )),
                                                                Expanded(
                                                                    child: Text(
                                                                      Helper.toUi("${billWisedetailData[index].blVDt}")
                                                                  ,
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .grey,
                                                                      fontSize:
                                                                          12.0),
                                                                )),
                                                                Expanded(
                                                                    child: Text(
                                                                  "${billWisedetailData[index].blBillNo}",
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .grey,
                                                                      fontSize:
                                                                          12.0),
                                                                )),
                                                                Expanded(
                                                                    child:
                                                                        Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          right:
                                                                              15.0),
                                                                  child: Align(
                                                                    alignment:
                                                                        Alignment
                                                                            .centerRight,
                                                                    child: Text(
                                                                      "${Helper.parseNumericValue(billWisedetailData[index].blAmt.toString())}",
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                    ),
                                                                  ),
                                                                )),
                                                                Expanded(
                                                                    child:
                                                                        Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          right:
                                                                              15.0),
                                                                  child: Align(
                                                                    alignment:
                                                                        Alignment
                                                                            .centerRight,
                                                                    child: Text(
                                                                      "${Helper.parseNumericValue(billWisedetailData[index].blPaid.toString())}",
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                    ),
                                                                  ),
                                                                )),
                                                              ],
                                                            ),
                                                            SizedBox(
                                                              height: 7.0,
                                                            ),
                                                          ],
                                                        );
                                                      }))
                                            ])
                                          else
                                            Column(children: [
                                              Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                          child: Text(
                                                        "Item Cd",
                                                        style: TextStyle(
                                                            fontSize: 12.0),
                                                      )),
                                                      Expanded(
                                                          flex: 4,
                                                          child: Text(
                                                            "Item Name",
                                                            style: TextStyle(
                                                                fontSize: 12.0),
                                                          )),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                          child: Text(
                                                        "Size Cd",
                                                        style: TextStyle(
                                                            fontSize: 12.0),
                                                      )),
                                                      Expanded(
                                                          child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                right: 15.0),
                                                        child: Align(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: Text(
                                                            "Quantity",
                                                            style: TextStyle(
                                                                fontSize: 12.0),
                                                          ),
                                                        ),
                                                      )),
                                                      Expanded(
                                                          child: Text(
                                                        "Free Qty",
                                                        style: TextStyle(
                                                            fontSize: 12.0),
                                                      )),
                                                      Expanded(
                                                          child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                right: 15.0),
                                                        child: Align(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: Text(
                                                            "Rate",
                                                            style: TextStyle(
                                                                fontSize: 12.0),
                                                          ),
                                                        ),
                                                      )),
                                                      Expanded(
                                                          child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                right: 15.0),
                                                        child: Align(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: Text(
                                                            "Vouch Amt",
                                                            style: TextStyle(
                                                                fontSize: 12.0),
                                                          ),
                                                        ),
                                                      )),
                                                    ],
                                                  )
                                                ],
                                              ),
                                              Padding(
                                                  padding:
                                                      EdgeInsets.only(top: 8.0),
                                                  child: ListView.builder(
                                                      physics:
                                                          NeverScrollableScrollPhysics(),
                                                      itemCount:
                                                          detailData.length,
                                                      shrinkWrap: true,
                                                      itemBuilder:
                                                          (context, index) {
                                                        return Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                    child: Text(
                                                                  "${detailData[index].itemCd}",
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .grey,
                                                                      fontSize:
                                                                          12.0),
                                                                )),
                                                                Expanded(
                                                                    flex: 4,
                                                                    child: Text(
                                                                      "${detailData[index].item.itemName}",
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                    )),
                                                              ],
                                                            ),
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                    child: Text(
                                                                  "${detailData[index].sizeCd}",
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .grey,
                                                                      fontSize:
                                                                          12.0),
                                                                )),
                                                                Expanded(
                                                                    child:
                                                                        Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          right:
                                                                              15.0),
                                                                  child: Align(
                                                                    alignment:
                                                                        Alignment
                                                                            .centerRight,
                                                                    child: Text(
                                                                      "${detailData[index].qty}",
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                    ),
                                                                  ),
                                                                )),
                                                                Expanded(
                                                                    child: Text(
                                                                  "${detailData[index].otherDesc}",
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .grey,
                                                                      fontSize:
                                                                          12.0),
                                                                )),
                                                                Expanded(
                                                                    child:
                                                                        Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          right:
                                                                              15.0),
                                                                  child: Align(
                                                                    alignment:
                                                                        Alignment
                                                                            .centerRight,
                                                                    child: Text(
                                                                      "${Helper.parseNumericValue(detailData[index].rate.toString())}",
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                    ),
                                                                  ),
                                                                )),
                                                                Expanded(
                                                                    child:
                                                                        Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          right:
                                                                              15.0),
                                                                  child: Align(
                                                                    alignment:
                                                                        Alignment
                                                                            .centerRight,
                                                                    child: Text(
                                                                      "${Helper.parseNumericValue(detailData[index].vouchAmt.toString())}",
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12.0),
                                                                    ),
                                                                  ),
                                                                )),
                                                              ],
                                                            ),
                                                            SizedBox(
                                                              height: 7.0,
                                                            ),
                                                          ],
                                                        );
                                                      }))
                                            ]),
                                        ]),
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
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5)),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ))
        ]),
      ),
    );
  }
}
