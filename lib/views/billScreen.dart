import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:arham_corporation/config/app_config.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';

import '../providers/bill_provider.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  TextEditingController dateClt = TextEditingController();
  var selectedCashBank;

  @override
  void initState() {
    super.initState();
    dateClt.text = DateFormat("yyyy-MM-dd").format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        context.read<BillProvider>().clearList();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Bill"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Step3Widget(),
        ),
      ),
    );
  }

  Widget Step3Widget() {
    return SingleChildScrollView(
      child: Consumer<BillProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.centerLeft,
                      padding:
                      EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
                      child: TextFormField(
                        decoration: InputDecoration(
                            label: Text("Voucher No"),
                            hintText: "Voucher No",
                            isDense: true,
                            border: InputBorder.none),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 15,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        DatePicker.showDatePicker(context,
                            showTitleActions: true,
                            minTime: DateTime(2000, 1, 1),
                            maxTime: DateTime.now(), onConfirm: (date) {
                              setState(() {
                                dateClt.text =
                                    DateFormat('yyyy-MM-dd').format(date);
                              });
                            },
                            currentTime: dateClt.text.isNotEmpty
                                ? DateTime.parse(dateClt.text)
                                : DateTime.now(),
                            locale: LocaleType.en);
                      },
                      child: AbsorbPointer(
                        child: Container(
                          decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(
                              left: 8, right: 8, top: 2, bottom: 2),
                          child: TextFormField(
                            controller: dateClt,
                            decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                label: Text("Date"),
                                hintText: "Select date"),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 15,
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.centerLeft,
                      padding:
                      EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2(
                          isExpanded: true,
                          hint: Text(
                            'Select Cash/Bank',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                          items: [
                            "A",
                            "A",
                            "A",
                            "A",
                          ]
                              .map((item) => DropdownMenuItem(
                            value: item,
                            child: Padding(
                              padding:
                              EdgeInsets.only(left: 15, right: 15),
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ))
                              .toList(),
                          value: selectedCashBank,
                          onChanged: (value) {
                            setState(() {
                              selectedCashBank = value;
                            });
                          },
                          buttonStyleData:
                          ButtonStyleData(padding: EdgeInsets.zero),
                          menuItemStyleData:
                          MenuItemStyleData(padding: EdgeInsets.zero),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 15,
                  ),
                  Expanded(child: Text("AU SMALL FINANCE BANK"))
                ],
              ),
              SizedBox(
                height: 15,
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.centerLeft,
                      padding:
                      EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2(
                          isExpanded: true,
                          hint: Text(
                            'Select Party',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                          items: [
                            "A",
                            "A",
                            "A",
                            "A",
                          ]
                              .map((item) => DropdownMenuItem(
                            value: item,
                            child: Padding(
                              padding:
                              EdgeInsets.only(left: 15, right: 15),
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ))
                              .toList(),
                          value: selectedCashBank,
                          onChanged: (value) {
                            setState(() {
                              selectedCashBank = value;
                            });
                          },
                          buttonStyleData:
                          ButtonStyleData(padding: EdgeInsets.zero),
                          menuItemStyleData:
                          MenuItemStyleData(padding: EdgeInsets.zero),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 15,
                  ),
                  Expanded(child: Text("ALIF MEDICAL STORE"))
                ],
              ),
              SizedBox(
                height: 15,
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.centerLeft,
                      padding:
                      EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          label: Text("Amount"),
                          hintText: "Amount",
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 15,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.centerLeft,
                      padding:
                      EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            label: Text("Cheque No . "),
                            hintText: "Cheque No",
                            isDense: true,
                            border: InputBorder.none),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 15,
              ),
              Container(
                height: 120,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.topLeft,
                padding: EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
                child: TextFormField(
                  maxLines: null,
                  decoration: InputDecoration(
                      label: Text("Remark"),
                      hintText: "Remark",
                      isDense: true,
                      border: InputBorder.none),
                ),
              ),
              SizedBox(
                height: 15,
              ),
              Container(
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton2(
                    isExpanded: true,
                    hint: Text(
                      'Type',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    items: [
                      "Bill Wise",
                    ]
                        .map((item) => DropdownMenuItem(
                      value: item,
                      child: Padding(
                        padding: EdgeInsets.only(left: 15, right: 15),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ))
                        .toList(),
                    value: selectedCashBank,
                    onChanged: (value) {
                      setState(() {
                        selectedCashBank = value;
                      });
                    },
                    buttonStyleData: ButtonStyleData(padding: EdgeInsets.zero),
                    menuItemStyleData:
                    MenuItemStyleData(padding: EdgeInsets.zero),
                  ),
                ),
              ),
              SizedBox(
                height: 25,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () {
                        showBillSelectedBottomSheet();
                      },
                      child: Text("Add Bill")),
                ],
              ),
              SizedBox(
                height: 15,
              ),
              Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(
                              "Sr",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.sp),
                            )),
                        VerticalDivider(),
                        Expanded(
                            flex: 2,
                            child: Text(
                              "Key",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.sp),
                            )),
                        VerticalDivider(),
                        Expanded(
                            flex: 2,
                            child: Text(
                              "Book",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.sp),
                            )),
                        VerticalDivider(),
                        Expanded(
                            flex: 2,
                            child: Text(
                              "V.No",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.sp),
                            )),
                        VerticalDivider(),
                        Expanded(
                            flex: 2,
                            child: Text(
                              "Date",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.sp),
                            )),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 5.h,
                  ),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(
                              "Ref.No",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.sp),
                            )),
                        VerticalDivider(),
                        Expanded(
                            flex: 2,
                            child: Text(
                              "Bill Amt",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.sp),
                            )),
                        VerticalDivider(),
                        Expanded(
                            flex: 2,
                            child: Text(
                              "Dr/Cr Note",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.sp),
                            )),
                        VerticalDivider(),
                        Expanded(
                            flex: 2,
                            child: Text(
                              "Kasar",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.sp),
                            )),
                        VerticalDivider(),
                        Expanded(
                            flex: 2,
                            child: Text(
                              "Paid",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12.sp),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 15,
              ),
              ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: provider.selectedIndex.length,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: index % 2 == 0
                                ? Colors.white
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(child: Text("${index + 1}")),
                                  VerticalDivider(),
                                  Expanded(flex: 2, child: Text("SA 1920")),
                                  VerticalDivider(),
                                  Expanded(flex: 2, child: Text("SA")),
                                  VerticalDivider(),
                                  Expanded(flex: 2, child: Text("1920")),
                                  VerticalDivider(),
                                  Expanded(flex: 2, child: Text("26/07/2023")),
                                ],
                              ),
                            ),
                            Divider(),
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(child: Text("D")),
                                  VerticalDivider(),
                                  Expanded(flex: 2, child: Text("RO1918")),
                                  VerticalDivider(),
                                  Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        decoration:
                                        InputDecoration(hintText: "Dr/Cr"),
                                        keyboardType: TextInputType.number,
                                      )),
                                  VerticalDivider(),
                                  Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        decoration:
                                        InputDecoration(hintText: "Kasar"),
                                        keyboardType: TextInputType.number,
                                      )),
                                  VerticalDivider(),
                                  Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        decoration:
                                        InputDecoration(hintText: "Paid"),
                                        keyboardType: TextInputType.number,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              InkWell(
                onTap: () {},
                child: Container(
                    height: 50.h,
                    decoration: BoxDecoration(
                        color: AppConfig.mainColor,
                        borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    padding:
                    EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
                    child: Text(
                      "Save",
                      style: TextStyle(color: Colors.white, fontSize: 18.sp),
                    )),
              ),
            ],
          );
        },
      ),
    );
  }

  showBillSelectedBottomSheet() {
    showModalBottomSheet(
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(25.0),
          ),
        ),
        context: context,
        builder: (context) {
          return Consumer<BillProvider>(
            builder: (context, provider, child) {
              return Container(
                padding: EdgeInsets.only(left: 8, right: 8),
                height: 600,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CupertinoSearchTextField(
                          controller: provider.searchItemCltt,
                          onChanged: (value) {
                            setState(() {});
                          }),
                    ),
                    SizedBox(
                      height: 5.h,
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(
                                      "Key",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    )),
                                VerticalDivider(),
                                Expanded(
                                    child: Text(
                                      "Book",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    )),
                                VerticalDivider(),
                                Expanded(
                                    child: Text(
                                      "V.No",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    )),
                                VerticalDivider(),
                                Expanded(
                                    child: Text(
                                      "Date",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    )),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 5.h,
                          ),
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(
                                      "C/D",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    )),
                                VerticalDivider(),
                                Expanded(
                                    child: Text(
                                      "Ref.No",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    )),
                                VerticalDivider(),
                                Expanded(
                                    child: Text(
                                      "Bill Amt",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    )),
                                VerticalDivider(),
                                Expanded(
                                    child: Text(
                                      "O/S Amt",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(),
                    Expanded(
                      child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: 10,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: InkWell(
                                onTap: () {
                                  provider.addRemoveItem(index);
                                },
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: provider.selectedIndex
                                          .contains(index)
                                          ? AppConfig.mainColor.withOpacity(0.3)
                                          : index % 2 == 0
                                          ? Colors.white
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                    children: [
                                      IntrinsicHeight(
                                        child: Row(
                                          children: [
                                            Expanded(child: Text("SA 1920")),
                                            VerticalDivider(),
                                            Expanded(child: Text("SA")),
                                            VerticalDivider(),
                                            Expanded(child: Text("1920")),
                                            VerticalDivider(),
                                            Expanded(child: Text("26/07/2023")),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height: 5.h,
                                      ),
                                      IntrinsicHeight(
                                        child: Row(
                                          children: [
                                            Expanded(child: Text("D")),
                                            VerticalDivider(),
                                            Expanded(child: Text("RO1918")),
                                            VerticalDivider(),
                                            Expanded(child: Text("547.00")),
                                            VerticalDivider(),
                                            Expanded(child: Text("547.00")),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                    )
                  ],
                ),
              );
            },
          );
        });
  }
}

