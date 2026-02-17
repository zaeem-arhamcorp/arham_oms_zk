import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/constants/constants.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/accountLeagerReportModal.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/models/salesRegisterReportModal.dart';
import 'package:arham_corporation/network.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/item_list_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/widgets/common_text.dart';
import 'package:arham_corporation/widgets/common_upload_input_dialog.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:arham_corporation/widgets/pdfViewerScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_share/whatsapp_share.dart';

import '../providers/global.dart';
import '../providers/party_provider.dart';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

class SalesRegisterReportScreen extends StatefulWidget {
  @override
  State<SalesRegisterReportScreen> createState() =>
      _SalesRegisterReportScreenState();
}

class _SalesRegisterReportScreenState extends State<SalesRegisterReportScreen> {
  List<DatumSalesRegisterReport> data = [];
  bool noList = false;
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();

  List<Detail> detailData = [];
  bool detailDataLoading = false;

  double vouchAmtTotal = 0.00;

  List<ExpansibleController> expansionController = [];
  int openTileIndex = -1;

  bool isWhatsappInstalled = false;
  bool isWhatsappBussinessInstalled = false;
  bool loading = false;

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

  getDate() {
    setState(() {
      data.clear();
      vouchAmtTotal = 0.00;
      noList = false;
      loading = true;
    });

    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);

