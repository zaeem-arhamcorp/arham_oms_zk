import 'dart:convert';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/views/receivable_confirm_receipt_settlement_page.dart';
import 'package:arham_corporation/views/receivable_report_receipt_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../helper/helper.dart';
import '../models/accountLeagerReportModal.dart';
import '../models/partyWiseOutstandingReportModal.dart';
import '../providers/party_provider.dart';
import '../providers/user_provider.dart';
import '../services/services.dart';
import '../widgets/common_button.dart';
import '../widgets/common_text.dart';
import '../widgets/custom_app_bar.dart';
import 'package:http/http.dart' as http;

class ReceivableReceiptSettlementPage extends StatefulWidget {
  @override
  _ReceivableReceiptSettlementPageState createState() =>
      _ReceivableReceiptSettlementPageState();
}

class _ReceivableReceiptSettlementPageState
    extends State<ReceivableReceiptSettlementPage> {
  List<Map<String, dynamic>> bankList = [];
  String? groupCode; // Stores the selected sync ID
  String selectedBankId = ''; // Stores the selected sync ID
  String selectedBankName = ''; // Stores the selected firm name
  bool isLoading = true; // Indicates loading state

  bool quickSaveEnabled = false;
  List<DatumPartyWiseOutstandingSale> selectedPurchases = [];
  List<Map<String, dynamic>> billwise = [];

  bool isDrawerOpen = false;
  String selectedPaymentMode = 'Bill Wise';
  String selectedPaymentType = 'Cash';
  bool _isCheckAccount = false;
  var reportShowFormat = 'Online'.obs;
  String _amountError = '';
  final _amountController = TextEditingController();
  final _checkController = TextEditingController();
  final _remarksController = TextEditingController();
  FocusNode _focusNodecheck = FocusNode();
  FocusNode _focusNodeAmount = FocusNode();
  FocusNode _focusNodeRemarks = FocusNode();

  // Function to calculate due days
  int calculateDueDays(String? dueDate) {
    if (dueDate == null) {
      return 0; // or some other default value
    }
    DateTime dueDateTime = DateTime.parse(dueDate);
    DateTime today = DateTime.now();
    int dueDays = dueDateTime.difference(today).inDays;
    return dueDays;
  }

  // Toggle purchase selection
  void togglePurchaseSelection1(
      bool selected, DatumPartyWiseOutstandingSale purchase) {
    setState(() {
      if (selected) {
        selectedPurchases.add(purchase);
        billwise = selectedPurchases.map((data) {
          return {
            "vouchType": data.vouchType,
            "bookCd": data.bookCd,
            "vNo": data.vouchNo,
            "billNo": data.partyBl,
            "billDate": data.vouchDt,
            "billAmt": data.vouchAmt,
            "drCrNote": "",
            "kasar": "",
            "paid": data.osAmt,
          };
        }).toList();
      } else {
        selectedPurchases.remove(purchase);
        billwise = selectedPurchases.map((data) {
          return {
            "vouchType": data.vouchType,
            "bookCd": data.bookCd,
            "vNo": data.vouchNo,
            "billNo": data.partyBl,
            "billDate": data.vouchDt,
            "billAmt": data.vouchAmt,
            "drCrNote": "",
            "kasar": "",
            "paid": data.osAmt,
          };
        }).toList();
      }
    });
  }

  void togglePurchaseSelection(
      bool selected, DatumPartyWiseOutstandingSale purchase) {
    setState(() {
      final amountText = autoAmountController.text;

      // If trying to check and no remaining amount, block addition (when amountText is not empty)
      if (selected && amountText.isNotEmpty && remainingAmount <= 0) {
        AppSnackBar.showGetXCustomSnackBar(
            message: "Remaining amount is 0, cannot select more bill.");
        return;
      }

      if (selected) {
        selectedPurchases.add(purchase);
      } else {
        selectedPurchases.remove(purchase);
      }

      // Build billwise list from selected purchases
      billwise = selectedPurchases.map((data) {
        return {
          "vouchType": data.vouchType,
          "bookCd": data.bookCd,
          "vNo": data.vouchNo,
          "billNo": data.partyBl,
          "billDate": data.vouchDt,
          //"billAmt": data.vouchAmt,
          "billAmt": double.parse(double.parse(data.vouchAmt!.toString()) < 0
              ? (-1 * double.parse(data.vouchAmt!.toString()))
                  .toStringAsFixed(2)
              : double.parse(data.vouchAmt!.toString()).toStringAsFixed(2)),
          "drCrNote": "",
          "kasar": "",
          "paid": data.vouchType == 'C'
              ? double.parse(double.parse(data.osAmt!.toString()) > 0
                  ? (-1 * double.parse(data.osAmt!.toString()))
                      .toStringAsFixed(2)
                  : double.parse(data.osAmt!.toString()).toStringAsFixed(2))
              : double.parse(data.osAmt!.toString()).toStringAsFixed(2),
          // "paid": data.vouchType == 'C'
          //     ? (double.parse(data.osAmt!.toString()) * -1).toStringAsFixed(2)
          //     : data.osAmt,
          //"paid": data.osAmt,
        };
      }).toList();

      billwise.sort((a, b) {
        // Compare vouchType first
        final vouchTypeA = a["vouchType"].toString();
        final vouchTypeB = b["vouchType"].toString();
        final vouchTypeComparison = vouchTypeA.compareTo(vouchTypeB);
        if (vouchTypeComparison != 0) return vouchTypeComparison;

        // If vouchType is same, compare billDate
        final dateA = _parseDate(a["billDate"]);
        final dateB = _parseDate(b["billDate"]);
        return dateA.compareTo(dateB); // ascending
      });

      //selectedPurchases.refresh();

      // Distribute FIFO payment after billwise is created
      distributeFIFOAmount();

      print("Final Distributed Billwise List:");
      print(billwise);
    });
  }

  /// FIFO Distribution of amountController value
  void distributeFIFOAmount() {
    setState(() {
      final amountText = autoAmountController.text.trim();

      // If amount is empty, use paid as settleAmt
      if (amountText.isEmpty) {
        billwise = billwise.map((item) {
          final paid = double.tryParse(item["paid"].toString()) ?? 0.0;

          return {
            ...item,
            "settleAmt": paid.toStringAsFixed(2),
          };
        }).toList();

        remainingAmount = 0.0; // Since no amount to distribute
      } else {
        remainingAmount = double.tryParse(amountText) ?? 0.0;

        billwise = billwise.map((item) {
          double paid = double.tryParse(item["paid"].toString()) ?? 0.0;
          double settleAmt = 0.0;

          if (remainingAmount >= paid) {
            settleAmt = paid;
            remainingAmount -= paid;
          } else if (remainingAmount > 0) {
            settleAmt = remainingAmount;
            remainingAmount = 0.0;
          } else {
            settleAmt = 0.0;
          }

          return {
            ...item,
            "settleAmt": settleAmt.toStringAsFixed(2),
          };
        }).toList();
      }

      print('Remaining Amt : $remainingAmount');
    });
  }

  /// Helper to parse dd-MM-yyyy date format
  DateTime _parseDate(String dateStr) {
    try {
      //return DateFormat("dd-MM-yyyy").parse(dateStr);
      return DateFormat("yyyy-MM-dd").parse(dateStr);
    } catch (_) {
      return DateTime(1900); // fallback for invalid date
    }
  }

  // Calculate total selected amount
  double calculateSelectedAmount1() {
    return selectedPurchases.fold(0.0, (sum, purchase) {
      // Convert partyBl to a double
      double amount = double.tryParse(purchase.osAmt.toString()) ?? 0.0;
      return sum + amount;
    });
  }

  double calculateSelectedAmount() {
    return billwise.fold(0.0, (sum, purchase) {
      // Convert partyBl to a double
      double amount = double.tryParse(purchase['settleAmt'].toString()) ?? 0.0;
      return sum + amount;
    });
  }

  // Reset page after finalizing payment
  void finalizePaymentQuickSave() {
    if (billwise.isEmpty) {
      //Fluttertoast.showToast(msg: 'Please select one select item in list');
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Please select one select item in list',
      );
    } else if (selectedBankName.isEmpty) {
      //Fluttertoast.showToast(msg: 'Please select payment mode');
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Please select payment mode',
      );
    } else if (_isCheckAccount &&
        _checkController.text.isEmpty &&
        reportShowFormat.value == "Cheque") {
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Please enter check number',
      );

      //Fluttertoast.showToast(msg: 'Please enter check number');
    } else {
      DateTime now = DateTime.now();
      String formattedTime = DateFormat('HH:mm:ss').format(now);
      _amountTotalController.text =
          calculateSelectedAmount().toStringAsFixed(2);
      billwise = billwise.map((item) {
        final settleAmt = double.tryParse(item["settleAmt"].toString()) ?? 0.0;
        final updatedItem = Map<String, dynamic>.from(item);

        // Check if amountController is empty
        final amountText = autoAmountController.value.text.trim();

        if (amountText.isNotEmpty) {
          updatedItem["paid"] = settleAmt.abs().toStringAsFixed(2);
        } else {
          final originalPaid = double.tryParse(item["paid"].toString()) ?? 0.0;
          updatedItem["paid"] = originalPaid.abs().toStringAsFixed(2);
        }

        updatedItem.remove("settleAmt");
        return updatedItem;
      }).toList();

      print("Updated billwise:");
      print(billwise);

      setState(() {
        Services()
            .finalReceivableReceiptPaymentQuickSave(
          context,
          Helper.toApi(toDateController.text),
          formattedTime,
          selectedBankId,
          Provider.of<PartyProvider>(context, listen: false).partyid,
          //calculateSelectedAmount(),
          double.tryParse(_amountTotalController.text) ?? 0,
          _checkController.text,
          _remarksController.text,
          'B',
          "RC",
          billwise,
        )
            .then((val) {
          if (val == true) {
            // Clear values on success
            setState(() {
              billwise.clear();
              selectedPurchases.clear();
              quickSaveEnabled = false;
              isDrawerOpen = false;
              selectedPaymentMode = 'Bill Wise';
              _isCheckAccount = false;
              reportShowFormat.value = "Online";
              _checkController.clear();
              _amountController.clear();
              _amountError = '';
              //bankList.clear();
              selectedBankId = '';
              selectedBankName = '';
              _remarksController.clear();
              autoAmountController.clear();
              _amountTotalController.clear();

              fetchData();

              final PartyProvider party =
                  Provider.of<PartyProvider>(context, listen: false);
              if (party.partyid != "") {
                isPartySelected = true;
                getDate();
              }

              // Dismiss the bottom sheet (without going back to the previous screen)
              Navigator.of(context).pop();

              //Refresh List
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => ReceivableReceiptSettlementPage(),
              //   ),
              // );

              Get.to(
                ReceivableReceiptSettlementPage(),
                arguments: {
                  'DeleteRight': receivableDeleteRight,
                  'ReadRight': receivableReadRight,
                }, // pass your argument here
              );
            });
          }
        });
      });
    }
  }

  void finalizePaymentManuallySave() {
    if (selectedBankName.isEmpty) {
      //Fluttertoast.showToast(msg: 'Please select payment mode');
      AppSnackBar.showGetXCustomSnackBar(message: 'Please select payment mode');
    } else if (_isCheckAccount &&
        _checkController.text.isEmpty &&
        reportShowFormat.value == "Cheque") {
      //Fluttertoast.showToast(msg: 'Please enter check number');
      AppSnackBar.showGetXCustomSnackBar(message: 'Please enter check number');
    } else if (_amountController.text.isEmpty) {
      //Fluttertoast.showToast(msg: 'Please enter amount');
      AppSnackBar.showGetXCustomSnackBar(message: 'Please enter amount');
    } else {
      DateTime now = DateTime.now();
      String formattedTime = DateFormat('HH:mm:ss').format(now);

      setState(() {
        Services()
            .finalReceivableReceiptPaymentManuallySave(
          context,
          Helper.toApi(toDateController.text),
          formattedTime,
          selectedBankId,
          Provider.of<PartyProvider>(context, listen: false).partyid,
          double.tryParse(_amountController.text) ?? 0,
          _checkController.text,
          _remarksController.text,
          'A',
          "RC",
          billwise,
        )
            .then((val) {
          if (val == true) {
            // Clear values on success
            setState(() {
              billwise.clear();
              selectedPurchases.clear();
              quickSaveEnabled = false;
              isDrawerOpen = false;
              selectedPaymentMode = 'Account Wise';
              _isCheckAccount = false;
              reportShowFormat.value = "Online";
              _checkController.clear();
              _amountController.clear();
              _amountError = '';
              selectedBankId = '';
              selectedBankName = '';
              _remarksController.clear();

              // Dismiss the bottom sheet (without going back to the previous screen)
              Navigator.of(context).pop();

              //Refresh List
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => ReceivableReceiptSettlementPage(),
              //   ),
              // );

              autoAmountController.clear();
              _amountTotalController.clear();

              fetchData();

              final PartyProvider party =
                  Provider.of<PartyProvider>(context, listen: false);
              if (party.partyid != "") {
                isPartySelected = true;
                getDate();
              }

              Get.to(
                ReceivableReceiptSettlementPage(),
                arguments: {
                  'DeleteRight': receivableDeleteRight,
                  'ReadRight': receivableReadRight,
                }, // pass your argument here
              );
            });
          }
        });
      });
    }
  }

  final TextEditingController searchPartyClt = TextEditingController();
  FocusNode _focusNode = FocusNode();

  final List _tempParty = [];
  bool isPartySelected = false;

  final TextEditingController searchPartyOnACClt = TextEditingController();
  FocusNode _focusOnACNode = FocusNode();

  final List _tempOnACParty = [];
  bool isPartySelectedOnAC = false;

  // Function to open the bottom sheet and handle selection
  void showPartySelectionMenu(BuildContext context) {
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    //pp.getpartyname(context); // API call to fetch party data
    pp.getpartynameForReceivable(context); // API call to fetch party data

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
                              focusNode: _focusNode,
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
                                    : _tempParty.isEmpty &&
                                            searchPartyClt.text.isNotEmpty
                                        ? Center(child: Text("No Party Found"))
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
                                                    totalOSAmount = 0.00;
                                                    getDate();
                                                  });
                                                  Get.back();
                                                },
                                                child: ListTile(
                                                  leading: Text("${index + 1}"),
                                                  title: Text(
                                                    "(${selectedParty.accCd}) ${selectedParty.accName}${selectedParty.person_nm != null && selectedParty.person_nm!.isNotEmpty ? " - ${selectedParty.person_nm}" : ""} || CL BAL : ${formatAmount((selectedParty.clBAL ?? 0).toDouble())}",
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

  void showPartySelectionMenu1(BuildContext context) {
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    //pp.getpartyname(context); // API call to fetch party data
    pp.getpartynameForReceivableWithoutFilter(context); // API call to fetch party data

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
                              controller: searchPartyOnACClt,
                              focusNode: _focusOnACNode,
                              onChanged: (value) {
                                setState(() {
                                  _tempOnACParty.clear();
                                  _tempOnACParty.addAll(
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
                                    : _tempOnACParty.isEmpty &&
                                            searchPartyOnACClt.text.isNotEmpty
                                        ? Center(child: Text("No Party Found"))
                                        : ListView.builder(
                                            itemCount: _tempOnACParty.isNotEmpty
                                                ? _tempOnACParty.length
                                                : party.data.length,
                                            itemBuilder: (context, index) {
                                              var selectedParty =
                                                  _tempOnACParty.isNotEmpty
                                                      ? _tempOnACParty[index]
                                                      : party.data[index];
                                              return InkWell(
                                                onTap: () async {
                                                  await party.changeParty(
                                                    selectedParty.accName,
                                                    selectedParty.accCd,
                                                    context,
                                                  );
                                                  setState(() {
                                                    isPartySelectedOnAC = true;
                                                    quickSaveEnabled = false;
                                                    selectedPurchases.clear();
                                                    totalOSAmount = 0.00;
                                                    getDate();
                                                  });
                                                  Get.back();
                                                },
                                                child: ListTile(
                                                  leading: Text("${index + 1}"),
                                                  title: Text(
                                                    "(${selectedParty.accCd}) ${selectedParty.accName}${selectedParty.person_nm != null && selectedParty.person_nm!.isNotEmpty ? " - ${selectedParty.person_nm}" : ""} || CL BAL : ${formatAmount((selectedParty.clBAL ?? 0).toDouble())}",
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

  List<DatumPartyWiseOutstandingSale> data = [];
  bool noList = false;
  double billAmtTotal = 0.00;
  double paidAmtTotal = 0.00;
  double balanceAmtTotal = 0.00;
  double totalOSAmount = 0.00;
  bool loading = false;

  List<ExpansibleController> expansionController = [];
  int openTileIndex = -1;
  bool detailDataLoading = false;
  List<Detail> detailData = [];
  List<BillWiseDetail> billWisedetailData = [];

  TextEditingController toDateController = TextEditingController();

  String formatAmount(double amount) {
    final formatter =
        NumberFormat('#,##0.00', 'en_US'); // Format with commas and 2 decimals
    return formatter.format(amount);
  }

  String getCurrentDate() {
    DateTime now = DateTime.now();
    //String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    String formattedDate = DateFormat('dd-MM-yyyy').format(now);
    return formattedDate;
  }

  String getCurrentDateDif() {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy')
        .format(now); // Fix: return in dd-MM-yyyy format
    return formattedDate;
  }

  getDate() {
    setState(() {
      data.clear();
      expansionController.clear();
      billAmtTotal = 0.00;
      paidAmtTotal = 0.00;
      balanceAmtTotal = 0.00;
      totalOSAmount = 0.00;
      noList = false;
      loading = true;
    });

    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);

    Services()
        .getPartyWiseOutStandingReceivableReport(
            context, Helper.toApi(getCurrentDate()), party.partyid)
        .then((value) {
      setState(() {
        if (value != null) {
          data.addAll(value.data);
          data.forEach((e) => expansionController.add(ExpansibleController()));

          // Get current date formatted as dd-MM-yyyy
          DateTime currentDate =
              DateFormat("dd-MM-yyyy").parse(getCurrentDateDif());
          print("Current Date: $currentDate");

          // Loop through the data and sum OS_AMT if DUE_DATE is before current date
          for (var item in data) {
            // Parse the DUE_DATE
            DateTime dueDate = DateFormat("dd-MM-yyyy").parse(item.dueDate);

            // Check if the DUE_DATE is before current date
            if (dueDate.isBefore(currentDate)) {
              // Add OS_AMT to the total sum
              totalOSAmount += double.parse(item.osAmt.toString());
            }
          }

          // Print the result
          print("Total OS Amount: \$${totalOSAmount.toStringAsFixed(2)}");

          billAmtTotal = value.data
              .fold(
                  0.00,
                  (previousValue, element) =>
                      previousValue + double.parse(element.vouchAmt.toString()))
              .toPrecision(2);

          paidAmtTotal = value.data
              .fold(
                  0.00,
                  (previousValue, element) =>
                      previousValue + double.parse(element.paidAmt.toString()))
              .toPrecision(2);

          balanceAmtTotal = value.data
              .fold(
                  0.00,
                  (previousValue, element) =>
                      previousValue + double.parse(element.osAmt.toString()))
              .toPrecision(2);

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

  getDetailData(bookCd, vouchDt, partyCd) {
    Services()
        .getPartyWiseOutStandingReceivableDetailReport(
            context, Helper.toApi(getCurrentDate()), Helper.toApi(vouchDt), bookCd, partyCd)
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
        .getPartyWiseOutStandingBillWiseReceivableDetailReport(
            context, Helper.toApi(getCurrentDate()), partyCd, Helper.toApi(vouchDt), bookCd, vouchNo)
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

  bool receivableDeleteRight = false;
  bool receivableReadRight = false;

  TextEditingController autoAmountController = TextEditingController();
  FocusNode autoAmountFocus = FocusNode();
  double remainingAmount = 0.0;
  final _amountTotalController = TextEditingController();

  bool get canShowSaveButton {
    setState(() {});

    final amountText = autoAmountController.text;

    final totalPaid = billwise.fold<double>(
      0.0,
      (sum, item) => sum + (double.tryParse(item["paid"].toString()) ?? 0.0),
    );

    // Show Save if amount is empty OR amount >= totalPaid
    final amountValid = amountText.isEmpty ||
        //(double.tryParse(amountText) ?? 0.0) >= totalPaid;
        //totalPaid >= (double.tryParse(amountText) ?? 0.0) // only paid amount logic
        (totalPaid >= (double.tryParse(amountText) ?? 0.0) &&
            remainingAmount <= 0);

    return quickSaveEnabled && selectedPurchases.isNotEmpty && amountValid;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _focusNodecheck.dispose();
    _focusNodeAmount.dispose();
    _focusNodeRemarks.dispose();
    _amountController.dispose();
    _checkController.dispose();
    _remarksController.dispose(); // Dispose of the remarks controller
    super.dispose();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    // final ProfileProvider p =
    // Provider.of<ProfileProvider>(context, listen: false);
    //
    // var receiptEntryModule = p.data?.modulesList?.firstWhere(
    //       (module) => module.mODULENO == "214",
    //   orElse: () => Modules(),
    // ) ??
    //     Modules();
    //
    // if (p.data?.modulesList != null &&
    //     p.data!.modulesList!.any((module) =>
    //     module.mODULENO == "214" && module.rEADRIGHT == true))

    _focusNode.requestFocus();
    _focusNodeRemarks.requestFocus();
    _focusNodeAmount.requestFocus();
    _focusNodecheck.requestFocus();
    receivableDeleteRight = Get.arguments['DeleteRight'];
    receivableReadRight = Get.arguments['ReadRight'];
    toDateController.text = getCurrentDate();

    fetchData();

    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    if (party.partyid != "") {
      isPartySelected = true;
      getDate();
    }
  }

  Future<void> fetchData() async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    final url = Uri.parse(
        AppConfig.baseURL + 'cash-bank-party'); // Replace with your API URL

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print(AppConfig.baseURL + 'cash-bank-party');
      print("Bearer ${ub.token}");
      print(response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> firms = data['data'];

        // Parse each entry to a map with firm name and sync ID
        setState(() {
          bankList = firms.map((item) {
            return {
              "BankName": item['ACC_NAME']?.replaceAll(RegExp(r'[\r\n]'), '') ??
                  'Unnamed Firm',
              "cashBnkCd": item['ACC_CD'],
              "GroupCode": item['GROUP_CD'],
            };
          }).toList();

          print(bankList);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Receipt Settlement Entry',
        actions: [
          Visibility(
            visible: false,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GestureDetector(
                  onTap: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ReceivableConfirmReceiptSettlementPage(),
                      ),
                    );
                  },
                  child: Icon(Icons.check)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Supplier details container
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
                      onPressed: () => showPartySelectionMenu(context),
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
                              Provider.of<PartyProvider>(context).party.isEmpty
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
                                setState(() {
                                  isPartySelected = false;
                                  data.clear();
                                  billAmtTotal = 0.00;
                                  paidAmtTotal = 0.00;
                                  balanceAmtTotal = 0.00;
                                  totalOSAmount = 0.00;
                                  quickSaveEnabled = false;
                                  selectedPurchases.clear();
                                });
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
            Visibility(
              visible: true,
              //visible: isPartySelected,
              child: Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withValues(alpha: 1), blurRadius: 5)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Purchases',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            SizedBox(height: 4),
                            Text(
                              data.length.toString(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              'Outstanding',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            SizedBox(height: 4),
                            Text(
                              NumberFormat('#,##0.00', 'en_US')
                                  .format(balanceAmtTotal),
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              'Overdue',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            SizedBox(height: 4),
                            Text(
                              NumberFormat('#,##0.00', 'en_US')
                                  .format(totalOSAmount),
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (isPartySelected) {
                                setState(() {
                                  //quickSaveEnabled = !quickSaveEnabled;

                                  quickSaveEnabled = false;
                                  selectedPurchases.clear();
                                  billwise.clear();

                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => AlertDialog(
                                      title: Center(
                                        child: CommonText(
                                          text: 'Auto Amount',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                        ),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: autoAmountController,
                                            keyboardType: TextInputType.number,
                                            textInputAction:
                                                TextInputAction.done,
                                            maxLength: 15,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                  RegExp(
                                                      r'^\d{0,12}(\.\d{0,2})?')),
                                            ],
                                            cursorColor: Colors.black,
                                            focusNode: autoAmountFocus,
                                            decoration: InputDecoration(
                                              labelText: 'Auto Amount',
                                              labelStyle: TextStyle(
                                                  color: Colors.black),
                                              border: OutlineInputBorder(),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Color(0XFF2c9ed9),
                                                    width: 2.0),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      actionsAlignment:
                                          MainAxisAlignment.center,
                                      actions: [
                                        CommonButton(
                                          buttonText: 'Continue',
                                          onPressed: () {
                                            setState(() {
                                              Get.back();
                                              remainingAmount = double.tryParse(
                                                      autoAmountController
                                                          .value.text) ??
                                                  0.0;

                                              quickSaveEnabled =
                                                  !quickSaveEnabled;
                                            });
                                          },
                                          isLoading: false,
                                        )
                                      ],
                                    ),
                                  );
                                });
                              } else {
                                AppSnackBar.showGetXCustomSnackBar(
                                    message: 'Please select party.');
                              }
                            },
                            child: Text(
                              'Bill Wise Entry',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    10), // Rounded corners
                              ),
                              backgroundColor: Color(0XFF2c9ed9),
                              minimumSize: Size(
                                  double.infinity, 40), // Full-width button
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                // if (isPartySelected) {
                                //   showBottomSheetDialogManuallySave(context);
                                // } else {
                                //   AppSnackBar.showGetXCustomSnackBar(
                                //       message: 'Please select party.');
                                // }

                                showBottomSheetDialogManuallySave(context);
                              });
                              },
                            child: Text(
                              'On Account',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    10), // Rounded corners
                              ),
                              backgroundColor: Color(0XFF2c9ed9),
                              minimumSize: Size(
                                  double.infinity, 40), // Full-width button
                            ),
                          ),
                        ),
                      ],
                    ),
                    Visibility(
                        visible: ub.role.toString().toUpperCase() == 'M' ||
                            receivableReadRight,
                        child: SizedBox(height: 10)),
                    Visibility(
                      visible: ub.role.toString().toUpperCase() == 'M' ||
                          receivableReadRight,
                      child: Row(
                        children: [
                          Visibility(
                            visible: ub.role.toString().toUpperCase() == 'M' ||
                                receivableReadRight,
                            child: Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Get.to(() => ReceivableReportReceiptPage(),
                                  //     arguments: {
                                  //       "DeleteRight": receivableDeleteRight,
                                  //       'ReadRight': receivableReadRight,
                                  //     });

                                  Get.to(() => ReceivableReportReceiptPage(),
                                      arguments: {
                                        "DeleteRight": receivableDeleteRight,
                                        "ReadRight": receivableReadRight,
                                      })?.then((result) {
                                    // Use '?.then()' to prevent null error
                                    if (result == true) {
                                      final PartyProvider party =
                                          Provider.of<PartyProvider>(context,
                                              listen: false);
                                      if (party.partyid != "") {
                                        isPartySelected = true;
                                        getDate();
                                      } else {
                                        setState(() {
                                          isPartySelected = false;
                                          data.clear();
                                          billAmtTotal = 0.00;
                                          paidAmtTotal = 0.00;
                                          balanceAmtTotal = 0.00;
                                          totalOSAmount = 0.00;
                                          quickSaveEnabled = false;
                                          selectedPurchases.clear();
                                        });
                                      }
                                    }
                                  });
                                },
                                child: Text(
                                  'Receipt Report',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        10), // Rounded corners
                                  ),
                                  backgroundColor: Color(0XFF2c9ed9),
                                  minimumSize: Size(
                                      double.infinity, 40), // Full-width button
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Visibility(
                            visible: ub.role.toString().toUpperCase() == 'M',
                            child: Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(
                                  //     builder: (context) => ReceivableConfirmReceiptSettlementPage(),
                                  //   ),
                                  // );

                                  Get.to(
                                      () =>
                                          ReceivableConfirmReceiptSettlementPage(),
                                      arguments: {
                                        "DeleteRight": receivableDeleteRight,
                                        'ReadRight': receivableReadRight,
                                      });
                                },
                                child: Text(
                                  'Confirm Receipt Entry',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        10), // Rounded corners
                                  ),
                                  backgroundColor: Color(0XFF2c9ed9),
                                  minimumSize: Size(
                                      double.infinity, 40), // Full-width button
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            loading
                ? Expanded(child: Center(child: CircularProgressIndicator()))
                : Visibility(
                    visible: isPartySelected,
                    child: data.isEmpty
                        ? Expanded(
                            child: Center(
                              child: Text("No Data Found"),
                            ),
                          )
                        : Expanded(
                            child: Column(
                              children: [
                                // Invoices list inside SingleChildScrollView
                                Expanded(
                                  child: ListView.builder(
                                      itemCount: data.length,
                                      shrinkWrap: true,
                                      itemBuilder: (context, index) {
                                        final invoice = data[index];
                                        return Row(
                                          children: [
                                            quickSaveEnabled
                                                ? Checkbox(
                                                    activeColor:
                                                        Color(0XFF2c9ed9),
                                                    value: selectedPurchases
                                                        .contains(invoice),
                                                    onChanged: (value) {
                                                      togglePurchaseSelection(
                                                          value!, invoice);
                                                    },
                                                  )
                                                : Container(),
                                            Expanded(
                                              flex: 1,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 5.0),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                      color: Colors.white),
                                                  child: Card(
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
                                                                        Helper.toUi("${data[index].vouchDt}"),
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
                                                                        "${data[index].bookCd}",
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
                                                                          color:
                                                                              Colors.black,
                                                                        ),
                                                                      ),
                                                                      Text(
                                                                        "${data[index].account.accName}",
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
                                                                          "Party Bill",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.black,
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
                                                                    child:
                                                                        Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                          "Bill Amt",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.black,
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
                                                                  Expanded(
                                                                    child:
                                                                        Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                          "Paid Amt",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.black,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          "${Helper.parseNumericValue(data[index].paidAmt.toString())}",
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
                                                                          "Bal Amt",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.black,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          //"${Helper.parseNumericValue(data[index].osAmt != null ? data[index].vouchType == 'C' ? (double.parse(data[index].osAmt.toString()) * -1).toStringAsFixed(2) : double.parse(data[index].osAmt.toString()).toStringAsFixed(2) : "0.00")}",
                                                                          "${Helper.parseNumericValue(data[index].osAmt != null ? data[index].vouchType == 'C' ? double.parse(data[index].osAmt.toString()) > 0 ? (-1 * double.parse(data[index].osAmt.toString())).toStringAsFixed(2) : double.parse(data[index].osAmt.toString()).toStringAsFixed(2) : double.parse(data[index].osAmt.toString()).toStringAsFixed(2) : "0.00")}",
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
                                                                          "${data[index].narration ?? ""}",
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
                                                            openTileIndex =
                                                                index;
                                                          });
                                                          if (val == true) {
                                                            setState(() {
                                                              detailDataLoading =
                                                                  true;
                                                            });
                                                            if (data[index].bookCd == "RC" ||
                                                                data[index]
                                                                        .bookCd ==
                                                                    "PY" ||
                                                                data[index]
                                                                        .bookCd ==
                                                                    "IC" ||
                                                                data[index]
                                                                        .bookCd ==
                                                                    "EP") {
                                                              getBillWiseDetailData(
                                                                  data[index]
                                                                      .account
                                                                      .accCd,
                                                                  data[index]
                                                                      .vouchDt,
                                                                  data[index]
                                                                      .bookCd,
                                                                  data[index]
                                                                      .vouchNo);
                                                            } else {
                                                              getDetailData(
                                                                  data[index]
                                                                      .bookCd,
                                                                  data[index]
                                                                      .vouchDt,
                                                                  data[index]
                                                                      .account
                                                                      .accCd);
                                                            }
                                                          } else {
                                                            setState(() {
                                                              detailData = [];
                                                            });
                                                          }
                                                        },
                                                        children: [
                                                          if (detailDataLoading ==
                                                              true)
                                                            Text("Loading....")
                                                          else if (data[
                                                                          index]
                                                                      .bookCd ==
                                                                  "RC" ||
                                                              data[index]
                                                                      .bookCd ==
                                                                  "PY" ||
                                                              data[index]
                                                                      .bookCd ==
                                                                  "IC" ||
                                                              data[index]
                                                                      .bookCd ==
                                                                  "EP")
                                                            Column(children: [
                                                              Column(
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      Expanded(
                                                                          child:
                                                                              Text(
                                                                        "Book Cd",
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12.0),
                                                                      )),
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
                                                                          top:
                                                                              8.0),
                                                                  child: ListView
                                                                      .builder(
                                                                          physics:
                                                                              NeverScrollableScrollPhysics(),
                                                                          itemCount: billWisedetailData
                                                                              .length,
                                                                          shrinkWrap:
                                                                              true,
                                                                          itemBuilder:
                                                                              (context, index) {
                                                                            return Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Row(
                                                                                  children: [
                                                                                    Expanded(
                                                                                        child: Text(
                                                                                      "${billWisedetailData[index].blBookCd}",
                                                                                      style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                    )),
                                                                                    Expanded(
                                                                                        child: Text(
                                                                                          Helper.toUi("${billWisedetailData[index].blVDt}"),
                                                                                      style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                    )),
                                                                                    Expanded(
                                                                                        child: Text(
                                                                                      "${billWisedetailData[index].blBillNo}",
                                                                                      style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                    )),
                                                                                    Expanded(
                                                                                        child: Text(
                                                                                      "${Helper.parseNumericValue(billWisedetailData[index].blAmt.toString())}",
                                                                                      style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                    )),
                                                                                    Expanded(
                                                                                        child: Text(
                                                                                      "${Helper.parseNumericValue(billWisedetailData[index].blPaid.toString())}",
                                                                                      style: TextStyle(color: Colors.grey, fontSize: 12.0),
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
                                                                          child:
                                                                              Text(
                                                                        "Item Cd",
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12.0),
                                                                      )),
                                                                      Expanded(
                                                                          flex:
                                                                              4,
                                                                          child:
                                                                              Text(
                                                                            "Item Name",
                                                                            style:
                                                                                TextStyle(fontSize: 12.0),
                                                                          )),
                                                                    ],
                                                                  ),
                                                                  Row(
                                                                    children: [
                                                                      Expanded(
                                                                          child:
                                                                              Text(
                                                                        "Size Cd",
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12.0),
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
                                                                              Alignment.centerRight,
                                                                          child:
                                                                              Text(
                                                                            "Quantity",
                                                                            style:
                                                                                TextStyle(fontSize: 12.0),
                                                                          ),
                                                                        ),
                                                                      )),
                                                                      Expanded(
                                                                          child:
                                                                              Text(
                                                                        "Free Qty",
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12.0),
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
                                                                              Alignment.centerRight,
                                                                          child:
                                                                              Text(
                                                                            "Rate",
                                                                            style:
                                                                                TextStyle(fontSize: 12.0),
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
                                                                              Alignment.centerRight,
                                                                          child:
                                                                              Text(
                                                                            "Vouch Amt",
                                                                            style:
                                                                                TextStyle(fontSize: 12.0),
                                                                          ),
                                                                        ),
                                                                      )),
                                                                    ],
                                                                  )
                                                                ],
                                                              ),
                                                              Padding(
                                                                  padding: EdgeInsets
                                                                      .only(
                                                                          top:
                                                                              8.0),
                                                                  child: ListView
                                                                      .builder(
                                                                          physics:
                                                                              NeverScrollableScrollPhysics(),
                                                                          itemCount: detailData
                                                                              .length,
                                                                          shrinkWrap:
                                                                              true,
                                                                          itemBuilder:
                                                                              (context, index) {
                                                                            return Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Row(
                                                                                  children: [
                                                                                    Expanded(
                                                                                        child: Text(
                                                                                      "${detailData[index].itemCd}",
                                                                                      style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                    )),
                                                                                    Expanded(
                                                                                        flex: 4,
                                                                                        child: Text(
                                                                                          "${detailData[index].item.itemName}",
                                                                                          style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                        )),
                                                                                  ],
                                                                                ),
                                                                                Row(
                                                                                  children: [
                                                                                    Expanded(
                                                                                        child: Text(
                                                                                      "${detailData[index].sizeCd}",
                                                                                      style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                    )),
                                                                                    Expanded(
                                                                                        child: Padding(
                                                                                      padding: const EdgeInsets.only(right: 15.0),
                                                                                      child: Align(
                                                                                        alignment: Alignment.centerRight,
                                                                                        child: Text(
                                                                                          "${detailData[index].qty}",
                                                                                          style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                        ),
                                                                                      ),
                                                                                    )),
                                                                                    Expanded(
                                                                                        child: Text(
                                                                                      "${detailData[index].otherDesc}",
                                                                                      style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                    )),
                                                                                    Expanded(
                                                                                        child: Padding(
                                                                                      padding: const EdgeInsets.only(right: 15.0),
                                                                                      child: Align(
                                                                                        alignment: Alignment.centerRight,
                                                                                        child: Text(
                                                                                          "${Helper.parseNumericValue(detailData[index].rate.toString())}",
                                                                                          style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                                                                        ),
                                                                                      ),
                                                                                    )),
                                                                                    Expanded(
                                                                                        child: Padding(
                                                                                      padding: const EdgeInsets.only(right: 15.0),
                                                                                      child: Align(
                                                                                        alignment: Alignment.centerRight,
                                                                                        child: Text(
                                                                                          "${Helper.parseNumericValue(detailData[index].vouchAmt.toString())}",
                                                                                          style: TextStyle(color: Colors.grey, fontSize: 12.0),
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
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                ),

                                // Obx(() {
                                //   return canShowSaveButton
                                //       ? Padding(
                                //           padding: const EdgeInsets.all(16.0),
                                //           child: ElevatedButton(
                                //             onPressed: () {
                                //               // setState(() {
                                //               //   isDrawerOpen = true;
                                //               // });
                                //
                                //               showBottomSheetDialogQuickSave(
                                //                   context);
                                //             },
                                //             child: Text(
                                //               'Save',
                                //               style:
                                //                   TextStyle(color: Colors.white),
                                //             ),
                                //             style: ElevatedButton.styleFrom(
                                //               minimumSize:
                                //                   Size(double.infinity, 50),
                                //               backgroundColor: Color(0XFF2c9ed9),
                                //             ),
                                //           ),
                                //         )
                                //       : SizedBox.shrink();
                                // }),

                                canShowSaveButton
                                    ? Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            // setState(() {
                                            //   isDrawerOpen = true;
                                            // });

                                            showBottomSheetDialogQuickSave(
                                                context);
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
                                      )
                                    : SizedBox.shrink()

                                // if (quickSaveEnabled &&
                                //     selectedPurchases.isNotEmpty)
                                //   Padding(
                                //     padding: const EdgeInsets.all(16.0),
                                //     child: ElevatedButton(
                                //       onPressed: () {
                                //         // setState(() {
                                //         //   isDrawerOpen = true;
                                //         // });
                                //
                                //         showBottomSheetDialogQuickSave(context);
                                //       },
                                //       child: Text(
                                //         'Save',
                                //         style: TextStyle(color: Colors.white),
                                //       ),
                                //       style: ElevatedButton.styleFrom(
                                //         minimumSize: Size(double.infinity, 50),
                                //         backgroundColor: Color(0XFF2c9ed9),
                                //       ),
                                //     ),
                                //   ),
                              ],
                            ),
                          ),
                  ),
            Visibility(
              visible: !isPartySelected,
              child: Expanded(
                child: Center(
                  child: Text(
                    'Please select a party to see details.',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.red,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // bottomSheet: isDrawerOpen
      //     ? Container(
      //         height: MediaQuery.of(context).size.height * 0.5,
      //         decoration: BoxDecoration(
      //           color: Colors.white,
      //           borderRadius: BorderRadius.only(
      //             topLeft: Radius.circular(20),
      //             topRight: Radius.circular(20),
      //           ),
      //           boxShadow: [
      //             BoxShadow(
      //               color: Colors.grey.withOpacity(0.5),
      //               spreadRadius: 5,
      //               blurRadius: 7,
      //               offset: Offset(0, 3), // changes position of shadow
      //             ),
      //           ],
      //         ),
      //         child: Padding(
      //           padding: const EdgeInsets.all(16.0),
      //           child: SingleChildScrollView(
      //             child: Column(
      //               children: [
      //                 Row(
      //                   mainAxisAlignment: MainAxisAlignment.end,
      //                   children: [
      //                     GestureDetector(
      //                       onTap: () {
      //                         setState(() {
      //                           isDrawerOpen = false;
      //                         });
      //                       },
      //                       child: Icon(Icons.close),
      //                     ),
      //                   ],
      //                 ),
      //                 ListView.builder(
      //                   shrinkWrap: true,
      //                   physics: NeverScrollableScrollPhysics(),
      //                   itemCount: selectedPurchases.length,
      //                   itemBuilder: (context, index) {
      //                     final purchase = selectedPurchases[index];
      //                     return ListTile(
      //                       title: Text(
      //                           "Vouch No : " + purchase.vouchNo.toString()),
      //                       subtitle: Text(
      //                           'Due Amount : \₹ ${formatAmount(double.tryParse(purchase.osAmt.toString()) ?? 0.0)}'),
      //                     );
      //                   },
      //                 ),
      //                 Divider(),
      //                 Row(
      //                   mainAxisAlignment: MainAxisAlignment.start,
      //                   children: [
      //                     Text(
      //                       'Total: \₹ ${formatAmount(calculateSelectedAmount())}',
      //                       style: TextStyle(
      //                           fontSize: 16, fontWeight: FontWeight.bold),
      //                     ),
      //                   ],
      //                 ),
      //                 SizedBox(height: 10),
      //                 Row(
      //                   mainAxisAlignment: MainAxisAlignment.start,
      //                   children: [
      //                     Text(
      //                       'Payment Options:',
      //                       style: TextStyle(
      //                           fontSize: 16, fontWeight: FontWeight.bold),
      //                     ),
      //                   ],
      //                 ),
      //                 SizedBox(height: 15),
      //                 DateTimePicker(
      //                   controller: toDateController,
      //                   decoration: InputDecoration(
      //                       contentPadding: EdgeInsets.symmetric(
      //                           vertical: 10.0, horizontal: 8),
      //                       border: OutlineInputBorder(
      //                           borderRadius: BorderRadius.circular(8)),
      //                       hintText: "Select date"),
      //                   firstDate: DateTime(-21000),
      //                   initialDate: DateTime.now(),
      //                   lastDate: DateTime(21000),
      //                   dateLabelText: 'Select Date',
      //                   validator: (val) {
      //                     print(val);
      //                     return null;
      //                   },
      //                 ),
      //                 SizedBox(height: 15),
      //                 Row(
      //                   mainAxisAlignment: MainAxisAlignment.start,
      //                   children: [
      //                     Visibility(
      //                       visible: false,
      //                       child: Expanded(
      //                         child: DropdownButtonFormField<String>(
      //                           decoration: InputDecoration(
      //                             contentPadding: EdgeInsets.symmetric(
      //                                 horizontal: 12, vertical: 8),
      //                             border: OutlineInputBorder(),
      //                             labelText: 'Payment Mode',
      //                           ),
      //                           value: selectedPaymentMode,
      //                           items:
      //                               ['Bill Wise', 'Account Wise'].map((mode) {
      //                             return DropdownMenuItem<String>(
      //                               value: mode,
      //                               child: Text(mode),
      //                             );
      //                           }).toList(),
      //                           onChanged: (value) {
      //                             setState(() {
      //                               selectedPaymentMode = value!;
      //                               if (value == 'Account Wise') {
      //                                 _isOnAccount = true;
      //                                 _amountController.clear();
      //                                 _amountError = '';
      //                               } else {
      //                                 _isOnAccount = false;
      //                                 _amountController.clear();
      //                                 _amountError = '';
      //                               }
      //                             });
      //                           },
      //                         ),
      //                       ),
      //                     ),
      //                     //SizedBox(width: 10),
      //                     Expanded(
      //                       child: DropdownButtonFormField<String>(
      //                         decoration: InputDecoration(
      //                           contentPadding: EdgeInsets.symmetric(
      //                               horizontal: 12, vertical: 8),
      //                           border: OutlineInputBorder(),
      //                           labelText: 'Payment Mode',
      //                         ),
      //                         value: selectedBankId,
      //                         items: bankList.map((firm) {
      //                           return DropdownMenuItem<String>(
      //                             value: firm['cashBnkCd'].toString(),
      //                             child: Text(firm['BankName'].toString()),
      //                           );
      //                         }).toList(),
      //                         onChanged: (String? newValue) {
      //                           setState(() {
      //                             selectedBankId = newValue;
      //                             // selectedBankName = bankList.firstWhere(
      //                             //     (firm) =>
      //                             //         firm['cashBnkCd'] ==
      //                             //         newValue)['BankName'];
      //
      //                             var selectedBank = bankList.firstWhere(
      //                                 (firm) => firm['cashBnkCd'] == newValue);
      //                             selectedBankName =
      //                                 selectedBank['BankName'].toString();
      //                             groupCode =
      //                                 selectedBank['GroupCode'].toString();
      //
      //                             if (groupCode == '88') {
      //                               _isCheckAccount = false;
      //                               _checkController.clear();
      //                             } else {
      //                               _isCheckAccount = true;
      //                               _checkController.clear();
      //                             }
      //
      //                             /*selectedPaymentType = newValue!;
      //                             if (newValue == 'Cheque') {
      //                               _isCheckAccount = true;
      //                               _checkController.clear();
      //                               _checkError = '';
      //                             } else {
      //                               _isCheckAccount = false;
      //                               _checkController.clear();
      //                               _checkError = '';
      //                             }*/
      //                           });
      //                         },
      //
      //                         /*value: selectedPaymentType,
      //                         items: ['Cash', 'Cheque', 'UPI'].map((type) {
      //                           return DropdownMenuItem<String>(
      //                             value: type,
      //                             child: Text(type),
      //                           );
      //                         }).toList(),
      //                         onChanged: (value) {
      //                           setState(() {
      //                             selectedPaymentType = value!;
      //                             if (value == 'Cheque') {
      //                               _isCheckAccount = true;
      //                               _checkController.clear();
      //                               _checkError = '';
      //                             } else {
      //                               _isCheckAccount = false;
      //                               _checkController.clear();
      //                               _checkError = '';
      //                             }
      //                           });
      //                         },*/
      //                       ),
      //                     ),
      //                   ],
      //                 ),
      //                 SizedBox(height: 15),
      //                 Visibility(
      //                   visible: _isCheckAccount,
      //                   //visible: true,
      //                   child: Padding(
      //                     padding: const EdgeInsets.symmetric(vertical: 8.0),
      //                     child: TextFormField(
      //                       controller: _checkController,
      //                       decoration: InputDecoration(
      //                         contentPadding: EdgeInsets.symmetric(
      //                             horizontal: 12, vertical: 8),
      //                         labelText: 'Enter Check No',
      //                         border: OutlineInputBorder(
      //                           borderSide: BorderSide(
      //                             color: _checkError.isEmpty
      //                                 ? Colors.grey
      //                                 : Colors.red,
      //                           ),
      //                         ),
      //                         errorBorder: OutlineInputBorder(
      //                           borderSide: BorderSide(color: Colors.red),
      //                         ),
      //                         focusedBorder: OutlineInputBorder(
      //                           borderSide:
      //                               BorderSide(color: Color(0XFF2c9ed9)),
      //                         ),
      //                         enabledBorder: OutlineInputBorder(
      //                           borderSide: BorderSide(
      //                             color: _checkError.isEmpty
      //                                 ? Colors.grey
      //                                 : Colors.red,
      //                           ),
      //                         ),
      //                         filled: true,
      //                         fillColor: Colors.white,
      //                         // errorText:
      //                         // _checkError.isNotEmpty ? _checkError : null,
      //                       ),
      //                     ),
      //                   ),
      //                 ),
      //                 Visibility(
      //                   //visible: _isCheckAccount,
      //                   visible: true,
      //                   child: Padding(
      //                     padding: const EdgeInsets.symmetric(vertical: 8.0),
      //                     child: TextFormField(
      //                       controller: _remarksController,
      //                       decoration: InputDecoration(
      //                         contentPadding: EdgeInsets.symmetric(
      //                             horizontal: 12, vertical: 8),
      //                         labelText: 'Enter Remarks',
      //                         border: OutlineInputBorder(
      //                           borderSide: BorderSide(
      //                             color: _checkError.isEmpty
      //                                 ? Colors.grey
      //                                 : Colors.red,
      //                           ),
      //                         ),
      //                         errorBorder: OutlineInputBorder(
      //                           borderSide: BorderSide(color: Colors.red),
      //                         ),
      //                         focusedBorder: OutlineInputBorder(
      //                           borderSide:
      //                               BorderSide(color: Color(0XFF2c9ed9)),
      //                         ),
      //                         enabledBorder: OutlineInputBorder(
      //                           borderSide: BorderSide(
      //                             color: _checkError.isEmpty
      //                                 ? Colors.grey
      //                                 : Colors.red,
      //                           ),
      //                         ),
      //                         filled: true,
      //                         fillColor: Colors.white,
      //                       ),
      //                     ),
      //                   ),
      //                 ),
      //                 Visibility(
      //                   visible: _isOnAccount,
      //                   child: Padding(
      //                     padding: const EdgeInsets.all(8.0),
      //                     child: TextFormField(
      //                       controller: _amountController,
      //                       keyboardType: TextInputType.number,
      //                       decoration: InputDecoration(
      //                         contentPadding: EdgeInsets.symmetric(
      //                             horizontal: 12, vertical: 8),
      //                         labelText: 'Amount',
      //                         hintText: 'Settle amount',
      //                         border: OutlineInputBorder(
      //                           borderSide: BorderSide(
      //                             color: _amountError.isEmpty
      //                                 ? Colors.grey
      //                                 : Colors.red,
      //                           ),
      //                         ),
      //                         errorBorder: OutlineInputBorder(
      //                           borderSide: BorderSide(color: Colors.red),
      //                         ),
      //                         focusedBorder: OutlineInputBorder(
      //                           borderSide:
      //                               BorderSide(color: Color(0XFF2c9ed9)),
      //                         ),
      //                         enabledBorder: OutlineInputBorder(
      //                           borderSide: BorderSide(
      //                             color: _amountError.isEmpty
      //                                 ? Colors.grey
      //                                 : Colors.red,
      //                           ),
      //                         ),
      //                         filled: true,
      //                         fillColor: Colors.white,
      //                         errorText:
      //                             _amountError.isNotEmpty ? _amountError : null,
      //                       ),
      //                       validator: (value) {
      //                         if (value == null || value.isEmpty) {
      //                           return 'Please enter amount';
      //                         }
      //                         return null;
      //                       },
      //                     ),
      //                   ),
      //                 ),
      //                 SizedBox(height: 20),
      //                 ElevatedButton(
      //                   onPressed: () {
      //                     /*if (_isOnAccount) {
      //                       if (_amountController.text.isEmpty) {
      //                         setState(() {
      //                           _amountError = 'Please enter amount';
      //                         });
      //                       } else {
      //                         setState(() {
      //                           _amountError = '';
      //                         });
      //                         finalizePayment();
      //                       }
      //                     }else if (_isCheckAccount) {
      //                       if (_checkController.text.isEmpty) {
      //                         setState(() {
      //                           _checkError = 'Please enter check no';
      //                         });
      //                       } else {
      //                         setState(() {
      //                           _amountError = '';
      //                         });
      //                         finalizePayment();
      //                       }
      //                     } else {
      //                       finalizePayment();
      //                     }*/
      //
      //                     finalizePayment();
      //                   },
      //                   child: Text(
      //                     'Finalize',
      //                     style: TextStyle(color: Colors.white),
      //                   ),
      //                   style: ElevatedButton.styleFrom(
      //                     minimumSize: Size(double.infinity, 50),
      //                     backgroundColor: Color(0XFF2c9ed9),
      //                   ),
      //                 ),
      //               ],
      //             ),
      //           ),
      //         ),
      //       )
      //     : null,
    );
  }

  void showBottomSheetDialogQuickSave(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context)
                    .viewInsets
                    .bottom, // Adjusts for keyboard visibility
              ),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                height: 600,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(Icons.close),
                          ),
                        ],
                      ),
                      // ListView.builder(
                      //   shrinkWrap: true,
                      //   physics: NeverScrollableScrollPhysics(),
                      //   itemCount: selectedPurchases.length,
                      //   itemBuilder: (context, index) {
                      //     final purchase = selectedPurchases[index];
                      //     return ListTile(
                      //       title:
                      //           Text("Vouch No : " + purchase.vouchNo.toString()),
                      //       subtitle: Text(
                      //           'Due Amount : \₹ ${formatAmount(double.tryParse(purchase.osAmt.toString()) ?? 0.0)}'),
                      //     );
                      //   },
                      // ),
                      // Divider(),
                      // Text(
                      //   'Total: \₹ ${formatAmount(calculateSelectedAmount())}',
                      //   style:
                      //       TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      // ),

                      Divider(
                        color: Colors.red,
                      ),
                      Row(
                        children: [
                          // Flexible(
                          //   flex: 1, // smallest
                          //   child: Align(
                          //     alignment: Alignment.centerLeft,
                          //     child: CommonText(text: 'V.No'),
                          //   ),
                          // ),
                          Flexible(
                            flex: 3,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Bill No'),
                            ),
                          ),
                          // Flexible(
                          //   flex: 2,
                          //   child: Align(
                          //     alignment: Alignment.centerRight,
                          //     child:Text('Bill Amt'),
                          //   ),
                          // ),
                          Flexible(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('OS Amt'),
                            ),
                          ),
                          Flexible(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('Paid Amt'),
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        color: Colors.red,
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: billwise.length,
                        itemBuilder: (context, index) {
                          final purchase = billwise[index];
                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Flexible(
                                  //   flex:1,
                                  //   child: Text(purchase['vNo'].toString(),
                                  //     textAlign: TextAlign.start,
                                  //   ),
                                  // ),
                                  Flexible(
                                    flex: 3,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        purchase['billNo'].toString(),
                                        textAlign: TextAlign.start,
                                      ),
                                    ),
                                  ),
                                  // Flexible(
                                  //   flex:2,
                                  // child: Text('₹ ${formatAmount(double.tryParse(purchase['billAmt'].toString()) ?? 0.0)}',
                                  //   textAlign: TextAlign.right,
                                  // ),
                                  // ),
                                  Flexible(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '₹ ${formatAmount(double.tryParse(purchase['paid'].toString()) ?? 0.0)}',
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '₹ ${formatAmount(double.tryParse(purchase['settleAmt'].toString()) ?? 0.0)}',
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Conditionally show divider except for last index
                              if (index != billwise.length - 1) Divider(),
                            ],
                          );
                          // return ListTile(
                          //   dense: true,
                          //   visualDensity: VisualDensity(vertical: -4),
                          //   title: CommonText(
                          //     text: "Vouch No : ${purchase['vNo']}",
                          //     fontSize: AppDimensions.fontSizeRegular,
                          //     fontWeight: AppFontWeight.w600,
                          //   ),
                          //   subtitle: Row(
                          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          //     children: [
                          //       Expanded(
                          //         child: CommonText(
                          //             text:
                          //                 'OS Amt : ${Utils.formatIndianAmount(double.tryParse(purchase['paid'].toString()) ?? 0.0)}'),
                          //       ),
                          //       Expanded(
                          //         child: CommonText(
                          //             text:
                          //             'Paid Amt : ${Utils.formatIndianAmount(double.tryParse(purchase['settleAmt'].toString()) ?? 0.0)}'),
                          //       ),
                          //     ],
                          //   ),
                          // );
                        },
                      ),
                      const Divider(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Total: ₹ ${formatAmount(calculateSelectedAmount())}',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Payment Options:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 15),
                      TextFormField(
                        controller: toDateController,
                        readOnly: true, // prevent keyboard
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
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
                              toDateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(date));

                              // toDateController.text =
                              //     DateFormat("yyyy-MM-dd").format(date);
                            },
                          );
                        },
                      ),
                      // DateTimePicker(
                      //   controller: toDateController,
                      //   decoration: InputDecoration(
                      //     border: OutlineInputBorder(
                      //         borderRadius: BorderRadius.circular(8)),
                      //     hintText: "Select date",
                      //   ),
                      //   firstDate: DateTime(-21000),
                      //   initialDate: DateTime.now(),
                      //   lastDate: DateTime(21000),
                      //   dateLabelText: 'Select Date',
                      // ),
                      SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Bank',
                        ),
                        initialValue:
                            selectedBankId.isNotEmpty ? selectedBankId : null,
                        items: bankList.map((firm) {
                          return DropdownMenuItem<String>(
                            value: firm['cashBnkCd'].toString(),
                            child: Text(firm['BankName'].toString()),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedBankId = newValue!;
                            var selectedBank = bankList.firstWhere(
                                (firm) => firm['cashBnkCd'] == newValue);
                            selectedBankName =
                                selectedBank['BankName'].toString();
                            groupCode = selectedBank['GroupCode'].toString();
                            _isCheckAccount = groupCode != '88';
                            _checkController.clear();
                          });
                        },
                      ),
                      SizedBox(height: 15),
                      if (_isCheckAccount)
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Radio(
                                      visualDensity: const VisualDensity(
                                          horizontal:
                                              VisualDensity.minimumDensity,
                                          vertical:
                                              VisualDensity.minimumDensity),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      value: 'Online',
                                      groupValue: reportShowFormat.value,
                                      onChanged: (val) async {
                                        setState(() {
                                          reportShowFormat.value =
                                              val.toString();
                                        });
                                      }),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Flexible(
                                    child: Text(
                                      "Online",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Radio(
                                      visualDensity: const VisualDensity(
                                          horizontal:
                                              VisualDensity.minimumDensity,
                                          vertical:
                                              VisualDensity.minimumDensity),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      value: 'Cheque',
                                      groupValue: reportShowFormat.value,
                                      onChanged: (val) async {
                                        setState(() {
                                          reportShowFormat.value =
                                              val.toString();
                                        });
                                      }),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Flexible(
                                    child: Text(
                                      "Cheque",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      if (_isCheckAccount) SizedBox(height: 15),
                      Visibility(
                        visible: _isCheckAccount,
                        child: TextFormField(
                          controller: _checkController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            // Only allows digits
                          ],
                          decoration: InputDecoration(
                              labelText: 'Enter Check No',
                              border: OutlineInputBorder(),
                              counterText: ''),
                          maxLength: 7,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextFormField(
                        controller: _remarksController,
                        decoration: InputDecoration(
                          labelText: 'Enter Remarks',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          finalizePaymentQuickSave();
                        },
                        child: Text('Finalize',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: Color(0XFF2c9ed9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  void showBottomSheetDialogManuallySave(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      // Allows the sheet to resize based on keyboard
      useSafeArea: true,
      enableDrag: false,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding:
                    MediaQuery.of(context).viewInsets, // Adjusts for keyboard
                child: Container(
                  height: 500, // Adjust as needed
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.5),
                        spreadRadius: 5,
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        // Adjusts height dynamically
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                },
                                child: Icon(Icons.close),
                              ),
                            ],
                          ),
                          Text(
                            'Payment Options:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 15),
                          TextFormField(
                            controller: toDateController,
                            readOnly: true, // prevent keyboard
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
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
                                  toDateController.text   = Helper.toUi(DateFormat("yyyy-MM-dd").format(date));
          
                                  // toDateController.text =
                                  //     DateFormat("yyyy-MM-dd").format(date);
                                },
                              );
                            },
                          ),
                          // DateTimePicker(
                          //   controller: toDateController,
                          //   decoration: InputDecoration(
                          //     contentPadding: EdgeInsets.symmetric(
                          //         vertical: 10.0, horizontal: 8),
                          //     border: OutlineInputBorder(
                          //         borderRadius: BorderRadius.circular(8)),
                          //     hintText: "Select date",
                          //   ),
                          //   firstDate: DateTime(-21000),
                          //   initialDate: DateTime.now(),
                          //   lastDate: DateTime(21000),
                          //   dateLabelText: 'Select Date',
                          // ),
                          SizedBox(height: 15),
                          InputDecorator(
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              labelText:
                                  'Search Party (Name, Phone Number, City, Area)',
                              border: OutlineInputBorder(),
                            ),
                            child: TextButton(
                              onPressed: () => showPartySelectionMenu1(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                splashFactory: NoSplash
                                    .splashFactory, // Disable splash effect
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
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
                                      textAlign: TextAlign
                                          .start, // Ensure the text is LTR
                                    ),
                                  ),
                                  if (Provider.of<PartyProvider>(context)
                                      .party
                                      .isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        final party =
                                            Provider.of<PartyProvider>(context,
                                                listen: false);
                                        party.clearParty();
                                        setState(() {
                                          isPartySelected = false;
                                          data.clear();
                                          billAmtTotal = 0.00;
                                          paidAmtTotal = 0.00;
                                          balanceAmtTotal = 0.00;
                                          totalOSAmount = 0.00;
                                          quickSaveEnabled = false;
                                          selectedPurchases.clear();
                                        });
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
                          ),
                          SizedBox(height: 15),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(),
                              labelText: 'Payment Mode',
                            ),
                            initialValue: selectedBankId.isNotEmpty
                                ? selectedBankId
                                : null,
                            items: bankList.map((firm) {
                              return DropdownMenuItem<String>(
                                value: firm['cashBnkCd'].toString(),
                                child: Text(firm['BankName'].toString()),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedBankId = newValue!;
                                var selectedBank = bankList.firstWhere(
                                    (firm) => firm['cashBnkCd'] == newValue);
                                selectedBankName =
                                    selectedBank['BankName'].toString();
                                groupCode =
                                    selectedBank['GroupCode'].toString();
          
                                _isCheckAccount = groupCode != '88';
                                _checkController.clear();
                              });
                            },
                          ),
                          SizedBox(height: 15),
                          if (_isCheckAccount)
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Radio(
                                          visualDensity: const VisualDensity(
                                              horizontal:
                                                  VisualDensity.minimumDensity,
                                              vertical:
                                                  VisualDensity.minimumDensity),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          value: 'Online',
                                          groupValue: reportShowFormat.value,
                                          onChanged: (val) async {
                                            setState(() {
                                              reportShowFormat.value =
                                                  val.toString();
                                            });
                                          }),
                                      SizedBox(
                                        width: 5,
                                      ),
                                      Flexible(
                                        child: Text(
                                          "Online",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Radio(
                                          visualDensity: const VisualDensity(
                                              horizontal:
                                                  VisualDensity.minimumDensity,
                                              vertical:
                                                  VisualDensity.minimumDensity),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          value: 'Check',
                                          groupValue: reportShowFormat.value,
                                          onChanged: (val) async {
                                            setState(() {
                                              reportShowFormat.value =
                                                  val.toString();
                                            });
                                          }),
                                      SizedBox(
                                        width: 5,
                                      ),
                                      Flexible(
                                        child: Text(
                                          "Cheque",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          if (_isCheckAccount) SizedBox(height: 15),
          
                          if (_isCheckAccount)
                            TextFormField(
                              controller: _checkController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                // Only allows digits
                              ],
                              decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  labelText: 'Enter Check No',
                                  border: OutlineInputBorder(),
                                  counterText: ''),
                              maxLength: 7,
                            ),
                          if (_isCheckAccount) SizedBox(height: 15),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              // Only allows digits
                            ],
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              labelText: 'Amount',
                              hintText: 'Settle amount',
                              border: OutlineInputBorder(),
                              errorText:
                                  _amountError.isNotEmpty ? _amountError : null,
                            ),
                          ),
                          SizedBox(height: 15),
                          TextFormField(
                            controller: _remarksController,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              labelText: 'Enter Remarks',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          SizedBox(height: 15),
                          ElevatedButton(
                            onPressed: () {
                              finalizePaymentManuallySave();
                            },
                            child: Text(
                              'Finalize',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50),
                              backgroundColor: Color(0XFF2c9ed9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
