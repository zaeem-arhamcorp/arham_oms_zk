// To parse this JSON data, do
//
//     final itemLeadgerReportModal = itemLeadgerReportModalFromJson(jsonString);

import 'dart:convert';

ItemLeadgerReportModal itemLeadgerReportModalFromJson(String str) =>
    ItemLeadgerReportModal.fromJson(json.decode(str));

String itemLeadgerReportModalToJson(ItemLeadgerReportModal data) =>
    json.encode(data.toJson());

class ItemLeadgerReportModal {
  ItemLeadgerReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumItermLedger> data;

  factory ItemLeadgerReportModal.fromJson(Map<String, dynamic> json) =>
      ItemLeadgerReportModal(
        message: json["message"],
        data: List<DatumItermLedger>.from(
            json["data"].map((x) => DatumItermLedger.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumItermLedger {
  DatumItermLedger(
      {required this.vouchDt,
      required this.bookCd,
      required this.itemCd,
      required this.refNo,
      required this.quantity,
      this.rate,
      required this.vouchAmt,
      this.item,
      required this.account,
      required this.crAmt,
      required this.drAmt,
      required this.sizeCd,
      required this.clStk,
      required this.otherDesc});

  dynamic vouchDt;
  String bookCd;
  String itemCd;
  String refNo;
  dynamic quantity;
  double? rate;
  dynamic vouchAmt;
  dynamic crAmt;
  dynamic drAmt;
  dynamic sizeCd;
  dynamic clStk;
  dynamic otherDesc;

  Item? item;
  Account account;

  factory DatumItermLedger.fromJson(Map<String, dynamic> json) =>
      DatumItermLedger(
        vouchDt: json["VOUCH_DT"],
        bookCd: json["BOOK_CD"],
        itemCd: json["ITEM_CD"],
        refNo: json["REF_NO"],
        quantity: json["QUANTITY"],
        rate: json["RATE"]?.toDouble(),
        vouchAmt: json["VOUCH_AMT"],
        crAmt: json['CR_AMT'],
        drAmt: json['DR_AMT'],
        clStk: json["CL_STK"],
        sizeCd: json['SIZE_CD'],
        otherDesc: json["OTHER_DESC"],
        item: Item.fromJson(json["item"]),
        account: Account.fromJson(json["account"]),
      );

  Map<String, dynamic> toJson() => {
        "VOUCH_DT":
            "${vouchDt.year.toString().padLeft(4, '0')}-${vouchDt.month.toString().padLeft(2, '0')}-${vouchDt.day.toString().padLeft(2, '0')}",
        "BOOK_CD": bookCd,
        "ITEM_CD": itemCd,
        "REF_NO": refNo,
        "QUANTITY": quantity,
        "RATE": rate,
        "CR_AMT": crAmt,
        "DR_AMT": drAmt,
        "SIZE_CD": sizeCd,
        "CL_STK": clStk,
        "OTHER_DESC": otherDesc,
        "VOUCH_AMT": vouchAmt,
        "item": item!.toJson(),
        "account": account.toJson(),
      };
}

class Account {
  Account({
    required this.accName,
    required this.accCd,
  });

  String accName;
  String accCd;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        accName: json["ACC_NAME"],
        accCd: json["ACC_CD"],
      );

  Map<String, dynamic> toJson() => {
        "ACC_NAME": accName,
        "ACC_CD": accCd,
      };
}

class Item {
  Item({
    required this.itemCd,
    required this.itemName,
  });

  String itemCd;
  String itemName;

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        itemCd: json["ITEM_CD"],
        itemName: json["ITEM_NAME"],
      );

  Map<String, dynamic> toJson() => {
        "ITEM_CD": itemCd,
        "ITEM_NAME": itemName,
      };
}
