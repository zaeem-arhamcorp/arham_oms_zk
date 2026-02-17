import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/deptmentListModal.dart';
import 'package:arham_corporation/models/itemListModal.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/models/stockReportModal.dart';
import 'package:arham_corporation/providers/item_list_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/views/itemLedgerScreen.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:arham_corporation/widgets/pdfViewerScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:number_paginator/number_paginator.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_share/whatsapp_share.dart';

import '../providers/party_provider.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({Key? key}) : super(key: key);

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  List<DatumStockWiseSale> data = [];
  bool noList = false;
  DatumItemList? selectedItem;
  DatumDeptment? selectedDeptment;

  StockReportModal? stockreport;

  NumberPaginatorController numberPaginatorController =
      NumberPaginatorController();

  bool checkMRP = false;
  bool purchaseRate = false;
  bool salesReport = false;
  bool showZeroStk = false;
  int radiocheck = 4;

  dynamic totalValue;

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
      noList = false;
      loading = true;
    });

    print(party.partyid);
    Services()
        .getStockReport(
            context,
            selectedItem != null ? selectedItem!.itemCd : null,
            selectedDeptment != null ? selectedDeptment!.deptCd : null,
            currentIndex + 1,
            showZeroStk,
            radiocheck)
        .then((value) {
      setState(() {
        if (value != null) {
          stockreport = value;
          data.addAll(value.data);
          totalValue = value.total;

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
  FocusNode _focusNode = FocusNode();
  FocusNode _focusNoded = FocusNode();

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
                  height: 420.0,
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
                  height: 420.0,
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
                            : item.dataDeptmant.isEmpty
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
          (module) => module.mODULENO == "305",
          orElse: () => Modules(),
        ) ??
        Modules();

    if (moduleEntryAccess.mODULENO == "305") {
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
      print("Module with MODULE_NO '305' not found.");
    }

    getItemWise();
    getDate();
    checkWhatsappInstalled();
    checkWhatsappBussinessInstalled();
    super.initState();
    _focusNoded.requestFocus();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ItemListProvider item = context.watch<ItemListProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: "Stock Report",
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
                          .getStockExportFile(
                              context,
                              selectedItem != null
                                  ? selectedItem!.itemCd
                                  : null,
                              selectedDeptment != null
                                  ? selectedDeptment!.deptCd
                                  : null,
                              currentIndex + 1,
                              showZeroStk,
                              radiocheck,
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          setState(() {
                            loading = false;
                          });
                          Get.to(() => PdfViewerScreen(
                              pdfUrl: value, fileName: "Stock Report"));
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
                          .getStockExportFile(
                              context,
                              selectedItem != null
                                  ? selectedItem!.itemCd
                                  : null,
                              selectedDeptment != null
                                  ? selectedDeptment!.deptCd
                                  : null,
                              currentIndex + 1,
                              showZeroStk,
                              radiocheck,
                              "excel")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(value, "Stock Report",
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
                          .getStockExportFile(
                              context,
                              selectedItem != null
                                  ? selectedItem!.itemCd
                                  : null,
                              selectedDeptment != null
                                  ? selectedDeptment!.deptCd
                                  : null,
                              currentIndex + 1,
                              showZeroStk,
                              radiocheck,
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(value, "Stock Report",
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
                          .getStockExportFile(
                              context,
                              selectedItem != null
                                  ? selectedItem!.itemCd
                                  : null,
                              selectedDeptment != null
                                  ? selectedDeptment!.deptCd
                                  : null,
                              currentIndex + 1,
                              showZeroStk,
                              radiocheck,
                              "pdf")
                          .then((value) {
                        if (value != null) {
                          Helper.saveFileAndroid(value, "Stock Report",
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
                  "Total Closing Stock : ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Flexible(
                  child: Text(
                      "${totalValue != null ? Helper.parseNumericValue(totalValue[0]['TOTAL_C_STK_VALUE'].toString()) : ""}",
                      maxLines: null,
                      style: TextStyle(overflow: TextOverflow.visible)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Row(
                children: [
                  Text(
                    "Total Amount : ",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Flexible(
                    child: Text(
                        "₹ ${totalValue != null ? Helper.parseNumericValue(totalValue[0]['TOTAL_RATE_VALUE'].toString()) : ""}",
                        maxLines: null,
                        style: TextStyle(overflow: TextOverflow.visible)),
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
                                    item.clearDepetmantforLeadgerReport();
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
                Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
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
                              "Landing Rate",
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
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
                                }),
                            Expanded(
                              child: Text(
                                "Purchase Rate",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
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
                              "Sales Rate",
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
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
                              "MRP",
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15.0, top: 8.0),
                  child: Row(
                    children: [
                      Checkbox(
                          visualDensity: const VisualDensity(
                              horizontal: VisualDensity.minimumDensity,
                              vertical: VisualDensity.minimumDensity),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          value: showZeroStk,
                          onChanged: (val) {
                            setState(() {
                              showZeroStk = val!;
                              getDate();
                            });
                          }),
                      Text("Show 0 stock Item"),
                    ],
                  ),
                ),
                Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      noList == true
                          ? Center(
                              child: Text("No Data Found"),
                            )
                          : ListView.builder(
                              itemCount: data.length,
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                return DetailCard(
                                  data: data,
                                  index: index,
                                  radiocheck: radiocheck,
                                );
                              }),
                      data.isEmpty
                          ? SizedBox()
                          : stockreport == null
                              ? SizedBox()
                              : Container(
                                  child: NumberPaginator(
                                    initialPage: currentIndex,
                                    numberPages: stockreport!
                                        .payload.pagination.lastPage,
                                    onPageChange: (int index) {
                                      changeCurrentIndex(index);
                                      print("AAAAAA ${index}");
                                    },
                                  ),
                                )
                    ],
                  ),
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

  //ValueNotifier currentIndex = ValueNotifier(1);
  int currentIndex = 0;

  changeCurrentIndex(val) {
    setState(() {
      currentIndex = val;
    });

    getDate();
  }
}

class DetailCard extends StatelessWidget {
  final List<DatumStockWiseSale> data;
  final dynamic index;
  final dynamic radiocheck;

  DetailCard({required this.data, this.index, this.radiocheck});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.only(top: 5.0),
        child: GestureDetector(
          onTap: () {
            Get.to(() => ItemLedgerReportScreen(
                item: DatumItemList(
                    itemCd: data[index].itemCd,
                    itemName: data[index].itemName,
                    deptCd: data[index].deptment?.deptCd ?? "")));
          },
          child: Container(
            decoration: BoxDecoration(color: Colors.white),
            child: IgnorePointer(
              ignoring: true,
              child: ListTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: <Widget>[
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Item Name",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black),
                              ),
                              Text(
                                "${Helper.trimValue(data[index].itemName, 35)}",
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              )
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Dept Name",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                "${Helper.trimValue(data[index].deptment?.deptName ?? "", 15)}",
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Cl Stock",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  "${data[index].cStk ?? ""}",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                )
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${radiocheck == 1 ? "P.Rate" : radiocheck == 2 ? "S.Rate" : radiocheck == 3 ? "MRP" : "L.Rate"} ",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  "${data[index].rate}",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                )
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Total",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  "${Helper.parseNumericValue(data[index].totalValue.toString())}",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                )
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Batch",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  "${data[index].lastSize ?? ""}",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                )
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Exp Date",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  "${data[index].exDt ?? ""}",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
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
        ),
      ),
    );
  }
}
