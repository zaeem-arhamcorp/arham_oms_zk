import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/OutstandingReportModal.dart';
import 'package:arham_corporation/models/accountLeagerReportModal.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/item_list_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/views/PartyWiseOutStandingReportPayableScreen.dart';
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

class OutStandingReportPayableScreen extends StatefulWidget {
  const OutStandingReportPayableScreen({Key? key}) : super(key: key);

  @override
  State<OutStandingReportPayableScreen> createState() =>
      _OutStandingReportPayableScreenState();
}

class _OutStandingReportPayableScreenState
    extends State<OutStandingReportPayableScreen> {
  List<DatumOutstandingSale> data = [];
  bool noList = false;
  TextEditingController toDateController = TextEditingController();
  FocusNode _focusNode = FocusNode();
  FocusNode _cfocusNode = FocusNode();

  List<Detail> detailData = [];
  bool detailDataLoading = false;

  double vouchAmtTotal = 0.00;
  double paidAmtTotal = 0.00;
  double osAmtTotal = 0.00;

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
      paidAmtTotal = 0.00;
      osAmtTotal = 0.00;
      noList = false;
      loading = true;
    });

    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);

    Services()
        .getOutStandingReportPayble(
            context,
            Helper.toApi(toDateController.text),
            party.partyid,
            selectedCity != null ? selectedCity!.city : null)
        .then((value) {
      setState(() {
        if (value != null) {
          data.addAll(value.data);
          vouchAmtTotal = value.data
                  .fold(
                      0.00,
                      (previousValue, element) =>
                          previousValue +
                          double.parse(element.sumVouchAmt.toString()))
                  .toPrecision(2) *
              -1;
          paidAmtTotal = value.data
              .fold(
                  0.00,
                  (previousValue, element) =>
                      previousValue +
                      double.parse(element.sumPaidAmt.toString()))
              .toPrecision(2);
          osAmtTotal = value.data
                  .fold(
                      0.00,
                      (previousValue, element) =>
                          previousValue +
                          double.parse(element.sumOsAmt.toString()))
                  .toPrecision(2) *
              -1;
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

  getFilterData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemListProvider>().getCity(context);
    });
  }

  void dispose() {
    _focusNode.dispose();
    _cfocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    var moduleEntryAccess = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "314",
          orElse: () => Modules(),
        ) ??
        Modules();

    if (moduleEntryAccess.mODULENO == "314") {
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
      print("Module with MODULE_NO '314' not found.");
    }

    //toDateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());
    toDateController.text =
        Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));
    getFilterData();
    getDate();
    checkWhatsappInstalled();
    checkWhatsappBussinessInstalled();
    super.initState();
    _focusNode.requestFocus();
    _cfocusNode.requestFocus();
  }

  TextEditingController searchPartyClt = TextEditingController();

  List _tempParty = [];

  showMenu() {
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    pp.getpartyname(context);
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
                                              setState(() {
                                                selectedCity = null;
                                              });
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

  /////////////////////////////////////////////////////////////////////////////////////////////

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
                                focusNode: _cfocusNode,
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

  @override
  Widget build(BuildContext context) {
    final ProfileProvider p = context.watch<ProfileProvider>();
    final PartyProvider party = context.watch<PartyProvider>();
    final Global global = context.watch<Global>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: "OutStanding Payable",
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
                          .getOutStandingExportFilePayable(
                              context,
                              Helper.toApi(toDateController.text),
                              party.partyid,
                              selectedCity != null ? selectedCity!.city : "",
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          setState(() {
                            loading = false;
                          });

                          Get.to(() => PdfViewerScreen(
                              pdfUrl: value,
                              fileName:
                                  "Outstanding Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}"));
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
                          .getOutStandingExportFilePayable(
                              context,
                              Helper.toApi(toDateController.text),
                              party.partyid,
                              selectedCity != null ? selectedCity!.city : "",
                              "excel")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(
                                  value,
                                  "Outstanding Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                          .getOutStandingExportFilePayable(
                              context,
                              Helper.toApi(toDateController.text),
                              party.partyid,
                              selectedCity != null ? selectedCity!.city : "",
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(
                                  value,
                                  "Outstanding Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                          .getOutStandingExportFilePayable(
                              context,
                              Helper.toApi(toDateController.text),
                              party.partyid,
                              selectedCity != null ? selectedCity!.city : "",
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(
                                  value,
                                  "Outstanding Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Row(
                //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          "Paid Amt: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Flexible(
                          child: Text(
                              "₹${Helper.parseNumericValue(paidAmtTotal.toString())}",
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
                          "Pending Amt: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Flexible(
                          child: Text(
                              "₹${Helper.parseNumericValue(osAmtTotal.toString())}",
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                                      borderRadius: BorderRadius.circular(5)),
                                  child: Text(
                                      "${selectedCity == null ? "Select City" : Helper.trimValue(selectedCity!.city, 20)}"),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                            // DateTimePicker(
                            //   controller: toDateController,
                            //   decoration: InputDecoration(
                            //       contentPadding: EdgeInsets.symmetric(
                            //           vertical: 0.0, horizontal: 8),
                            //       border: OutlineInputBorder(
                            //           borderRadius: BorderRadius.circular(5)),
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

                            TextFormField(
                              controller: toDateController,
                              readOnly: true,
                              // prevent typing manually
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
                                  // safe range instead of -21000
                                  maxTime: DateTime(2100, 12, 31),
                                  // safe range instead of 21000
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
                                    getDate(); // call your existing function
                                  },
                                );
                              },
                              validator: (val) {
                                print(val);
                                return null;
                              },
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
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
                                    child: GestureDetector(
                                      onTap: () async {
                                        if (p.data != null &&
                                            p.data!.modulesList!.any((module) =>
                                                module.mODULENO == "315" &&
                                                module.rEADRIGHT == true)) {
                                          await global.changePartyname(
                                              data[index].accName);
                                          await party.changeParty(
                                              data[index].accName,
                                              data[index].accCd,
                                              context);

                                          Get.to(() =>
                                              PartyWiseOutStandingReportPayableScreen(
                                                toDate: toDateController.text,
                                              ));
                                        } else {
                                          AppSnackBar.showGetXCustomSnackBar(
                                              message:
                                                  'There is nothing to do.');
                                        }
                                      },
                                      child: ListTile(
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
                                                        "Acc Name",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${data[index].accName ?? ""}",
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
                                                        "Bill Amt",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${Helper.parseNumericValue(((double.tryParse(data[index].sumOsAmt.toString()) ?? 0) * -1).toString())}",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey,
                                                        ),
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
                                                        "Paid Amt",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${Helper.parseNumericValue(((double.tryParse(data[index].sumPaidAmt.toString()) ?? 0) * -1).toString())}",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey,
                                                        ),
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
                                                        "Pending Amt",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${Helper.parseNumericValue(((double.tryParse(data[index].sumOsAmt.toString()) ?? 0) * -1).toString())}",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey,
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "City",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${data[index].city ?? ""}",
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
                                      ),
                                    )),
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
    );
  }
}