    Services()
        .getSalesRegisterReport(
            context,
            Helper.toApi(fromDateController.text),
            Helper.toApi(toDateController.text),
            party.partyid,
            selectedCity != null ? selectedCity!.city : null)
        .then((value) {
      setState(() {
        if (value != null) {
          data.addAll(value.data);
          data.forEach((e) => expansionController.add(ExpansibleController()));
          vouchAmtTotal = value.data
              .fold(
                  0.00,
                  (previousValue, element) =>
                      previousValue + double.parse(element.vouchAmt.toString()))
              .toPrecision(2);

          if (data.isEmpty) {
            noList = true;
          }
        } else {
          noList = true;
        }
        loading = false;
      });
    });
  }

  getDetailData(partyCd, bookCd, vouchDt) {
    detailData.clear();

    Services()
        .getSalesRegisterDetailReport(
            context,
            Helper.toApi(fromDateController.text),
            Helper.toApi(toDateController.text),
            partyCd,
            Helper.toApi(vouchDt),
            bookCd)
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

  void dispose() {
    _focusNode.dispose();
    _focusNodec.dispose();

    super.dispose();
  }

  @override
  void initState() {
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    var moduleEntryAccess = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "313",
          orElse: () => Modules(),
        ) ??
        Modules();

    if (moduleEntryAccess.mODULENO == "313") {
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
      print("Module with MODULE_NO '313' not found.");
    }

    // fromDateController.text = Helper.getDefaultFromDate();
    // toDateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());

    fromDateController.text = Helper.toUi(Helper.getDefaultFromDate());
    toDateController.text =
        Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));

    checkWhatsappInstalled();
    checkWhatsappBussinessInstalled();
    getFilterData();
    getDate();

    super.initState();
    _focusNode.requestFocus();
    _focusNodec.requestFocus();
  }

  TextEditingController searchPartyClt = TextEditingController();
  FocusNode _focusNode = FocusNode();
  FocusNode _focusNodec = FocusNode();
  List _tempParty = [];

  showMenu() {
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);

    showModalBottomSheet(
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
            child: StatefulBuilder(builder: (context, StateSetter setStatee) {
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
                                    _tempParty = _buildSearchList(value, party);
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
                                                  ? _tempParty[index].accName
                                                  : party.data[index].accName);
                                          await party.changeParty(
                                              (_tempParty.length > 0)
                                                  ? _tempParty[index].accName
                                                  : party.data[index].accName,
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
            }),
          );
        });
  }

  List _buildSearchList(String userSearchTerm, PartyProvider party) {
    List _searchList = [];

    for (int i = 0; i < party.data.length; i++) {
      String name = party.data[i].accName;
      String mobileNo = party.data[i].mobile;
      String accCd = party.data[i].accCd;
      String cartItem = party.data[i].accCartItem;
      if (name.toLowerCase().contains(userSearchTerm.toLowerCase()) ||
          mobileNo.toLowerCase().contains(userSearchTerm.toLowerCase()) ||
          accCd.toLowerCase().contains(userSearchTerm.toLowerCase()) ||
          cartItem.toLowerCase().contains(userSearchTerm.toLowerCase())) {
        _searchList.add(party.data[i]);
      }
    }
    return _searchList;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  TextEditingController searchCityClt = TextEditingController();
  List _tempCity = [];
  var selectedCity;

  showMenuCity() {
    showModalBottomSheet(
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
            child: StatefulBuilder(builder: (context, StateSetter setStatee) {
              final ItemListProvider item = context.watch<ItemListProvider>();
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
                                left: 20.0, bottom: 5.0, top: 20.0),
                            child: Text("Select City:",
                                style: TextStyle(
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CupertinoSearchTextField(
                                controller: searchCityClt,
                                focusNode: _focusNodec,
                                onChanged: (value) {
                                  //4
                                  setStatee(() {
                                    _tempCity =
                                        _buildSearchListCity(value, item);
                                  });
                                }),
                          ),
                        ],
                      ),
                      Expanded(
                        child: item.noListCity == true
                            ? Center(
                                child: Text("No City List"),
                              )
                            : item.dataCity.isEmpty
                                ? Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ListView.builder(
                                    itemCount: (_tempCity.length > 0)
                                        ? _tempCity.length
                                        : item.dataCity.length,
                                    itemBuilder: (builder, index) {
                                      return InkWell(
                                        onTap: () async {
                                          final PartyProvider party =
                                              Provider.of<PartyProvider>(
                                                  context,
                                                  listen: false);
                                          party.clearParty();
                                          party.clearPunchInOutParty();
                                          setState(() {
                                            selectedCity = null;
                                            if (_tempCity.length > 0) {
                                              selectedCity = _tempCity[index];
                                            } else {
                                              selectedCity =
                                                  item.dataCity[index];
                                            }
                                          });
                                          Get.back();
                                          getDate();
                                        },
                                        child: (_tempCity.length > 0)
                                            ? _showBottomSheetWithSearchCity(
                                                index, _tempCity)
                                            : _showBottomSheetWithSearchCity(
                                                index, item.dataCity),
                                      );
                                    }),
                      )
                    ],
                  ),
                ),
              );
            }),
          );
        });
  }

  Widget _showBottomSheetWithSearchCity(int index, List listOfParty) {
    return ListTile(
      leading: Text("${index + 1}"),
      title: Text("${listOfParty[index].city}",
          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
      dense: true,
    );
  }

  List _buildSearchListCity(String userSearchTerm, ItemListProvider item) {
    List _searchList = [];
    for (int i = 0; i < item.dataCity.length; i++) {
      String name = item.dataCity[i].city;
      if (name.toLowerCase().contains(userSearchTerm.toLowerCase())) {
        _searchList.add(item.dataCity[i]);
      }
    }
    return _searchList;
  }

  getFilterData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemListProvider>().getCity(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final PartyProvider party = context.watch<PartyProvider>();
    final ProfileProvider profile = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: "Sales Register Report",
        actions: [
          if (printRight)
            PopupMenuButton<dynamic>(
              itemBuilder: (BuildContext context) => <PopupMenuEntry<dynamic>>[
                if (printRight)
                  PopupMenuItem(
                    value: 0,
                    child: Text('Export PDF'),
                    onTap: () {
                      setState(() {
                        loading = true;
                      });
                      Services()
                          .getSalesRegisterReportExportFile(
                              context,
                              Helper.toApi(fromDateController.text),
                              Helper.toApi(toDateController.text),
                              party.partyid,
                              selectedCity != null ? selectedCity!.city : null,
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          setState(() {
                            loading = false;
                          });
                          Get.to(() => PdfViewerScreen(
                              pdfUrl: value,
                              fileName:
                                  "Sales Register Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}"));
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
                          .getSalesRegisterReportExportFile(
                              context,
                              Helper.toApi(fromDateController.text),
                              Helper.toApi(toDateController.text),
                              party.partyid,
                              selectedCity != null ? selectedCity!.city : null,
                              "excel")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(
                                  value,
                                  "Sales Register Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                          .getSalesRegisterReportExportFile(
                              context,
                              Helper.toApi(fromDateController.text),
                              Helper.toApi(toDateController.text),
                              party.partyid,
                              selectedCity != null ? selectedCity!.city : null,
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(
                                  value,
                                  "Sales Register Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                          .getSalesRegisterReportExportFile(
                              context,
                              Helper.toApi(fromDateController.text),
                              Helper.toApi(toDateController.text),
                              party.partyid,
                              selectedCity != null ? selectedCity!.city : null,
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(
                                  value,
                                  "Sales Register Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
      persistentFooterButtons: [
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Bill Amt: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Flexible(
                  child: Text(
                      "₹${Helper.parseNumericValue(vouchAmtTotal.toString())}",
                      maxLines: null,
                      style: TextStyle(overflow: TextOverflow.visible)),
                ),
              ],
            ),
          ],
        )
      ],
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Party: ${Helper.trimValue(party.party, 15)} '),
                            Row(
                              children: [
                                TextButton(
                                    onPressed: showMenu, child: Text("Change")),
                                SizedBox(
                                  width: 2.0,
                                ),
                                GestureDetector(
                                    onTap: () {
                                      party.clearParty();
                                      party.clearPunchInOutParty();
                                      setState(() {
                                        data.clear();
                                        vouchAmtTotal = 0.00;
                                        noList = false;
                                      });
                                      getDate();
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 18,
                                    )),
                              ],
                            )
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("City"),
                                SizedBox(
                                  width: 15,
                                ),
                                GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        searchCityClt.clear();
                                        selectedCity = null;
                                      });
                                      getDate();
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 18,
                                    )),
                              ],
                            ),
                            SizedBox(
                              height: 5.h,
                            ),
                            SizedBox(
                              width: 165.w,
                              child: GestureDetector(
                                onTap: showMenuCity,
                                child: Container(
                                  padding: EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                      "${selectedCity == null ? "Select City" : Helper.trimValue(selectedCity!.city, 20)}"),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

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
                            SizedBox(height: 5),
                            TextFormField(
                              controller: fromDateController,
                              readOnly: true,
                              // 👈 Prevent keyboard
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
                                      // fromDateController.text =
                                      //     DateFormat("yyyy-MM-dd")
                                      //         .format(DateTime.now());

                                      fromDateController.text = Helper.toUi(
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
                                  maxTime: DateTime(2100, 12, 31),
                                  currentTime: DateTime.now(),
                                  locale: LocaleType.en,
                                  onConfirm: (date) {
                                    setState(() {
                                      // fromDateController.text =
                                      //     DateFormat("yyyy-MM-dd").format(date);

                                      fromDateController.text = Helper.toUi(
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
                            SizedBox(height: 5),
                            TextFormField(
                              controller: toDateController,
                              readOnly: true,
                              // 👈 Prevent keyboard
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 10.0, horizontal: 8),
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
                                  maxTime: DateTime(2100, 12, 31),
                                  currentTime: DateTime.now(),
                                  locale: LocaleType.en,
                                  onConfirm: (date) {
                                    setState(() {
                                      // toDateController.text =
                                      //     DateFormat("yyyy-MM-dd").format(date);

                                      toDateController.text = Helper.toUi(
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
                            ),
                          ],
                        ),
                      ),
                    ],
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
                //               controller: fromDateController,
                //               decoration: InputDecoration(
                //                 contentPadding: EdgeInsets.symmetric(
                //                     vertical: 10.0, horizontal: 5),
                //                 border: OutlineInputBorder(
                //                     borderRadius: BorderRadius.circular(12)),
                //                 hintText: "Select date",
                //                 suffixIcon: GestureDetector(
                //                     onTap: () {
                //                       setState(() {
                //                         fromDateController.text =
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
                //                       vertical: 0.0, horizontal: 8),
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
                //             )
                //           ],
                //         ),
                //       )
                //     ],
                //   ),
                // ),
                Divider(),
                Expanded(
                  child: noList == true
                      ? Center(
                          child: Text("No Data Found"),
                        )
                      : ListView.builder(
                          itemCount: data.length,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            return Card(
                              elevation: 2,
                              child: Padding(
                                  padding: const EdgeInsets.only(top: 5.0),
                                  child: Container(
                                    decoration:
                                        BoxDecoration(color: Colors.white),
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
                                                        "Date",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        Helper.toUi(
                                                            "${data[index].vouchDt ?? ""}"),
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
                                                        "Book Cd",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${data[index].bookCd ?? ""}",
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
                                                        "Bill No",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${data[index].partyBl ?? ""}",
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
                                                        "Amount",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${Helper.parseNumericValue(data[index].vouchAmt.toString())}",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey),
                                                      )
                                                    ],
                                                  ),
                                                ),
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
                                                        "Party Name",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${data[index].account.accName}",
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
                                                        "Narration",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${data[index].narration ?? ""}",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            )
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

                                            getDetailData(
                                                data[index].partyCd,
                                                data[index].bookCd,
                                                data[index].vouchDt);
                                          } else {
                                            setState(() {
                                              detailData = [];
                                            });
                                          }
                                        },
                                        children: [
                                          if (detailDataLoading == true)
                                            Text("Loading....")
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
                                                            Divider(
                                                                height: 8.0,
                                                                thickness: 1.0),
                                                          ],
                                                        );
                                                      })),
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
                                                          '' &&
                                                      profile.userCode ==
                                                          data[index]
                                                              .user
                                                              .userCd)
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
                                                  Container(
                                                    child: profile.userCode ==
                                                            data[index]
                                                                .user
                                                                .userCd
                                                        ? IconButton(
                                                            onPressed: () {
                                                              // _openUploadDialog(
                                                              //   context:
                                                              //       context,
                                                              //   oId: data[index]
                                                              //       .oId.toString(),
                                                              // );

                                                              final TextEditingController
                                                                  remarksController =
                                                                  TextEditingController();

                                                              showDialog(
                                                                context:
                                                                    context,
                                                                barrierDismissible:
                                                                    false,
                                                                builder: (_) =>
                                                                    CommonUploadInputDialog(
                                                                  title:
                                                                      "Upload Proof",
                                                                  message:
                                                                      "Please upload delivery proof for Order ID: ${data[index].sId}.",
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
                                                                    if (proofOfDelivery.value ==
                                                                            null &&
                                                                        proofOfDeliveryWeb.value ==
                                                                            null) {
                                                                      AppSnackBar.showGetXCustomSnackBar(
                                                                          message:
                                                                              "Please upload image");
                                                                      return;
                                                                    }

                                                                    await insertOrUpdateSalesRegister(
                                                                      data[index]
                                                                          .sId
                                                                          .toString(),
                                                                      context,
                                                                      "",
                                                                      remarksController
                                                                          .text,
                                                                    );

                                                                    removeImage(
                                                                        'proofOfDelivery');
                                                                    Get.back();
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
                                                            },
                                                            icon: Icon(Icons
                                                                .attach_file))
                                                        : Container(),
                                                  ),
                                                ],
                                              )
                                            ]),
                                        ]),
                                  )),
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
    );
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

  Future<void> insertOrUpdateSalesRegister(
    String sId,
    BuildContext context,
    String type,
    String remarks,
  ) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

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
        "sId": sId,
        //"moduleNo": "205",
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
    } catch (e) {
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

                        await insertOrUpdateSalesRegister(
                          oId,
                          context,
                          "", // Insert
                          remarksController.text.trim(),
                        );

                        removeImage('proofOfDelivery');
                        Get.back();
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
