import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/ItemWiseReportModal.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/services/services.dart';
//---
import 'package:arham_corporation/views/item_wise_sale/models/deptmentListModal.dart';
import 'package:arham_corporation/views/item_wise_sale/models/itemListModal.dart';
import 'package:arham_corporation/views/item_wise_sale/providers/item_list_provider.dart';
//---
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:arham_corporation/widgets/pdfViewerScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// import 'package:whatsapp_share_improved/whatsapp_share_improved.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';

class ItemWiseOrderReportView extends StatefulWidget {
  const ItemWiseOrderReportView({Key? key}) : super(key: key);

  @override
  State<ItemWiseOrderReportView> createState() =>
      _ItemWiseOrderReportScreenState();
}

class _ItemWiseOrderReportScreenState extends State<ItemWiseOrderReportView> {
  List<DatumItemWiseReport> data = [];
  bool noList = false;

  List<DatumItemWiseDetailReport> detailData = [];
  bool detailDataLoading = false;

  TextEditingController fromdateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  TextEditingController searchItemClt = TextEditingController();
  FocusNode _focusNode = FocusNode();
  FocusNode _focusNoded = FocusNode();
  DatumItemList? selectedItem;
  DatumDeptment? selectedDeptment;

  double totalQty = 0.0;
  double totalAmt = 0.0;

  bool isWhatsappInstalled = false;
  bool isWhatsappBussinessInstalled = false;
  bool loading = false;

  var viewRight = false;
  var addRight = false;
  var updateRight = false;
  var deleteRight = false;
  var printRight = false;

  Future<bool?> checkWhatsappInstalled() async {
    // isWhatsappInstalled =
    //     await WhatsappShareImproved.isInstalled(package: Package.whatsapp) ?? false;
    isWhatsappInstalled = await WhatsappSharePlus.isWhatsappInstalled();
    return null;
  }

  Future<bool?> checkWhatsappBussinessInstalled() async {
    // isWhatsappBussinessInstalled =
    //     await WhatsappShareImproved.isInstalled(package: Package.businessWhatsapp) ??
    //         false;
    isWhatsappBussinessInstalled = await WhatsappSharePlus.isWhatsappBusinessInstalled();
    return null;
  }

  List<ExpansibleController> expansionController = [];
  int openTileIndex = -1;

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    try {
      return double.parse(v.toString());
    } catch (e) {
      return 0.0;
    }
  }

  getDate() {
    setState(() {
      data.clear();
      expansionController.clear();
      totalQty = 0.0;
      totalAmt = 0.0;
      noList = false;
      loading = true;
    });
    print(fromdateController.text);
    print(toDateController.text);

    Services()
        .getItemWiseOrderReport(
            context,
            Helper.toApi(fromdateController.text),
            Helper.toApi(toDateController.text),
            selectedItem != null ? selectedItem!.itemCd : null,
            selectedDeptment != null ? selectedDeptment!.deptCd : null)
        .then((value) {
      setState(() {
        if (value != null) {
          data.addAll(value.data);
          data.forEach((e) => expansionController.add(ExpansibleController()));
          if (value.data.isNotEmpty) {
            totalQty = value.data
                .fold(
                    0.00,
                    (previousValue, element) =>
                        previousValue + _toDouble(element.sumQty))
                .toPrecision(2);
            totalAmt = value.data
                .fold(
                    0.00,
                    (previousValue, element) =>
                        previousValue + _toDouble(element.sumVouchAmt))
                .toPrecision(2);
          }
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

  getDetailData(itemCd) {
    Services()
        .getItemWiseOrderDetailReport(
            context,
            Helper.toApi(fromdateController.text),
            Helper.toApi(toDateController.text),
            itemCd,
            typeFull: true)
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
    _focusNoded.dispose();

    super.dispose();
  }

  @override
  void initState() {
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    var moduleEntryAccess = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "325",
          orElse: () => Modules(),
        ) ??
        Modules();

    if (moduleEntryAccess.mODULENO == "325") {
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
      print("Module with MODULE_NO '325' not found.");
    }

    // fromdateController.text = Helper.getDefaultFromDate();
    // toDateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());

    fromdateController.text = Helper.toUi(Helper.getDefaultFromDate());
    toDateController.text =
        Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));

    getItemWise();
    getDate();
    checkWhatsappInstalled();
    checkWhatsappBussinessInstalled();
    super.initState();
    _focusNode.requestFocus();
    _focusNoded.requestFocus();
  }

  getItemWise() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemListProvider>().getItems(context);
      context.read<ItemListProvider>().getDeptment(context);
    });
  }

  List _tempItem = [];
  List _tempDeptement = [];

  TextEditingController searchItemCltt = TextEditingController();
  TextEditingController searchDeptmentCltt = TextEditingController();

