// To parse this JSON data, do
//
//     final accountLEadgerReportModal = accountLEadgerReportModalFromJson(jsonString);

import 'dart:convert';

AccountLEadgerReportModal accountLEadgerReportModalFromJson(String str) =>
    AccountLEadgerReportModal.fromJson(json.decode(str));

String accountLEadgerReportModalToJson(AccountLEadgerReportModal data) =>
    json.encode(data.toJson());

AccountLEadgerDetailReportModal accountLEadgerDetailReportModalFromJson(
        String str) =>
    AccountLEadgerDetailReportModal.fromJson(json.decode(str));

String accountLEadgerDetailReportModalToJson(
        AccountLEadgerDetailReportModal data) =>
    json.encode(data.toJson());

AccountLEadgerBillWiseDetailReportModal
    accountLEadgerBillWiseDetailReportModalFromJson(String str) =>
        AccountLEadgerBillWiseDetailReportModal.fromJson(json.decode(str));

String accountLEadgerBillWiseDetailReportModalToJson(
        AccountLEadgerBillWiseDetailReportModal data) =>
    json.encode(data.toJson());

class AccountLEadgerReportModal {
  AccountLEadgerReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumAccountLeager> data;

  factory AccountLEadgerReportModal.fromJson(Map<String, dynamic> json) =>
      AccountLEadgerReportModal(
        message: json["message"],
        data: List<DatumAccountLeager>.from(
            json["data"].map((x) => DatumAccountLeager.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class AccountLEadgerDetailReportModal {
  AccountLEadgerDetailReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<Detail> data;

  factory AccountLEadgerDetailReportModal.fromJson(Map<String, dynamic> json) =>
      AccountLEadgerDetailReportModal(
        message: json["message"],
        data: List<Detail>.from(json["data"].map((x) => Detail.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class AccountLEadgerBillWiseDetailReportModal {
  AccountLEadgerBillWiseDetailReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<BillWiseDetail> data;

  factory AccountLEadgerBillWiseDetailReportModal.fromJson(
          Map<String, dynamic> json) =>
      AccountLEadgerBillWiseDetailReportModal(
        message: json["message"],
        data: List<BillWiseDetail>.from(
            json["data"].map((x) => BillWiseDetail.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumAccountLeager {
  DatumAccountLeager(
      {required this.vouchDt,
      required this.vouchNo,
      required this.bookCd,
      required this.billno,
      required this.accName,
      required this.accCd,
      required this.drAmt,
      required this.crAmt,
      required this.narration,
      this.clBal,
      this.partyCd,
      this.partyTcd,
      this.syncId});

  dynamic vouchDt;
  dynamic vouchNo;
  String bookCd;
  dynamic billno;
  dynamic accName;
  dynamic accCd;
  dynamic drAmt;
  dynamic crAmt;
  dynamic clBal;
  dynamic narration;
  dynamic partyTcd;
  dynamic partyCd;
  dynamic syncId;

  factory DatumAccountLeager.fromJson(Map<String, dynamic> json) =>
      DatumAccountLeager(
        vouchDt: json["VOUCH_DT"],
        vouchNo: json["VOUCH_NO"],
        bookCd: json["BOOK_CD"],
        billno: json["BILL_NO"],
        accName: json["ACC_NAME"],
        accCd: json["ACC_CD"],
        drAmt: json["DR_AMT"] ?? 0,
        crAmt: json["CR_AMT"] ?? 0,
        narration: json["NARRATION"],
        clBal: json['CL_BAL'],
        partyTcd: json['PARTY_TCD'],
        partyCd: json['PARTY_CD'],
        syncId: json['SYNC_ID'],
      );

  Map<String, dynamic> toJson() => {
        "VOUCH_DT": vouchDt,
        "BOOK_CD": bookCd,
        "VOUCH_NO": vouchNo,
        "BILL_NO": billno,
        "ACC_NAME": accName,
        "ACC_CD": accCd,
        "DR_AMT": drAmt,
        "CR_AMT": crAmt,
        "NARRATION": narration,
        "CL_BAL": clBal,
        "PARTY_TCD": partyTcd,
        "PARTY_CD": partyCd,
        "SYNC_ID": syncId
      };
}

class Detail {
  Detail({
    required this.itemCd,
    required this.sizeCd,
    required this.qty,
    required this.otherDesc,
    required this.rate,
    required this.vouchAmt,
    required this.item,
  });

  String itemCd;
  String sizeCd;
  dynamic qty;
  dynamic otherDesc;
  dynamic rate;
  dynamic vouchAmt;
  Item item;

  factory Detail.fromJson(Map<String, dynamic> json) => Detail(
      itemCd: json["ITEM_CD"],
      sizeCd: json['SIZE_CD'],
      qty: json['QUANTITY'],
      otherDesc: json['OTHER_DESC'],
      rate: json['RATE'],
      vouchAmt: json['VOUCH_AMT'],
      item: Item.fromJson(json['item']));

  Map<String, dynamic> toJson() => {
        "ITEM_CD": itemCd,
        "SIZE_CD": sizeCd,
        "QUANTITY": qty,
        "OTHER_DESC": otherDesc,
        "RATE": rate,
        "VOUCH_AMT": vouchAmt,
        "item": item
      };
}

class BillWiseDetail {
  BillWiseDetail({
    required this.blBookCd,
    required this.blVDt,
    required this.blBillNo,
    required this.blAmt,
    required this.blPaid,
  });

  String blBookCd;
  dynamic blVDt;
  dynamic blBillNo;
  dynamic blAmt;
  dynamic blPaid;

  factory BillWiseDetail.fromJson(Map<String, dynamic> json) => BillWiseDetail(
        blBookCd: json["BL_BOOK_CD"],
        blVDt: json['BL_V_DT'],
        blBillNo: json['BL_BILL_NO'],
        blAmt: json['BL_AMOUNT'],
        blPaid: json['BL_PAID'],
      );

  Map<String, dynamic> toJson() => {
        "BL_BOOK_CD": blBookCd,
        "BL_V_DT": blVDt,
        "BL_BILL_NO": blBillNo,
        "BL_AMOUNT": blAmt,
        "BL_PAID": blAmt,
      };
}

class Item {
  dynamic nrate;
  dynamic avlStk;
  dynamic exDt;
  dynamic itemCd;
  dynamic itemName;
  dynamic itemSname;
  dynamic itemLname;
  dynamic deptCd;
  dynamic srate1;
  dynamic srate3;
  dynamic cStk;
  dynamic orStk;
  dynamic syncId;
  dynamic frmlSrt1;
  dynamic sdisc;
  dynamic sdisc1;

  Item(
      {required this.nrate,
      required this.avlStk,
      this.exDt,
      required this.itemCd,
      required this.itemName,
      required this.itemSname,
      required this.itemLname,
      required this.deptCd,
      required this.srate1,
      required this.srate3,
      required this.cStk,
      this.orStk,
      required this.syncId,
      required this.frmlSrt1,
      required this.sdisc,
      required this.sdisc1});

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        nrate: json["NRATE"],
        avlStk: json["AVL_STK"],
        exDt: json["EX_DT"],
        itemCd: json["ITEM_CD"],
        itemName: json["ITEM_NAME"],
        itemSname: json["ITEM_SNAME"],
        itemLname: json["ITEM_LNAME"],
        deptCd: json["DEPT_CD"],
        srate1: json["SRATE1"]?.toDouble(),
        srate3: json["SRATE3"],
        cStk: json["C_STK"],
        orStk: json["OR_STK"],
        syncId: json["SYNC_ID"],
        frmlSrt1: json["FRML_SRT1"],
        sdisc: json["SDISC"],
        sdisc1: json["SDISC1"],
      );

  Map<String, dynamic> toJson() => {
        "NRATE": nrate,
        "AVL_STK": avlStk,
        "EX_DT": exDt,
        "ITEM_CD": itemCd,
        "ITEM_NAME": itemName,
        "ITEM_SNAME": itemSname,
        "ITEM_LNAME": itemLname,
        "DEPT_CD": deptCd,
        "SRATE1": srate1,
        "SRATE3": srate3,
        "C_STK": cStk,
        "OR_STK": orStk,
        "SYNC_ID": syncId,
        "FRML_SRT1": frmlSrt1,
        "SDISC": sdisc,
        "SDISC1": sdisc1
      };
}
