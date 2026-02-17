import 'dart:convert';

import 'package:arham_corporation/models/receipt_confim_model.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
//import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../helper/helper.dart';
import '../models/accountLeagerReportModal.dart';
import '../providers/party_provider.dart';
import '../providers/user_provider.dart';
import '../services/services.dart';
import '../widgets/custom_app_bar.dart';
import 'package:http/http.dart' as http;

class ReceivableConfirmReceiptSettlementPage extends StatefulWidget {
  @override
  _ReceivableConfirmReceiptSettlementPageState createState() =>
      _ReceivableConfirmReceiptSettlementPageState();
}

class _ReceivableConfirmReceiptSettlementPageState
    extends State<ReceivableConfirmReceiptSettlementPage> {
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
                                                    fontWeight: FontWeight.bold),
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
                                                                color:
                                                                    Colors.amber),
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

  getConfirmReceivableEntry() {
    setState(() {
      data.clear();
      expansionController.clear();
      noList = false;
      loading = true;
    });

    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);

    Services()
        .getReceiptReceivableConfirm(
      context,
      '',
      '',
      false,
      party.partyid,
      '',
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
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    if (party.partyid != "") {
      isPartySelected = true;
      getConfirmReceivableEntry();
    } else {
      getConfirmReceivableEntry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Receipt Confirm Entry',
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) => Column(
            children: [
              // Supplier details container
              Visibility(
                visible: false,
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
                              onPressed: () => showPartySelectionMenu(context),
                              child: Text("Change")),
                          SizedBox(width: 2.0),
                          // Close button
                          GestureDetector(
                            onTap: () {
                              final party = Provider.of<PartyProvider>(context,
                                  listen: false);
                              party.clearParty();
                              setState(() {
                                isPartySelected = false;
                                data.clear();
                                quickSaveEnabled = false;
                                selectedPurchases.clear();
                              });
                            },
                            child: Icon(Icons.close, size: 18),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 10,
              ),
              loading
                  ? Expanded(child: Center(child: CircularProgressIndicator()))
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
                                                visible: true,
                                                child: Checkbox(
                                                  activeColor: Color(0XFF2c9ed9),
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
                                                  padding: const EdgeInsets.only(
                                                      top: 5.0),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                        color: index % 2 == 0
                                                            ? Colors.blueGrey
                                                                .withOpacity(0.1)
                                                            : Colors.transparent),
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
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        "Date",
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.black),
                                                                      ),
                                                                      Text(
                                                                        Helper.toUi("${data[index].vOUCHDT}"),
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.grey),
                                                                      )
                                                                    ],
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  flex: 3,
                                                                  child: Column(
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
                                                                          color: Colors
                                                                              .black,
                                                                        ),
                                                                      ),
                                                                      Text(
                                                                        "${data[index].party?.aCCNAME ?? ''}",
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.grey),
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
                                                                          "Book Cd",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.black,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          "${data[index].bOOKCD}",
                                                                          style: TextStyle(
                                                                              fontSize:
                                                                                  12,
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
                                                                          "Vouch No",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.black,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          "${data[index].vOUCHNO ?? ""}",
                                                                          style: TextStyle(
                                                                              fontSize:
                                                                                  12,
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
                                                                          "Narration",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.black,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          "${data[index].nARRATION ?? ""}",
                                                                          style: TextStyle(
                                                                              fontSize:
                                                                                  12,
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
                                                                          "Amt",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.black,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          "${Helper.parseNumericValue(data[index].aMOUNT.toString())}",
                                                                          style: TextStyle(
                                                                              fontSize:
                                                                                  12,
                                                                              color:
                                                                                  Colors.grey),
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
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                      children: [
                                                                        Text(
                                                                          "Type",
                                                                          style:
                                                                          TextStyle(
                                                                            fontSize:
                                                                            12,
                                                                            color:
                                                                            Colors.black,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          data[index].billwiseSettlements!.isEmpty ? 'On Account': 'BillWise',
                                                                          style: TextStyle(
                                                                              fontSize: 12,
                                                                              color: Colors.grey),
                                                                        )
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  Expanded(
                                                                    child:
                                                                    Column(
                                                                      crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                      children: [
                                                                        Text(
                                                                          "Cash/Bank Party",
                                                                          style:
                                                                          TextStyle(
                                                                            fontSize:
                                                                            12,
                                                                            color:
                                                                            Colors.black,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          "${data[index].cshbnkParty?.aCCNAME ?? ""}",
                                                                          style: TextStyle(
                                                                              fontSize: 12,
                                                                              color: Colors.grey),
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
                                                            openTileIndex = index;
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
                                                            data[index].billwiseSettlements!.isNotEmpty ? Column(children: [
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
                                                                      SizedBox(width: 5,),
                                                                      Expanded(
                                                                          child:
                                                                              Text(
                                                                        "Vouch Dt",
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12.0),
                                                                      )),
                                                                      Expanded(
                                                                          child:
                                                                              Text(
                                                                        "Bill No",
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12.0),
                                                                      )),
                                                                      Expanded(
                                                                          child:
                                                                              Text(
                                                                        "Bill Amt",
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12.0),
                                                                      )),
                                                                      Expanded(
                                                                          child:
                                                                              Text(
                                                                        "Bill Paid Amt",
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12.0),
                                                                      )),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                              Padding(
                                                                padding: EdgeInsets
                                                                    .only(
                                                                        top: 8.0),
                                                                child: ListView
                                                                    .builder(
                                                                  physics:
                                                                      NeverScrollableScrollPhysics(),
                                                                  itemCount: data[
                                                                          index]
                                                                      .billwiseSettlements!
                                                                      .length,
                                                                  // Length of the inner billwiseSettlements list
                                                                  shrinkWrap:
                                                                      true,
                                                                  itemBuilder:
                                                                      (context,
                                                                          innerIndex) {
                                                                    var settlement =
                                                                        data[index]
                                                                                .billwiseSettlements![
                                                                            innerIndex];
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
                                                                          style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                        ),
                                                                        SizedBox(width: 5,),
                                                                        Expanded(
                                                                          child:
                                                                              Text(
                                                                                Helper.toUi("${settlement.bLVDT}"),
                                                                                style: TextStyle(
                                                                                color: Colors.grey,
                                                                                fontSize: 12.0),
                                                                          ),
                                                                        ),
                                                                        Expanded(
                                                                          child:
                                                                              Text(
                                                                            "${settlement.bLBILLNO}",
                                                                            style: TextStyle(
                                                                                color: Colors.grey,
                                                                                fontSize: 12.0),
                                                                          ),
                                                                        ),
                                                                        Expanded(
                                                                          child:
                                                                              Text(
                                                                            "${Helper.parseNumericValue(settlement.bLAMOUNT.toString())}",
                                                                            style: TextStyle(
                                                                                color: Colors.grey,
                                                                                fontSize: 12.0),
                                                                          ),
                                                                        ),
                                                                        Expanded(
                                                                          child:
                                                                              Text(
                                                                            "${Helper.parseNumericValue(settlement.bLPAID.toString())}",
                                                                            style: TextStyle(
                                                                                color: Colors.grey,
                                                                                fontSize: 12.0),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  },
                                                                ),
                                                              )
                                                            ]) : SizedBox.shrink(),

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
                                                                  visible: false,
                                                                  child: Expanded(
                                                                    child:
                                                                        Padding(
                                                                      padding:
                                                                          const EdgeInsets
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
                                                                          style: TextStyle(
                                                                              color:
                                                                                  Colors.white),
                                                                        ),
                                                                        style: ElevatedButton
                                                                            .styleFrom(
                                                                          minimumSize: Size(
                                                                              double.infinity,
                                                                              50),
                                                                          backgroundColor:
                                                                              Color(0XFF2c9ed9),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                Visibility(
                                                                  visible: Get
                                                                          .arguments[
                                                                      'DeleteRight'],
                                                                  child: SizedBox(
                                                                    height: 25,
                                                                    child:
                                                                        IconButton(
                                                                      highlightColor:
                                                                          Colors
                                                                              .transparent,
                                                                      // No highlight color
                                                                      splashColor:
                                                                          Colors
                                                                              .transparent,
                                                                      // No splash effect
                                                                      color: Colors
                                                                          .red,
                                                                      // Icon color
                                                                      icon: Icon(Icons
                                                                          .delete),
                                                                      onPressed:
                                                                          () {
                                                                        showDialog(
                                                                          context:
                                                                              context,
                                                                          builder:
                                                                              (BuildContext
                                                                                  context) {
                                                                            return AlertDialog(
                                                                              title:
                                                                                  Text('Delete Confirmation'),
                                                                              content:
                                                                                  Text('Are you sure you want to delete receipt report? - ${data[index].vOUCHNO.toString()}'),
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
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: Size(double.infinity, 50),
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
        Get.back();
        // Fluttertoast.showToast(
        //     msg: "Receipt Confirm Entry deleted successfully!");
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
    } catch (e) {
      //Fluttertoast.showToast(msg: "Something went wrong: $e");
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong: $e");
    }
  }
}