///////////////////////////////////////////////////////////////////////////////////

  showMenuItem() {
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
                  height: 350,
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
                            child: Text("Select Item:",
                                style: TextStyle(
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CupertinoSearchTextField(
                                controller: searchItemCltt,
                                focusNode: _focusNode,
                                onChanged: (value) {
                                  //4
                                  setStatee(() {
                                    _tempItem =
                                        _buildSearchListItem(value, item);
                                  });
                                }),
                          ),
                        ],
                      ),
                      Expanded(
                        child: item.noList == true
                            ? Center(
                                child: Text("No List"),
                              )
                            : item.itemListForSalesReport.isEmpty
                                ? Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ListView.builder(
                                    itemCount: (_tempItem.length > 0)
                                        ? _tempItem.length
                                        : item.itemListForSalesReport.length,
                                    itemBuilder: (builder, index) {
                                      return InkWell(
                                        onTap: () async {
                                          setState(() {
                                            if (_tempItem.length > 0) {
                                              selectedItem = _tempItem[index];
                                            } else {
                                              selectedItem =
                                                  item.itemListForSalesReport[
                                                      index];
                                            }
                                          });

                                          Get.back();
                                          getDate();
                                        },
                                        child: (_tempItem.length > 0)
                                            ? _showBottomSheetWithSearchItem(
                                                index, _tempItem)
                                            : _showBottomSheetWithSearchItem(
                                                index,
                                                item.itemListForSalesReport),
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

  Widget _showBottomSheetWithSearchItem(int index, List listOfParty) {
    return ListTile(
      leading: Text("${index + 1}"),
      title: Text("${listOfParty[index].itemName}",
          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
      dense: true,
    );
  }

  List _buildSearchListItem(String userSearchTerm, ItemListProvider item) {
    List _searchList = [];

    for (int i = 0; i < item.itemListForSalesReport.length; i++) {
      String name = item.itemListForSalesReport[i].itemName;

      if (name.toLowerCase().contains(userSearchTerm.toLowerCase())) {
        _searchList.add(item.itemListForSalesReport[i]);
      }
    }
    return _searchList;
  }

////////////////////////////////////////////////////////////////////////////////////

  showMenuDeptment() {
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
                            child: Text("Select Department:",
                                style: TextStyle(
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CupertinoSearchTextField(
                                controller: searchDeptmentCltt,
                                focusNode: _focusNoded,
                                onChanged: (value) {
                                  //4
                                  setStatee(() {
                                    _tempDeptement =
                                        _buildSearchListDeptment(value, item);
                                  });
                                }),
                          ),
                        ],
                      ),
                      Expanded(
                        child: item.noListDeptment == true
                            ? Center(
                                child: Text("No Department List"),
                              )
                            : item.itemListForSalesReport.isEmpty
                                ? Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ListView.builder(
                                    itemCount: (_tempDeptement.length > 0)
                                        ? _tempDeptement.length
                                        : item.dataDeptmant.length,
                                    itemBuilder: (builder, index) {
                                      return InkWell(
                                        onTap: () async {
                                          setState(() {
                                            selectedItem = null;
                                            searchItemCltt.clear();
                                            _tempItem.clear();
                                            if (_tempDeptement.length > 0) {
                                              selectedDeptment =
                                                  _tempDeptement[index];
                                            } else {
                                              selectedDeptment =
                                                  item.dataDeptmant[index];
                                            }
                                          });
                                          Get.back();
                                          getDate();
                                        },
                                        child: (_tempDeptement.length > 0)
                                            ? _showBottomSheetWithSearchDeptment(
                                                index, _tempDeptement)
                                            : _showBottomSheetWithSearchDeptment(
                                                index, item.dataDeptmant),
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

  Widget _showBottomSheetWithSearchDeptment(int index, List listOfParty) {
    return ListTile(
      leading: Text("${index + 1}"),
      title: Text("${listOfParty[index].deptName}",
          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
      dense: true,
    );
  }

  List _buildSearchListDeptment(String userSearchTerm, ItemListProvider item) {
    List _searchList = [];
    for (int i = 0; i < item.dataDeptmant.length; i++) {
      String name = item.dataDeptmant[i].deptName;
      if (name.toLowerCase().contains(userSearchTerm.toLowerCase())) {
        _searchList.add(item.dataDeptmant[i]);
      }
    }
    return _searchList;
  }

///////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    late ItemListProvider it;
    try {
      it = context.watch<ItemListProvider>();
    } catch (e) {
      // Provider not found, return error state
      print('[ItemWiseOrderReportView] Provider error: $e');
      return Scaffold(
        appBar: CustomAppBar(title: "Item Wise Order Report"),
        body: Center(
          child: Text('Unable to load data. Please try again.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: "Item Wise Order Report",
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
                          .getItemWiseOrderExportFile(
                              context,
                              Helper.toApi(fromdateController.text),
                              Helper.toApi(toDateController.text),
                              selectedItem != null
                                  ? selectedItem!.itemCd
                                  : null,
                              selectedDeptment != null
                                  ? selectedDeptment!.deptCd
                                  : null,
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          setState(() {
                            loading = false;
                          });
                          Get.to(() => PdfViewerScreen(
                              pdfUrl: value,
                              fileName:
                                  "Item Wise Order Report_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}"));
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
                          .getItemWiseOrderExportFile(
                              context,
                              Helper.toApi(fromdateController.text),
                              Helper.toApi(toDateController.text),
                              selectedItem != null
                                  ? selectedItem!.itemCd
                                  : null,
                              selectedDeptment != null
                                  ? selectedDeptment!.deptCd
                                  : null,
                              "excel")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(
                                  value,
                                  "Item Wise Order Report_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                          .getItemWiseOrderExportFile(
                              context,
                              Helper.toApi(fromdateController.text),
                              Helper.toApi(toDateController.text),
                              selectedItem != null
                                  ? selectedItem!.itemCd
                                  : null,
                              selectedDeptment != null
                                  ? selectedDeptment!.deptCd
                                  : null,
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(
                                  value,
                                  "Item Wise Order Report_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
                                  "Pdf file has been downloaded")
                              .then((value) async {
                            setState(() {
                              loading = false;
                            });
                            if (value != null) {
                               // await WhatsappShareImproved.shareFile(
                               //         phone: "91",
                               //         filePath: [value],
                               //         package: Package.whatsapp)
                               await WhatsappSharePlus.shareImageToWhatsapp(
                                       phone: "91",
                                       imagePath: value)
                                   .catchError((err) {
                                 print(err);
                                 return false;
                               });
                             }
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
                          .getItemWiseOrderExportFile(
                              context,
                              Helper.toApi(fromdateController.text),
                              Helper.toApi(toDateController.text),
                              selectedItem != null
                                  ? selectedItem!.itemCd
                                  : null,
                              selectedDeptment != null
                                  ? selectedDeptment!.deptCd
                                  : null,
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(
                                  value,
                                  "Item Wise Order Report_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
                                  "Pdf file has been downloaded")
                              .then((value) async {
                            setState(() {
                              loading = false;
                            });
                            if (value != null) {
                                 // await WhatsappShareImproved.shareFile(
                                 //         phone: "91",
                                 //         filePath: [value],
                                 //         package: Package.businessWhatsapp)
                                 await WhatsappSharePlus.shareImageToWhatsappBusiness(
                                         phone: "91",
                                         imagePath: value)
                                     .catchError((err) {
                                   print(err);
                                   return false;
                                 });
                               }
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
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Row(
                //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          "Total Qty: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Flexible(
                          child: Text("${totalQty}",
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
                          "Total Amt: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Flexible(
                          child: Text(
                              "₹${Helper.parseNumericValue(totalAmt.toString())}",
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
                      horizontal: 10.0, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Item Name"),
                              SizedBox(
                                width: 15,
                              ),
                              GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      searchItemClt.clear();
                                      selectedItem = null;
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
                              onTap: showMenuItem,
                              child: Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                    "${selectedItem == null ? "Select Item" : Helper.trimValue(selectedItem!.itemName, 20)}"),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Department Name"),
                              SizedBox(
                                width: 15,
                              ),
                              GestureDetector(
                                  onTap: () {
                                    searchDeptmentCltt.clear();
                                    selectedDeptment = null;
                                    it.clearDepetmantforSalceReport();
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
                              onTap: showMenuDeptment,
                              child: Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                    "${selectedDeptment == null ? "Select Department" : Helper.trimValue(selectedDeptment!.deptName, 20)}"),
                              ),
                            ),
                          ),
                        ],
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
                //               onSaved: (val) {
                //                 setState(() {
                //                   getDate();
                //                 });
                //               },
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
                //               onSaved: (val) {
                //                 setState(() {
                //                   getDate();
                //                 });
                //               },
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
                              onSaved: (val) {
                                setState(() {
                                  getDate();
                                });
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
                              onSaved: (val) {
                                setState(() {
                                  getDate();
                                });
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
                                      title: Row(
                                        children: <Widget>[
                                          // Expanded(
                                          //   child: Column(
                                          //     crossAxisAlignment:
                                          //         CrossAxisAlignment.start,
                                          //     children: [
                                          //       Text(
                                          //         "Item Cd",
                                          //         style: TextStyle(
                                          //             fontSize: 12,
                                          //             color: Colors.black),
                                          //       ),
                                          //       Text(
                                          //         "${data[index].itemCd}",
                                          //         style: TextStyle(
                                          //             fontSize: 12,
                                          //             color: Colors.grey),
                                          //       )
                                          //     ],
                                          //   ),
                                          // ),
                                          SizedBox(
                                            width: 90,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Item Name",
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black),
                                                ),
                                                Text(
                                                  "${data[index].item.itemName}",
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
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  "Qty",
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black),
                                                ),
                                                Text(
                                                  "${data[index].sumQty}",
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
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  "Free",
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black),
                                                ),
                                                Text(
                                                  "${data[index].sumOtherDesc}",
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
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text("Amount",
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black)),
                                              Text(
                                                "${Helper.parseNumericValue(data[index].sumVouchAmt.toString())}",
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              )
                                            ],
                                          )),
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
                                          getDetailData(data[index].itemCd);
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
                                                    // Expanded(
                                                    //     child: Text(
                                                    //   "Bill No",
                                                    //   style: TextStyle(
                                                    //       fontSize: 12.0),
                                                    // )),
                                                    Expanded(
                                                        child: Text(
                                                      "Date",
                                                      style: TextStyle(
                                                          fontSize: 12.0),
                                                    )),
                                                    Expanded(
                                                        flex: 3,
                                                        child: Text(
                                                          "Party Name",
                                                          style: TextStyle(
                                                              fontSize: 12.0),
                                                        )),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    // Expanded(
                                                    //     child: Text(
                                                    //   "Batch/MRP",
                                                    //   style: TextStyle(
                                                    //       fontSize: 12.0),
                                                    // )),
                                                    Expanded(
                                                        child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
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
                                                        child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              right: 15.0),
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: Text(
                                                          "Free Qty",
                                                          style: TextStyle(
                                                              fontSize: 12.0),
                                                        ),
                                                      ),
                                                    )),
                                                    Expanded(
                                                        child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
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
                                                          const EdgeInsets.only(
                                                              right: 15.0),
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: Text(
                                                          "Amt",
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
                                                              // Expanded(
                                                              //     child: Text(
                                                              //   "${detailData[index].refNo}",
                                                              //   style: TextStyle(
                                                              //       color: Colors
                                                              //           .grey,
                                                              //       fontSize:
                                                              //           12.0),
                                                              // )),
                                                              Expanded(
                                                                  child: Text(
                                                                Helper.toUi(
                                                                    "${detailData[index].vouchDt}"),
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .grey,
                                                                    fontSize:
                                                                        12.0),
                                                              )),
                                                              Expanded(
                                                                  flex: 3,
                                                                  child: Text(
                                                                    "${detailData[index].account.accName}",
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
                                                              // Expanded(
                                                              //     child: Text(
                                                              //   "${detailData[index].sizeCd}",
                                                              //   style: TextStyle(
                                                              //       color: Colors
                                                              //           .grey,
                                                              //       fontSize:
                                                              //           12.0),
                                                              // )),
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
                                                                    "${detailData[index].otherDesc}",
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
