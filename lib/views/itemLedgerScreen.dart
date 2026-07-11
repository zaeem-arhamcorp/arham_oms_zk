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
// import 'package:whatsapp_share_improved/whatsapp_share_improved.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';

import '../helper/helper.dart';
import '../models/deptmentListModal.dart';
import '../models/itemLedgerReportModal.dart';
import '../models/itemListModal.dart';
import '../providers/item_list_provider.dart';

class ItemLedgerReportScreen extends StatefulWidget {
  final DatumItemList? item;

  const ItemLedgerReportScreen({Key? key, this.item});

  @override
  State<ItemLedgerReportScreen> createState() => _ItemLedgerReportScreenState();
}

class _ItemLedgerReportScreenState extends State<ItemLedgerReportScreen> {
  List<DatumItermLedger> data = [];
  bool noList = false;

  TextEditingController fromdateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  TextEditingController searchItemClt = TextEditingController();
  FocusNode _focusNode = FocusNode();
  DatumItemList? selectedItem;
  DatumDeptment? selectedDeptment;

  double totalClStk = 0.0;
  double totalcrAmt = 0.0;
  double totaldrAmt = 0.0;
  double difference = 0.0;

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

  getDate() {
    setState(() {
      data.clear();
      totalClStk = 0.0;
      totalcrAmt = 0.0;
      totaldrAmt = 0.0;
      difference = 0.0;
      noList = false;
      loading = true;
    });

    Services()
        .getItemLeagerReport(context, Helper.toApi(fromdateController.text),
            Helper.toApi(toDateController.text), selectedItem!.itemCd)
        .then((value) {
      setState(() {
        if (value != null) {
          data.addAll(value.data);
          if (data.isEmpty) {
            noList = true;
          } else {
            totalClStk = double.parse(value.data.last.clStk.toString());
            totaldrAmt = value.data
                .fold(
                    0.00,
                    (previousValue, element) =>
                        previousValue +
                        (element.drAmt != null
                            ? double.parse(element.drAmt.toString())
                            : 0))
                .toPrecision(2);
            totalcrAmt = value.data
                .fold(
                    0.00,
                    (previousValue, element) =>
                        previousValue +
                        (element.crAmt != null
                            ? double.parse(element.crAmt.toString())
                            : 0))
                .toPrecision(2);
            difference = totaldrAmt - totalcrAmt;
          }
        } else {
          setState(() {
            noList = true;
          });
        }
        loading = false;
      });
    });
  }

  void dispose() {
    _focusNode.dispose();
    _1focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    var moduleEntryAccess = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "303",
          orElse: () => Modules(),
        ) ??
        Modules();

    if (moduleEntryAccess.mODULENO == "303") {
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
      print("Module with MODULE_NO '303' not found.");
    }

    if (widget.item != null) {
      selectedItem = widget.item;
    }
    // fromdateController.text = Helper.getDefaultFromDate();
    // toDateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());

    fromdateController.text = Helper.toUi(Helper.getDefaultFromDate());
    toDateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));

    getItemWise();
    checkWhatsappInstalled();
    checkWhatsappBussinessInstalled();
    super.initState();
    _1focusNode.requestFocus();
    _focusNode.requestFocus();
  }

  getItemWise() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemListProvider>().getItems(context);
      context.read<ItemListProvider>().getDeptment(context);
      if (widget.item != null) {
        getDate();
      }
    });
  }

  List _tempItem = [];
  List _tempDeptement = [];

  TextEditingController searchItemCltt = TextEditingController();
  TextEditingController searchDeptmentCltt = TextEditingController();
  FocusNode _1focusNode = FocusNode();

