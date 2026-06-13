//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/cartListModal.dart';
import 'package:arham_corporation/models/deptmentListModal.dart';
import 'package:arham_corporation/models/itemWisePartyWiseReportModal.dart';
import 'package:arham_corporation/models/narrationModal.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/cart_list_provider.dart';
import 'package:arham_corporation/providers/global.dart';
import 'package:arham_corporation/providers/item_list_provider.dart';
import 'package:arham_corporation/providers/party_provider.dart';
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

class ItemWisePartyWiseSaleReportView extends StatefulWidget {
  const ItemWisePartyWiseSaleReportView({Key? key}) : super(key: key);

  @override
  State<ItemWisePartyWiseSaleReportView> createState() =>
      _ItemWisePartyWiseSaleReportViewState();
}

class _ItemWisePartyWiseSaleReportViewState
    extends State<ItemWisePartyWiseSaleReportView> {
  List<DatumItemWisePartyWise> _originalData = [];
  List<DatumItemWisePartyWise> data = [];
  TextEditingController searchItemClt = TextEditingController();
  FocusNode _focusSearchNode = FocusNode();
  FocusNode _focusNode = FocusNode();
  List<DatumItemWisePartyWise> _tempItem = [];
  bool noList = true;

  List<DatumItemWisePartyWise> buildSearchList(
      String searchValue, List<DatumItemWisePartyWise> dataList) {
    return dataList.where((item) {
      return item.itemCd.toLowerCase().contains(searchValue.toLowerCase()) ||
          item.itemName.toLowerCase().contains(searchValue.toLowerCase());
    }).toList();
  }

// Call this method to search for data when the search input changes.
  void searchData1(String searchValue) {
    List<DatumItemWisePartyWise> filteredData =
        buildSearchList(searchValue, _tempItem);
    setState(() {
      // Update the UI with the filtered data.
      _tempItem = filteredData;
    });
  }

  void searchData(String searchValue) {
    if (searchValue.isEmpty) {
      // Reset the data if search is cleared
      setState(() {
        data = List.from(_originalData); // Show all data again
      });
    } else {
      // Filter the data based on search value
      setState(() {
        data = _originalData.where((item) {
          return item.itemCd
                  .toLowerCase()
                  .contains(searchValue.toLowerCase()) ||
              item.itemName.toLowerCase().contains(searchValue.toLowerCase());
        }).toList();
      });
    }
  }

  List<DatumItemWisePartyWiseDetail> detailData = [];
  bool detailDataLoading = false;

  TextEditingController fromdateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();

  DatumDeptment? selectedDeptment;

  double totalQty = 0.00;
  double totalAmt = 0.00;
  double totalFreeQty = 0.00;

  List<String> isCardItemLoading = [];

  List<TextEditingController> qty = [];
  List<TextEditingController> freeQty = [];
  List<DatumNarration> otherDescOptions = [];

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

  getOptions() {
    Services().getNarration(context, "OTHER_DESC").then((value) {
      setState(() {
        value!.forEach((e) => otherDescOptions.add(DatumNarration(
            NARR_NAME: e.NARR_NAME,
            NARR_TYPE: e.NARR_TYPE,
            SYNC_ID: e.SYNC_ID)));
      });
    });
  }

  getDate() {
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    setState(() {
      data.clear();
      expansionController.clear();
      totalAmt = 0.0;
      totalQty = 0.0;
      totalFreeQty = 0.0;
      noList = false;
      loading = true;
    });
    print(fromdateController.text);
    print(toDateController.text);

    Services()
        .getPartyWiseItemOrder(
            context,
            Helper.toApi(fromdateController.text),
            Helper.toApi(
              toDateController.text,
            ),
            party.partyid,
            selectedDeptment != null ? selectedDeptment!.deptCd : null)
        .then((value) {
      setState(() {
        if (value != null) {
          _originalData = value.data; // Store the original data
          data = List.from(
              _originalData); // Set the displayed data to the original
          //data.addAll(value.data);
          data.forEach((e) {
            expansionController.add(ExpansibleController());
            qty.add(TextEditingController(text: ""));
            freeQty.add(TextEditingController(text: ""));
          });
          if (value.data.isNotEmpty) {
            totalAmt = value.data
                .fold(
                    0.00,
                    (previousValue, element) =>
                        previousValue +
                        double.parse(element.vouchAmt.toString()))
                .toPrecision(2);
            totalFreeQty = value.data
                .fold(
                    0.00,
                    (previousValue, element) =>
                        previousValue +
                        double.parse(element.otherDesc == null
                            ? "0"
                            : element.otherDesc.toString()))
                .toPrecision(2);
            totalQty = value.data
                .fold(
                    0.00,
                    (previousValue, element) =>
                        previousValue + double.parse(element.qty.toString()))
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
    print(fromdateController.text);
    print(toDateController.text);

    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);

    Services()
        .getPartyWiseItemOrderDetailReport(
            context,
            Helper.toApi(fromdateController.text),
            Helper.toApi(
              toDateController.text,
            ),
            party.partyid,
            selectedDeptment != null ? selectedDeptment!.deptCd : "",
            itemCd)
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

  additemtoCart(itemCd, qty, freeQty, rate, remarks) {
    final CartListProvider cart =
        Provider.of<CartListProvider>(context, listen: false);
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    if (party.party == "") {
      //Fluttertoast.showToast(msg: "Please select party first");
      AppSnackBar.showGetXCustomSnackBar(message: "Please select party first");
    } else {
      setState(() {
        isCardItemLoading.add(itemCd);
      });
      Services()
          .addItemtoCartPartyWise(party.partyid, itemCd, qty.toString(),
              freeQty.toString(), context, rate.toString(), remarks)
          .then((value) {
        if (value != null && value['statusCode'] == 200) {
          cart.data.add(DatumCartList(itemCd: itemCd));
          cart.getCartItem(context, party.partyid);
        }
        isCardItemLoading =
            isCardItemLoading.where((element) => element != itemCd).toList();
        setState(() {});
        //Fluttertoast.showToast(msg: value['message']);
        if (value != null && value['statusCode'] == 200) {
          AppSnackBar.showGetXCustomSnackBar(
              message: value['message'], backgroundColor: Colors.green);
        } else {
          AppSnackBar.showGetXCustomSnackBar(message: value['message']);
        }
      });
    }
  }

  @override
  void dispose() {
    searchItemClt.dispose();
    _focusSearchNode.dispose();
    _focusNode.dispose();
    _1focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    var moduleEntryAccess = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "324",
          orElse: () => Modules(),
        ) ??
        Modules();

    if (moduleEntryAccess.mODULENO == "324") {
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
      print("Module with MODULE_NO '324' not found.");
    }

    _focusSearchNode.addListener(() {
      if (_focusSearchNode.hasFocus) {
        // When focus is gained, set selection to the end (so the cursor is at the end of the text)
        //searchClt.selection =
        //    TextSelection.collapsed(offset: searchClt.text.length);

        searchItemClt.selection = TextSelection(
            baseOffset: 0, extentOffset: searchItemClt.text.length);
      }
    });
    // fromdateController.text = Helper.getDefaultFromDate();
    // toDateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());

    fromdateController.text = Helper.toUi(Helper.getDefaultFromDate());
    toDateController.text =
        Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));

    getOptions();
    getItemWise();
    checkWhatsappInstalled();
    checkWhatsappBussinessInstalled();
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    if (party.partyid != '') {
      getDate();
    }
    super.initState();
    _focusNode.requestFocus();
    _1focusNode.requestFocus();
  }

  getItemWise() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemListProvider>().getItems(context);
      context.read<ItemListProvider>().getDeptment(context);
    });
  }

  List _tempDeptement = [];

  TextEditingController searchDeptmentCltt = TextEditingController();
  FocusNode _1focusNode = FocusNode();

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
                                          final PartyProvider party =
                                              Provider.of<PartyProvider>(
                                                  context,
                                                  listen: false);
                                          if (party.partyid != '') {
                                            setState(() {
                                              if (_tempDeptement.length > 0) {
                                                selectedDeptment =
                                                    _tempDeptement[index];
                                              } else {
                                                selectedDeptment =
                                                    item.dataDeptmant[index];
                                              }

                                              item.fillterListForPartyWiseSaleReport(
                                                  selectedDeptment!.deptCd);
                                            });
                                            getDate();
                                          } else {
                                            // Fluttertoast.showToast(
                                            //     msg: "Please select the party");
                                            AppSnackBar.showGetXCustomSnackBar(
                                                message:
                                                    "Please select the party");
                                          }
                                          Get.back();
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
                                    left: 20.0, bottom: 5.0, top: 20.0),
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
                                              setState(() {
                                                noList = true;
                                              });
                                              Get.back();
                                              if (party.party != "") {
                                                getDate();
                                              }
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
    final ItemListProvider item = context.watch<ItemListProvider>();
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    final CartListProvider cart = context.watch<CartListProvider>();
    final ProfileProvider profile =
        Provider.of<ProfileProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: "Party Wise Item Wise Order Report",
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
                            .getPartyWiseItemOrderExportFile(
                                context,
                                Helper.toApi(fromdateController.text),
                                Helper.toApi(toDateController.text),
                                party.partyid,
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
                                    "Party Wise Item Wise Order Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}"));
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
                            .getPartyWiseItemOrderExportFile(
                                context,
                                Helper.toApi(fromdateController.text),
                                Helper.toApi(toDateController.text),
                                party.partyid,
                                selectedDeptment != null
                                    ? selectedDeptment!.deptCd
                                    : null,
                                "excel")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Party Wise Item Wise Order Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                            .getPartyWiseItemOrderExportFile(
                                context,
                                Helper.toApi(fromdateController.text),
                                Helper.toApi(toDateController.text),
                                party.partyid,
                                selectedDeptment != null
                                    ? selectedDeptment!.deptCd
                                    : null,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Party Wise Item Wise Order Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
                            .getPartyWiseItemOrderExportFile(
                                context,
                                Helper.toApi(fromdateController.text),
                                Helper.toApi(toDateController.text),
                                party.partyid,
                                selectedDeptment != null
                                    ? selectedDeptment!.deptCd
                                    : null,
                                "pdf")
                            .then((value) {
                          if (value != null) {
                            Helper.saveFileAndroid(
                                    value,
                                    "Party Wise Item Wise Order Report${party.party != '' ? "_" + (party.party.toLowerCase().capitalize ?? "") : ""}_${DateFormat('dd-MM-yyyy').format(DateFormat("yyyy-MM-dd").parse(toDateController.text))}",
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
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Row(
                //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Text(
                          "Qty: ",
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
                          "Free Qty: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Flexible(
                          child: Text("${totalFreeQty}",
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
                                      setState(() {});
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
                              children: [
                                Text("Department Name"),
                                SizedBox(
                                  width: 15,
                                ),
                                GestureDetector(
                                    onTap: () {
                                      searchDeptmentCltt.clear();
                                      selectedDeptment = null;
                                      item.clearDepetmantforPartyWiseSalesReport();
                                      final PartyProvider party =
                                          Provider.of<PartyProvider>(context,
                                              listen: false);
                                      if (party.partyid != '') {
                                        getDate();
                                      } else {
                                        // Fluttertoast.showToast(
                                        //     msg: "Please select the Party");
                                        AppSnackBar.showGetXCustomSnackBar(
                                            message: "Please select the party");
                                      }
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 15,
                                    )),
                              ],
                            ),
                            SizedBox(
                              height: 5.h,
                            ),
                            GestureDetector(
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
                //                         // Fluttertoast.showToast(
                //                         //     msg: "Please Select the Party");
                //                         AppSnackBar.showGetXCustomSnackBar(
                //                             message: "Please select the party");
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
                //                 if (party.partyid != "") {
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
                //                 if (party.partyid != "") {
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
                              // prevent typing
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

                                        fromdateController.text = Helper.toUi(
                                            DateFormat("yyyy-MM-dd")
                                                .format(DateTime.now()));
                                      });
                                      getDate();
                                    } else {
                                      AppSnackBar.showGetXCustomSnackBar(
                                          message: "Please select the party");
                                    }
                                  },
                                  child: Tooltip(
                                    message: "Today",
                                    child: Icon(Icons.today_outlined),
                                  ),
                                ),
                              ),
                              onTap: () {
                                if (party.partyid != "") {
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

                                        fromdateController.text = Helper.toUi(
                                            DateFormat("yyyy-MM-dd")
                                                .format(date));
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
                                if (party.partyid != "") {
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
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CupertinoSearchTextField(
                    controller: searchItemClt,
                    focusNode: _focusSearchNode,
                    onChanged: (value) {
                      searchData(value); // Trigger search on every change
                    },
                    onSuffixTap: () {
                      _focusSearchNode.unfocus(); // Dismiss the keyboard
                      searchItemClt.clear(); // Clear the text field
                      setState(() {
                        data = List.from(_originalData); // Show all data again
                      });
                    },
                  ),
                ),
                Expanded(
                  child: party.party == ""
                      ? Center(
                          child: Text("Please Select Party"),
                        )
                      : noList == true
                          ? Center(
                              child: Text("No Data Found"),
                            )
                          : ListView.builder(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: data.length,
                              shrinkWrap: true,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 5.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: index % 2 == 0
                                            ? Colors.blueGrey.withOpacity(0.1)
                                            : Colors.transparent),
                                    child: Card(
                                      elevation: 2,
                                      child: ExpansionTile(
                                          //cart.data
                                          controller:
                                              expansionController[index],
                                          subtitle: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              // if (profile.data != null &&
                                              //     profile.data!.moduleNos
                                              //         .contains("205"))
                                              if (profile.data != null &&
                                                  profile.data!.modulesList!
                                                      .any((module) =>
                                                          module.mODULENO ==
                                                          "205"))
                                                isCardItemLoading.contains(
                                                        data[index].itemCd)
                                                    ? Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                EdgeInsets.all(
                                                                    12.0.w),
                                                            child: SizedBox(
                                                              height: 25.0,
                                                              width: 25.0,
                                                              child:
                                                                  CircularProgressIndicator(),
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : cart.data.any((element) =>
                                                            element.itemCd ==
                                                            data[index].itemCd)
                                                        ? Container()
                                                        : Row(
                                                            children: [
                                                              Expanded(
                                                                child: Container(
                                                                    child: TextFormField(
                                                                  keyboardType:
                                                                      TextInputType
                                                                          .number,
                                                                  decoration:
                                                                      InputDecoration(
                                                                    hintText:
                                                                        "Enter Qty",
                                                                    label: Text(
                                                                        "Enter Qty"),
                                                                    isDense:
                                                                        true,
                                                                  ),
                                                                  controller:
                                                                      qty[index],
                                                                )),
                                                              ),
                                                              SizedBox(
                                                                width: 10.w,
                                                              ),
                                                              Expanded(
                                                                child: Padding(
                                                                  padding: EdgeInsets
                                                                      .only(
                                                                          bottom:
                                                                              4.h),
                                                                  child: DropdownMenu<
                                                                      dynamic>(
                                                                    width: 90.w,
                                                                    controller:
                                                                        freeQty[
                                                                            index],
                                                                    requestFocusOnTap:
                                                                        true,
                                                                    enableFilter:
                                                                        true,
                                                                    label: const Text(
                                                                        'Free'),
                                                                    dropdownMenuEntries: otherDescOptions
                                                                        .map((e) => DropdownMenuEntry<dynamic>(
                                                                            value:
                                                                                e.NARR_NAME,
                                                                            label: e.NARR_NAME))
                                                                        .toList(),
                                                                    inputDecorationTheme:
                                                                        const InputDecorationTheme(
                                                                      isDense:
                                                                          true,
                                                                    ),
                                                                    enableSearch:
                                                                        true,
                                                                  ),
                                                                ),
                                                              ),
                                                              GestureDetector(
                                                                // onTap: () async {
                                                                //   // Get qty using setting logic
                                                                //   final itemQty =
                                                                //   _getItemQty(profile, qty[index]);
                                                                //
                                                                //   // ❌ If addtocartdef1 = N and qty empty → show message
                                                                //   if (itemQty.isEmpty) {
                                                                //     AppSnackBar.showGetXCustomSnackBar(
                                                                //         message: "Please Enter Quantity");
                                                                //     return;
                                                                //   }
                                                                //
                                                                //   additemtoCart(
                                                                //       data[index]
                                                                //           .itemCd,
                                                                //       qty[index].text ==
                                                                //           "" ||
                                                                //           qty[index].text ==
                                                                //               "0"
                                                                //           ? "1"
                                                                //           : qty[index]
                                                                //           .text,
                                                                //       freeQty[index]
                                                                //           .text,
                                                                //       data[index]
                                                                //           .rate,
                                                                //       "");
                                                                // },

                                                                onTap:
                                                                    () async {
                                                                  // Get qty using setting logic
                                                                  final itemQty =
                                                                      _getItemQty(
                                                                          profile,
                                                                          qty[index]);

                                                                  final freeText =
                                                                      freeQty[index]
                                                                          .text
                                                                          .trim();
                                                                  final qtyText =
                                                                      qty[index]
                                                                          .text
                                                                          .trim();

                                                                  final settingOn =
                                                                      _shouldShowQty1(
                                                                          profile);

                                                                  // ------------------------------
                                                                  // VALIDATION LOGIC
                                                                  // ------------------------------

                                                                  if (!settingOn) {
                                                                    // Setting OFF (addtocartdef1 = N)

                                                                    if (qtyText
                                                                            .isEmpty &&
                                                                        freeText
                                                                            .isEmpty) {
                                                                      AppSnackBar.showGetXCustomSnackBar(
                                                                          message:
                                                                              "Please Enter Quantity");
                                                                      return;
                                                                    }
                                                                  }

                                                                  // ------------------------------
                                                                  // FINAL QTY TO SEND
                                                                  // ------------------------------

                                                                  String
                                                                      finalQty;

                                                                  if (settingOn) {
                                                                    // Setting ON → qty = itemQty (returns "1" or user input)
                                                                    finalQty =
                                                                        itemQty;
                                                                  } else {
                                                                    // Setting OFF
                                                                    if (qtyText
                                                                            .isEmpty &&
                                                                        freeText
                                                                            .isNotEmpty) {
                                                                      finalQty =
                                                                          "0"; // freeQty entered but qty empty → qty = 0
                                                                    } else {
                                                                      finalQty = qtyText
                                                                              .isEmpty
                                                                          ? "0"
                                                                          : qtyText;
                                                                    }
                                                                  }

                                                                  // Call add to cart
                                                                  additemtoCart(
                                                                    data[index]
                                                                        .itemCd,
                                                                    finalQty,
                                                                    freeText,
                                                                    data[index]
                                                                        .rate,
                                                                    "",
                                                                  );
                                                                },

                                                                // onTap: () {
                                                                //   additemtoCart(
                                                                //       data[index]
                                                                //           .itemCd,
                                                                //       qty[index].text ==
                                                                //                   "" ||
                                                                //               qty[index].text ==
                                                                //                   "0"
                                                                //           ? "1"
                                                                //           : qty[index]
                                                                //               .text,
                                                                //       freeQty[index]
                                                                //           .text,
                                                                //       data[index]
                                                                //           .rate,
                                                                //       "");
                                                                // },
                                                                child:
                                                                    Container(
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color:
                                                                              Color(0xffFFAE37),
                                                                          borderRadius:
                                                                              BorderRadius.circular(8),
                                                                        ),
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            Icon(
                                                                              Icons.add_shopping_cart,
                                                                              size: 20,
                                                                              color: Colors.white,
                                                                            ),
                                                                            SizedBox(
                                                                              width: 3,
                                                                            ),
                                                                            Text(
                                                                              "Add",
                                                                              style: TextStyle(color: Colors.white, fontSize: 12),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        padding: EdgeInsets.only(
                                                                            left:
                                                                                8,
                                                                            right:
                                                                                8,
                                                                            top:
                                                                                8,
                                                                            bottom:
                                                                                8)),
                                                              ),
                                                            ],
                                                          )
                                            ],
                                          ),
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
                                                  SizedBox(
                                                    width: 110,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Dept Name",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.black),
                                                        ),
                                                        Text(
                                                          "${data[index].deptName}",
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                  // Expanded(
                                                  //   child: Column(
                                                  //     crossAxisAlignment:
                                                  //         CrossAxisAlignment
                                                  //             .start,
                                                  //     children: [
                                                  //       Text(
                                                  //         "Item Cd",
                                                  //         style: TextStyle(
                                                  //             fontSize: 12,
                                                  //             color:
                                                  //                 Colors.black),
                                                  //       ),
                                                  //       Text(
                                                  //         "${data[index].itemCd}",
                                                  //         style: TextStyle(
                                                  //             fontSize: 12,
                                                  //             color:
                                                  //                 Colors.grey),
                                                  //       )
                                                  //     ],
                                                  //   ),
                                                  // ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Item Name",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.black),
                                                        ),
                                                        Text(
                                                          "${data[index].itemName}",
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
                                              Row(
                                                children: [
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
                                                              color:
                                                                  Colors.black),
                                                        ),
                                                        Text(
                                                          "${data[index].qty}",
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
                                                    children: [
                                                      Text("Free",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .black)),
                                                      Text(
                                                        "${data[index].otherDesc}",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey),
                                                      )
                                                    ],
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                  )),
                                                  Expanded(
                                                      child: Column(
                                                    children: [
                                                      Text("Rate",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .black)),
                                                      Text(
                                                        "${Helper.parseNumericValue(data[index].rate.toString())}",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey),
                                                      )
                                                    ],
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                  )),
                                                  Expanded(
                                                      child: Column(
                                                    children: [
                                                      Text("Cl.Stk",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color: data[index]
                                                                          .cStk <=
                                                                      0
                                                                  ? Colors.red
                                                                  : Colors
                                                                      .green)),
                                                      Text(
                                                        "${data[index].cStk}",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: data[index]
                                                                        .cStk <=
                                                                    0
                                                                ? Colors.red
                                                                : Colors.green),
                                                      )
                                                    ],
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                  )),
                                                  Expanded(
                                                      child: Column(
                                                    children: [
                                                      Text("Amount",
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .black)),
                                                      Text(
                                                        "${Helper.parseNumericValue(data[index].vouchAmt.toString())}",
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey),
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
                                                expansionController[
                                                        openTileIndex]
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
                                                        Expanded(
                                                            child: Text(
                                                          "Book Cd",
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
                                                            child: Text(
                                                          "Vouch Date",
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
                                                              "Qty",
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      12.0),
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
                                                              "Free Qty",
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      12.0),
                                                            ),
                                                          ),
                                                        )),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
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
                                                                  fontSize:
                                                                      12.0),
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
                                                              "Amount",
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      12.0),
                                                            ),
                                                          ),
                                                        )),
                                                        Expanded(
                                                            child: Text("")),
                                                        Expanded(
                                                            child: Text("")),
                                                        Expanded(
                                                            child: Text(""))
                                                      ],
                                                    )
                                                  ],
                                                ),
                                                Padding(
                                                    padding: EdgeInsets.only(
                                                        top: 8.0),
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
                                                                      child:
                                                                          Text(
                                                                    "${detailData[index].bookCd}",
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .grey,
                                                                        fontSize:
                                                                            12.0),
                                                                  )),
                                                                  Expanded(
                                                                      child:
                                                                          Text(
                                                                    "${detailData[index].refNo}",
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .grey,
                                                                        fontSize:
                                                                            12.0),
                                                                  )),
                                                                  Expanded(
                                                                      child:
                                                                          Text(
                                                                    Helper.toUi(
                                                                        "${detailData[index].vouchDt}"),
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .grey,
                                                                        fontSize:
                                                                            12.0),
                                                                  )),
                                                                  Expanded(
                                                                      child:
                                                                          Align(
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
                                                                  )),
                                                                  Expanded(
                                                                      child:
                                                                          Text(
                                                                    "${detailData[index].otherDesc}",
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
                                                                      child:
                                                                          Padding(
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        right:
                                                                            15.0),
                                                                    child:
                                                                        Align(
                                                                      alignment:
                                                                          Alignment
                                                                              .centerRight,
                                                                      child:
                                                                          Text(
                                                                        "${Helper.parseNumericValue(detailData[index].rate.toString())}",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Colors.grey,
                                                                            fontSize: 12.0),
                                                                      ),
                                                                    ),
                                                                  )),
                                                                  Expanded(
                                                                      child:
                                                                          Padding(
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        right:
                                                                            15.0),
                                                                    child:
                                                                        Align(
                                                                      alignment:
                                                                          Alignment
                                                                              .centerRight,
                                                                      child:
                                                                          Text(
                                                                        "${Helper.parseNumericValue(detailData[index].vouchAmt.toString())}",
                                                                        style: TextStyle(
                                                                            color:
                                                                                Colors.grey,
                                                                            fontSize: 12.0),
                                                                      ),
                                                                    ),
                                                                  )),
                                                                  Expanded(
                                                                      child: Text(
                                                                          "")),
                                                                  Expanded(
                                                                      child: Text(
                                                                          "")),
                                                                  Expanded(
                                                                      child: Text(
                                                                          ""))
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

  String _getItemQty(
      ProfileProvider profile, TextEditingController qtyController) {
    final useDefaultQty =
        _shouldShowQty1(profile); // true when addtocartdef1 = ‘Y’

    print('defult qty setting $useDefaultQty');

    final qtyText = qtyController.text.trim();

    if (qtyText.isEmpty) {
      if (useDefaultQty) {
        print('call qty 1');
        return "1"; // Default Qty = 1
      } else {
        print('call qty empty');
        return ""; // Return empty → we will handle validation
      }
    }

    return qtyText; // User entered qty
  }

  bool _shouldShowQty1(ProfileProvider profile) {
    return profile.data?.profileSettings.any((element) =>
            element.variable == 'addtocartdef1' && element.value == 'Y') ??
        false;
  }
}
