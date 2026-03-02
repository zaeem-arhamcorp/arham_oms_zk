import 'dart:convert';

import 'package:arham_corporation/models/receipt_confim_model.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/item_list_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../helper/helper.dart';
import '../models/accountLeagerReportModal.dart';
import '../providers/party_provider.dart';
import '../providers/user_provider.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class ReceivableReportReceiptPage extends StatefulWidget {
  @override
  _ReceivableReportReceiptPageState createState() =>
      _ReceivableReportReceiptPageState();
}

class _ReceivableReportReceiptPageState
    extends State<ReceivableReportReceiptPage> {
  bool isLoading = true; // Indicates loading state

  bool quickSaveEnabled = false;
  List<Data> selectedPurchases = [];
  List<Map<String, dynamic>> billwise = [];

  // Toggle purchase selection
  void togglePurchaseSelection(bool selected, Data purchase) {
    setState(() {
      if (selected) {
        selectedPurchases.add(purchase);
        billwise = selectedPurchases.map((data) {
          return {
            "vouchNo": data.vOUCHNO,
          };
        }).toList();
      } else {
        selectedPurchases.remove(purchase);
        billwise = selectedPurchases.map((data) {
          return {
            "vouchNo": data.vOUCHNO,
          };
        }).toList();
      }
    });
  }

  final TextEditingController searchPartyClt = TextEditingController();
  final List _tempParty = [];
  bool isPartySelected = false;

  // Function to open the bottom sheet and handle selection
  void showPartySelectionMenu(BuildContext context) {
    //searchPartyClt.clear();
    //_tempParty.clear();
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    pp.getpartyname(context); // API call to fetch party data

    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: Consumer<PartyProvider>(
            builder: (context, party, child) {
              return StatefulBuilder(
                builder: (context, StateSetter setState) {
                  return Padding(
                    padding: MediaQuery.of(context).viewInsets,
                    child: Container(
                      height: 450,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 20.0, bottom: 14.0, top: 20.0),
                            child: Text(
                              "Select Party:",
                              style: TextStyle(
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8),
                            ),
                          ),
                          // Search Field
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CupertinoSearchTextField(
                              controller: searchPartyClt,
                              onChanged: (value) {
                                setState(() {
                                  _tempParty.clear();
                                  _tempParty.addAll(
                                      Helper.buildSearchList(value, party));
                                });
                              },
                            ),
                          ),
                          // List of parties
                          Expanded(
                            child: party.nolistParty
                                ? Center(child: Text("No List"))
                                : party.data.isEmpty
                                    ? Center(child: CircularProgressIndicator())
                                    : ListView.builder(
                                        itemCount: _tempParty.isNotEmpty
                                            ? _tempParty.length
                                            : party.data.length,
                                        itemBuilder: (context, index) {
                                          var selectedParty =
                                              _tempParty.isNotEmpty
                                                  ? _tempParty[index]
                                                  : party.data[index];
                                          return InkWell(
                                            onTap: () async {
                                              await party.changeParty(
                                                selectedParty.accName,
                                                selectedParty.accCd,
                                                context,
                                              );
                                              setState(() {
                                                isPartySelected = true;
                                                quickSaveEnabled = false;
                                                selectedPurchases.clear();
                                                getConfirmReceivableEntry();
                                                // Reset any related state
                                                // For example:
                                                // data.clear();
                                                // vouchAmtTotal = 0.00;
                                                // paidAmtTotal = 0.00;
                                                // osAmtTotal = 0.00;
                                              });
                                              Get.back();
                                            },
                                            child: ListTile(
                                              leading: Text("${index + 1}"),
                                              title: Text(
                                                "(${selectedParty.accCd}) ${selectedParty.accName} ${selectedParty.person_nm != null ? " - " + selectedParty.person_nm : ""}",
                                                style: TextStyle(
                                                    fontSize: 15.0,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              subtitle: RichText(
                                                text: TextSpan(
                                                  text:
                                                      "${selectedParty.accAddress} || ${selectedParty.mobile}",
                                                  style: TextStyle(
                                                      color: Colors.black),
                                                  children: selectedParty
                                                              .accCartItem !=
                                                          null
                                                      ? [
                                                          TextSpan(
                                                            text:
                                                                " || ${selectedParty.accCartItem}",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .amber),
                                                          )
                                                        ]
                                                      : [],
                                                ),
                                              ),
                                              dense: true,
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  List<Data> data = [];
  bool noList = false;
  bool loading = false;

  List<ExpansibleController> expansionController = [];
  int openTileIndex = -1;
  bool detailDataLoading = false;
  List<Detail> detailData = [];

  final TextEditingController fromdateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  bool isValid = false;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  TextEditingController searchOpUsersClt = TextEditingController();
  List _tempOpUsers = [];
  var selectedOpUsers;

  bool deleteRights = false;
  bool readRights = false;

  showMenuOpUsers() {
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
                            child: Text("Select User:",
                                style: TextStyle(
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CupertinoSearchTextField(
                                controller: searchOpUsersClt,
                                onChanged: (value) {
                                  //4
                                  setStatee(() {
                                    _tempOpUsers =
                                        _buildSearchListOpUsers(value, item);
                                  });
                                }),
                          ),
                        ],
                      ),
                      Expanded(
                        child: item.noOpUsers == true
                            ? Center(
                                child: Text("No User List"),
                              )
                            : item.dataOpUsers.isEmpty
                                ? Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ListView.builder(
                                    itemCount: (_tempOpUsers.length > 0)
                                        ? _tempOpUsers.length
                                        : item.dataOpUsers.length,
                                    itemBuilder: (builder, index) {
                                      return InkWell(
                                        onTap: () async {
                                          // final PartyProvider party =
                                          //     Provider.of<PartyProvider>(context,
                                          //         listen: false);
                                          // party.clearParty();

                                          setState(() {
                                            selectedOpUsers = null;
                                            if (_tempOpUsers.length > 0) {
                                              selectedOpUsers =
                                                  _tempOpUsers[index];
                                            } else {
                                              selectedOpUsers =
                                                  item.dataOpUsers[index];
                                            }
                                          });
                                          Get.back();
                                          getConfirmReceivableEntry();
                                        },
                                        child: (_tempOpUsers.length > 0)
                                            ? _showBottomSheetWithSearchOpUsers(
                                                index, _tempOpUsers)
                                            : _showBottomSheetWithSearchOpUsers(
                                                index, item.dataOpUsers),
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

  Widget _showBottomSheetWithSearchOpUsers(int index, List listOfParty) {
    return ListTile(
      leading: Text("${index + 1}"),
      title: Text(
          "${listOfParty[index].userName} - ${listOfParty[index].userCd}",
          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
      dense: true,
    );
  }

  List _buildSearchListOpUsers(String userSearchTerm, ItemListProvider item) {
    List _searchList = [];
    for (int i = 0; i < item.dataOpUsers.length; i++) {
      String name = item.dataOpUsers[i].userName;
      String userCd = item.dataOpUsers[i].userCd;
      if (name.toLowerCase().contains(userSearchTerm.toLowerCase()) ||
          userCd.toLowerCase().contains(userSearchTerm.toLowerCase())) {
        _searchList.add(item.dataOpUsers[i]);
      }
    }
    return _searchList;
  }

  getFilterData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemListProvider>().getOpUsers(context);
    });
  }

  getConfirmReceivableEntry() {
    setState(() {
      data.clear();
      expansionController.clear();
      noList = false;
      loading = true;
    });

    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    Services()
        .getReceiptReceivableConfirm(
      context,
      Helper.toApi(fromdateController.text),
      Helper.toApi(toDateController.text),
      '',
      party.partyid,
      //p.data?.userType == 'M' ? '' : p.data?.userCd,
      p.data?.userType == 'M'
          ? selectedOpUsers != null
              ? selectedOpUsers!.userCd
              : null
          : p.data?.userCd,
    )
        .then((value) {
      setState(() {
        if (value != null) {
          data.addAll(value.data as Iterable<Data>);
          data.forEach((e) => expansionController.add(ExpansibleController()));

          print(data);

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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    deleteRights = Get.arguments['DeleteRight'];
    readRights = Get.arguments['ReadRight'];

    getFilterData();
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    // fromdateController.text = Helper.getDefaultFromDate();
    // toDateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());
    fromdateController.text = Helper.toUi(Helper.getDefaultFromDate());
    toDateController.text =
        Helper.toUi(DateFormat("yyyy-MM-dd").format(DateTime.now()));
    if (party.partyid != "") {
      isPartySelected = true;
      getConfirmReceivableEntry();
    } else {
      getConfirmReceivableEntry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    return WillPopScope(
      onWillPop: () async {
        Get.back(result: true); // This will send 'true' as a result
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        appBar: CustomAppBar(
          title: 'Receipt Report',
        ),
        body: SafeArea(
          child: Builder(
            builder: (context) => Column(
              children: [
                // Supplier details container
                Visibility(
                  visible: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Displaying selected party
                        Text(
                            'Party: ${Helper.trimValue(Provider.of<PartyProvider>(context).party, 24)} '),
                        Row(
                          children: [
                            // Change button to open the menu
                            TextButton(
                                onPressed: () =>
                                    showPartySelectionMenu(context),
                                child: Text("Change")),
                            SizedBox(width: 2.0),
                            // Close button
                            GestureDetector(
                              onTap: () {
                                final party = Provider.of<PartyProvider>(
                                    context,
                                    listen: false);
                                party.clearParty();
                                setState(() {
                                  isPartySelected = false;
                                  data.clear();
                                  quickSaveEnabled = false;
                                  selectedPurchases.clear();
                                });

                                getConfirmReceivableEntry();
                              },
                              child: Icon(Icons.close, size: 18),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                Visibility(
                  visible: p.data?.userType == 'M',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("Users"),
                        SizedBox(
                          width: 15,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: showMenuOpUsers,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(5)),
                              child: Text(
                                  "${selectedOpUsers == null ? "Select Users" : Helper.trimValue(selectedOpUsers!.userCd, 20)}"),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 15,
                        ),
                        GestureDetector(
                            onTap: () {
                              setState(() {
                                searchOpUsersClt.clear();
                                selectedOpUsers = null;
                              });
                              getConfirmReceivableEntry();
                            },
                            child: Icon(
                              Icons.close,
                              size: 15,
                            )),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 10,
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
                //                       setState(() {
                //                         fromdateController.text =
                //                             DateFormat("yyyy-MM-dd")
                //                                 .format(DateTime.now());
                //                       });
                //                       getConfirmReceivableEntry();
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
                //                 getConfirmReceivableEntry();
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
                //                 getConfirmReceivableEntry();
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
                              // prevent keyboard
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 10.0, horizontal: 5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                hintText: "Select date",
                                suffixIcon: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      fromdateController.text = Helper.toUi(
                                          DateFormat("yyyy-MM-dd")
                                              .format(DateTime.now()));

                                      // fromdateController.text =
                                      //     DateFormat("yyyy-MM-dd")
                                      //         .format(DateTime.now());
                                    });
                                    getConfirmReceivableEntry();
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
                                      fromdateController.text = Helper.toUi(
                                          DateFormat("yyyy-MM-dd")
                                              .format(date));

                                      // fromdateController.text =
                                      //     DateFormat("yyyy-MM-dd").format(date);
                                    });
                                    getConfirmReceivableEntry();
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
                                    getConfirmReceivableEntry();
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
                SizedBox(
                  height: 10,
                ),
                loading
                    ? Expanded(
                        child: Center(child: CircularProgressIndicator()))
                    : Visibility(
                        //visible: isPartySelected,
                        visible: true,
                        child: data.isEmpty
                            ? Expanded(
                                child: Center(
                                  child: Text("No Data Found"),
                                ),
                              )
                            : Expanded(
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                          itemCount: data.length,
                                          shrinkWrap: true,
                                          itemBuilder: (context, index) {
                                            final invoice = data[index];
                                            return Row(
                                              children: [
                                                Visibility(
                                                  visible: false,
                                                  child: Checkbox(
                                                    activeColor:
                                                        Color(0XFF2c9ed9),
                                                    value: selectedPurchases
                                                        .contains(invoice),
                                                    onChanged: (value) {
                                                      togglePurchaseSelection(
                                                          value!, invoice);
                                                    },
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 5.0),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                          color: index % 2 == 0
                                                              ? Colors.blueGrey
                                                                  .withOpacity(
                                                                      0.1)
                                                              : Colors
                                                                  .transparent),
                                                      child: ExpansionTile(
                                                          controller:
                                                              expansionController[
                                                                  index],
                                                          expandedAlignment:
                                                              Alignment.topLeft,
                                                          childrenPadding:
                                                              EdgeInsets.only(
                                                                  left: 20,
                                                                  right: 20,
                                                                  top: 15,
                                                                  bottom: 15),
                                                          title: Column(
                                                            children: [
                                                              Row(
                                                                children: <Widget>[
                                                                  Expanded(
                                                                    child:
                                                                        Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                          "Date",
                                                                          style: TextStyle(
                                                                              fontSize: 12,
                                                                              color: Colors.black),
                                                                        ),
                                                                        Text(
                                                                          Helper.toUi(
                                                                              "${data[index].vOUCHDT}"),
                                                                          style: TextStyle(
                                                                              fontSize: 12,
                                                                              color: Colors.grey),
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  Expanded(
                                                                    flex: 3,
                                                                    child:
                                                                        Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                          "Acc Name",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.black,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          "${data[index].party?.aCCNAME ?? ''}",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            // color: (data[index].iSVALID ?? false)
                                                                            //     ? Colors.grey
                                                                            //     : Colors.red,
                                                                            color: ((data[index].iSVALID ?? 0) == 1)
                                                                                ? Colors.grey
                                                                                : Colors.red,
                                                                          ),
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        top:
                                                                            10.0),
                                                                child: Row(
                                                                  children: <Widget>[
                                                                    Expanded(
                                                                      child:
                                                                          Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            "Book Cd",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 12,
                                                                              color: Colors.black,
                                                                            ),
                                                                          ),
                                                                          Text(
                                                                            "${data[index].bOOKCD}",
                                                                            style:
                                                                                TextStyle(fontSize: 12, color: Colors.grey),
                                                                          )
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    Expanded(
                                                                      child:
                                                                          Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            "Vouch No",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 12,
                                                                              color: Colors.black,
                                                                            ),
                                                                          ),
                                                                          Text(
                                                                            "${data[index].vOUCHNO ?? ""}",
                                                                            style:
                                                                                TextStyle(fontSize: 12, color: Colors.grey),
                                                                          )
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    Expanded(
                                                                      child:
                                                                          Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            "Narration",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 12,
                                                                              color: Colors.black,
                                                                            ),
                                                                          ),
                                                                          Text(
                                                                            "${data[index].nARRATION ?? ""}",
                                                                            style:
                                                                                TextStyle(fontSize: 12, color: Colors.grey),
                                                                          )
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    Expanded(
                                                                      child:
                                                                          Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          // Text(
                                                                          //   "Bill Amt",
                                                                          //   style:
                                                                          //       TextStyle(
                                                                          //     fontSize:
                                                                          //         12,
                                                                          //     color:
                                                                          //         Colors.black,
                                                                          //   ),
                                                                          // ),
                                                                          Text(
                                                                            "Amt",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 12,
                                                                              color: Colors.black,
                                                                            ),
                                                                          ),
                                                                          Text(
                                                                            "${Helper.parseNumericValue(data[index].aMOUNT.toString())}",
                                                                            style:
                                                                                TextStyle(fontSize: 12, color: Colors.grey),
                                                                          )
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        top:
                                                                            10.0),
                                                                child: Row(
                                                                  children: <Widget>[
                                                                    Expanded(
                                                                      child:
                                                                          Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            "Type",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 12,
                                                                              color: Colors.black,
                                                                            ),
                                                                          ),
                                                                          Text(
                                                                            data[index].billwiseSettlements!.isEmpty
                                                                                ? 'On Account'
                                                                                : 'BillWise',
                                                                            style:
                                                                                TextStyle(fontSize: 12, color: Colors.grey),
                                                                          )
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    Expanded(
                                                                      child:
                                                                          Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            "Cash/Bank Party",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 12,
                                                                              color: Colors.black,
                                                                            ),
                                                                          ),
                                                                          Text(
                                                                            "${data[index].cshbnkParty?.aCCNAME ?? ""}",
                                                                            style:
                                                                                TextStyle(fontSize: 12, color: Colors.grey),
                                                                          )
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          onExpansionChanged:
                                                              (val) {
                                                            setState(() {
                                                              if (openTileIndex !=
                                                                      -1 &&
                                                                  openTileIndex !=
                                                                      index) {
                                                                expansionController[
                                                                        openTileIndex]
                                                                    .collapse();
                                                              }
                                                              openTileIndex =
                                                                  index;
                                                            });
                                                          },
                                                          children: [
                                                            /*if (detailDataLoading ==
                                                                true)
                                                              Text("Loading....")
                                                            else*/
                                                            if (data[index].bOOKCD == "RC" ||
                                                                data[index]
                                                                        .bOOKCD ==
                                                                    "PY" ||
                                                                data[index]
                                                                        .bOOKCD ==
                                                                    "IC" ||
                                                                data[index]
                                                                        .bOOKCD ==
                                                                    "EP")
                                                              data[index]
                                                                      .billwiseSettlements!
                                                                      .isNotEmpty
                                                                  ? Column(
                                                                      children: [
                                                                          Column(
                                                                            children: [
                                                                              Row(
                                                                                children: [
                                                                                  // Expanded(
                                                                                  //     child: Text(
                                                                                  //   "Book Cd",
                                                                                  //   style: TextStyle(fontSize: 12.0),
                                                                                  // )),
                                                                                  Text(
                                                                                    "Book",
                                                                                    style: TextStyle(fontSize: 12.0),
                                                                                  ),
                                                                                  SizedBox(
                                                                                    width: 5,
                                                                                  ),
                                                                                  Expanded(
                                                                                      child: Text(
                                                                                    "Vouch Dt",
                                                                                    style: TextStyle(fontSize: 12.0),
                                                                                  )),
                                                                                  Expanded(
                                                                                      child: Text(
                                                                                    "Bill No",
                                                                                    style: TextStyle(fontSize: 12.0),
                                                                                  )),
                                                                                  Expanded(
                                                                                      child: Text(
                                                                                    "Bill Amt",
                                                                                    style: TextStyle(fontSize: 12.0),
                                                                                  )),
                                                                                  Expanded(
                                                                                      child: Text(
                                                                                    "Bill Paid Amt",
                                                                                    style: TextStyle(fontSize: 12.0),
                                                                                  )),
                                                                                ],
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          Padding(
                                                                            padding:
                                                                                EdgeInsets.only(top: 8.0),
                                                                            child:
                                                                                ListView.builder(
                                                                              physics: NeverScrollableScrollPhysics(),
                                                                              itemCount: data[index].billwiseSettlements!.length,
                                                                              // Length of the inner billwiseSettlements list
                                                                              shrinkWrap: true,
                                                                              itemBuilder: (context, innerIndex) {
                                                                                var settlement = data[index].billwiseSettlements![innerIndex];
                                                                                return Row(
                                                                                  children: [
                                                                                    // Expanded(
                                                                                    //   child: Text(
                                                                                    //     "${settlement.bLBOOKCD}",
                                                                                    //     style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                    //   ),
                                                                                    // ),
                                                                                    Text(
                                                                                      "${settlement.bLBOOKCD}",
                                                                                      style: TextStyle(
                                                                                        color: Colors.grey,
                                                                                        fontSize: 12.0,
                                                                                      ),
                                                                                    ),
                                                                                    SizedBox(
                                                                                      width: 5,
                                                                                    ),
                                                                                    Expanded(
                                                                                      child: Text(
                                                                                        Helper.toUi("${settlement.bLVDT}"),
                                                                                        style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                      ),
                                                                                    ),
                                                                                    Expanded(
                                                                                      child: Text(
                                                                                        "${settlement.bLBILLNO}",
                                                                                        style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                      ),
                                                                                    ),
                                                                                    Expanded(
                                                                                      child: Text(
                                                                                        "${Helper.parseNumericValue(settlement.bLAMOUNT.toString())}",
                                                                                        style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                      ),
                                                                                    ),
                                                                                    Expanded(
                                                                                      child: Text(
                                                                                        "${Helper.parseNumericValue(settlement.bLPAID.toString())}",
                                                                                        style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                );
                                                                              },
                                                                            ),
                                                                          )
                                                                        ])
                                                                  : SizedBox
                                                                      .shrink(),

                                                            Visibility(
                                                              visible: true,
                                                              child: Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                // Vertical alignment
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                // Horizontal alignment
                                                                children: [
                                                                  Visibility(
                                                                    visible:
                                                                        false,
                                                                    child:
                                                                        Expanded(
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            10.0),
                                                                        child:
                                                                            ElevatedButton(
                                                                          onPressed:
                                                                              () {
                                                                            /*Services().receiptPaymentValidateAPI(
                                                                                context,
                                                                                data[index].vOUCHNO.toString(),
                                                                                data[index].bOOKCD.toString(),
                                                                                []).then((value) {
                                                                              setState(
                                                                                  () {
                                                                                getConfirmReceivableEntry();
                                                                              });
                                                                            });*/
                                                                          },
                                                                          child:
                                                                              Text(
                                                                            'Validate',
                                                                            style:
                                                                                TextStyle(color: Colors.white),
                                                                          ),
                                                                          style:
                                                                              ElevatedButton.styleFrom(
                                                                            minimumSize:
                                                                                Size(double.infinity, 50),
                                                                            backgroundColor:
                                                                                Color(0XFF2c9ed9),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Visibility(
                                                                    //visible: !data[index].iSVALID! && deleteRights && p.data?.userType == 'M',
                                                                    visible: deleteRights &&
                                                                        (p.data?.userType == 'M' ||
                                                                            //(!data[index].iSVALID! &&
                                                                            (data[index].iSVALID != 1 && readRights)),
                                                                    child:
                                                                        SizedBox(
                                                                      height:
                                                                          25,
                                                                      child:
                                                                          IconButton(
                                                                        highlightColor:
                                                                            Colors.transparent,
                                                                        // No highlight color
                                                                        splashColor:
                                                                            Colors.transparent,
                                                                        // No splash effect
                                                                        color: Colors
                                                                            .red,
                                                                        // Icon color
                                                                        icon: Icon(
                                                                            Icons.delete),
                                                                        onPressed:
                                                                            () {
                                                                          showDialog(
                                                                            context:
                                                                                context,
                                                                            builder:
                                                                                (BuildContext context) {
                                                                              return AlertDialog(
                                                                                title: Text('Delete Confirmation'),
                                                                                content: Text('Are you sure you want to delete receipt report? - ${data[index].vOUCHNO.toString()}'),
                                                                                actions: [
                                                                                  TextButton(
                                                                                    onPressed: () {
                                                                                      // Cancel button: Close the dialog
                                                                                      Get.back();
                                                                                    },
                                                                                    child: Text('No'),
                                                                                  ),
                                                                                  TextButton(
                                                                                    onPressed: () {
                                                                                      // Confirm logout
                                                                                      deleteReceivableConfirm(context, data[index].vOUCHNO.toString());
                                                                                    },
                                                                                    child: Text('Yes'),
                                                                                  ),
                                                                                ],
                                                                              );
                                                                            },
                                                                          );
                                                                        },
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),

                                                            // else
                                                            //   Column(children: [
                                                            //     Column(
                                                            //       children: [
                                                            //         Row(
                                                            //           children: [
                                                            //             Expanded(
                                                            //                 child:
                                                            //                     Text(
                                                            //               "Item Cd",
                                                            //               style: TextStyle(
                                                            //                   fontSize:
                                                            //                       12.0),
                                                            //             )),
                                                            //             Expanded(
                                                            //                 flex: 4,
                                                            //                 child:
                                                            //                     Text(
                                                            //                   "Item Name",
                                                            //                   style:
                                                            //                       TextStyle(fontSize: 12.0),
                                                            //                 )),
                                                            //           ],
                                                            //         ),
                                                            //         Row(
                                                            //           children: [
                                                            //             Expanded(
                                                            //                 child:
                                                            //                     Text(
                                                            //               "Size Cd",
                                                            //               style: TextStyle(
                                                            //                   fontSize:
                                                            //                       12.0),
                                                            //             )),
                                                            //             Expanded(
                                                            //                 child:
                                                            //                     Padding(
                                                            //               padding: const EdgeInsets
                                                            //                       .only(
                                                            //                   right:
                                                            //                       15.0),
                                                            //               child:
                                                            //                   Align(
                                                            //                 alignment:
                                                            //                     Alignment.centerRight,
                                                            //                 child:
                                                            //                     Text(
                                                            //                   "Quantity",
                                                            //                   style:
                                                            //                       TextStyle(fontSize: 12.0),
                                                            //                 ),
                                                            //               ),
                                                            //             )),
                                                            //             Expanded(
                                                            //                 child:
                                                            //                     Text(
                                                            //               "Free Qty",
                                                            //               style: TextStyle(
                                                            //                   fontSize:
                                                            //                       12.0),
                                                            //             )),
                                                            //             Expanded(
                                                            //                 child:
                                                            //                     Padding(
                                                            //               padding: const EdgeInsets
                                                            //                       .only(
                                                            //                   right:
                                                            //                       15.0),
                                                            //               child:
                                                            //                   Align(
                                                            //                 alignment:
                                                            //                     Alignment.centerRight,
                                                            //                 child:
                                                            //                     Text(
                                                            //                   "Rate",
                                                            //                   style:
                                                            //                       TextStyle(fontSize: 12.0),
                                                            //                 ),
                                                            //               ),
                                                            //             )),
                                                            //             Expanded(
                                                            //                 child:
                                                            //                     Padding(
                                                            //               padding: const EdgeInsets
                                                            //                       .only(
                                                            //                   right:
                                                            //                       15.0),
                                                            //               child:
                                                            //                   Align(
                                                            //                 alignment:
                                                            //                     Alignment.centerRight,
                                                            //                 child:
                                                            //                     Text(
                                                            //                   "Vouch Amt",
                                                            //                   style:
                                                            //                       TextStyle(fontSize: 12.0),
                                                            //                 ),
                                                            //               ),
                                                            //             )),
                                                            //           ],
                                                            //         )
                                                            //       ],
                                                            //     ),
                                                            //     Visibility(
                                                            //       visible: false,
                                                            //       child: Padding(
                                                            //           padding: EdgeInsets
                                                            //               .only(
                                                            //                   top:
                                                            //                       8.0),
                                                            //           child: ListView
                                                            //               .builder(
                                                            //                   physics:
                                                            //                       NeverScrollableScrollPhysics(),
                                                            //                   itemCount: detailData
                                                            //                       .length,
                                                            //                   shrinkWrap:
                                                            //                       true,
                                                            //                   itemBuilder:
                                                            //                       (context, index) {
                                                            //                     return Column(
                                                            //                       crossAxisAlignment: CrossAxisAlignment.start,
                                                            //                       children: [
                                                            //                         Row(
                                                            //                           children: [
                                                            //                             Expanded(
                                                            //                                 child: Text(
                                                            //                               "${detailData[index].itemCd}",
                                                            //                               style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                            //                             )),
                                                            //                             Expanded(
                                                            //                                 flex: 4,
                                                            //                                 child: Text(
                                                            //                                   "${detailData[index].item.itemName}",
                                                            //                                   style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                            //                                 )),
                                                            //                           ],
                                                            //                         ),
                                                            //                         Row(
                                                            //                           children: [
                                                            //                             Expanded(
                                                            //                                 child: Text(
                                                            //                               "${detailData[index].sizeCd}",
                                                            //                               style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                            //                             )),
                                                            //                             Expanded(
                                                            //                                 child: Padding(
                                                            //                               padding: const EdgeInsets.only(right: 15.0),
                                                            //                               child: Align(
                                                            //                                 alignment: Alignment.centerRight,
                                                            //                                 child: Text(
                                                            //                                   "${detailData[index].qty}",
                                                            //                                   style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                            //                                 ),
                                                            //                               ),
                                                            //                             )),
                                                            //                             Expanded(
                                                            //                                 child: Text(
                                                            //                               "${detailData[index].otherDesc}",
                                                            //                               style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                            //                             )),
                                                            //                             Expanded(
                                                            //                                 child: Padding(
                                                            //                               padding: const EdgeInsets.only(right: 15.0),
                                                            //                               child: Align(
                                                            //                                 alignment: Alignment.centerRight,
                                                            //                                 child: Text(
                                                            //                                   "${Helper.parseNumericeValue(detailData[index].rate.toString())}",
                                                            //                                   style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                            //                                 ),
                                                            //                               ),
                                                            //                             )),
                                                            //                             Expanded(
                                                            //                                 child: Padding(
                                                            //                               padding: const EdgeInsets.only(right: 15.0),
                                                            //                               child: Align(
                                                            //                                 alignment: Alignment.centerRight,
                                                            //                                 child: Text(
                                                            //                                   "${Helper.parseNumericeValue(detailData[index].vouchAmt.toString())}",
                                                            //                                   style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                            //                                 ),
                                                            //                               ),
                                                            //                             )),
                                                            //                           ],
                                                            //                         ),
                                                            //                         SizedBox(
                                                            //                           height: 7.0,
                                                            //                         ),
                                                            //                       ],
                                                            //                     );
                                                            //                   })),
                                                            //     ),
                                                            //     SizedBox(
                                                            //       height: 25,
                                                            //       child: IconButton(
                                                            //         highlightColor:
                                                            //             Colors
                                                            //                 .transparent,
                                                            //         // No highlight color
                                                            //         splashColor: Colors
                                                            //             .transparent,
                                                            //         // No splash effect
                                                            //         color:
                                                            //             Colors.red,
                                                            //         // Icon color
                                                            //         icon: Icon(Icons
                                                            //             .delete),
                                                            //         onPressed: () {
                                                            //           print(
                                                            //               'delete api call & get api list');
                                                            //         },
                                                            //       ),
                                                            //     ),
                                                            //   ]),
                                                          ]),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }),
                                    ),
                                    if (selectedPurchases.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Services()
                                                .receiptPaymentValidateAPI(
                                                    context, billwise)
                                                .then((value) {
                                              setState(() {
                                                selectedPurchases.clear();
                                                getConfirmReceivableEntry();
                                              });
                                            });
                                          },
                                          child: Text(
                                            'Save',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            minimumSize:
                                                Size(double.infinity, 50),
                                            backgroundColor: Color(0XFF2c9ed9),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> deleteReceivableConfirm(
      BuildContext context, String vouchNo) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    try {
      String url = '${AppConfig.baseURL}receipt-entry/$vouchNo';

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Fluttertoast.showToast(
        //     msg: "Receipt Confirm Entry deleted successfully!");
        Get.back();

        AppSnackBar.showGetXCustomSnackBar(
            message: "Receipt Confirm Entry deleted successfully!",
            backgroundColor: Colors.green);

        getConfirmReceivableEntry();
      } else {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final String message = responseBody['message'] ?? 'An error occurred.';
        //Fluttertoast.showToast(msg: message);
        AppSnackBar.showGetXCustomSnackBar(message: message);
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong: $e");
      //Fluttertoast.showToast(msg: "Something went wrong: $e");
    }
  }
}
