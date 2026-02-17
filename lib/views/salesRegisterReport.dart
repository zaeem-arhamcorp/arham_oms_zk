import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/accountLeagerReportModal.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/models/salesRegisterReportModal.dart';
import 'package:arham_corporation/providers/item_list_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:arham_corporation/widgets/pdfViewerScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_share/whatsapp_share.dart';

import '../providers/global.dart';
import '../providers/party_provider.dart';

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
                                                          ],
                                                        );
                                                      }))
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
}