///////////////////////////////////////////////////////////////////////////////////

  showMenuItem() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
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
                            : item.itemListForLeadgerReport.isEmpty
                                ? Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ListView.builder(
                                    itemCount: (_tempItem.length > 0)
                                        ? _tempItem.length
                                        : item.itemListForLeadgerReport.length,
                                    itemBuilder: (builder, index) {
                                      return InkWell(
                                        onTap: () async {
                                          setState(() {
                                            if (_tempItem.length > 0) {
                                              selectedItem = _tempItem[index];
                                            } else {
                                              selectedItem =
                                                  item.itemListForLeadgerReport[
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
                                                item.itemListForLeadgerReport),
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

    for (int i = 0; i < item.itemListForLeadgerReport.length; i++) {
      String name = item.itemListForLeadgerReport[i].itemName;

      if (name.toLowerCase().contains(userSearchTerm.toLowerCase())) {
        _searchList.add(item.itemListForLeadgerReport[i]);
      }
    }
    return _searchList;
  }

////////////////////////////////////////////////////////////////////////////////////

  showMenuDeptment() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
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
                                focusNode: _1focusNode,
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

                                            item.fillterListForLeadgerReport(
                                                selectedDeptment!.deptCd);
                                          });
                                          Get.back();
                                          //getDate();
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
    final ItemListProvider item = context.watch<ItemListProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: "Item Ledger Report",
        actions: [
          if (printRight)
            PopupMenuButton<dynamic>(
              itemBuilder: (BuildContext context) => <PopupMenuEntry<dynamic>>[
                if (printRight)
                  PopupMenuItem(
                    value: 0,
                    child: Text('Export PDF'),
                    onTap: () {
                      if (selectedItem == null ||
                          selectedItem!.itemCd.isEmpty) {
                        AppSnackBar.showGetXCustomSnackBar(
                            message: 'Please select item');
                      } else {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getItemLeagerExportFile(
                                context,
                                Helper.toApi(fromdateController.text),
                            Helper.toApi(toDateController.text),
                                selectedItem!.itemCd,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            setState(() {
                              loading = false;
                            });
                            Get.to(() => PdfViewerScreen(
                                pdfUrl: value,
                                fileName:
                                    "Item Ledger Report_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}"));
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
                      if (selectedItem == null ||
                          selectedItem!.itemCd.isEmpty) {
                        AppSnackBar.showGetXCustomSnackBar(
                            message: 'Please select item');
                      } else {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getItemLeagerExportFile(
                                context,
                            Helper.toApi(fromdateController.text),
                            Helper.toApi(toDateController.text),
                                selectedItem!.itemCd,
                                "excel")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Item Ledger Report_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                      if (selectedItem == null ||
                          selectedItem!.itemCd.isEmpty) {
                        AppSnackBar.showGetXCustomSnackBar(
                            message: 'Please select item');
                      } else {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getItemLeagerExportFile(
                                context,
                            Helper.toApi(fromdateController.text),
                            Helper.toApi(toDateController.text),
                                selectedItem!.itemCd,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Item Ledger Report_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                      }
                    },
                  ),
                if (isWhatsappBussinessInstalled && printRight)
                  PopupMenuItem(
                    value: 1,
                    child: Text('Whatsapp \nBussiness Share'),
                    onTap: () {
                      if (selectedItem == null ||
                          selectedItem!.itemCd.isEmpty) {
                        AppSnackBar.showGetXCustomSnackBar(
                            message: 'Please select item');
                      } else {
                        setState(() {
                          loading = true;
                        });
                        Services()
                            .getItemLeagerExportFile(
                                context,
                            Helper.toApi(fromdateController.text),
                            Helper.toApi(toDateController.text),
                                selectedItem!.itemCd,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Item Ledger Report_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                        child: Text("${totalClStk}",
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
                        "Difference: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Flexible(
                        child: Text(
                            "₹${Helper.parseNumericValue(difference.toString())}",
                            maxLines: null,
                            style: TextStyle(overflow: TextOverflow.visible)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: 5.0),
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
                          child: Text("₹${totaldrAmt}",
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
                          child: Text("₹${totalcrAmt}",
                              maxLines: null,
                              style: TextStyle(overflow: TextOverflow.visible)),
                        ),
                      ],
                    ),
                  ),
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
                          Text("Item Name"),
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
                                    borderRadius: BorderRadius.circular(5)),
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
                                    item.clearDepetmantforLeadgerReport();
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
                                    borderRadius: BorderRadius.circular(5)),
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
                //                     borderRadius: BorderRadius.circular(5)),
                //                 hintText: "Select date",
                //                 suffixIcon: GestureDetector(
                //                     onTap: () {
                //                       if (widget.item != null) {
                //                         setState(() {
                //                           fromdateController.text =
                //                               DateFormat("yyyy-MM-dd")
                //                                   .format(DateTime.now());
                //                         });
                //                         getDate();
                //                       } else {
                //                         // Fluttertoast.showToast(
                //                         //     msg: "Please Select the Item");
                //                         AppSnackBar.showGetXCustomSnackBar(
                //                             message: 'Please Select the Item');
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
                //                 if (selectedItem != null) {
                //                   getDate();
                //                 }
                //               },
                //               validator: (val) {
                //                 print(val);
                //                 return null;
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
                //                       borderRadius: BorderRadius.circular(5)),
                //                   hintText: "Select date"),
                //               firstDate: DateTime(-21000),
                //               initialDate: DateTime.now(),
                //               lastDate: DateTime(21000),
                //               dateLabelText: 'Select Date',
                //               onChanged: (val) {
                //                 if (selectedItem != null) {
                //                   getDate();
                //                 }
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
                                    if (widget.item != null ||
                                        selectedItem != null) {
                                      setState(() {
                                        // fromdateController.text =
                                        //     DateFormat("yyyy-MM-dd")
                                        //         .format(DateTime.now());

                                        fromdateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));

                                      });
                                      getDate();
                                    } else {
                                      AppSnackBar.showGetXCustomSnackBar(
                                          message: 'Please Select the Item');
                                    }
                                  },
                                  child: Tooltip(
                                    message: "Today",
                                    child: Icon(Icons.today_outlined),
                                  ),
                                ),
                              ),
                              onTap: () {
                                if (selectedItem != null) {
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
                                        //     DateFormat("yyyy-MM-dd")
                                        //         .format(date);

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
                                if (selectedItem != null) {
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
                                        //     DateFormat("yyyy-MM-dd")
                                        //         .format(date);

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
                  child: selectedItem == null
                      ? Center(
                          child: Text("Please Select Item"),
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
                                      child: ListTile(
                                        title: Column(
                                          children: [
                                            Row(
                                              children: <Widget>[
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "Voucher Dt",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.black),
                                                      ),
                                                      Text(
                                                        Helper.toUi("${data[index].vouchDt ?? ""}")
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
                                                        "Book Cd",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black,
                                                        ),
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
                                                        "${data[index].refNo}",
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
                                                        "Acc Name",
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
                                              ],
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 10.0),
                                              child: Row(
                                                children: <Widget>[
                                                  Expanded(
                                                    flex: 2,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Batch",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        Text(
                                                          "${data[index].sizeCd}",
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
                                                          "Qty",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        Text(
                                                          "${data[index].quantity ?? ""}",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
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
                                                          "Free Qty",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        Text(
                                                          "${data[index].otherDesc}",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
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
                                                          "Rate",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        Text(
                                                          "${data[index].rate}",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
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
                                                          "${data[index].crAmt != null ? "Cr Amt" : "Dr Amt"}",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        Text(
                                                          "${data[index].crAmt != null ? Helper.parseNumericValue(data[index].crAmt.toString()) : Helper.parseNumericValue(data[index].drAmt.toString())}",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
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
                                                          "Cl Stk",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        Text(
                                                          "${data[index].clStk}",
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
                                            ),
                                          ],
                                        ),
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
    );
  }
}
